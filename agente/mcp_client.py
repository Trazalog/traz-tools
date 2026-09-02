"""Cliente MCP: la unica via por la que el agente ve datos del cliente (ADR-A3).

Dos modos, por AGENTE_MCP_MODO:

  apim  El camino real. Habla el protocolo MCP (JSON-RPC) contra el Virtual MCP
        Server del gateway, reenviando el Bearer del usuario TAL CUAL llego. El
        APIM ya lo valido y de el deriva el empr_id, asi que el agente no
        resuelve identidad ni la puede falsear.

  mi    Camino de desarrollo. REST directo al MI con X-JWT-Assertion, para
        poder trabajar sin un APIM levantado. Mismo contrato de tools, misma
        sequence de identidad en el MI. NO USAR fuera de desarrollo: el MI
        decodifica la assertion sin validar la firma, porque en el flujo real
        eso lo hace el gateway.

Regla de oro que este modulo respeta y hace cumplir: el empr_id NUNCA viaja
como parametro. Sale del token, y el token viene del usuario.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any

import httpx

from .config import Config

PROTOCOL_VERSION = "2025-06-18"


class MCPError(RuntimeError):
    def __init__(self, tool: str, mensaje: str, status: int | None = None, cuerpo: Any = None):
        self.tool, self.status, self.cuerpo = tool, status, cuerpo
        super().__init__(f"{tool}: {mensaje}")


@dataclass
class LlamadaTool:
    """Traza de una llamada, para guardar en agente.interaccion.tools_llamadas."""

    tool: str
    argumentos: dict
    status: str
    latencia_ms: int
    error: str | None = None

    def a_dict(self) -> dict:
        d = {
            "tool": self.tool, "argumentos": self.argumentos,
            "status": self.status, "latencia_ms": self.latencia_ms,
        }
        if self.error:
            d["error"] = self.error
        return d


@dataclass
class ClienteMCP:
    cfg: Config
    autorizacion: str          # el header Authorization del usuario, tal cual llego
    cliente: httpx.AsyncClient | None = None
    llamadas: list[LlamadaTool] = field(default_factory=list)
    _tools: list[dict] | None = None
    _session_id: str | None = None

    async def __aenter__(self) -> "ClienteMCP":
        if self.cliente is None:
            self.cliente = httpx.AsyncClient(timeout=float(self.cfg.mcp_timeout))
            self._propio = True
        return self

    async def __aexit__(self, *_) -> None:
        if getattr(self, "_propio", False) and self.cliente is not None:
            await self.cliente.aclose()
            self.cliente = None

    # ------------------------------------------------------------------ auth
    @property
    def _headers(self) -> dict[str, str]:
        h = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
        if self.cfg.mcp_modo == "apim":
            # Passthrough: el token del usuario va tal cual. El agente no lo
            # reemite, no lo modifica y no le agrega claims.
            h["Authorization"] = self.autorizacion
        else:
            # En modo MI la assertion viaja en su propio header; el valor lo
            # arma quien construye el cliente (ver scripts/dev/mcp_tools_client.py).
            h["X-JWT-Assertion"] = self.autorizacion.removeprefix("Bearer ").strip()
        if self._session_id:
            h["Mcp-Session-Id"] = self._session_id
        return h

    # ------------------------------------------------------------- JSON-RPC
    async def _rpc(self, metodo: str, params: dict | None = None) -> dict:
        if self.cliente is None:
            raise MCPError(metodo, "El cliente HTTP no esta abierto; usar 'async with'.")
        cuerpo = {"jsonrpc": "2.0", "id": 1, "method": metodo}
        if params is not None:
            cuerpo["params"] = params
        try:
            r = await self.cliente.post(self.cfg.mcp_url, headers=self._headers, json=cuerpo)
        except httpx.HTTPError as e:
            raise MCPError(metodo, f"no se pudo llegar al MCP Gateway: {e}") from e

        # El gateway devuelve el id de sesion en el primer intercambio.
        if "Mcp-Session-Id" in r.headers:
            self._session_id = r.headers["Mcp-Session-Id"]

        if r.status_code >= 400:
            raise MCPError(metodo, f"HTTP {r.status_code}", r.status_code, r.text[:500])

        try:
            data = _parsear_respuesta(r.text)
        except ValueError as e:
            raise MCPError(metodo, str(e), r.status_code, r.text[:500]) from e

        if "error" in data:
            raise MCPError(metodo, str(data["error"]), r.status_code, data["error"])
        return data.get("result", {})

    async def inicializar(self) -> None:
        if self.cfg.mcp_modo != "apim":
            return
        await self._rpc("initialize", {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {},
            "clientInfo": {"name": "trazalog-agente-minero", "version": "0.1.0"},
        })

    # ------------------------------------------------------------------ API
    async def listar_tools(self) -> list[dict]:
        """Las tools disponibles, en el formato que espera OpenAI/OpenRouter."""
        if self._tools is not None:
            return self._tools
        if self.cfg.mcp_modo != "apim":
            self._tools = _TOOLS_DEV
            return self._tools

        await self.inicializar()
        result = await self._rpc("tools/list")
        self._tools = [
            {
                "type": "function",
                "function": {
                    "name": t["name"],
                    "description": t.get("description", ""),
                    "parameters": t.get("inputSchema") or {"type": "object", "properties": {}},
                },
            }
            for t in result.get("tools", [])
        ]
        return self._tools

    async def llamar(self, nombre: str, argumentos: dict) -> Any:
        """Ejecuta una tool. El empr_id NO va aca: sale del token."""
        if "empr_id" in argumentos:
            # Defensa explicita: si el modelo alucina un empr_id, se descarta
            # antes de salir. La identidad la resuelve el gateway, no el agente.
            argumentos = {k: v for k, v in argumentos.items() if k != "empr_id"}

        import time
        t0 = time.monotonic()
        try:
            if self.cfg.mcp_modo == "apim":
                result = await self._rpc("tools/call", {"name": nombre, "arguments": argumentos})
                salida = _contenido_mcp(result)
            else:
                salida = await self._llamar_rest(nombre, argumentos)
        except MCPError as e:
            self.llamadas.append(LlamadaTool(
                nombre, argumentos, "error",
                int((time.monotonic() - t0) * 1000), str(e)[:300],
            ))
            raise
        self.llamadas.append(LlamadaTool(
            nombre, argumentos, "ok", int((time.monotonic() - t0) * 1000)
        ))
        return salida

    # ------------------------------------------------------- modo desarrollo
    async def _llamar_rest(self, nombre: str, argumentos: dict) -> Any:
        ruta = _RUTAS_DEV.get(nombre)
        if ruta is None:
            raise MCPError(nombre, "tool desconocida en modo 'mi'")
        url = self.cfg.mcp_url.rstrip("/") + ruta.format(**argumentos)
        try:
            r = await self.cliente.get(url, headers=self._headers)
        except httpx.HTTPError as e:
            raise MCPError(nombre, f"no se pudo llegar al MI: {e}") from e
        if r.status_code >= 400:
            raise MCPError(nombre, f"HTTP {r.status_code}", r.status_code, r.text[:500])
        try:
            return r.json()
        except (json.JSONDecodeError, ValueError):
            return r.text


def _parsear_respuesta(texto: str) -> dict:
    """El gateway puede responder JSON o Server-Sent Events."""
    texto = texto.strip()
    if texto.startswith("{"):
        return json.loads(texto)
    for linea in texto.splitlines():
        if linea.startswith("data:"):
            return json.loads(linea[5:].strip())
    raise ValueError("respuesta que no es ni JSON ni SSE")


def _contenido_mcp(result: dict) -> Any:
    """Desempaqueta el content de un tools/call a algo usable."""
    contenido = result.get("content") or []
    textos = [c.get("text", "") for c in contenido if c.get("type") == "text"]
    crudo = "\n".join(textos) if textos else json.dumps(result)
    try:
        return json.loads(crudo)
    except (json.JSONDecodeError, ValueError):
        return crudo


# --- Tools del modo desarrollo -------------------------------------------
# Subconjunto de las tools reales, con las rutas REST del MI. Solo lectura: el
# modo dev no expone escritura para no crear OTs sin querer mientras se prueba.
_RUTAS_DEV = {
    "man_get_equipos": "/man/equipos",
    "man_get_equipo": "/man/equipo/{equi_id}",
    "man_get_ots": "/man/ots",
    "man_get_kpi_mtbf": "/man/kpi/mtbf",
    "man_get_kpi_disponibilidad": "/man/kpi/disponibilidad",
}

_TOOLS_DEV = [
    {"type": "function", "function": {
        "name": "man_get_equipos",
        "description": "Lista los equipos de la empresa del usuario.",
        "parameters": {"type": "object", "properties": {}},
    }},
    {"type": "function", "function": {
        "name": "man_get_equipo",
        "description": "Ficha de un equipo por su id.",
        "parameters": {
            "type": "object",
            "properties": {"equi_id": {"type": "string", "description": "Id del equipo"}},
            "required": ["equi_id"],
        },
    }},
    {"type": "function", "function": {
        "name": "man_get_ots",
        "description": "Ordenes de trabajo de la empresa del usuario.",
        "parameters": {"type": "object", "properties": {}},
    }},
    {"type": "function", "function": {
        "name": "man_get_kpi_mtbf",
        "description": "MTBF (tiempo medio entre fallas) de los equipos.",
        "parameters": {"type": "object", "properties": {}},
    }},
    {"type": "function", "function": {
        "name": "man_get_kpi_disponibilidad",
        "description": "Disponibilidad de los equipos.",
        "parameters": {"type": "object", "properties": {}},
    }},
]
