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

from . import agentes, cargas, configuracion, funciones, guardian, mediciones, metas, pantalla, planes, planillas, rag, simulados, sugerencias, web
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
    # La pantalla de Tools donde esta el usuario (AGENTE-AS-01), ej.
    # "traz-comp-almacenes/Articulo". None = no se sabe (el chat de pagina).
    pantalla: str | None = None
    # El agente ya resuelto y con el acceso verificado (agentes.para_consulta).
    # None = el agente por defecto.
    agente: Agente | None = None
    # La planilla que el administrador subio para que Kuntur la pase a la
    # Carga Masiva (agente/planillas.py). None = no hay planilla en juego.
    planilla_id: str | None = None


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
    # Metas que Kuntur propuso con kpi_proponer_meta (AGENTE-CO-03). No se
    # graban: el panel las muestra y las carga el administrador.
    propuestas_meta: list[dict] = field(default_factory=list)
    # Cargas de configuracion que propuso Kuntur (ADR-A12): no se ejecutaron;
    # el panel las muestra y se ejecutan si el administrador toca "Cargar".
    propuestas_carga: list[dict] = field(default_factory=list)
    # Planes de accion que propuso Kuntur (ADR-A13): no se creo nada en Tareas;
    # el panel los muestra y se crean si el administrador toca "Aceptar".
    propuestas_plan: list[dict] = field(default_factory=list)


def _args_normalizados(crudo) -> dict:
    """Los argumentos de una tool como dict, para comparar dos llamadas."""
    try:
        v = json.loads(crudo or "{}") if isinstance(crudo, str) else (crudo or {})
    except (json.JSONDecodeError, ValueError):
        return {"_crudo": str(crudo)}
    return v if isinstance(v, dict) else {"_valor": v}


def _textos_del_plan(p: dict) -> list[str]:
    """Todo lo que el plan deja escrito en Tareas, para que el guardian lo revise.

    Prueba contra DEV (2026-11-23): una tarea llevaba "sugerido: 100 u. aceite",
    cantidades que no salian de ninguna tool, y terminaban en el pedido real."""
    out = [p.get("porque", ""), p.get("objetivo", "")]
    ped = p.get("pedido") or {}
    out += [ped.get("nombre", ""), ped.get("descripcion", "")]
    for h in p.get("hitos") or []:
        out.append(h.get("nombre", ""))
        for t in h.get("tareas") or []:
            out += [t.get("nombre", ""), t.get("descripcion", "")]
    return [x for x in out if x]


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
        # ADR-A11: el conocimiento de la industria de la empresa, mas lo general.
        vertical = await rag.vertical_de(con, consulta.empr_id)
        res.controles.append({"control": "vertical", "vertical": vertical or "sin_declarar"})
        try:
            vector = (await llm.embeddings([consulta.pregunta]))[0]
            fragmentos = (
                await rag.buscar_conocimiento(con, self.cfg, vector, vertical=vertical)
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
        ]
        # Donde esta parado el usuario (AGENTE-AS-01): los casos de uso de esa
        # pantalla, encontrados por su controlador. Tambien cuentan como fuente
        # para el guardian de cifras.
        if consulta.pantalla and pantalla.ruta_valida(consulta.pantalla):
            casos = await pantalla.casos_de(con, consulta.pantalla)
            texto_pantalla = pantalla.contexto(consulta.pantalla, casos)
            mensajes.append({"role": "system", "content": texto_pantalla})
            contexto += "\n\n" + texto_pantalla
            res.controles.append({"control": "pantalla", "ruta": consulta.pantalla,
                                  "casos": [c.caso_uso for c in casos]})
        # Lo que el administrador le conto a Kuntur en la entrevista de
        # configuracion (AGENTE-CO-02): que exige la operadora, que le preocupa.
        if consulta.agente.clave == "kuntur":
            texto_perfil = configuracion.contexto(await configuracion.perfil(con, consulta.empr_id))
            if texto_perfil:
                mensajes.append({"role": "system", "content": texto_perfil})
                contexto += "\n\n" + texto_perfil
            res.controles.append({"control": "perfil_empresa", "configurado": bool(texto_perfil)})
            # La planilla subida: al modelo, solo encabezados y unas 20 filas (P-8).
            # Cuenta como fuente para el guardian de cifras.
            if consulta.planilla_id:
                try:
                    texto_planilla = planillas.contexto(await planillas.obtener(con, consulta.planilla_id))
                    mensajes.append({"role": "system", "content": texto_planilla})
                    contexto += "\n\n" + texto_planilla
                    res.controles.append({"control": "planilla", "planilla_id": consulta.planilla_id})
                except planillas.PlanillaInvalida:
                    res.controles.append({"control": "planilla", "planilla_id": consulta.planilla_id,
                                          "error": "no existe"})
            # Planes que el administrador no quiso (ADR-A13): para no repetirlos.
            descartados = await planes.descartados_recientes(con)
            if descartados:
                lineas = [f"- «{d['pedido']}»: {planes.MOTIVOS.get(d['motivo'], d['motivo'])}"
                          + (f" ({d['texto']})" if d.get("texto") else "") for d in descartados]
                mensajes.append({"role": "system", "content":
                                 "Planes de acción que el administrador no quiso en los últimos 90 días "
                                 "(no los vuelvas a proponer igual):\n" + "\n".join(lineas)})
        mensajes.append({"role": "user", "content": consulta.pregunta})
        # Lista blanca (ADR-A8, AGENTE-M-02). Primera barrera: el modelo solo
        # VE las tools que este agente puede usar. Las de escritura no estan,
        # aunque el gateway las publique.
        permitidas = await agentes.tools_permitidas(con, consulta.agente.clave)
        # Las de configuracion (ADR-A12) se ofrecen, pero el motor no las ejecuta.
        de_config = await cargas.de_configuracion(con, consulta.agente.clave)
        try:
            del_gateway = await mcp.listar_tools()
        except MCPError as e:
            # Sin el gateway igual se responde con lo que se sabe (conocimiento y
            # web), avisando que no se pudieron consultar los datos de la empresa.
            # Antes, la consulta entera terminaba en "problema técnico".
            log.warning("Gateway MCP no disponible, se responde sin datos de la empresa: %s", e)
            res.controles.append({"control": "mcp_no_disponible", "error": str(e)[:200]})
            del_gateway = []
            mensajes.insert(len(mensajes) - 1, {"role": "system", "content":
                "Ahora no podés consultar los datos de la empresa: el sistema que los da no responde. "
                "Si la pregunta los necesita, decilo así y no des cifras de la empresa. "
                "Si se puede responder con lo que sabés o con internet, respondé."})
        tools = [t for t in del_gateway
                 if t.get("function", {}).get("name") in permitidas]
        # La busqueda web es una tool del motor, no del gateway: pasa por la
        # misma lista blanca, y solo se ofrece si hay un buscador configurado.
        if web.NOMBRE in permitidas and web.habilitada(self.cfg):
            tools.append(web.DEFINICION)
        # Proponer una meta tambien es del motor: no escribe nada (AGENTE-CO-03).
        if metas.NOMBRE in permitidas:
            tools.append(metas.DEFINICION)
        # Proponer un plan de accion es del motor y no crea nada en Tareas (ADR-A13).
        if planes.NOMBRE in permitidas:
            tools.append(planes.DEFINICION)
        # Pedir una medicion a Quirqui (AGENTE-CO-06): del motor, solo escribe la
        # base del agente y el administrador la ve y la cancela (R11).
        if mediciones.NOMBRE in permitidas:
            tools.append(mediciones.DEFINICION)
        # Servicios simulados de la puesta en marcha (deuda tecnica): mismo
        # nombre e interfaz que tendran los reales. Si el gateway ya publica
        # uno, gana el del gateway.
        # Son parte de la puesta en marcha: solo para el agente que la hace (el
        # que tiene tools de configuracion). Quirqui no ve datos simulados.
        publicadas = {t.get("function", {}).get("name") for t in tools}
        if de_config:
            tools += [d for d in simulados.definiciones(permitidas) if d["function"]["name"] not in publicadas]
        # La carga masiva de una planilla es del motor (lote 2): solo si hay planilla.
        if planillas.NOMBRE in de_config and consulta.planilla_id:
            tools.append(planillas.DEFINICION)
        res.controles.append({
            "control": "lista_blanca",
            "publicadas": len(del_gateway), "ofrecidas": len(tools),
        })

        reintento_usado = False
        cerrada = False
        ya_consultadas: set[tuple[str, str]] = set()
        # Una vuelta de mas, reservada para el reintento: no compite con las consultas.
        for vuelta in range(self.cfg.max_iteraciones + 1):
            if vuelta == self.cfg.max_iteraciones and not reintento_usado:
                break  # la vuelta extra es solo para el reintento
            respuesta = await llm.chat(mensajes, tools=tools)
            res.modelo = respuesta.modelo
            res.tokens_prompt += respuesta.tokens_prompt
            res.tokens_respuesta += respuesta.tokens_respuesta
            if respuesta.costo_usd is not None:
                res.costo_usd = (res.costo_usd or 0.0) + float(respuesta.costo_usd)

            if not respuesta.pide_tools:
                texto = respuesta.texto.strip()
                res.respuesta = texto
                bloqueada = bool(texto) and self._guardian(consulta, res, contexto)
                # Un solo reintento (2026-11-22): si la respuesta vino vacia o el guardian
                # la bloqueo, se le pide al modelo que la rehaga. Lo que se muestra pasa
                # igual por el guardian: R4 no se afloja, se le da una segunda oportunidad.
                if (not texto or bloqueada) and not reintento_usado:
                    reintento_usado = True
                    res.controles.append({"control": "reintento",
                                          "motivo": "vacia" if not texto else "cifras_sin_fuente"})
                    if texto:
                        cifras = res.incidentes[-1].get("cifras", []) if res.incidentes else []
                        mensajes.append({"role": "assistant", "content": texto})
                        mensajes.append({"role": "system", "content":
                            "Esa respuesta no se le mostró al usuario: tiene cifras que no aparecen tal cual "
                            f"en los datos ({', '.join(map(str, cifras)) or 'ver arriba'}). Reescribila sin esas "
                            "cifras y sin cuentas propias (sumas, totales, promedios): nombrá cada valor como vino "
                            "de las herramientas. Las tarjetas que propusiste en esta respuesta tampoco se "
                            "mostraron: si querés proponer algo, volvé a usar la herramienta sin esas cifras."})
                    else:
                        mensajes.append({"role": "system", "content":
                            "No respondiste nada. Respondele al usuario ahora con lo que ya consultaste, "
                            "o usá la herramienta que corresponda."})
                    continue
                if not texto:
                    res.respuesta = ("No pude armar una respuesta esta vez. "
                                     "Probá de nuevo o reformulá la pregunta.")
                cerrada = True
                break

            # 4. El modelo pidio datos: se los buscamos y volvemos a preguntar.
            mensajes.append({
                "role": "assistant", "content": respuesta.texto or None,
                "tool_calls": respuesta.tool_calls,
            })
            for llamada in respuesta.tool_calls:
                pedida = llamada.get("function", {}).get("name")
                if pedida == mediciones.NOMBRE and pedida in permitidas:
                    mensaje = await self._pedir_medicion(con, consulta, mcp, llamada)
                elif pedida in de_config:
                    mensaje = await self._proponer_carga(con, consulta, mcp, llamada, res)
                elif pedida == planes.NOMBRE and pedida in permitidas:
                    mensaje = await self._proponer_plan(con, consulta, mcp, llamada, res)
                elif (de_config and pedida in permitidas and pedida in simulados.SERVICIOS
                      and simulados.SERVICIOS[pedida].clase == simulados.LECTURA):
                    mensaje = await self._leer_simulado(con, consulta, mcp, llamada)
                else:
                    # La misma consulta con los mismos parametros no se repite en una
                    # corrida: los modelos chicos insisten y gastan las vueltas.
                    fn = llamada.get("function", {})
                    clave_llamada = (pedida, json.dumps(_args_normalizados(fn.get("arguments")), sort_keys=True))
                    if clave_llamada in ya_consultadas:
                        mensaje = {"role": "tool", "tool_call_id": llamada.get("id"), "name": pedida,
                                   "content": json.dumps({"aviso": "Ya hiciste esta misma consulta en esta "
                                                          "respuesta; usá ese resultado y seguí."}, ensure_ascii=False)}
                        mensajes.append(mensaje)
                        continue
                    ya_consultadas.add(clave_llamada)
                    mensaje = await self._ejecutar(mcp, llamada, permitidas, res)
                mensajes.append(mensaje)
                res.contenidos_tools.append(mensaje["content"])
                res.tools_vistas.append((mensaje["name"], mensaje["content"]))
                if mcp.llamadas and mcp.llamadas[-1].status == "bloqueada":
                    res.incidentes.append({
                        "tipo": "tool_bloqueada", "tool": mensaje["name"],
                        "detalle": "el modelo pidio una tool fuera de su lista blanca",
                    })
        if not cerrada and (res.propuestas_meta or res.propuestas_carga
                            or getattr(res, "propuestas_plan", None)):
            # Se quedo sin vueltas justo despues de proponer: la propuesta es la respuesta.
            res.respuesta = "Te dejé la propuesta lista en la tarjeta: revisala y decidí."
        elif not cerrada:
            # Se agotaron las iteraciones sin una respuesta final.
            res.respuesta = (
                "Necesité consultar varios datos y no llegué a cerrar una respuesta. "
                "Probá acotando un poco la pregunta."
            )
            res.error = "max_iteraciones alcanzado"

        res.tools_llamadas = [ll.a_dict() for ll in mcp.llamadas]
        return res

    def _guardian(self, consulta: Consulta, res: Resultado, contexto: str) -> bool:
        """R4: toda cifra de la respuesta tiene que tener origen, o se bloquea.

        Se compara contra lo que el modelo LEYO en esta corrida: el contenido de
        cada tool tal como se le paso, el contexto de conocimiento y memoria, y
        la pregunta. Ver agente/guardian.py.
        """
        # El motivo de una meta propuesta lo escribe el modelo y se muestra en la
        # tarjeta: sus cifras se controlan igual que las de la respuesta.
        texto = "\n\n".join([res.respuesta] + [p["motivo"] for p in res.propuestas_meta]
                              + [t for p in res.propuestas_plan for t in _textos_del_plan(p)])
        veredicto = guardian.revisar(texto, tools=res.tools_vistas, contexto=contexto,
                                     pregunta=consulta.pregunta)
        res.controles.append(veredicto.control())
        if veredicto.bloquear:
            log.warning("R4: respuesta bloqueada por cifras sin fuente: %s",
                        veredicto.sin_fuente + veredicto.web_sin_cita)
            res.incidentes.append(veredicto.incidente(texto))
            res.respuesta = guardian.MENSAJE_BLOQUEO
            # Una tarjeta de meta al lado de "no tengo datos" confunde: se cae con la respuesta.
            res.propuestas_meta = []
            # Las cargas quedan guardadas como propuesta, pero no se muestran: sin
            # tarjeta nadie las confirma y vencen solas.
            res.propuestas_carga = []
            # Igual con los planes: quedan como propuesta y vencen solos.
            res.propuestas_plan = []
            return True
        return False

    async def _ejecutar(self, mcp: ClienteMCP, llamada: dict,
                        permitidas: frozenset[str], res: Resultado | None = None) -> dict:
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
        if nombre == metas.NOMBRE:
            return self._proponer_meta(mcp, llamada, argumentos, res)

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

    async def _proponer_carga(self, con, consulta: Consulta, mcp: ClienteMCP, llamada: dict,
                              res: Resultado) -> dict:
        """Una tool de configuracion (ADR-A12): se guarda como carga propuesta y
        NO sale al MCP. La ejecuta el administrador desde la tarjeta."""
        fn = llamada.get("function", {})
        nombre = fn.get("name", "")
        try:
            argumentos = json.loads(fn.get("arguments") or "{}")
        except (json.JSONDecodeError, ValueError):
            argumentos = None
        error = None
        if not isinstance(argumentos, dict):
            error = "Los datos de la carga no son válidos: revisalos y volvé a armarla."
        elif nombre == planillas.NOMBRE:
            # El modelo dio el mapeo; las filas las transforma el codigo, todas.
            try:
                argumentos = await planillas.preparar(con, argumentos)
            except planillas.PlanillaInvalida as e:
                error = f"No se puede proponer: {e}. Corregilo y volvé a armarla."
        elif nombre in simulados.SERVICIOS:
            # La interfaz se controla al proponer: una tarjeta que no se puede cargar no se muestra.
            try:
                argumentos = simulados.validar(nombre, argumentos)
            except simulados.SimulacionInvalida as e:
                error = f"No se puede proponer: {e}. Corregilo y volvé a armarla."
        if error:
            mcp.llamadas.append(LlamadaTool(nombre, argumentos if isinstance(argumentos, dict) else {},
                                            "error", 0, error[:300]))
            salida = {"error": error}
        else:
            p = await cargas.proponer(
                con, empr_id=consulta.empr_id, interaccion_id=res.interaccion_id,
                agente=consulta.agente.clave, usuario=consulta.usuario_nick or str(consulta.usr_id or ""),
                tool=nombre, argumentos=argumentos)
            res.propuestas_carga.append(p.tarjeta())
            registro = ({k: v for k, v in argumentos.items() if k != "filas"} | {"total_filas": len(argumentos["filas"])}
                        if isinstance(argumentos.get("filas"), list) else argumentos)
            mcp.llamadas.append(LlamadaTool(nombre, registro, "propuesta", 0, None))
            salida = p.para_el_modelo()
        return {"role": "tool", "tool_call_id": llamada.get("id", ""), "name": nombre,
                "content": json.dumps(salida, ensure_ascii=False)[:8000]}

    async def _proponer_plan(self, con, consulta: Consulta, mcp: ClienteMCP, llamada: dict,
                             res: Resultado) -> dict:
        """kuntur_proponer_plan (ADR-A13): se valida y se guarda como propuesta.
        No sale al MCP ni crea nada en Tareas; lo crea el administrador al aceptar."""
        fn = llamada.get("function", {})
        try:
            argumentos = json.loads(fn.get("arguments") or "{}")
        except (json.JSONDecodeError, ValueError):
            argumentos = None
        try:
            plan = planes.validar(argumentos)
        except planes.PlanInvalido as e:
            mcp.llamadas.append(LlamadaTool(planes.NOMBRE, argumentos if isinstance(argumentos, dict) else {},
                                            "error", 0, str(e)[:300]))
            salida = {"error": f"No se puede proponer: {e} Corregilo y volvé a armarlo."}
        else:
            p = await planes.proponer(
                con, empr_id=consulta.empr_id, interaccion_id=res.interaccion_id,
                usuario=consulta.usuario_nick or str(consulta.usr_id or ""), plan=plan,
                agente=consulta.agente.clave)
            res.propuestas_plan.append(p.tarjeta())
            mcp.llamadas.append(LlamadaTool(planes.NOMBRE, {"pedido": plan["pedido"]["nombre"],
                                                             "hitos": len(plan["hitos"]),
                                                             "tareas": plan["total_tareas"]}, "propuesta", 0, None))
            salida = p.para_el_modelo()
        return {"role": "tool", "tool_call_id": llamada.get("id", ""), "name": planes.NOMBRE,
                "content": json.dumps(salida, ensure_ascii=False)}

    async def _leer_simulado(self, con, consulta: Consulta, mcp: ClienteMCP, llamada: dict) -> dict:
        """Una lectura de los servicios simulados (agente/simulados.py)."""
        nombre = llamada.get("function", {}).get("name", "")
        t0 = time.monotonic()
        salida = await simulados.leer(con, consulta.empr_id, nombre)
        mcp.llamadas.append(LlamadaTool(nombre, {}, "ok", int((time.monotonic() - t0) * 1000)))
        return {"role": "tool", "tool_call_id": llamada.get("id", ""), "name": nombre,
                "content": json.dumps(salida, ensure_ascii=False)[:8000]}

    async def _pedir_medicion(self, con, consulta: Consulta, mcp: ClienteMCP, llamada: dict) -> dict:
        """kuntur_pedir_medicion: valida y deja la medicion activa en la base del
        agente (AGENTE-CO-06). Quirqui la ejecuta en el trabajo programado."""
        fn = llamada.get("function", {})
        try:
            argumentos = json.loads(fn.get("arguments") or "{}")
        except (json.JSONDecodeError, ValueError):
            argumentos = {}
        try:
            salida = await mediciones.pedir(con, consulta.empr_id, argumentos)
            salida["nota"] = ("Queda activa: el administrador la ve en 'Lo que estoy midiendo' y la puede "
                              "cancelar. Quirqui la mide en el trabajo programado.")
            status, error = "ok", None
        except mediciones.MedicionInvalida as e:
            salida, status, error = {"error": str(e)}, "error", str(e)[:300]
        mcp.llamadas.append(LlamadaTool(mediciones.NOMBRE, argumentos, status, 0, error))
        return {"role": "tool", "tool_call_id": llamada.get("id", ""), "name": mediciones.NOMBRE,
                "content": json.dumps(salida, ensure_ascii=False, default=str)}

    def _proponer_meta(self, mcp: ClienteMCP, llamada: dict, argumentos: dict,
                       res: Resultado | None) -> dict:
        """kpi_proponer_meta: valida y deja la propuesta en la respuesta. No graba
        nada; la meta la carga el administrador desde la tarjeta (ADR-A8)."""
        try:
            propuesta = metas.proponer(argumentos)
            if res is not None:
                res.propuestas_meta.append(propuesta)
            # Al modelo vuelve la propuesta SIN el motivo: si volviera entero, una
            # cifra inventada en el motivo pasaria despues como "leida de una tool".
            salida = {"propuesta": {k: propuesta[k] for k in ("kpi", "titulo", "operador", "meta", "hasta")},
                      "nota": "Se le muestra al administrador como tarjeta; la carga él si está de acuerdo."}
            status, error = "ok", None
        except metas.PropuestaInvalida as e:
            salida, status, error = {"error": str(e)}, "error", str(e)[:300]
        mcp.llamadas.append(LlamadaTool(metas.NOMBRE, argumentos, status, 0, error))
        return {"role": "tool", "tool_call_id": llamada.get("id", ""), "name": metas.NOMBRE,
                "content": json.dumps(salida, ensure_ascii=False)}

    # ------------------------------------------------------- siguiente paso
    async def sugerir(self, con: psycopg.AsyncConnection, consulta: Consulta) -> list[dict]:
        """Hasta N propuestas de siguiente paso para la pantalla (AGENTE-AS-02).

        Reglas sobre las tools de esa pantalla (agente/sugerencias.py), con el
        token del usuario y por la lista blanca de su agente. No usa el modelo.
        La corrida queda registrada como cualquier otra (R8), con disparador
        'apertura_pantalla'.
        """
        from datetime import date

        t0 = time.monotonic()
        res = Resultado(interaccion_id=str(uuid.uuid4()), respuesta="")
        consulta.disparador = "apertura_pantalla"
        await rag.fijar_empresa(con, consulta.empr_id)
        if consulta.agente is None:
            consulta.agente = await agentes.obtener(con, AGENTE_POR_DEFECTO)

        propuestas: list[dict] = []
        modulo = sugerencias.modulo_de(consulta.pantalla)
        tools = tuple(sugerencias.REGLAS_POR_MODULO.get(modulo or "", ())) + sugerencias.REGLAS_SIEMPRE
        try:
            permitidas = await agentes.tools_permitidas(con, consulta.agente.clave)
            usar = [t for t in tools if t in permitidas]
            res.controles.append({"control": "lista_blanca", "publicadas": len(tools),
                                  "ofrecidas": len(usar)})
            cands: list[sugerencias.Candidata] = []
            async with ClienteMCP(self.cfg, consulta.autorizacion) as mcp:
                for tool in usar:
                    try:
                        data = await mcp.llamar(tool, {})
                    except MCPError as e:
                        log.warning("Sugerencias: %s fallo: %s", tool, e)
                        continue
                    res.tools_vistas.append((tool, json.dumps(data, ensure_ascii=False)[:8000]))
                    res.contenidos_tools.append(res.tools_vistas[-1][1])
                    cands += sugerencias.candidatas(
                        tool, data, hoy=date.today(),
                        dias_certificacion=self.cfg.sugerencia_dias_certificacion,
                        usuario=consulta.usuario_nick)
                res.tools_llamadas = [ll.a_dict() for ll in mcp.llamadas]
            cands.sort(key=lambda c: c.prioridad)
            propuestas = await self._guardar_propuestas(con, consulta, cands)
            res.respuesta = " · ".join(p["titulo"] for p in propuestas) or "(sin propuestas)"
        except Exception as e:  # noqa: BLE001 - se registra y se devuelve vacio
            res.error = f"{type(e).__name__}: {e}"
            res.respuesta = "(sin propuestas: error)"
            propuestas = []

        res.latencia_ms = int((time.monotonic() - t0) * 1000)
        if con.info.transaction_status == psycopg.pq.TransactionStatus.INERROR:
            await con.rollback()
            await rag.fijar_empresa(con, consulta.empr_id)
        await self._registrar(con, consulta, res)
        return propuestas

    async def _guardar_propuestas(self, con, consulta: Consulta, cands: list, *,
                                  maximo: int | None = None, silencio_dias: int | None = None,
                                  silencio_por_empresa: bool = False) -> list[dict]:
        """Guarda las propuestas nuevas y devuelve las que hay que mostrar.

        No repite lo que el usuario descarto hace menos de N dias, y reusa la
        pendiente si ya se habia propuesto lo mismo. Con silencio_por_empresa
        (funciones sin usar de Kuntur, AGENTE-CO-08), lo descartado por
        cualquier usuario de la empresa cuenta para todos.
        """
        usuario = consulta.usuario_nick or str(consulta.usr_id or "")
        maximo = self.cfg.sugerencias_max if maximo is None else maximo
        silencio = self.cfg.sugerencia_silencio_dias if silencio_dias is None else silencio_dias
        salida: list[dict] = []
        async with con.cursor() as cur:
            for c in cands:
                if len(salida) >= maximo:
                    break
                await cur.execute(
                    """
                    SELECT 1 FROM agente.propuesta
                    WHERE empr_id = %s AND clave = %s AND (%s OR usuario = %s)
                      AND estado = 'descartada'
                      AND fec_respuesta > now() - make_interval(days => %s)
                    """, (consulta.empr_id, c.clave, silencio_por_empresa, usuario, silencio))
                if await cur.fetchone():
                    continue
                await cur.execute(
                    """
                    INSERT INTO agente.propuesta
                        (empr_id, usuario, clave, tipo, pantalla, titulo, detalle, accion)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (empr_id, usuario, clave) WHERE estado = 'pendiente'
                    DO UPDATE SET titulo = EXCLUDED.titulo, detalle = EXCLUDED.detalle,
                                  accion = EXCLUDED.accion, pantalla = EXCLUDED.pantalla
                    RETURNING propuesta_id, tipo, titulo, detalle, accion
                    """,
                    (consulta.empr_id, usuario, c.clave, c.tipo, consulta.pantalla, c.titulo,
                     c.detalle, json.dumps(c.accion, ensure_ascii=False)))
                salida.append(dict(await cur.fetchone()))
        return salida

    async def recomendar_funciones(self, con: psycopg.AsyncConnection,
                                   consulta: Consulta) -> list[dict]:
        """Hasta N funciones de Tools que la empresa no usa (AGENTE-CO-08).

        Solo para Kuntur (quien llama ya verifico que es administrador, R1).
        Reglas sobre las tools de lectura (agente/funciones.py), con el token
        del administrador y por la lista blanca de Kuntur. No usa el modelo.
        Queda registrada como corrida (R8), con disparador 'apertura_pantalla'.
        """
        t0 = time.monotonic()
        res = Resultado(interaccion_id=str(uuid.uuid4()), respuesta="")
        consulta.disparador = "apertura_pantalla"
        await rag.fijar_empresa(con, consulta.empr_id)
        if consulta.agente is None:
            consulta.agente = await agentes.obtener(con, "kuntur")

        propuestas: list[dict] = []
        try:
            perfil = await configuracion.perfil(con, consulta.empr_id)
            modulos = list((perfil or {}).get("modulos") or []) if (perfil or {}).get("confirmado_por") else []
            tools = funciones.tools_necesarias(modulos)
            permitidas = await agentes.tools_permitidas(con, consulta.agente.clave)
            usar = [t for t in tools if t in permitidas]
            res.controles.append({"control": "lista_blanca", "publicadas": len(tools),
                                  "ofrecidas": len(usar)})
            datos: dict = {}
            async with ClienteMCP(self.cfg, consulta.autorizacion) as mcp:
                for tool in usar:
                    try:
                        datos[tool] = await mcp.llamar(tool, {})
                    except MCPError as e:
                        log.warning("Funciones sin usar: %s fallo: %s", tool, e)
                        continue
                    res.tools_vistas.append((tool, json.dumps(datos[tool], ensure_ascii=False)[:8000]))
                    res.contenidos_tools.append(res.tools_vistas[-1][1])
                res.tools_llamadas = [ll.a_dict() for ll in mcp.llamadas]
            cands = funciones.candidatas(datos, modulos)
            propuestas = await self._guardar_propuestas(
                con, consulta, cands, maximo=self.cfg.funciones_max,
                silencio_dias=self.cfg.funciones_silencio_dias, silencio_por_empresa=True)
            res.respuesta = " · ".join(p["titulo"] for p in propuestas) or "(sin funciones para recomendar)"
        except Exception as e:  # noqa: BLE001 - se registra y se devuelve vacio
            res.error = f"{type(e).__name__}: {e}"
            res.respuesta = "(sin funciones: error)"
            propuestas = []

        res.latencia_ms = int((time.monotonic() - t0) * 1000)
        if con.info.transaction_status == psycopg.pq.TransactionStatus.INERROR:
            await con.rollback()
            await rag.fijar_empresa(con, consulta.empr_id)
        await self._registrar(con, consulta, res)
        return propuestas

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
