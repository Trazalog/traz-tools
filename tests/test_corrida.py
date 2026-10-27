"""La corrida auditable (R8, AGENTE-M-03).

Cada corrida tiene que dejar: que agente respondio, que la disparo, cuanto
costo, que controles se aplicaron, que incidentes hubo, y por cada tool lo que
EFECTIVAMENTE vio el modelo -- que es contra lo que el guardian de cifras (R4)
va a comparar los numeros de la respuesta.

Y tiene que quedar aislada por empresa: interaccion y tool_llamada guardan
datos del cliente.
"""
from __future__ import annotations

import json

import psycopg
import pytest

from agente import rag
from agente.config import Config
from agente.llm import Respuesta
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool
from test_orquestador import TOOL_EQUIPOS, MCPFalso, _parchar

EMPRESA = 900001
OTRA = 900002


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


async def _corrida(con, interaccion_id: str, empr_id: int = EMPRESA) -> dict | None:
    await rag.fijar_empresa(con, empr_id)
    async with con.cursor() as cur:
        await cur.execute(
            "SELECT agente, disparador, costo_usd, controles, incidentes, error "
            "FROM agente.interaccion WHERE interaccion_id = %s", (interaccion_id,))
        return await cur.fetchone()


async def _tools(con, interaccion_id: str, empr_id: int = EMPRESA) -> list[dict]:
    await rag.fijar_empresa(con, empr_id)
    async with con.cursor() as cur:
        await cur.execute(
            "SELECT orden, tool, status, contenido FROM agente.tool_llamada "
            "WHERE interaccion_id = %s ORDER BY orden", (interaccion_id,))
        return await cur.fetchall()


def _con_costo(texto: str, costo: float, **kw) -> Respuesta:
    base = respuesta_tool(**kw) if "nombre" in kw else respuesta_texto(texto)
    return Respuesta(texto=base.texto, tool_calls=base.tool_calls, modelo=base.modelo,
                     tokens_prompt=base.tokens_prompt, tokens_respuesta=base.tokens_respuesta,
                     costo_usd=costo)


# ================================================================ la corrida
async def test_queda_el_agente_el_disparador_y_el_control_de_lista_blanca(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_texto("ok")])
    _parchar(monkeypatch, llm, MCPFalso(tools=[TOOL_EQUIPOS]))

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="hola", autorizacion="Bearer t",
    ))

    fila = await _corrida(con, res.interaccion_id)
    assert fila["agente"] == "quirqui"
    assert fila["disparador"] == "consulta"
    assert fila["controles"] == [{"control": "lista_blanca", "publicadas": 1, "ofrecidas": 1}]
    assert fila["incidentes"] == []


async def test_el_costo_es_la_suma_de_las_llamadas_al_modelo(con, monkeypatch, llm_falso):
    llm = llm_falso([
        _con_costo("", 0.0012, nombre="man_get_equipos"),
        _con_costo("Tenés 3 equipos.", 0.0008),
    ])
    _parchar(monkeypatch, llm, MCPFalso(tools=[TOOL_EQUIPOS]))

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="¿Cuántos equipos?", autorizacion="Bearer t",
    ))

    assert float((await _corrida(con, res.interaccion_id))["costo_usd"]) == pytest.approx(0.0020)


async def test_sin_costo_informado_queda_vacio_no_en_cero(con, monkeypatch, llm_falso):
    """Cero diria "fue gratis", que es falso: no se sabe."""
    llm = llm_falso([respuesta_texto("ok")])
    _parchar(monkeypatch, llm, MCPFalso())

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="hola", autorizacion="Bearer t",
    ))

    assert (await _corrida(con, res.interaccion_id))["costo_usd"] is None


async def test_cada_tool_queda_con_lo_que_vio_el_modelo(con, monkeypatch, llm_falso):
    """Es lo que va a mirar el guardian de cifras: el 3 de "tenés 3 equipos"
    tiene que estar en algo que el modelo leyo."""
    llm = llm_falso([respuesta_tool("man_get_equipos"), respuesta_texto("Tenés 3 equipos.")])
    salida = {"equipos": ["COMP-001", "BOMB-002", "CHAN-003"], "total": 3}
    _parchar(monkeypatch, llm, MCPFalso(tools=[TOOL_EQUIPOS], salidas={"man_get_equipos": salida}))

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="¿Cuántos equipos?", autorizacion="Bearer t",
    ))

    tools = await _tools(con, res.interaccion_id)
    assert [(t["orden"], t["tool"], t["status"]) for t in tools] == [(1, "man_get_equipos", "ok")]
    visto = [m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"][0]["content"]
    assert tools[0]["contenido"] == visto
    assert json.loads(tools[0]["contenido"])["total"] == 3


async def test_una_tool_bloqueada_es_un_incidente(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_tool("man_create_ot"), respuesta_texto("No puedo crearla.")])
    _parchar(monkeypatch, llm, MCPFalso(tools=[TOOL_EQUIPOS]))

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="Creá una OT", autorizacion="Bearer t",
    ))

    fila = await _corrida(con, res.interaccion_id)
    assert fila["incidentes"][0]["tipo"] == "tool_bloqueada"
    assert fila["incidentes"][0]["tool"] == "man_create_ot"
    assert [t["status"] for t in await _tools(con, res.interaccion_id)] == ["bloqueada"]


async def test_una_corrida_que_rompe_la_base_igual_queda_registrada(con, monkeypatch, llm_falso):
    """Las corridas que fallan son las mas informativas. Si lo que fallo fue
    una consulta a la base, la transaccion queda abortada; el orquestador tiene
    que volver a una limpia para poder registrar."""
    llm = llm_falso([respuesta_texto("no deberia llegar")])
    _parchar(monkeypatch, llm, MCPFalso())

    async def rompe_la_transaccion(c, _clave):
        async with c.cursor() as cur:
            await cur.execute("SELECT * FROM agente.tabla_que_no_existe")

    monkeypatch.setattr("agente.orquestador.agentes.tools_permitidas", rompe_la_transaccion)

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="hola", autorizacion="Bearer t",
    ))

    fila = await _corrida(con, res.interaccion_id)
    assert fila is not None, "La corrida fallida tiene que quedar registrada"
    assert "tabla_que_no_existe" in fila["error"]


# ============================================================ aislamiento
async def test_otra_empresa_no_ve_la_corrida_ni_lo_que_vio_el_modelo(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_tool("man_get_equipos"), respuesta_texto("ok")])
    _parchar(monkeypatch, llm, MCPFalso(tools=[TOOL_EQUIPOS],
                                        salidas={"man_get_equipos": {"secreto": "de 900001"}}))

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="secreta", autorizacion="Bearer t",
    ))

    assert await _corrida(con, res.interaccion_id, empr_id=OTRA) is None
    assert await _tools(con, res.interaccion_id, empr_id=OTRA) == []
    # Y la propia si la ve: el aislamiento no es "no se ve nada".
    assert await _corrida(con, res.interaccion_id) is not None


async def test_el_runtime_no_puede_corregir_ni_borrar_lo_que_vio_el_modelo(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_tool("man_get_equipos"), respuesta_texto("ok")])
    _parchar(monkeypatch, llm, MCPFalso(tools=[TOOL_EQUIPOS]))
    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="hola", autorizacion="Bearer t",
    ))

    for sql in ("UPDATE agente.tool_llamada SET contenido = 'otro' WHERE interaccion_id = %s",
                "DELETE FROM agente.tool_llamada WHERE interaccion_id = %s"):
        await rag.fijar_empresa(con, EMPRESA)
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            async with con.cursor() as cur:
                await cur.execute(sql, (res.interaccion_id,))
        await con.rollback()
