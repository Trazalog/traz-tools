"""Tool web_buscar sobre SearXNG (AGENTE-M-05).

Con SearXNG simulado (respx) para la logica, y uno contra el SearXNG real que
corre solo si AGENTE_WEB_URL esta configurada (como el smoke de OpenRouter).
"""
from __future__ import annotations

import json
import os
from dataclasses import replace

import httpx
import pytest
import respx

from agente import guardian, rag, web
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool
from test_orquestador import TOOL_EQUIPOS, MCPFalso, _parchar

SEARXNG = "http://searxng.prueba"
RESPUESTA_SEARXNG = {"results": [
    {"title": "Vicuña: inversión", "url": "https://ejemplo.org/vicuna",
     "content": "El proyecto invertirá 7100 millones de dólares."},
    {"title": "Sin URL", "content": "se descarta"},
]}


def _cfg(**kw) -> Config:
    return replace(Config(), web_url=kw.get("web_url", SEARXNG), web_resultados=5)


# ================================================================ cliente
@respx.mock
async def test_buscar_devuelve_titulo_url_y_extracto():
    respx.get(f"{SEARXNG}/search").respond(json=RESPUESTA_SEARXNG)
    salida = await web.buscar(_cfg(), "inversión Vicuña")
    assert salida["resultados"] == [{
        "titulo": "Vicuña: inversión", "url": "https://ejemplo.org/vicuna",
        "extracto": "El proyecto invertirá 7100 millones de dólares.",
    }]


@respx.mock
async def test_buscar_pide_json_en_español():
    ruta = respx.get(f"{SEARXNG}/search").respond(json={"results": []})
    await web.buscar(_cfg(), "MTBF")
    params = ruta.calls[0].request.url.params
    assert params["format"] == "json" and params["language"] == "es" and params["q"] == "MTBF"


@respx.mock
async def test_un_searxng_sin_json_habilitado_da_un_error_entendible():
    respx.get(f"{SEARXNG}/search").respond(403, text="Forbidden")
    with pytest.raises(web.WebError, match="403"):
        await web.buscar(_cfg(), "MTBF")


async def test_consulta_vacia():
    with pytest.raises(web.WebError):
        await web.buscar(_cfg(), "  ")


def test_sin_url_la_busqueda_esta_apagada():
    assert not web.habilitada(_cfg(web_url=""))


def test_la_descripcion_le_prohibe_al_modelo_mandar_datos_de_la_empresa():
    """Es lo unico que el modelo lee al decidir usar la tool."""
    d = web.DEFINICION["function"]["description"]
    assert "NO puede incluir datos de la empresa" in d
    assert "citá su URL" in d


# =================================================== en el orquestador
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


async def _requiere_014(con):
    async with con.cursor() as cur:
        await cur.execute("SELECT 1 FROM agente.tool WHERE nombre = 'web_buscar'")
        if not await cur.fetchone():
            pytest.skip("Falta aplicar 014-tool-web.sql")


async def test_quirqui_recibe_la_tool_si_hay_buscador(con, monkeypatch, llm_falso):
    await _requiere_014(con)
    llm = llm_falso([respuesta_texto("ok")])
    _parchar(monkeypatch, llm, MCPFalso(tools=[TOOL_EQUIPOS]))
    await Orquestador(_cfg()).responder(con, Consulta(
        empr_id=900001, pregunta="hola", autorizacion="Bearer t"))
    assert "web_buscar" in [t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]]


async def test_sin_buscador_configurado_no_se_ofrece(con, monkeypatch, llm_falso):
    await _requiere_014(con)
    llm = llm_falso([respuesta_texto("ok")])
    _parchar(monkeypatch, llm, MCPFalso(tools=[TOOL_EQUIPOS]))
    await Orquestador(_cfg(web_url="")).responder(con, Consulta(
        empr_id=900001, pregunta="hola", autorizacion="Bearer t"))
    assert "web_buscar" not in [t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]]


@respx.mock
async def test_la_cifra_de_la_web_citada_llega_y_queda_registrada(con, monkeypatch, llm_falso):
    """De punta a punta: busca, responde con la cifra y la URL, el guardian la
    deja pasar y la busqueda queda en tool_llamada."""
    await _requiere_014(con)
    respx.get(f"{SEARXNG}/search").respond(json=RESPUESTA_SEARXNG)
    llm = llm_falso([
        respuesta_tool("web_buscar", json.dumps({"consulta": "inversión Vicuña"})),
        respuesta_texto("Vicuña va a invertir 7100 millones (https://ejemplo.org/vicuna)."),
    ])
    _parchar(monkeypatch, llm, MCPFalso())

    res = await Orquestador(_cfg()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Cuánto invierte Vicuña?", autorizacion="Bearer t"))

    assert res.respuesta.startswith("Vicuña va a invertir 7100")
    assert res.incidentes == []
    assert res.tools_llamadas[0]["tool"] == "web_buscar"
    assert res.tools_llamadas[0]["status"] == "ok"


@respx.mock
async def test_la_misma_cifra_sin_la_url_se_bloquea(con, monkeypatch, llm_falso):
    await _requiere_014(con)
    respx.get(f"{SEARXNG}/search").respond(json=RESPUESTA_SEARXNG)
    llm = llm_falso([
        respuesta_tool("web_buscar", json.dumps({"consulta": "inversión Vicuña"})),
        respuesta_texto("Vicuña va a invertir 7100 millones."),
    ])
    _parchar(monkeypatch, llm, MCPFalso())

    res = await Orquestador(_cfg()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Cuánto invierte Vicuña?", autorizacion="Bearer t"))

    assert res.respuesta == guardian.MENSAJE_BLOQUEO
    assert res.incidentes[0]["web_sin_cita"] == ["7100"]


@respx.mock
async def test_si_el_buscador_falla_el_agente_sigue(con, monkeypatch, llm_falso):
    await _requiere_014(con)
    respx.get(f"{SEARXNG}/search").mock(side_effect=httpx.ConnectTimeout("timeout"))
    llm = llm_falso([
        respuesta_tool("web_buscar", json.dumps({"consulta": "norma"})),
        respuesta_texto("No pude buscar en internet ahora."),
    ])
    _parchar(monkeypatch, llm, MCPFalso())

    res = await Orquestador(_cfg()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Qué dice la norma?", autorizacion="Bearer t"))

    assert res.error is None
    assert res.tools_llamadas[0]["status"] == "error"
    devuelto = [m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"]
    assert "No se pudo buscar" in devuelto[0]["content"]


# =========================================== contra el SearXNG de verdad
@pytest.mark.skipif(not os.environ.get("AGENTE_WEB_URL_REAL"),
                    reason="Sin AGENTE_WEB_URL: se saltea la busqueda real")
async def test_busqueda_real():
    salida = await web.buscar(_cfg(web_url=os.environ["AGENTE_WEB_URL_REAL"]), "MTBF mantenimiento")
    assert salida["resultados"], "SearXNG no devolvio resultados (¿buscadores sin salida?)"
    assert all(r["url"].startswith("http") for r in salida["resultados"])
