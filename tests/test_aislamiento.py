"""Aislamiento multi-tenant visto desde el codigo, no desde SQL.

db/agente/tests/test-aislamiento.sql ya verifica que las policies de RLS hacen
lo suyo. Esto verifica lo otro: que el codigo del orquestador USA esas policies
como corresponde. Un esquema perfecto no sirve de nada si el modulo de RAG se
olvida de fijar el contexto de empresa, o si lo deja pegado en una conexion que
despues se reutiliza para otro cliente.

Estos tests son los que no pueden fallar nunca.
"""
from __future__ import annotations

import pytest

from agente import rag
from agente.config import Config

EMPRESA_A = 900001
EMPRESA_B = 900002


async def _conectar_o_saltear():
    cfg = Config()
    if not cfg.db_password:
        pytest.skip("Sin AGENTE_DB_PASSWORD: se saltean los tests con base")
    try:
        return await rag.abrir(cfg)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"Base del agente no disponible: {e}")


@pytest.fixture
async def con():
    c = await _conectar_o_saltear()
    try:
        yield c
    finally:
        await c.rollback()
        await c.close()


def _vector(pos: int) -> list[float]:
    v = [0.0] * 1024
    v[pos] = 1.0
    return v


@pytest.mark.asyncio
async def test_sin_fijar_empresa_no_se_ve_nada(con):
    """Falla cerrado.

    Si el codigo se olvida de llamar a fijar_empresa, la consulta tiene que
    devolver vacio -- no todas las filas de todos los clientes.
    """
    cfg = Config()
    frags = await rag.buscar_memoria(con, cfg, EMPRESA_A, _vector(0))
    assert frags == [], "Sin contexto de empresa no se puede ver memoria"


@pytest.mark.asyncio
async def test_una_empresa_no_ve_la_memoria_de_otra(con):
    """El control central: con el contexto de A, la memoria de B no existe."""
    cfg = Config()

    # Preparacion: las particiones ya tienen que existir. Si no, se saltea:
    # el alta de empresa es un paso administrativo, no del runtime.
    async with con.cursor() as cur:
        await cur.execute(
            "SELECT count(*) AS n FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
            "WHERE n.nspname='agente' AND c.relname IN ('memoria_e900001','memoria_e900002')"
        )
        if (await cur.fetchone())["n"] < 2:
            pytest.skip(
                "Faltan las particiones de prueba. Crearlas con: "
                "SELECT agente.crear_particion_empresa(900001), agente.crear_particion_empresa(900002);"
            )

    await rag.fijar_empresa(con, EMPRESA_A)
    id_a = await rag.guardar_memoria(
        con, EMPRESA_A, "SECRETO DE A: la chancadora 7 falla los martes", _vector(5)
    )
    await rag.fijar_empresa(con, EMPRESA_B)
    id_b = await rag.guardar_memoria(
        con, EMPRESA_B, "SECRETO DE B: el molino 3 consume de mas", _vector(5)
    )

    # Con el contexto de A: se ve lo de A y no lo de B.
    await rag.fijar_empresa(con, EMPRESA_A)
    frags = await rag.buscar_memoria(con, Config(), EMPRESA_A, _vector(5))
    contenidos = " ".join(f.contenido for f in frags)
    assert "SECRETO DE A" in contenidos
    assert "SECRETO DE B" not in contenidos, "FUGA DE DATOS ENTRE CLIENTES"
    assert all(f.id != id_b for f in frags)

    # Y simetrico.
    await rag.fijar_empresa(con, EMPRESA_B)
    frags = await rag.buscar_memoria(con, Config(), EMPRESA_B, _vector(5))
    contenidos = " ".join(f.contenido for f in frags)
    assert "SECRETO DE B" in contenidos
    assert "SECRETO DE A" not in contenidos, "FUGA DE DATOS ENTRE CLIENTES"
    assert all(f.id != id_a for f in frags)

    await con.rollback()


@pytest.mark.asyncio
async def test_no_se_puede_escribir_en_la_memoria_de_otra_empresa(con):
    """Con el contexto de A, insertar como B tiene que ser rechazado."""
    import psycopg

    async with con.cursor() as cur:
        await cur.execute(
            "SELECT count(*) AS n FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
            "WHERE n.nspname='agente' AND c.relname='memoria_e900002'"
        )
        if (await cur.fetchone())["n"] < 1:
            pytest.skip("Falta la particion de prueba de la empresa 900002")

    await rag.fijar_empresa(con, EMPRESA_A)
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        await rag.guardar_memoria(con, EMPRESA_B, "escritura cruzada", _vector(9))
    await con.rollback()


@pytest.mark.asyncio
async def test_el_conocimiento_compartido_es_de_solo_lectura(con):
    """ADR-A4 verificado desde el codigo, con el usuario real del orquestador."""
    import psycopg

    # Leer, si.
    frags = await rag.buscar_conocimiento(con, Config(), _vector(1))
    assert isinstance(frags, list)

    # Escribir, no.
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        async with con.cursor() as cur:
            await cur.execute(
                "INSERT INTO agente.chunk (fuente_id, contenido) VALUES (1, 'intento')"
            )
    await con.rollback()


@pytest.mark.asyncio
async def test_el_contexto_no_queda_pegado_entre_transacciones(con):
    """fijar_empresa usa SET LOCAL: el contexto muere con la transaccion.

    Importa para el dia que haya un pool: si el contexto sobreviviera al
    commit, la proxima consulta que tomara esa conexion heredaria la empresa
    de la anterior. Seria la fuga mas dificil de encontrar.
    """
    await rag.fijar_empresa(con, EMPRESA_A)
    async with con.cursor() as cur:
        await cur.execute("SELECT current_setting('agente.empr_id', true) AS e")
        assert (await cur.fetchone())["e"] == str(EMPRESA_A)

    await con.commit()

    async with con.cursor() as cur:
        await cur.execute("SELECT current_setting('agente.empr_id', true) AS e")
        heredado = (await cur.fetchone())["e"]
    assert heredado in (None, ""), (
        f"El contexto de empresa sobrevivio al commit ({heredado!r}): "
        "con un pool, la proxima consulta veria datos de la empresa anterior"
    )
