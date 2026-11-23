"""Tools de lectura de Tareas (AGENTE-TAR-01).

- En modo desarrollo ('mi') el cliente arma la URL de la fachada: el número
  del pedido va en la ruta y los filtros como parámetros; el empr_id nunca
  sale del agente.
- Las cuatro tools están declaradas, con ruta y descripción, y en la spec
  OpenAPI que publica el gateway (modo 'apim').
"""
from __future__ import annotations

import dataclasses
from pathlib import Path

import httpx
import pytest
import yaml

from agente.config import Config
from agente.mcp_client import ClienteMCP, MCPError, _RUTAS_DEV, _TOOLS_DEV

RAIZ = Path(__file__).resolve().parent.parent
TOOLS = ["tar_get_pedidos", "tar_get_pedido", "tar_get_tareas", "tar_get_atrasadas"]


def _cliente(pedidos: list[str]) -> ClienteMCP:
    def responder(req: httpx.Request) -> httpx.Response:
        pedidos.append(str(req.url))
        return httpx.Response(200, json={"ok": True})

    cfg = dataclasses.replace(Config(), mcp_modo="mi", mcp_url="http://mi:8290/tools/mcp/mcp")
    c = ClienteMCP(cfg, autorizacion="Bearer t")
    c.cliente = httpx.AsyncClient(transport=httpx.MockTransport(responder))
    return c


@pytest.mark.asyncio
async def test_urls_de_la_fachada():
    urls: list[str] = []
    c = _cliente(urls)
    await c.llamar("tar_get_pedidos", {})
    await c.llamar("tar_get_pedidos", {"buscar": "pala norte", "todos": True, "empr_id": "99"})
    await c.llamar("tar_get_pedido", {"petr_id": "17"})
    await c.llamar("tar_get_tareas", {"hito_id": "3", "estado": ""})
    await c.llamar("tar_get_atrasadas", {})
    assert urls == [
        "http://mi:8290/tools/mcp/mcp/tar/pedidos",
        "http://mi:8290/tools/mcp/mcp/tar/pedidos?buscar=pala+norte&todos=true",
        "http://mi:8290/tools/mcp/mcp/tar/pedido/17",
        "http://mi:8290/tools/mcp/mcp/tar/tareas?hito_id=3",
        "http://mi:8290/tools/mcp/mcp/tar/atrasadas",
    ]


@pytest.mark.asyncio
async def test_el_numero_de_pedido_no_puede_cambiar_la_ruta():
    urls: list[str] = []
    c = _cliente(urls)
    await c.llamar("tar_get_pedido", {"petr_id": "17/../../man/ot"})
    assert urls == ["http://mi:8290/tools/mcp/mcp/tar/pedido/17%2F..%2F..%2Fman%2Fot"]


@pytest.mark.asyncio
async def test_sin_numero_de_pedido_falla_antes_de_llamar():
    urls: list[str] = []
    with pytest.raises(MCPError):
        await _cliente(urls).llamar("tar_get_pedido", {})
    assert urls == []


def test_las_cuatro_tools_estan_declaradas_con_ruta():
    nombres = {t["function"]["name"] for t in _TOOLS_DEV}
    for t in TOOLS:
        assert t in nombres and t in _RUTAS_DEV


def test_las_cuatro_estan_en_la_spec_que_publica_el_gateway():
    spec = yaml.safe_load((RAIZ / "doc/api/trazalog-operaciones.yaml").read_text())
    ops = {op["operationId"]: (ruta, metodo) for ruta, m in spec["paths"].items() for metodo, op in m.items()}
    for t in TOOLS:
        assert t in ops, f"{t} no está en la spec"
        ruta, metodo = ops[t]
        assert metodo == "get" and ruta.startswith("/mcp/tar/")


def test_la_fachada_tiene_los_cuatro_recursos_y_solo_get():
    xml = (RAIZ / "_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMCPAPI.xml").read_text()
    for uri in ("/mcp/tar/pedidos", "/mcp/tar/pedido/{petr_id}", "/mcp/tar/tareas", "/mcp/tar/atrasadas"):
        assert f'<resource methods="GET" uri-template="{uri}">' in xml
        # Las lecturas no tienen variante de escritura (las altas del plan de acción,
        # AGENTE-CO-04, usan otras rutas y son de clase "accion").
        for metodo in ("POST", "PUT", "DELETE"):
            assert f'methods="{metodo}" uri-template="{uri}"' not in xml
