"""El loop del agente, con OpenRouter mockeado (no gasta tokens).

Las interacciones que estos tests generan quedan en la base con empr_id 900001
--un id alto, reservado para pruebas, que no colisiona con empresas reales--.
No se borran porque el rol del orquestador no tiene DELETE sobre interaccion, y
eso es deliberado (ver test_el_orquestador_no_puede_borrar_interacciones). Para
purgarlas hace falta el rol propietario:

    DELETE FROM agente.interaccion WHERE empr_id >= 900000;

Los tests que necesitan base usan la base real del agente; si no esta
disponible se saltean, asi la suite corre igual en una maquina sin ella.
"""
from __future__ import annotations

import json
import os

import pytest

from agente import rag
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool


# --------------------------------------------------------------- infraestructura
async def _conectar_o_saltear() -> object:
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
        await c.close()


class MCPFalso:
    """Doble del cliente MCP. Registra lo llamado, sin red."""

    def __init__(self, tools=None, salidas=None):
        self._tools = tools or []
        self._salidas = salidas or {}
        self.llamadas = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_):
        return None

    async def listar_tools(self):
        return self._tools

    async def llamar(self, nombre, argumentos):
        from agente.mcp_client import LlamadaTool
        self.llamadas.append(LlamadaTool(nombre, argumentos, "ok", 1))
        return self._salidas.get(nombre, {"ok": True})


def _parchar(monkeypatch, llm, mcp):
    """Sustituye OpenRouter y ClienteMCP dentro del orquestador."""
    import agente.orquestador as mod
    monkeypatch.setattr(mod, "OpenRouter", lambda cfg: llm)
    monkeypatch.setattr(mod, "ClienteMCP", lambda cfg, auth: mcp)


TOOL_EQUIPOS = {
    "type": "function",
    "function": {"name": "man_get_equipos", "description": "equipos",
                 "parameters": {"type": "object", "properties": {}}},
}


# ------------------------------------------------------------------- tests
@pytest.mark.asyncio
async def test_responde_sin_llamar_tools(con, monkeypatch, llm_falso):
    """Una pregunta de conocimiento general no necesita datos del cliente."""
    llm = llm_falso([respuesta_texto("Cada 500 horas de operación.")])
    mcp = MCPFalso(tools=[TOOL_EQUIPOS])
    _parchar(monkeypatch, llm, mcp)

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Cada cuánto se cambian las muelas?",
        autorizacion="Bearer t",
    ))

    assert res.respuesta == "Cada 500 horas de operación."
    assert res.tools_llamadas == []
    assert res.error is None
    assert llm.textos_vectorizados == ["¿Cada cuánto se cambian las muelas?"]


@pytest.mark.asyncio
async def test_llama_una_tool_y_despues_responde(con, monkeypatch, llm_falso):
    """Cuando la pregunta depende de datos, el modelo pide la tool."""
    llm = llm_falso([
        respuesta_tool("man_get_equipos"),
        respuesta_texto("Tenés 3 equipos activos."),
    ])
    mcp = MCPFalso(tools=[TOOL_EQUIPOS], salidas={"man_get_equipos": {"equipos": [1, 2, 3]}})
    _parchar(monkeypatch, llm, mcp)

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Cuántos equipos tengo?", autorizacion="Bearer t",
    ))

    assert res.respuesta == "Tenés 3 equipos activos."
    assert [t["tool"] for t in res.tools_llamadas] == ["man_get_equipos"]
    # La salida de la tool tiene que haberle vuelto al modelo como mensaje 'tool'.
    ultimos = llm.llamadas_chat[-1]["mensajes"]
    assert any(m.get("role") == "tool" for m in ultimos)


@pytest.mark.asyncio
async def test_una_tool_que_falla_no_corta_la_conversacion(con, monkeypatch, llm_falso):
    """El error vuelve al modelo como contenido, para que pueda explicarlo.

    Si se propagara como excepcion, el usuario recibiria un error tecnico en
    lugar de "no pude consultar el dato".
    """
    from agente.mcp_client import MCPError

    class MCPQueFalla(MCPFalso):
        async def llamar(self, nombre, argumentos):
            from agente.mcp_client import LlamadaTool
            self.llamadas.append(LlamadaTool(nombre, argumentos, "error", 1, "HTTP 500"))
            raise MCPError(nombre, "HTTP 500")

    llm = llm_falso([
        respuesta_tool("man_get_equipos"),
        respuesta_texto("No pude consultar tus equipos en este momento."),
    ])
    mcp = MCPQueFalla(tools=[TOOL_EQUIPOS])
    _parchar(monkeypatch, llm, mcp)

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Cuántos equipos tengo?", autorizacion="Bearer t",
    ))

    assert "No pude consultar" in res.respuesta
    assert res.tools_llamadas[0]["status"] == "error"
    contenido_tool = [
        m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"
    ][0]["content"]
    assert "error" in json.loads(contenido_tool)


@pytest.mark.asyncio
async def test_si_falla_el_modelo_el_usuario_recibe_un_mensaje_util(con, monkeypatch, llm_falso):
    """Un fallo del LLM no puede salir como stacktrace ni como 500 pelado."""
    from agente.llm import LLMError

    class LLMQueFalla:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            return None

        async def embeddings(self, textos):
            return [[0.0] * 1023 + [1.0]]

        async def chat(self, mensajes, tools=None):
            raise LLMError("OpenRouter respondio 503", 503)

    _parchar(monkeypatch, LLMQueFalla(), MCPFalso())

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="hola", autorizacion="Bearer t",
    ))

    assert "problema técnico" in res.respuesta
    assert res.error and "LLMError" in res.error


@pytest.mark.asyncio
async def test_corta_si_el_modelo_pide_tools_para_siempre(con, monkeypatch, llm_falso):
    """Sin tope, un modelo que insiste en llamar tools nunca responderia."""
    llm = llm_falso([respuesta_tool("man_get_equipos") for _ in range(10)])
    mcp = MCPFalso(tools=[TOOL_EQUIPOS])
    _parchar(monkeypatch, llm, mcp)

    cfg = Config()
    res = await Orquestador(cfg).responder(con, Consulta(
        empr_id=900001, pregunta="dale", autorizacion="Bearer t",
    ))

    assert res.error == "max_iteraciones alcanzado"
    assert len(llm.llamadas_chat) == cfg.max_iteraciones
    assert res.respuesta  # igual le contesta algo al usuario


@pytest.mark.asyncio
async def test_la_interaccion_queda_registrada(con, monkeypatch, llm_falso):
    """Sin este registro, el feedback no sirve para nada."""
    llm = llm_falso([respuesta_texto("respuesta de prueba")])
    _parchar(monkeypatch, llm, MCPFalso())

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="pregunta de prueba", autorizacion="Bearer t",
    ))

    async with con.cursor() as cur:
        await cur.execute(
            "SELECT pregunta, respuesta, modelo, fragmentos_rag, tools_llamadas "
            "FROM agente.interaccion WHERE interaccion_id = %s",
            (res.interaccion_id,),
        )
        fila = await cur.fetchone()

    assert fila is not None, "La interaccion tiene que quedar registrada"
    assert fila["pregunta"] == "pregunta de prueba"
    assert fila["respuesta"] == "respuesta de prueba"
    assert fila["modelo"] == "modelo-de-prueba"


@pytest.mark.asyncio
async def test_el_orquestador_no_puede_borrar_interacciones(con, monkeypatch, llm_falso):
    """El historial no se puede alterar desde el runtime.

    agente_app tiene SELECT/INSERT/UPDATE sobre interaccion, pero NO DELETE. Es
    a proposito: el registro de que se pregunto y que se respondio es el insumo
    del ciclo de mejora y la evidencia de que dijo el agente. Un bug o un abuso
    del orquestador no tiene que poder borrarlo.
    """
    import psycopg

    llm = llm_falso([respuesta_texto("otra respuesta")])
    _parchar(monkeypatch, llm, MCPFalso())
    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="pregunta que no se puede borrar",
        autorizacion="Bearer t",
    ))

    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        async with con.cursor() as cur:
            await cur.execute(
                "DELETE FROM agente.interaccion WHERE interaccion_id = %s",
                (res.interaccion_id,),
            )
    await con.rollback()
