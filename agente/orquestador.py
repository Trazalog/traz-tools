"""El loop del agente: recibe una consulta y arma la respuesta.

El ciclo, en criollo:

  1. Vectoriza la pregunta.
  2. Busca en el conocimiento compartido y en la memoria de ESA empresa.
  3. Le pasa al modelo el prompt de sistema + ese contexto + las tools MCP.
  4. Si el modelo pide llamar tools, las llama y le devuelve los resultados.
     Repite hasta que responda o se agote el maximo de iteraciones.
  5. Registra todo en agente.interaccion: pregunta, respuesta, que fragmentos
     uso y que tools llamo. Eso es lo que despues hace accionable un pulgar
     abajo.

Lo que decide si usar RAG, MCP o ambos es el modelo, no una heuristica nuestra:
tiene el contexto recuperado a la vista y las tools declaradas, y elige. El
prompt de sistema le dice cuando corresponde cada fuente.
"""
from __future__ import annotations

import json
import time
import uuid
from dataclasses import dataclass, field

import psycopg

from . import rag
from .config import Config
from .llm import LLMError, OpenRouter
from .mcp_client import ClienteMCP, MCPError
from .prompt import cargar as cargar_prompt


@dataclass
class Consulta:
    empr_id: int
    pregunta: str
    autorizacion: str
    usr_id: int | None = None
    usuario_nick: str | None = None
    canal: str = "chat_tools"


@dataclass
class Resultado:
    interaccion_id: str
    respuesta: str
    fragmentos: list[dict] = field(default_factory=list)
    tools_llamadas: list[dict] = field(default_factory=list)
    modelo: str = ""
    tokens_prompt: int = 0
    tokens_respuesta: int = 0
    latencia_ms: int = 0
    error: str | None = None


class Orquestador:
    def __init__(self, cfg: Config):
        self.cfg = cfg

    async def responder(
        self, con: psycopg.AsyncConnection, consulta: Consulta,
    ) -> Resultado:
        t0 = time.monotonic()
        interaccion_id = str(uuid.uuid4())
        res = Resultado(interaccion_id=interaccion_id, respuesta="")

        # RLS: sin esto no se ve ni se escribe nada de la empresa.
        await rag.fijar_empresa(con, consulta.empr_id)

        try:
            async with OpenRouter(self.cfg) as llm, ClienteMCP(
                self.cfg, consulta.autorizacion
            ) as mcp:
                res = await self._loop(con, consulta, llm, mcp, res)
        except (LLMError, MCPError) as e:
            res.error = f"{type(e).__name__}: {e}"
            res.respuesta = (
                "No pude responder ahora mismo por un problema técnico. "
                "Probá de nuevo en un momento."
            )
        except Exception as e:  # noqa: BLE001 - se registra y se responde igual
            res.error = f"{type(e).__name__}: {e}"
            res.respuesta = "No pude responder ahora mismo por un problema técnico."

        res.latencia_ms = int((time.monotonic() - t0) * 1000)
        await self._registrar(con, consulta, res)
        return res

    # ------------------------------------------------------------------ loop
    async def _loop(self, con, consulta, llm, mcp, res: Resultado) -> Resultado:
        # 1-2. Recuperacion
        vector = (await llm.embeddings([consulta.pregunta]))[0]
        fragmentos = (
            await rag.buscar_conocimiento(con, self.cfg, vector)
            + await rag.buscar_memoria(con, self.cfg, consulta.empr_id, vector)
        )
        fragmentos.sort(key=lambda f: f.distancia)
        res.fragmentos = [
            {"cita": f.cita, "origen": f.origen, "id": f.id,
             "distancia": round(f.distancia, 4)}
            for f in fragmentos
        ]

        # 3. Conversacion
        sistema = cargar_prompt(self.cfg.prompt_path)
        mensajes = [
            {"role": "system", "content": sistema},
            {"role": "system", "content":
                "Contexto recuperado para esta consulta:\n\n"
                + rag.armar_contexto(fragmentos)},
            {"role": "user", "content": consulta.pregunta},
        ]
        tools = await mcp.listar_tools()

        for _ in range(self.cfg.max_iteraciones):
            respuesta = await llm.chat(mensajes, tools=tools)
            res.modelo = respuesta.modelo
            res.tokens_prompt += respuesta.tokens_prompt
            res.tokens_respuesta += respuesta.tokens_respuesta

            if not respuesta.pide_tools:
                res.respuesta = respuesta.texto.strip()
                break

            # 4. El modelo pidio datos: se los buscamos y volvemos a preguntar.
            mensajes.append({
                "role": "assistant", "content": respuesta.texto or None,
                "tool_calls": respuesta.tool_calls,
            })
            for llamada in respuesta.tool_calls:
                mensajes.append(await self._ejecutar(mcp, llamada))
        else:
            # Se agotaron las iteraciones sin una respuesta final.
            res.respuesta = (
                "Necesité consultar varios datos y no llegué a cerrar una respuesta. "
                "Probá acotando un poco la pregunta."
            )
            res.error = "max_iteraciones alcanzado"

        res.tools_llamadas = [ll.a_dict() for ll in mcp.llamadas]
        return res

    async def _ejecutar(self, mcp: ClienteMCP, llamada: dict) -> dict:
        """Ejecuta una tool y arma el mensaje de vuelta para el modelo."""
        fn = llamada.get("function", {})
        nombre = fn.get("name", "")
        try:
            argumentos = json.loads(fn.get("arguments") or "{}")
        except (json.JSONDecodeError, ValueError):
            argumentos = {}

        try:
            salida = await mcp.llamar(nombre, argumentos)
            contenido = json.dumps(salida, ensure_ascii=False)[:8000]
        except MCPError as e:
            # El error vuelve al modelo como contenido, no como excepcion: asi
            # puede decirle al usuario que no pudo consultar el dato, en vez de
            # que se corte la conversacion entera.
            contenido = json.dumps(
                {"error": f"No se pudo consultar {nombre}: {e}"}, ensure_ascii=False
            )

        return {
            "role": "tool",
            "tool_call_id": llamada.get("id", ""),
            "name": nombre,
            "content": contenido,
        }

    # ------------------------------------------------------------- registro
    async def _registrar(self, con, consulta: Consulta, res: Resultado) -> None:
        """Guarda la interaccion completa. Es el insumo del ciclo de mejora."""
        sql = """
            INSERT INTO agente.interaccion
                (interaccion_id, empr_id, usr_id, usuario_nick, canal, pregunta,
                 respuesta, fragmentos_rag, tools_llamadas, modelo,
                 tokens_prompt, tokens_respuesta, latencia_ms, error)
            VALUES (%(id)s, %(empr_id)s, %(usr_id)s, %(nick)s, %(canal)s, %(pregunta)s,
                    %(respuesta)s, %(frags)s, %(tools)s, %(modelo)s,
                    %(tp)s, %(tr)s, %(lat)s, %(error)s)
            ON CONFLICT (interaccion_id) DO NOTHING
        """
        try:
            async with con.cursor() as cur:
                await cur.execute(sql, {
                    "id": res.interaccion_id, "empr_id": consulta.empr_id,
                    "usr_id": consulta.usr_id, "nick": consulta.usuario_nick,
                    "canal": consulta.canal, "pregunta": consulta.pregunta,
                    "respuesta": res.respuesta,
                    "frags": json.dumps(res.fragmentos, ensure_ascii=False),
                    "tools": json.dumps(res.tools_llamadas, ensure_ascii=False),
                    "modelo": res.modelo, "tp": res.tokens_prompt,
                    "tr": res.tokens_respuesta, "lat": res.latencia_ms,
                    "error": res.error,
                })
            await con.commit()
        except psycopg.Error:
            # Que falle el registro no puede tumbar una respuesta que ya esta
            # lista. Se pierde la traza de esa interaccion, no la respuesta.
            await con.rollback()
