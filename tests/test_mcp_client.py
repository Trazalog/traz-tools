"""Cliente MCP: passthrough del token y la regla de que empr_id no viaja."""
from __future__ import annotations

import httpx
import pytest
import respx

from agente.config import Config
from agente.mcp_client import ClienteMCP, MCPError, _contenido_mcp, _parsear_respuesta


def _cfg(**kw) -> Config:
    import os
    for k, v in kw.items():
        os.environ[k] = str(v)
    return Config()


@pytest.mark.asyncio
@respx.mock
async def test_el_token_del_usuario_viaja_tal_cual():
    """Passthrough: el agente no reemite ni modifica el token.

    Si lo reemitiera con claims propios, el aislamiento por empr_id dejaria de
    depender de lo que el gateway valido y pasaria a depender del agente.
    """
    cfg = _cfg(AGENTE_MCP_MODO="apim", AGENTE_MCP_URL="http://gw/mcp")
    ruta = respx.post("http://gw/mcp").mock(
        return_value=httpx.Response(200, json={"jsonrpc": "2.0", "id": 1, "result": {"tools": []}})
    )
    async with ClienteMCP(cfg, "Bearer token-del-usuario-123") as mcp:
        await mcp.listar_tools()

    for pedido in ruta.calls:
        assert pedido.request.headers["Authorization"] == "Bearer token-del-usuario-123"


@pytest.mark.asyncio
@respx.mock
async def test_empr_id_nunca_viaja_como_argumento():
    """Si el modelo alucina un empr_id, se descarta antes de salir.

    La identidad la resuelve el gateway desde el token. Un empr_id por
    parametro seria exactamente la violacion de arquitectura que el
    CONTEXT-PACK marca como motivo de parar y escalar.
    """
    cfg = _cfg(AGENTE_MCP_MODO="apim", AGENTE_MCP_URL="http://gw/mcp")
    capturado = {}

    def responder(request):
        import json
        capturado.update(json.loads(request.content))
        return httpx.Response(200, json={
            "jsonrpc": "2.0", "id": 1,
            "result": {"content": [{"type": "text", "text": "{\"ok\":true}"}]},
        })

    respx.post("http://gw/mcp").mock(side_effect=responder)

    async with ClienteMCP(cfg, "Bearer t") as mcp:
        await mcp.llamar("man_get_equipos", {"empr_id": 99, "estado": "AC"})

    argumentos = capturado["params"]["arguments"]
    assert "empr_id" not in argumentos, "El empr_id no puede salir como argumento"
    assert argumentos == {"estado": "AC"}, "El resto de los argumentos tiene que pasar"


@pytest.mark.asyncio
@respx.mock
async def test_un_error_del_gateway_se_reporta_no_se_traga():
    cfg = _cfg(AGENTE_MCP_MODO="apim", AGENTE_MCP_URL="http://gw/mcp")
    respx.post("http://gw/mcp").mock(return_value=httpx.Response(401, text="no autorizado"))
    async with ClienteMCP(cfg, "Bearer vencido") as mcp:
        with pytest.raises(MCPError) as e:
            await mcp.llamar("man_get_equipos", {})
    assert e.value.status == 401


@pytest.mark.asyncio
@respx.mock
async def test_toda_llamada_queda_trazada():
    """La traza es lo que se guarda en interaccion.tools_llamadas.

    Sin ella, un pulgar abajo no permite distinguir "el conocimiento estaba
    mal" de "la tool fallo".
    """
    cfg = _cfg(AGENTE_MCP_MODO="apim", AGENTE_MCP_URL="http://gw/mcp")
    respx.post("http://gw/mcp").mock(return_value=httpx.Response(200, json={
        "jsonrpc": "2.0", "id": 1,
        "result": {"content": [{"type": "text", "text": "[]"}]},
    }))
    async with ClienteMCP(cfg, "Bearer t") as mcp:
        await mcp.llamar("man_get_ots", {})
    assert len(mcp.llamadas) == 1
    traza = mcp.llamadas[0].a_dict()
    assert traza["tool"] == "man_get_ots"
    assert traza["status"] == "ok"
    assert traza["latencia_ms"] >= 0


@pytest.mark.asyncio
@respx.mock
async def test_una_tool_que_falla_tambien_queda_trazada():
    cfg = _cfg(AGENTE_MCP_MODO="apim", AGENTE_MCP_URL="http://gw/mcp")
    respx.post("http://gw/mcp").mock(return_value=httpx.Response(500, text="boom"))
    async with ClienteMCP(cfg, "Bearer t") as mcp:
        with pytest.raises(MCPError):
            await mcp.llamar("man_get_equipos", {})
    assert mcp.llamadas[0].status == "error"
    assert mcp.llamadas[0].error


def test_se_entiende_la_respuesta_sse():
    """El gateway del APIM puede responder Server-Sent Events en vez de JSON."""
    sse = 'event: message\ndata: {"jsonrpc":"2.0","id":1,"result":{"tools":[]}}\n\n'
    assert _parsear_respuesta(sse)["result"] == {"tools": []}


def test_se_desempaqueta_el_content_de_mcp():
    result = {"content": [{"type": "text", "text": '{"equipos":[{"id":1}]}'}]}
    assert _contenido_mcp(result) == {"equipos": [{"id": 1}]}
    # Si no es JSON, vuelve el texto tal cual en vez de explotar.
    assert _contenido_mcp({"content": [{"type": "text", "text": "sin datos"}]}) == "sin datos"
