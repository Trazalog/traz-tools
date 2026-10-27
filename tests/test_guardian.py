"""Guardian de cifras (R4, AGENTE-M-04).

Decision del PM: si una cifra no tiene origen, se BLOQUEA la respuesta y el
usuario recibe "no tengo datos". Una cifra de internet vale solo si se cita la
fuente.

Dos capas: el criterio (sin base, rapido, con los bordes) y el bloqueo de
punta a punta en el orquestador.
"""
from __future__ import annotations

import json

import pytest

from agente import guardian, rag
from agente.config import Config
from agente.guardian import revisar
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool
from test_orquestador import TOOL_EQUIPOS, MCPFalso, _parchar


def _tool(nombre: str, data) -> tuple[str, str]:
    return (nombre, json.dumps(data, ensure_ascii=False))


def _bloquea(respuesta: str, **kw) -> bool:
    return revisar(respuesta, tools=kw.pop("tools", []), **kw).bloquear


# ============================================================== bloquea
@pytest.mark.parametrize("respuesta", [
    "Tenés 7 órdenes vencidas.",
    "Cambiá el filtro cada 250 horas.",
    "Cambiá el filtro cada 250hs.",               # pegado a la unidad
    "El torque de ajuste es 45,5 Nm.",
    "Según la ISO 55000, documentalo.",           # una norma inventada es una cifra inventada
    "La disponibilidad bajó al 61 %.",
])
def test_una_cifra_sin_origen_se_bloquea(respuesta):
    assert _bloquea(respuesta, tools=[_tool("man_get_ots", {"ots": [{"id": 1}, {"id": 2}]})])


def test_una_cifra_de_la_web_sin_citar_la_url_se_bloquea():
    web = _tool("web_buscar", {"resultados": [
        {"url": "https://ejemplo.org/vicuna", "extracto": "invertirá 7100 millones"}]})
    v = revisar("Vicuña va a invertir 7100 millones.", tools=[web])
    assert v.bloquear and v.web_sin_cita == ["7100"]


# ================================================================ pasa
def test_una_cifra_que_devolvio_una_tool_pasa():
    assert not _bloquea("Quedan 12 unidades.", tools=[_tool("alm_get_stock", {"cantidad": 12})])


def test_un_conteo_de_lo_que_devolvio_la_tool_pasa():
    """Contar no es inventar: la tool devolvio tres, el modelo dice tres."""
    data = {"equipos": [{"cod": "A"}, {"cod": "B"}, {"cod": "C"}]}
    assert not _bloquea("Tenés 3 equipos.", tools=[_tool("man_get_equipos", data)])


@pytest.mark.parametrize("respuesta,fuente", [
    ("La disponibilidad es 72 %.", 0.7183),     # fraccion -> porcentaje, redondeado
    ("La disponibilidad es 71,8 %.", 71.83),    # redondeo a un decimal
    ("La disponibilidad es 72%.", 72),
])
def test_porcentajes_y_redondeos(respuesta, fuente):
    assert not _bloquea(respuesta, tools=[_tool("man_get_kpi_disponibilidad", {"valor": fuente})])


@pytest.mark.parametrize("respuesta", ["Quedan 1.500 unidades.", "Quedan 1500 unidades."])
def test_separador_de_miles_argentino(respuesta):
    assert not _bloquea(respuesta, tools=[_tool("alm_get_stock", {"cantidad": 1500})])


def test_un_redondeo_que_cambia_el_numero_no_pasa():
    """72 contra 71,83 es redondeo; 75 contra 71,83 es otro numero."""
    assert _bloquea("La disponibilidad es 75 %.",
                    tools=[_tool("man_get_kpi_disponibilidad", {"valor": 71.83})])


def test_una_cifra_del_conocimiento_recuperado_pasa():
    contexto = "[conocimiento:4] (fuente: manual OEM)\nCambiar el filtro cada 250 horas."
    assert not _bloquea("Según el manual, cada 250 horas.", contexto=contexto)


def test_repetir_un_numero_de_la_pregunta_pasa():
    assert not _bloquea("Con 4 técnicos podés cubrirlo así...",
                        pregunta="Tengo 4 técnicos, ¿cómo organizo los turnos?")


def test_una_cifra_de_la_web_citando_la_url_pasa():
    web = _tool("web_buscar", {"resultados": [
        {"url": "https://ejemplo.org/vicuna", "extracto": "invertirá 7100 millones"}]})
    assert not _bloquea("Vicuña va a invertir 7100 millones (https://ejemplo.org/vicuna).",
                        tools=[web])


@pytest.mark.parametrize("respuesta", [
    "La OT se cargó el 27/10/2026 a las 14:30 hs.",
    "Programada para 2026-11-03.",
    "Revisá el COMP-001 y la OT1234.",
    "Te propongo 3 pasos:\n1. Revisá la bomba\n2. Cargá la lectura",
    "Hay 2 opciones.",
    "Sin cifras: revisá el equipo antes de intervenirlo.",
])
def test_lo_que_no_es_una_cifra_no_se_controla(respuesta):
    v = revisar(respuesta, tools=[])
    assert not v.bloquear, (v.cifras, v.sin_fuente)


def test_un_numero_grande_de_discurso_si_se_controla():
    """'3 pasos' es discurso; '45 pasos' ya es un dato que alguien tiene que respaldar."""
    assert _bloquea("Son 45 pasos.")


def test_una_tool_web_no_valida_cifras_como_si_fuera_una_tool_de_datos():
    """El mismo numero, devuelto por la web, exige la cita; devuelto por una
    tool de datos, no."""
    assert _bloquea("Son 7100.", tools=[_tool("web_buscar", {"t": "7100", "url": "https://a.org"})])
    assert not _bloquea("Son 7100.", tools=[_tool("alm_get_stock", {"t": 7100})])


# ======================================================= en el orquestador
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


@pytest.fixture(autouse=True)
def sin_conocimiento(monkeypatch):
    """Estos tests prueban que cifra tiene origen; no pueden depender de lo que
    haya ingestado en la base. Con conocimiento cargado, un "7" de cualquier
    ayuda respaldaria por coincidencia un "7" inventado (limitacion conocida
    del guardian, D-24)."""
    async def vacio(*_a, **_k):
        return []
    monkeypatch.setattr("agente.orquestador.rag.buscar_conocimiento", vacio)
    monkeypatch.setattr("agente.orquestador.rag.buscar_memoria", vacio)


async def test_el_usuario_recibe_no_tengo_datos_en_vez_del_numero_inventado(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_texto("Cada 500 horas de operación.")])
    _parchar(monkeypatch, llm, MCPFalso())

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Cada cuánto se cambian las muelas?", autorizacion="Bearer t",
    ))

    assert res.respuesta == guardian.MENSAJE_BLOQUEO
    assert "500" not in res.respuesta
    incidente = res.incidentes[0]
    assert incidente["tipo"] == "cifra_sin_fuente"
    assert incidente["cifras"] == ["500"]
    # La respuesta original queda para revisar el caso, no se pierde.
    assert incidente["respuesta_bloqueada"] == "Cada 500 horas de operación."


async def test_una_respuesta_respaldada_por_la_tool_llega_entera(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_tool("man_get_equipos"), respuesta_texto("Tenés 3 equipos.")])
    _parchar(monkeypatch, llm, MCPFalso(
        tools=[TOOL_EQUIPOS], salidas={"man_get_equipos": {"equipos": ["A", "B", "C"]}}))

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Cuántos equipos tengo?", autorizacion="Bearer t",
    ))

    assert res.respuesta == "Tenés 3 equipos."
    assert res.incidentes == []
    assert {"control": "R4_cifras", "cifras": 1, "sin_fuente": 0} in res.controles


async def test_el_bloqueo_queda_registrado_en_la_corrida(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_texto("Tenés 7 órdenes vencidas.")])
    _parchar(monkeypatch, llm, MCPFalso())

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Cuántas órdenes vencidas tengo?", autorizacion="Bearer t",
    ))

    await rag.fijar_empresa(con, 900001)
    async with con.cursor() as cur:
        await cur.execute("SELECT respuesta, incidentes FROM agente.interaccion "
                          "WHERE interaccion_id = %s", (res.interaccion_id,))
        fila = await cur.fetchone()
    assert fila["respuesta"] == guardian.MENSAJE_BLOQUEO
    assert fila["incidentes"][0]["respuesta_bloqueada"] == "Tenés 7 órdenes vencidas."
