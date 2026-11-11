"""Configuracion de los agentes: Kuntur, Quirqui y Faustino (ADR-A7, AGENTE-M-01).

Tres capas:

  * La logica de acceso, sin base: quien puede usar a quien.
  * La configuracion real en agente.agente: que este, que sea coherente y que
    el runtime no la pueda modificar.
  * La API: que /agentes y /consulta respeten el acceso, y que un empleado no
    pueda ni confirmar que el Coach existe (R1).
"""
from __future__ import annotations

import base64
import json
from pathlib import Path

import psycopg
import pytest
from httpx import ASGITransport, AsyncClient

from agente import agentes, rag
from agente.agentes import Agente
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto

RAIZ = Path(__file__).resolve().parent.parent
PROMPTS = RAIZ / "prompts"

# Nombres de las tools que escriben. Ninguna puede quedar permitida (ADR-A8).
TOOLS_DE_ESCRITURA = ("man_create_ot", "alm_crear_pedido_materiales")


def _agente(**cambios) -> Agente:
    base = dict(
        clave="quirqui", nombre="Quirqui", rol="asistente", personalidad="Sos Quirqui.",
        acceso="usuario", prompt="quirqui.md", tools_permitidas=("man_get_*", "web_buscar"),
        disparadores=("consulta",), fuentes=("industria", "empresa"),
        autonomia="proponer", avatar="quirqui", activo=True,
    )
    base.update(cambios)
    return Agente(**base)


KUNTUR = _agente(clave="kuntur", nombre="Kuntur", rol="coach", acceso="admin",
                 prompt="kuntur.md", avatar="kuntur")
FAUSTINO = _agente(clave="faustino", nombre="Faustino", rol="entrevistador",
                   acceso="curador", prompt="faustino.md", avatar="faustino")


# ===================================================== acceso, sin base
@pytest.mark.parametrize("rol", ["1", 1, " 1 "])
def test_el_admin_de_dnato_puede_usar_al_coach(rol):
    assert KUNTUR.puede_usarlo(rol)


@pytest.mark.parametrize("rol", ["4", "2", "3", "8", None, "", "admin"])
def test_nadie_mas_puede_usar_al_coach(rol):
    """R1. Dnato usa numeros: 1 es administrador, el resto no."""
    assert not KUNTUR.puede_usarlo(rol)


@pytest.mark.parametrize("rol", ["1", "4", None])
def test_el_asistente_es_para_todo_el_equipo(rol):
    assert _agente().puede_usarlo(rol)


def test_el_entrevistador_no_se_ofrece_por_consulta():
    assert not FAUSTINO.puede_usarlo("1")


def test_patrones_de_tools_permitidas():
    q = _agente()
    assert q.tool_permitida("man_get_equipos")
    assert q.tool_permitida("web_buscar")
    assert not q.tool_permitida("man_create_ot")
    assert not q.tool_permitida("alm_get_stock")


def test_el_nombre_sale_de_la_configuracion_no_del_prompt():
    """Cambiar el nombre no puede obligar a editar las instrucciones."""
    otro = _agente(nombre="Tatú", personalidad="Sos Tatú.")
    sistema = otro.sistema(PROMPTS)
    assert sistema.startswith("Te llamás Tatú.")
    assert "presentate como Tatú" in sistema


def test_el_sistema_trae_las_instrucciones_sin_comentarios():
    sistema = _agente().sistema(PROMPTS)
    assert "Cuando no sabés" in sistema
    assert "<!--" not in sistema


@pytest.mark.parametrize("archivo", ["quirqui.md", "kuntur.md", "faustino.md"])
def test_existe_el_prompt_de_cada_agente(archivo):
    assert (PROMPTS / archivo).exists()


def test_ningun_prompt_habla_de_mineria_como_unica_industria():
    """ADR-A11: el producto es multi-vertical."""
    for archivo in ("quirqui.md", "kuntur.md", "faustino.md"):
        texto = (PROMPTS / archivo).read_text(encoding="utf-8").lower()
        assert "agente minero" not in texto, archivo
        assert "oil & gas" in texto, f"{archivo} no nombra las otras verticales"


# ================================================ configuracion real
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


async def test_estan_los_tres_agentes(con):
    claves = {a.clave for a in await agentes.listar(con)}
    assert {"kuntur", "quirqui", "faustino"} <= claves


async def test_kuntur_es_coach_solo_para_admin_y_activo(con):
    """Activo desde 023 (metas); el acceso sigue siendo solo de administradores (R1)."""
    k = await agentes.obtener(con, "kuntur", solo_activos=False)
    assert (k.rol, k.acceso, k.activo) == ("coach", "admin", True)


async def test_el_prompt_de_cada_agente_existe_en_disco(con):
    for a in await agentes.listar(con):
        assert a.ruta_prompt(PROMPTS).exists(), f"{a.clave}: falta prompts/{a.prompt}"


async def test_ningun_agente_tiene_tools_de_escritura(con):
    """ADR-A8: los agentes dicen como, no hacen."""
    for a in await agentes.listar(con):
        for tool in TOOLS_DE_ESCRITURA:
            assert not a.tool_permitida(tool), f"{a.clave} tiene permitida {tool}"


async def test_un_empleado_no_puede_usar_al_coach(con):
    """R1: para un empleado, Kuntur es igual que un agente que no existe."""
    with pytest.raises(agentes.AccesoDenegado):
        await agentes.para_consulta(con, "kuntur", "4")
    with pytest.raises(agentes.AccesoDenegado):
        await agentes.para_consulta(con, "kuntur", None)


async def test_el_admin_usa_al_coach(con):
    k = await agentes.para_consulta(con, "kuntur", "1")
    assert k.clave == "kuntur"


async def test_un_empleado_no_sabe_si_el_coach_esta_inactivo(con_admin):
    """R1 tambien con Kuntur apagado: al empleado no se le dice "todavia no esta
    disponible" (sabria que existe); al administrador, si."""
    async with con_admin.cursor() as cur:
        await cur.execute("UPDATE agente.agente SET activo = false WHERE clave = 'kuntur'")
    with pytest.raises(agentes.AccesoDenegado):
        await agentes.para_consulta(con_admin, "kuntur", "4")
    with pytest.raises(agentes.AgenteNoDisponible):
        await agentes.para_consulta(con_admin, "kuntur", "1")


async def test_faustino_no_responde_consultas(con):
    with pytest.raises(agentes.AccesoDenegado):
        await agentes.para_consulta(con, "faustino", "1")


async def test_agente_inexistente(con):
    with pytest.raises(agentes.AgenteDesconocido):
        await agentes.para_consulta(con, "nadie", "1")


async def test_el_runtime_no_puede_cambiar_la_configuracion(con):
    """Que un bug del orquestador no pueda abrirle el Coach a cualquiera."""
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        async with con.cursor() as cur:
            await cur.execute("UPDATE agente.agente SET acceso = 'usuario' WHERE clave = 'kuntur'")


async def test_el_orquestador_responde_como_quirqui_por_defecto(con, monkeypatch, llm_falso):
    from test_orquestador import MCPFalso, _parchar
    llm = llm_falso([respuesta_texto("Hola.")])
    _parchar(monkeypatch, llm, MCPFalso())

    await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Quién sos?", autorizacion="Bearer t",
    ))

    sistema = llm.llamadas_chat[0]["mensajes"][0]["content"]
    assert sistema.startswith("Te llamás Quirqui.")


# ================================================================ API
def _jwt(**claims) -> str:
    def b64(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")
    return f"Bearer {b64({'alg': 'none'})}.{b64(claims)}.firma"


@pytest.fixture
def api(monkeypatch):
    """La app con la base y el orquestador reemplazados: prueba solo el acceso."""
    import agente.api as mod

    class ConFalsa:
        async def close(self):
            pass

    async def conexion_falsa():
        yield ConFalsa()

    # Kuntur ACTIVO a proposito: asi se prueba que el filtro es por rol, no
    # porque hoy este inactivo.
    kuntur_activo = KUNTUR
    catalogo = {"quirqui": _agente(), "kuntur": kuntur_activo, "faustino": FAUSTINO}

    async def listar(_con):
        return list(catalogo.values())

    async def obtener(_con, clave, *, solo_activos=True):
        if clave not in catalogo:
            raise agentes.AgenteDesconocido(clave)
        return catalogo[clave]

    class OrqFalso:
        async def responder(self, _con, consulta):
            from agente.orquestador import Resultado
            return Resultado(interaccion_id="i-1", respuesta=f"soy {consulta.agente.nombre}")

    monkeypatch.setattr(mod.agentes, "listar", listar)
    monkeypatch.setattr(mod.agentes, "obtener", obtener)
    monkeypatch.setattr(mod, "orquestador", OrqFalso())
    mod.app.dependency_overrides[mod.conexion] = conexion_falsa
    yield AsyncClient(transport=ASGITransport(app=mod.app), base_url="http://t")
    mod.app.dependency_overrides.clear()


async def test_un_empleado_no_ve_al_coach_en_la_lista(api):
    r = await api.get("/agentes", headers={"Authorization": _jwt(empr_id=1, role="4")})
    assert r.status_code == 200
    assert [a["clave"] for a in r.json()["agentes"]] == ["quirqui"]


async def test_el_admin_ve_al_coach_en_la_lista(api):
    r = await api.get("/agentes", headers={"Authorization": _jwt(empr_id=1, role="1")})
    assert {a["clave"] for a in r.json()["agentes"]} == {"quirqui", "kuntur"}


async def test_la_lista_no_expone_el_prompt_ni_las_tools(api):
    r = await api.get("/agentes", headers={"Authorization": _jwt(empr_id=1, role="1")})
    for a in r.json()["agentes"]:
        assert set(a) == {"clave", "nombre", "rol", "avatar"}


async def test_un_empleado_que_pide_al_coach_recibe_lo_mismo_que_si_no_existiera(api):
    h = {"Authorization": _jwt(empr_id=1, role="4")}
    coach = await api.post("/consulta", json={"pregunta": "hola", "agente": "kuntur"}, headers=h)
    nadie = await api.post("/consulta", json={"pregunta": "hola", "agente": "nadie"}, headers=h)
    assert coach.status_code == nadie.status_code == 404
    assert coach.json() == nadie.json()


async def test_el_admin_consulta_al_coach(api):
    r = await api.post("/consulta", json={"pregunta": "hola", "agente": "kuntur"},
                       headers={"Authorization": _jwt(empr_id=1, role="1")})
    assert r.status_code == 200
    assert r.json()["agente"] == "kuntur"
    assert r.json()["respuesta"] == "soy Kuntur"


async def test_sin_agente_responde_quirqui(api):
    r = await api.post("/consulta", json={"pregunta": "hola"},
                       headers={"Authorization": _jwt(empr_id=1, role="4")})
    assert r.status_code == 200
    assert r.json()["agente"] == "quirqui"


async def test_una_clave_con_caracteres_raros_se_rechaza_antes_de_llegar_a_la_base(api):
    r = await api.post("/consulta", json={"pregunta": "hola", "agente": "../kuntur"},
                       headers={"Authorization": _jwt(empr_id=1, role="1")})
    assert r.status_code == 422
