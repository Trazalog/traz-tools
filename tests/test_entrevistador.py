"""El agente entrevistador: agenda, sesión, estructuración y validación cruzada.

OpenRouter va mockeado; la base es la real.

Los datos de prueba NO se borran al terminar: el rol del orquestador no tiene
DELETE sobre las tablas del entrevistador --el conocimiento capturado y su
trazabilidad no se borran desde el runtime-- asi que quedan marcados con el
prefijo "TEST ". Para purgarlos hace falta el rol propietario:

    DELETE FROM agente.sesion_entrevista s
     USING agente.experto e
     WHERE e.experto_id = s.experto_id AND e.nombre LIKE 'TEST %';
    DELETE FROM agente.experto WHERE nombre LIKE 'TEST %';
"""
from __future__ import annotations

import json

import pytest

from agente import entrevistador as ent
from agente import rag
from agente.config import Config
from conftest import respuesta_texto


async def _conectar_o_saltear():
    cfg = Config()
    if not cfg.db_password:
        pytest.skip("Sin AGENTE_DB_PASSWORD")
    try:
        return await rag.abrir(cfg)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"Base no disponible: {e}")


@pytest.fixture
async def con():
    c = await _conectar_o_saltear()
    try:
        yield c
    finally:
        await c.rollback()
        await c.close()


@pytest.fixture
async def expertos(con):
    """Dos expertos de prueba: la validación cruzada necesita dos."""
    async with con.cursor() as cur:
        ids = []
        for nombre in ("TEST Experto Uno", "TEST Experto Dos"):
            await cur.execute(
                "INSERT INTO agente.experto (nombre, especialidad) VALUES (%s, 'prueba') "
                "ON CONFLICT (nombre) DO UPDATE SET especialidad = 'prueba' RETURNING experto_id",
                (nombre,),
            )
            ids.append((await cur.fetchone())["experto_id"])
    await con.commit()
    yield ids
    # No se borran: el rol del orquestador no tiene DELETE sobre las tablas del
    # entrevistador, y es deliberado (ver el test del final). Se desactivan.
    async with con.cursor() as cur:
        await cur.execute(
            "UPDATE agente.experto SET activo = false WHERE nombre LIKE 'TEST Experto%'"
        )
    await con.commit()


class LLMFalso:
    def __init__(self, respuestas):
        self._r = list(respuestas)
        self.pedidos = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_):
        return None

    async def chat(self, mensajes, tools=None):
        self.pedidos.append(mensajes)
        return respuesta_texto(self._r.pop(0))

    async def embeddings(self, textos):
        return [[0.0] * 1023 + [1.0] for _ in textos]


# ------------------------------------------------------------------ agenda
@pytest.mark.asyncio
async def test_la_agenda_viene_priorizada(con):
    temas = await ent.agenda(con, limite=50)
    assert temas, "El seed de la taxonomía tiene que estar aplicado (010)"
    prioridades = [t.prioridad for t in temas]
    assert prioridades == sorted(prioridades, reverse=True), (
        "La agenda tiene que venir de mayor a menor prioridad"
    )


@pytest.mark.asyncio
async def test_la_agenda_cubre_las_dos_areas(con):
    """Mismo criterio que el resto del agente: mantenimiento Y almacenes."""
    modulos = {t.modulo for t in await ent.agenda(con, limite=50)}
    assert "man" in modulos, "Faltan temas de mantenimiento"
    assert "alm" in modulos, "Faltan temas de almacenes"


@pytest.mark.asyncio
async def test_filtrar_por_area_trae_tambien_lo_general(con):
    """Seguridad y normativa aplican a las dos áreas: no se filtran."""
    modulos = {t.modulo for t in await ent.agenda(con, limite=50, modulo="alm")}
    assert modulos <= {"alm", "general"}
    assert "man" not in modulos


@pytest.mark.asyncio
async def test_los_datos_reales_reordenan_la_agenda(con):
    """La fuente más potente de priorización son las OTs por familia de equipo.

    Si las chancadoras generan la mayoría de las OTs, ese tema tiene que subir
    aunque su peso base sea menor que el de otro.
    """
    antes = {t.nombre: t.prioridad for t in await ent.agenda(con, limite=50)}

    await ent.recalcular_prioridades(con, {"chancadora": 400, "bomba": 10})
    despues = await ent.agenda(con, limite=50)
    por_nombre = {t.nombre: t for t in despues}

    chancadoras = por_nombre["Chancadoras"]
    assert chancadoras.prioridad > antes["Chancadoras"], (
        "Un tema con muchas OTs tiene que subir"
    )
    # Y la agenda queda auditable: se puede saber POR QUÉ subió.
    assert chancadoras.origen_prioridad["ots"] > 0
    assert chancadoras.origen_prioridad["ots_contadas"] == 400

    # Se restaura el estado del seed para no ensuciar la base.
    await ent.recalcular_prioridades(con, {})


# --------------------------------------------------------------- entrevista
@pytest.mark.asyncio
async def test_la_entrevista_arranca_con_una_pregunta_amplia(con, expertos):
    temas = await ent.agenda(con, limite=1)
    llm = LLMFalso(["Contame cómo encarás el cambio de muelas de una chancadora."])

    r = await ent.iniciar(con, Config(), llm, expertos[0], temas[0].tema_id)

    assert r["pregunta"].startswith("Contame")
    assert r["sesion_id"]
    # El prompt del entrevistador tiene que ser el suyo, no el del chat.
    sistema = llm.pedidos[0][0]["content"]
    assert "entrevistador" in sistema.lower()



@pytest.mark.asyncio
async def test_la_conversacion_queda_completa_en_la_transcripcion(con, expertos):
    """Se guarda todo, no solo los hechos: la estructuración pierde matices."""
    temas = await ent.agenda(con, limite=1)
    llm = LLMFalso(["¿Cómo lo hacés?", "¿Cada cuántas horas?"])
    cfg = Config()

    r = await ent.iniciar(con, cfg, llm, expertos[0], temas[0].tema_id)
    await ent.responder(con, cfg, llm, r["sesion_id"], "Se cambian por desgaste.")

    async with con.cursor() as cur:
        await cur.execute("SELECT transcripcion FROM agente.sesion_entrevista WHERE sesion_id = %s",
                          (r["sesion_id"],))
        t = (await cur.fetchone())["transcripcion"]

    roles = [m["rol"] for m in t]
    assert roles == ["agente", "experto", "agente"]
    assert t[1]["texto"] == "Se cambian por desgaste."



@pytest.mark.asyncio
async def test_el_agente_puede_cerrar_el_tema(con, expertos):
    """Si el tema está cubierto, cierra en vez de estirar la entrevista."""
    temas = await ent.agenda(con, limite=1)
    llm = LLMFalso(["¿Cómo lo hacés?", "CERRAR"])
    cfg = Config()

    r = await ent.iniciar(con, cfg, llm, expertos[0], temas[0].tema_id)
    rsp = await ent.responder(con, cfg, llm, r["sesion_id"], "Ya te conté todo.")

    assert rsp["cerrar"] is True

    async with con.cursor() as cur:
        await cur.execute("SELECT estado FROM agente.sesion_entrevista WHERE sesion_id = %s",
                          (r["sesion_id"],))
        assert (await cur.fetchone())["estado"] == "estructurando"


# ------------------------------------------------------------ estructuración
def test_se_descartan_los_hechos_de_confianza_baja():
    """El prompt dice que por debajo de 0.5 no se registre. Se hace cumplir acá.

    Un hecho con confianza baja es uno que el modelo interpretó o que el experto
    dijo con dudas: en una base de conocimiento minera, eso no entra.
    """
    crudo = json.dumps([
        {"contenido": "Las muelas se cambian cada 500 horas de operación.", "confianza": 0.9},
        {"contenido": "Puede que convenga revisar el manto de vez en cuando.", "confianza": 0.3},
    ])
    hechos = ent._parsear_hechos(crudo)
    assert len(hechos) == 1
    assert "500 horas" in hechos[0]["contenido"]


def test_se_descartan_los_hechos_demasiado_cortos():
    """Un hecho de una línea suelta no se sostiene solo fuera de contexto."""
    crudo = json.dumps([{"contenido": "Cambiar muelas.", "confianza": 0.9}])
    assert ent._parsear_hechos(crudo) == []


def test_se_entiende_el_json_envuelto_en_backticks():
    """Los modelos envuelven en ``` aunque se les pida que no."""
    crudo = '```json\n[{"contenido": "Las muelas se cambian cada 500 horas.", "confianza": 0.8}]\n```'
    assert len(ent._parsear_hechos(crudo)) == 1


def test_una_respuesta_sin_json_no_rompe():
    assert ent._parsear_hechos("No pude estructurar nada.") == []


@pytest.mark.asyncio
async def test_estructurar_deja_los_hechos_en_borrador(con, expertos):
    """Todavía no son conocimiento: son una propuesta que el experto revisa."""
    temas = await ent.agenda(con, limite=1)
    cfg = Config()
    llm = LLMFalso([
        "¿Cómo lo hacés?",
        "¿Cada cuántas horas?",
        json.dumps([{"contenido": "En chancadoras cónicas las muelas se cambian "
                                  "cada 500 horas de operación.",
                     "tipo_equipo": "chancadora", "situacion": "mantenimiento",
                     "confianza": 0.9}]),
    ])

    r = await ent.iniciar(con, cfg, llm, expertos[0], temas[0].tema_id)
    await ent.responder(con, cfg, llm, r["sesion_id"],
                        "Se cambian cada 500 horas de operación.")
    hechos = await ent.estructurar(con, cfg, llm, r["sesion_id"])

    assert len(hechos) == 1
    async with con.cursor() as cur:
        await cur.execute("SELECT estado_validacion, modulo FROM agente.hecho WHERE hecho_id = %s",
                          (hechos[0]["hecho_id"],))
        h = await cur.fetchone()
        assert h["estado_validacion"] == "borrador"
        assert h["modulo"] == temas[0].modulo


# --------------------------------------------------------- validación cruzada
@pytest.mark.asyncio
async def test_un_experto_no_ve_sus_propios_hechos_para_validar(con, expertos):
    """Si validara lo suyo, la validación cruzada no significaría nada."""
    temas = await ent.agenda(con, limite=1)
    cfg = Config()
    llm = LLMFalso(["¿Cómo?", "¿Y después?", json.dumps([
        {"contenido": "Un hecho de prueba con largo suficiente para pasar el filtro.",
         "confianza": 0.8}])])

    r = await ent.iniciar(con, cfg, llm, expertos[0], temas[0].tema_id)
    await ent.responder(con, cfg, llm, r["sesion_id"], "Te cuento cómo lo hago.")
    hechos = await ent.estructurar(con, cfg, llm, r["sesion_id"])
    await ent.validar(con, hechos[0]["hecho_id"], aprobado=True)

    propios = await ent.para_validar(con, expertos[0])
    ajenos = await ent.para_validar(con, expertos[1])

    ids_propios = [h["hecho_id"] for h in propios]
    ids_ajenos = [h["hecho_id"] for h in ajenos]
    assert hechos[0]["hecho_id"] not in ids_propios, "Un experto no valida lo suyo"
    assert hechos[0]["hecho_id"] in ids_ajenos, "El otro experto sí tiene que verlo"



@pytest.mark.asyncio
async def test_si_los_expertos_discrepan_el_hecho_queda_en_zona_gris(con, expertos):
    """Un desacuerdo entre expertos es información, no algo para descartar."""
    temas = await ent.agenda(con, limite=1)
    cfg = Config()
    llm = LLMFalso(["¿Cómo?", "¿Y después?", json.dumps([
        {"contenido": "Un hecho sobre el que los expertos no se van a poner de acuerdo.",
         "confianza": 0.8}])])

    r = await ent.iniciar(con, cfg, llm, expertos[0], temas[0].tema_id)
    await ent.responder(con, cfg, llm, r["sesion_id"], "Yo lo hago de esta manera.")
    hechos = await ent.estructurar(con, cfg, llm, r["sesion_id"])
    await ent.validar(con, hechos[0]["hecho_id"], aprobado=True)

    rsp = await ent.opinar(con, hechos[0]["hecho_id"], expertos[1], "discrepa",
                           "En mi experiencia es distinto")

    assert rsp["estado"] == "zona_gris", (
        "Si discrepan, el hecho se conserva marcado, no se descarta"
    )



@pytest.mark.asyncio
async def test_no_se_puede_promover_un_hecho_sin_validar(con, expertos):
    """ADR-A4: al conocimiento compartido solo llega lo que un humano aprobó."""
    temas = await ent.agenda(con, limite=1)
    cfg = Config()
    llm = LLMFalso(["¿Cómo?", "¿Y después?", json.dumps([
        {"contenido": "Un hecho en borrador que no deberia poder promoverse.",
         "confianza": 0.8}])])

    r = await ent.iniciar(con, cfg, llm, expertos[0], temas[0].tema_id)
    await ent.responder(con, cfg, llm, r["sesion_id"], "Lo hago de tal forma.")
    hechos = await ent.estructurar(con, cfg, llm, r["sesion_id"])

    with pytest.raises(ValueError, match="solo se promueve"):
        await ent.promover(con, cfg, llm, hechos[0]["hecho_id"], curador="test")



@pytest.mark.asyncio
async def test_el_runtime_no_puede_borrar_lo_capturado(con, expertos):
    """El conocimiento capturado a un experto no se borra desde el runtime.

    agente_app tiene SELECT/INSERT/UPDATE sobre las tablas del entrevistador,
    pero no DELETE. Una entrevista es evidencia de lo que dijo una persona: un
    bug del orquestador no tiene que poder hacerla desaparecer.
    """
    import psycopg

    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        async with con.cursor() as cur:
            await cur.execute("DELETE FROM agente.experto WHERE experto_id = %s",
                              (expertos[0],))
    await con.rollback()


@pytest.mark.asyncio
async def test_no_se_estructura_una_entrevista_sin_respuestas(con, expertos):
    """Sin nada del experto no hay conocimiento que estructurar.

    Si no, el modelo se inventaría los hechos a partir de su propia pregunta —
    exactamente lo que el prompt le prohíbe.
    """
    temas = await ent.agenda(con, limite=1)
    cfg = Config()
    llm = LLMFalso(["¿Cómo lo hacés?"])

    r = await ent.iniciar(con, cfg, llm, expertos[0], temas[0].tema_id)

    with pytest.raises(ValueError, match="ninguna respuesta del experto"):
        await ent.estructurar(con, cfg, llm, r["sesion_id"])
