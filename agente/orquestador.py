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

import logging

import psycopg

from . import agentes, guardian, rag, web
from .agentes import Agente
from .config import Config
from .llm import LLMError, OpenRouter
from .mcp_client import ClienteMCP, LlamadaTool, MCPError

log = logging.getLogger("agente.orquestador")

# Quien responde cuando la consulta no dice a que agente va.
AGENTE_POR_DEFECTO = "quirqui"


@dataclass
class Consulta:
    empr_id: int
    pregunta: str
    autorizacion: str
    usr_id: int | None = None
    usuario_nick: str | None = None
    canal: str = "chat_tools"
    # Que puso en marcha la corrida (R8): una consulta, un evento operativo...
    disparador: str = "consulta"
    # El agente ya resuelto y con el acceso verificado (agentes.para_consulta).
    # None = el agente por defecto.
    agente: Agente | None = None


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
    # R8: que se controlo, que hay que revisar, cuanto costo, y lo que cada tool
    # le devolvio al modelo (insumo del guardian de cifras, R4).
    costo_usd: float | None = None
    controles: list[dict] = field(default_factory=list)
    incidentes: list[dict] = field(default_factory=list)
    contenidos_tools: list[str] = field(default_factory=list)
    # (tool, contenido) en el orden en que se ejecutaron: lo que lee el guardian.
    tools_vistas: list[tuple[str, str]] = field(default_factory=list)


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

        if consulta.agente is None:
            consulta.agente = await agentes.obtener(con, AGENTE_POR_DEFECTO)

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

        # Si lo que fallo fue la base, la transaccion quedo abortada y el
        # registro tambien fallaria. Justo esas corridas son las que mas
        # interesa ver: se vuelve a una transaccion limpia, con la empresa.
        if con.info.transaction_status == psycopg.pq.TransactionStatus.INERROR:
            await con.rollback()
            await rag.fijar_empresa(con, consulta.empr_id)
        await self._registrar(con, consulta, res)
        return res

    # ------------------------------------------------------------------ loop
    async def _loop(self, con, consulta, llm, mcp, res: Resultado) -> Resultado:
        # 1-2. Recuperacion
        #
        # Si la vectorizacion falla, el agente NO se cae: sigue sin RAG, con las
        # tools y lo que el modelo sepa. Una respuesta sin conocimiento propio es
        # peor que una con el, pero es muchisimo mejor que ninguna -- y el caso
        # tipico es quedarse sin credito para embeddings, que no tiene por que
        # dejar al agente mudo.
        #
        # Queda registrado en la interaccion para que se vea por que esa
        # respuesta no tuvo fragmentos.
        fragmentos = []
        try:
            vector = (await llm.embeddings([consulta.pregunta]))[0]
            fragmentos = (
                await rag.buscar_conocimiento(con, self.cfg, vector)
                + await rag.buscar_memoria(con, self.cfg, consulta.empr_id, vector)
            )
            fragmentos.sort(key=lambda f: f.distancia)
        except LLMError as e:
            res.error = f"RAG no disponible: {e}"
            log.warning("Sin embeddings, se responde sin RAG: %s", e)
        res.fragmentos = [
            {"cita": f.cita, "origen": f.origen, "id": f.id,
             "distancia": round(f.distancia, 4)}
            for f in fragmentos
        ]

        # 3. Conversacion
        sistema = consulta.agente.sistema(self.cfg.prompts_dir)
        contexto = rag.armar_contexto(fragmentos)
        mensajes = [
            {"role": "system", "content": sistema},
            {"role": "system", "content":
                "Contexto recuperado para esta consulta:\n\n" + contexto},
            {"role": "user", "content": consulta.pregunta},
        ]
        # Lista blanca (ADR-A8, AGENTE-M-02). Primera barrera: el modelo solo
        # VE las tools que este agente puede usar. Las de escritura no estan,
        # aunque el gateway las publique.
        permitidas = await agentes.tools_permitidas(con, consulta.agente.clave)
        del_gateway = await mcp.listar_tools()
        tools = [t for t in del_gateway
                 if t.get("function", {}).get("name") in permitidas]
        # La busqueda web es una tool del motor, no del gateway: pasa por la
        # misma lista blanca, y solo se ofrece si hay un buscador configurado.
        if web.NOMBRE in permitidas and web.habilitada(self.cfg):
            tools.append(web.DEFINICION)
        res.controles.append({
            "control": "lista_blanca",
            "publicadas": len(del_gateway), "ofrecidas": len(tools),
        })

        for _ in range(self.cfg.max_iteraciones):
            respuesta = await llm.chat(mensajes, tools=tools)
            res.modelo = respuesta.modelo
            res.tokens_prompt += respuesta.tokens_prompt
            res.tokens_respuesta += respuesta.tokens_respuesta
            if respuesta.costo_usd is not None:
                res.costo_usd = (res.costo_usd or 0.0) + float(respuesta.costo_usd)

            if not respuesta.pide_tools:
                res.respuesta = respuesta.texto.strip()
                self._guardian(consulta, res, contexto)
                break

            # 4. El modelo pidio datos: se los buscamos y volvemos a preguntar.
            mensajes.append({
                "role": "assistant", "content": respuesta.texto or None,
                "tool_calls": respuesta.tool_calls,
            })
            for llamada in respuesta.tool_calls:
                mensaje = await self._ejecutar(mcp, llamada, permitidas)
                mensajes.append(mensaje)
                res.contenidos_tools.append(mensaje["content"])
                res.tools_vistas.append((mensaje["name"], mensaje["content"]))
                if mcp.llamadas and mcp.llamadas[-1].status == "bloqueada":
                    res.incidentes.append({
                        "tipo": "tool_bloqueada", "tool": mensaje["name"],
                        "detalle": "el modelo pidio una tool fuera de su lista blanca",
                    })
        else:
            # Se agotaron las iteraciones sin una respuesta final.
            res.respuesta = (
                "Necesité consultar varios datos y no llegué a cerrar una respuesta. "
                "Probá acotando un poco la pregunta."
            )
            res.error = "max_iteraciones alcanzado"

        res.tools_llamadas = [ll.a_dict() for ll in mcp.llamadas]
        return res

    def _guardian(self, consulta: Consulta, res: Resultado, contexto: str) -> None:
        """R4: toda cifra de la respuesta tiene que tener origen, o se bloquea.

        Se compara contra lo que el modelo LEYO en esta corrida: el contenido de
        cada tool tal como se le paso, el contexto de conocimiento y memoria, y
        la pregunta. Ver agente/guardian.py.
        """
        veredicto = guardian.revisar(res.respuesta, tools=res.tools_vistas, contexto=contexto,
                                     pregunta=consulta.pregunta)
        res.controles.append(veredicto.control())
        if veredicto.bloquear:
            log.warning("R4: respuesta bloqueada por cifras sin fuente: %s",
                        veredicto.sin_fuente + veredicto.web_sin_cita)
            res.incidentes.append(veredicto.incidente(res.respuesta))
            res.respuesta = guardian.MENSAJE_BLOQUEO

    async def _ejecutar(self, mcp: ClienteMCP, llamada: dict,
                        permitidas: frozenset[str]) -> dict:
        """Ejecuta una tool y arma el mensaje de vuelta para el modelo."""
        fn = llamada.get("function", {})
        nombre = fn.get("name", "")
        try:
            argumentos = json.loads(fn.get("arguments") or "{}")
        except (json.JSONDecodeError, ValueError):
            argumentos = {}

        # Segunda barrera: el modelo puede pedir una tool que no se le ofrecio
        # (porque la invento, o porque la conoce de otra conversacion). No sale
        # al MCP: se registra como bloqueada y vuelve al modelo como error.
        if nombre not in permitidas:
            log.warning("Tool fuera de la lista blanca bloqueada: %s", nombre)
            mcp.llamadas.append(LlamadaTool(
                nombre, argumentos, "bloqueada", 0, "fuera de la lista blanca del agente",
            ))
            contenido = json.dumps(
                {"error": f"La herramienta {nombre} no está disponible. "
                          "Solo podés consultar datos, no modificarlos."},
                ensure_ascii=False,
            )
            return {"role": "tool", "tool_call_id": llamada.get("id", ""),
                    "name": nombre, "content": contenido}

        if nombre == web.NOMBRE:
            return await self._buscar_web(mcp, llamada, argumentos)

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

    async def _buscar_web(self, mcp: ClienteMCP, llamada: dict, argumentos: dict) -> dict:
        """Ejecuta web_buscar. La traza va a la misma lista que las tools MCP,
        para que quede en tool_llamada en el orden en que se llamo."""
        t0 = time.monotonic()
        if not web.habilitada(self.cfg):
            salida, status, error = {"error": "La búsqueda en internet no está habilitada."}, "error", "sin AGENTE_WEB_URL"
        else:
            try:
                salida = await web.buscar(self.cfg, argumentos.get("consulta", ""))
                status, error = "ok", None
            except web.WebError as e:
                salida = {"error": f"No se pudo buscar en internet: {e}"}
                status, error = "error", str(e)[:300]
        mcp.llamadas.append(LlamadaTool(
            web.NOMBRE, argumentos, status, int((time.monotonic() - t0) * 1000), error,
        ))
        return {"role": "tool", "tool_call_id": llamada.get("id", ""), "name": web.NOMBRE,
                "content": json.dumps(salida, ensure_ascii=False)[:8000]}

    # ------------------------------------------------------------- registro
    async def _registrar(self, con, consulta: Consulta, res: Resultado) -> None:
        """Guarda la corrida completa (R8). Es el insumo del ciclo de mejora.

        Una fila en interaccion y una en tool_llamada por cada tool, en la misma
        transaccion: o queda la corrida entera o no queda nada.
        """
        sql = """
            INSERT INTO agente.interaccion
                (interaccion_id, empr_id, usr_id, usuario_nick, canal, pregunta,
                 respuesta, fragmentos_rag, tools_llamadas, modelo,
                 tokens_prompt, tokens_respuesta, latencia_ms, error,
                 agente, disparador, costo_usd, controles, incidentes)
            VALUES (%(id)s, %(empr_id)s, %(usr_id)s, %(nick)s, %(canal)s, %(pregunta)s,
                    %(respuesta)s, %(frags)s, %(tools)s, %(modelo)s,
                    %(tp)s, %(tr)s, %(lat)s, %(error)s,
                    %(agente)s, %(disparador)s, %(costo)s, %(controles)s, %(incidentes)s)
            ON CONFLICT (interaccion_id) DO NOTHING
        """
        sql_tool = """
            INSERT INTO agente.tool_llamada
                (interaccion_id, empr_id, orden, tool, argumentos, status,
                 contenido, latencia_ms, error)
            VALUES (%(id)s, %(empr_id)s, %(orden)s, %(tool)s, %(args)s, %(status)s,
                    %(contenido)s, %(lat)s, %(error)s)
        """
        # Lo que vio el modelo de cada tool, en el mismo orden que las llamadas.
        # Si la corrida se corto a mitad, puede haber menos contenidos que
        # llamadas: esas quedan sin contenido.
        filas_tools = [
            {"id": res.interaccion_id, "empr_id": consulta.empr_id, "orden": n,
             "tool": t["tool"],
             "args": json.dumps(t.get("argumentos") or {}, ensure_ascii=False),
             "status": t["status"],
             "contenido": res.contenidos_tools[n - 1] if n <= len(res.contenidos_tools) else None,
             "lat": t.get("latencia_ms"), "error": t.get("error")}
            for n, t in enumerate(res.tools_llamadas, start=1)
        ]
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
                    "agente": consulta.agente.clave if consulta.agente else None,
                    "disparador": consulta.disparador,
                    "costo": res.costo_usd,
                    "controles": json.dumps(res.controles, ensure_ascii=False),
                    "incidentes": json.dumps(res.incidentes, ensure_ascii=False),
                })
                if filas_tools:
                    await cur.executemany(sql_tool, filas_tools)
            await con.commit()
        except psycopg.Error as e:
            # Que falle el registro no puede tumbar una respuesta que ya esta
            # lista. Se pierde la traza de esa interaccion, no la respuesta.
            log.error("No se pudo registrar la corrida %s: %s", res.interaccion_id, e)
            await con.rollback()
