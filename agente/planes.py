"""Plan de accion de Kuntur, opcion B (ADR-A13, AGENTE-CO-04).

Decision del PM (2026-11-12): Kuntur arma el plan COMPLETO -pedido de
trabajo, hitos y tareas sin responsable- y lo guarda en la base del agente
(agente.plan_propuesta). En Tareas no se crea nada hasta que el administrador
toca "Aceptar"; ahi se crea el pedido con SU token y siempre con el Proceso
Estandar. Si no lo quiere, queda descartado con el motivo.

  1. kuntur_proponer_plan (tool del motor, clase 'generacion'): el modelo
     llena la estructura; este modulo la valida (topes, nombres, nunca un
     responsable asignado, nunca un proceso) y la guarda como propuesta.
  2. El panel la muestra como tarjeta: por que, que se espera lograr, pedido
     (Proceso Estandar - N hitos - M tareas - S semanas), hitos por semana con
     sus tareas y el responsable SUGERIDO en gris. Aceptar / Pedir cambios /
     No lo quiero.
  3. aceptar(): ejecuta, todo o nada, alta de pedido -> hitos -> tareas (cada
     tarea queda colgada de su hito). Si un paso falla, deshace lo creado: da
     de baja las tareas y el pedido (los hitos no tienen baja en el servicio de
     datos; quedan colgados de un pedido eliminado, que ninguna lista muestra).

Mientras el PM no apruebe los recursos MCP de escritura (anexo del analisis
de impacto), SIMULADO = True: el mismo recorrido corre contra un registro en
agente.simulacion y devuelve un pedido 'SIM-n'. La tarjeta dice "(simulado)".
"""
from __future__ import annotations

import json
import re
import time
import uuid
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Any, Protocol

import psycopg

from . import metas, rag
from .config import Config
from .mcp_client import ClienteMCP, MCPError

NOMBRE = "kuntur_proponer_plan"

# Hasta que el PM apruebe los recursos MCP de escritura de Tareas.
SIMULADO = False  # el PM aprobó las escrituras en Tareas (anexo A) el 2026-11-22
ENTIDAD_SIMULACION = "tar.plan_accion"

# Lo fijo del pedido (regla del PM, 2026-11-12): la tool NO recibe proceso.
PROCESO = "PROCESO-STANDAR"
NOMBRE_PROCESO = "Proceso Estándar"

MAX_HITOS = 6
MAX_TAREAS = 30
MAX_SEMANAS = 26
VIGENCIA_DIAS = 7
MOTIVOS = {
    "no_es_prioridad": "No es prioridad ahora",
    "ya_lo_hacemos": "Ya lo estamos haciendo",
    "no_aplica": "No aplica a nuestra empresa",
    "otro": "Otro motivo",
}
# Claves que el modelo no puede mandar: el proceso es fijo y nadie se asigna.
_PROHIBIDAS = {"proceso", "proc_id", "user_id", "usuario", "responsable", "asignado", "case_id"}

DEFINICION = {
    "type": "function",
    "function": {
        "name": NOMBRE,
        "description": (
            "Propone al administrador un PLAN DE ACCIÓN para un desvío real de una meta: un pedido de "
            "trabajo con hitos (etapas por semana) y tareas. NO crea nada: el administrador lo ve como "
            "tarjeta y decide si lo acepta. Usala solo después de consultar los datos con tus "
            "herramientas; el 'porque' tiene que citar la cifra que leíste. Nunca asignes "
            "responsables: podés sugerir un puesto en 'responsable_sugerido'. El proceso es siempre el "
            "Proceso Estándar y no se elige."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "porque": {"type": "string",
                           "description": ("En una o dos líneas: qué número se movió y la causa principal, con la cifra "
                                           "leída. Nombrá la fuente en palabras («según el indicador de disponibilidad»), "
                                           "nunca el nombre interno de la herramienta.")},
                "objetivo": {"type": "string", "description": "Qué se espera lograr y en cuánto tiempo."},
                "meta": {
                    "type": "object",
                    "description": "Opcional: la meta del pedido sobre un indicador, para medir si el plan funcionó.",
                    "properties": {
                        "kpi": {"type": "string", "enum": sorted(metas.INDICADORES)},
                        "operador": {"type": "string", "enum": [">=", "<="]},
                        "meta": {"type": "number"},
                        "hasta": {"type": "string", "description": "YYYY-MM-DD"},
                    },
                    "required": ["kpi", "operador", "meta", "hasta"],
                },
                "pedido": {
                    "type": "object",
                    "properties": {
                        "nombre": {"type": "string", "description": "Nombre corto del pedido de trabajo."},
                        "descripcion": {"type": "string"},
                    },
                    "required": ["nombre"],
                },
                "hitos": {
                    "type": "array", "maxItems": MAX_HITOS,
                    "items": {
                        "type": "object",
                        "properties": {
                            "nombre": {"type": "string"},
                            "semana_desde": {"type": "integer", "minimum": 1},
                            "semana_hasta": {"type": "integer", "minimum": 1},
                            "tareas": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "nombre": {"type": "string"},
                                        "descripcion": {"type": "string"},
                                        "responsable_sugerido": {
                                            "type": "string",
                                            "description": "Un puesto (ej. 'jefe de taller'), nunca una persona del sistema."},
                                    },
                                    "required": ["nombre"],
                                },
                            },
                        },
                        "required": ["nombre", "semana_desde", "semana_hasta", "tareas"],
                    },
                },
            },
            "required": ["porque", "objetivo", "pedido", "hitos"],
        },
    },
}


class PlanInvalido(ValueError):
    """El modelo armo mal el plan. El texto vuelve al modelo para que lo corrija."""


class PlanNoDisponible(ValueError):
    """No se puede responder: no existe, ya se respondio o vencio."""


class PasoFallido(RuntimeError):
    """Un paso de la creacion en Tareas fallo."""


def _texto(v: Any, maximo: int) -> str:
    """Normaliza espacios y recorta sin cortar una palabra a la mitad."""
    t = re.sub(r"\s+", " ", str(v or "")).strip()
    if len(t) <= maximo:
        return t
    corte = t[:maximo - 1].rsplit(" ", 1)[0].rstrip(" ,;:.")
    return corte + "…"


def _entero(v: Any, campo: str) -> int:
    try:
        n = int(v)
    except (TypeError, ValueError):
        raise PlanInvalido(f"{campo} tiene que ser un número de semana.") from None
    if n < 1 or n > MAX_SEMANAS:
        raise PlanInvalido(f"{campo} tiene que estar entre 1 y {MAX_SEMANAS}.")
    return n


def _prohibidas(d: dict, donde: str) -> None:
    malas = sorted(k for k in d if str(k).lower() in _PROHIBIDAS)
    if malas:
        raise PlanInvalido(f"{donde}: no se puede mandar {', '.join(malas)}. El proceso es siempre el "
                           "Proceso Estándar y nadie se asigna: sugerí un puesto en 'responsable_sugerido'.")


def validar(argumentos: Any, *, hoy: date | None = None) -> dict:
    """Lo que pidio el modelo, controlado y normalizado. PlanInvalido si no sirve."""
    if not isinstance(argumentos, dict):
        raise PlanInvalido("El plan no vino bien armado.")
    _prohibidas(argumentos, "El plan")
    porque = _texto(argumentos.get("porque"), 300)
    objetivo = _texto(argumentos.get("objetivo"), 300)
    if not porque:
        raise PlanInvalido("Falta el 'porque': qué número se movió y por qué.")
    if not objetivo:
        raise PlanInvalido("Falta el 'objetivo': qué se espera lograr.")
    pedido = argumentos.get("pedido")
    if not isinstance(pedido, dict):
        raise PlanInvalido("Falta el pedido.")
    _prohibidas(pedido, "El pedido")
    nombre = _texto(pedido.get("nombre"), 100)
    if not nombre:
        raise PlanInvalido("El pedido necesita un nombre.")
    hitos_in = argumentos.get("hitos")
    if not isinstance(hitos_in, list) or not hitos_in:
        raise PlanInvalido("El plan necesita al menos un hito.")
    if len(hitos_in) > MAX_HITOS:
        raise PlanInvalido(f"Máximo {MAX_HITOS} hitos: agrupá etapas.")
    hitos, total = [], 0
    for i, h in enumerate(hitos_in, start=1):
        if not isinstance(h, dict):
            raise PlanInvalido(f"El hito {i} no vino bien armado.")
        _prohibidas(h, f"El hito {i}")
        hn = _texto(h.get("nombre"), 100)
        if not hn:
            raise PlanInvalido(f"El hito {i} necesita un nombre.")
        desde = _entero(h.get("semana_desde"), f"semana_desde del hito {i}")
        hasta = _entero(h.get("semana_hasta"), f"semana_hasta del hito {i}")
        if hasta < desde:
            raise PlanInvalido(f"En el hito {i}, semana_hasta no puede ser anterior a semana_desde.")
        tareas_in = h.get("tareas")
        if not isinstance(tareas_in, list) or not tareas_in:
            raise PlanInvalido(f"El hito {i} necesita al menos una tarea.")
        tareas = []
        for j, t in enumerate(tareas_in, start=1):
            if not isinstance(t, dict):
                raise PlanInvalido(f"La tarea {j} del hito {i} no vino bien armada.")
            _prohibidas(t, f"La tarea {j} del hito {i}")
            tn = _texto(t.get("nombre"), 100)
            if not tn:
                raise PlanInvalido(f"La tarea {j} del hito {i} necesita un nombre.")
            tareas.append({"nombre": tn, "descripcion": _texto(t.get("descripcion"), 500),
                           "responsable_sugerido": _texto(t.get("responsable_sugerido"), 80)})
        total += len(tareas)
        hitos.append({"nombre": hn, "semana_desde": desde, "semana_hasta": hasta, "tareas": tareas})
    if total > MAX_TAREAS:
        raise PlanInvalido(f"Máximo {MAX_TAREAS} tareas en todo el plan (vinieron {total}).")
    plan = {
        "porque": porque, "objetivo": objetivo,
        "pedido": {"nombre": nombre, "descripcion": _texto(pedido.get("descripcion"), 500)},
        "proceso": PROCESO,
        "hitos": hitos,
        "semanas": max(h["semana_hasta"] for h in hitos),
        "total_tareas": total,
    }
    if argumentos.get("meta"):
        if not isinstance(argumentos["meta"], dict):
            raise PlanInvalido("La meta no vino bien armada.")
        try:
            m = metas.proponer({**argumentos["meta"], "motivo": objetivo}, hoy=hoy)
        except metas.PropuestaInvalida as e:
            raise PlanInvalido(f"Meta del plan: {e}") from None
        plan["meta"] = {k: m[k] for k in ("kpi", "titulo", "operador", "meta", "hasta")}
    return plan


# ----------------------------------------------------------- propuestas
@dataclass
class Propuesta:
    plan_id: str
    plan: dict
    estado: str = "propuesta"

    def tarjeta(self) -> dict:
        return {"plan_id": self.plan_id, "estado": self.estado, "simulado": SIMULADO,
                **self.plan, "proceso": NOMBRE_PROCESO}

    def para_el_modelo(self) -> dict:
        # Sin el 'porque' ni el 'objetivo': si volvieran, una cifra inventada ahi
        # pasaria despues como "leida de una tool" (mismo criterio que las metas).
        return {"plan_propuesto": self.plan_id, "hitos": len(self.plan["hitos"]),
                "tareas": self.plan["total_tareas"], "semanas": self.plan["semanas"],
                # Las semanas de cada hito las fija el plan, no son datos de la empresa:
                # el modelo las nombra ("Semana 1") y el guardian tiene que verlas.
                "calendario": [{"hito": i, "semana_desde": h.get("semana_desde"), "semana_hasta": h.get("semana_hasta")}
                               for i, h in enumerate(self.plan["hitos"], 1)],
                "nota": "No se creó nada en Tareas. El administrador ve el plan como tarjeta y lo crea "
                        "solo si toca «Aceptar». Decíselo así; no digas que ya está creado."}


async def proponer(con: psycopg.AsyncConnection, *, empr_id: int, interaccion_id: str | None,
                   usuario: str, plan: dict, agente: str = "kuntur") -> Propuesta:
    plan_id = str(uuid.uuid4())
    async with con.cursor() as cur:
        await cur.execute(
            "INSERT INTO agente.plan_propuesta (plan_id, empr_id, interaccion_id, agente, usuario, plan) "
            "VALUES (%s, %s, %s, %s, %s, %s::jsonb)",
            (plan_id, empr_id, interaccion_id, agente, usuario, json.dumps(plan, ensure_ascii=False)))
    return Propuesta(plan_id, plan)


async def pendientes(con: psycopg.AsyncConnection) -> list[dict]:
    """Las propuestas abiertas de la empresa (la del RLS), para pintarlas al abrir el panel."""
    async with con.cursor() as cur:
        await cur.execute(
            "UPDATE agente.plan_propuesta SET estado = 'vencida', fec_respuesta = now() "
            "WHERE estado = 'propuesta' AND fec_alta < now() - make_interval(days => %s)", (VIGENCIA_DIAS,))
        await cur.execute(
            "SELECT plan_id::text, plan FROM agente.plan_propuesta WHERE estado = 'propuesta' "
            "ORDER BY fec_alta DESC LIMIT 5")
        filas = await cur.fetchall()
    return [Propuesta(f["plan_id"], f["plan"]).tarjeta() for f in filas]


async def _pendiente(con: psycopg.AsyncConnection, plan_id: str) -> dict:
    try:
        uuid.UUID(plan_id)
    except ValueError:
        raise PlanNoDisponible("No existe ese plan") from None
    async with con.cursor() as cur:
        await cur.execute(
            "SELECT plan_id::text, plan, estado, fec_alta < now() - make_interval(days => %s) AS vencida "
            "FROM agente.plan_propuesta WHERE plan_id = %s FOR UPDATE", (VIGENCIA_DIAS, plan_id))
        f = await cur.fetchone()
    if not f:
        raise PlanNoDisponible("No existe ese plan")
    if f["estado"] != "propuesta":
        raise PlanNoDisponible(f"Ese plan ya está {f['estado']}")
    if f["vencida"]:
        async with con.cursor() as cur:
            await cur.execute("UPDATE agente.plan_propuesta SET estado = 'vencida', fec_respuesta = now() "
                              "WHERE plan_id = %s", (plan_id,))
        await con.commit()
        raise PlanNoDisponible(f"El plan venció (dura {VIGENCIA_DIAS} días). Pedile a Kuntur que lo arme de nuevo.")
    return dict(f)


# ------------------------------------------------------------ ejecucion
class Destino(Protocol):
    """Donde se crea el plan: el modulo de Tareas (por la fachada MCP) o la simulacion."""
    async def alta_pedido(self, datos: dict) -> str: ...
    async def alta_hito(self, petr_id: str, datos: dict) -> str: ...
    async def alta_tarea(self, hito_id: str, datos: dict) -> str: ...
    async def baja_pedido(self, petr_id: str) -> None: ...
    async def baja_tarea(self, tapl_id: str) -> None: ...


def _id(salida: Any, clave: str, paso: str) -> str:
    """El id que devuelve un paso: {'petr_id': ...} o anidado en 'respuesta'."""
    if isinstance(salida, dict):
        for d in (salida, salida.get("respuesta") if isinstance(salida.get("respuesta"), dict) else {}):
            v = d.get(clave)
            if v not in (None, ""):
                return str(v)
    raise PasoFallido(f"{paso}: no devolvió {clave}")


class DestinoMCP:
    """Tareas de verdad, por la fachada MCP, con el token del administrador.

    Los recursos estan en toolsMCPAPI.xml (POST/DELETE /mcp/tar/...); falta la
    aprobacion del PM para publicarlos (anexo del analisis de impacto)."""

    def __init__(self, mcp: ClienteMCP):
        self.mcp = mcp

    async def _llamar(self, tool: str, args: dict) -> Any:
        try:
            return await self.mcp.llamar(tool, args)
        except MCPError as e:
            raise PasoFallido(f"{tool}: {e}") from e

    async def alta_pedido(self, datos: dict) -> str:
        return _id(await self._llamar("tar_alta_pedido", datos), "petr_id", "Alta del pedido")

    async def alta_hito(self, petr_id: str, datos: dict) -> str:
        return _id(await self._llamar("tar_alta_hito", {"petr_id": petr_id, **datos}), "hito_id", "Alta de un hito")

    async def alta_tarea(self, hito_id: str, datos: dict) -> str:
        return _id(await self._llamar("tar_alta_tarea", {"hito_id": hito_id, **datos}), "tapl_id", "Alta de una tarea")

    async def baja_pedido(self, petr_id: str) -> None:
        await self._llamar("tar_baja_pedido", {"petr_id": petr_id})

    async def baja_tarea(self, tapl_id: str) -> None:
        await self._llamar("tar_baja_tarea", {"tapl_id": tapl_id})


class DestinoSimulado:
    """El mismo recorrido, sin tocar Tareas. Lo creado se graba al final, si todo anduvo."""

    def __init__(self):
        self.creado: dict = {"pedido": None, "hitos": [], "tareas": []}
        self._n = 0

    def _nuevo(self, prefijo: str) -> str:
        self._n += 1
        return f"SIM-{prefijo}{self._n}"

    async def alta_pedido(self, datos: dict) -> str:
        petr_id = self._nuevo("P")
        self.creado["pedido"] = {"petr_id": petr_id, **datos}
        return petr_id

    async def alta_hito(self, petr_id: str, datos: dict) -> str:
        hito_id = self._nuevo("H")
        self.creado["hitos"].append({"hito_id": hito_id, "petr_id": petr_id, **datos})
        return hito_id

    async def alta_tarea(self, hito_id: str, datos: dict) -> str:
        tapl_id = self._nuevo("T")
        self.creado["tareas"].append({"tapl_id": tapl_id, "hito_id": hito_id, **datos})
        return tapl_id

    async def baja_pedido(self, petr_id: str) -> None:
        self.creado["pedido"] = None

    async def baja_tarea(self, tapl_id: str) -> None:
        self.creado["tareas"] = [t for t in self.creado["tareas"] if t["tapl_id"] != tapl_id]


def codigo_de(plan_id: str, hoy: date) -> str:
    """El codigo del pedido (cod_proyecto, unico por empresa): K-AAMMDD-xxxx."""
    return f"K-{hoy:%y%m%d}-{plan_id.replace('-', '')[:6].upper()}"


def pasos(plan: dict, *, hoy: date | None = None, codigo: str = "K-PLAN") -> tuple[dict, list[tuple[dict, list[dict]]]]:
    """Lo que se manda a cada alta (contratos de /mcp/tar/* en toolsMCPAPI.xml).
    Fechas: el pedido arranca hoy; cada hito, en su semana relativa (semana 1 = hoy).
    El 'objetivo' de pedidos e hitos en Tareas es una DURACION: van las semanas."""
    hoy = hoy or date.today()
    fin = hoy + timedelta(weeks=plan["semanas"])
    pedido = {
        "codigo": codigo,
        "nombre": plan["pedido"]["nombre"],
        "descripcion": " ".join(x for x in (plan["pedido"]["descripcion"], f"Objetivo: {plan['objetivo']}",
                                            "(Plan propuesto por Kuntur)") if x),
        "semanas": plan["semanas"],
        "fec_inicio": hoy.isoformat(), "fec_entrega": fin.isoformat(),
    }
    hitos = []
    for n, h in enumerate(plan["hitos"], start=1):
        datos = {
            "numero": f"H{n:02d}",
            "descripcion": h["nombre"],
            "fec_inicio": (hoy + timedelta(weeks=h["semana_desde"] - 1)).isoformat(),
            "semanas": h["semana_hasta"] - h["semana_desde"] + 1,
        }
        tareas = [{"nombre": t["nombre"],
                   "descripcion": (t["descripcion"] + (f" (sugerido: {t['responsable_sugerido']})"
                                                        if t["responsable_sugerido"] else "")).strip()}
                  for t in h["tareas"]]
        hitos.append((datos, tareas))
    return pedido, hitos


async def crear(destino: Destino, plan: dict, *, hoy: date | None = None, codigo: str = "K-PLAN") -> dict:
    """Todo o nada: pedido -> hitos -> tareas. Si algo falla, deshace y avisa."""
    pedido, hitos = pasos(plan, hoy=hoy, codigo=codigo)
    petr_id, tareas_creadas, hitos_creados = None, [], []
    try:
        petr_id = await destino.alta_pedido(pedido)
        for datos, tareas in hitos:
            hito_id = await destino.alta_hito(petr_id, datos)
            hitos_creados.append(hito_id)
            for t in tareas:
                tareas_creadas.append(await destino.alta_tarea(hito_id, t))
    except PasoFallido as e:
        restos = []
        for tapl_id in reversed(tareas_creadas):
            try:
                await destino.baja_tarea(tapl_id)
            except PasoFallido:
                restos.append(f"tarea {tapl_id}")
        if petr_id is not None:
            try:
                await destino.baja_pedido(petr_id)
            except PasoFallido:
                restos.append(f"pedido {petr_id}")
        raise PasoFallido(
            f"No se creó el plan (es todo o nada): {e}."
            + (f" No se pudo deshacer: {', '.join(restos)}; avisá a soporte." if restos else "")
        ) from e
    return {"petr_id": petr_id, "hitos": hitos_creados, "tareas": tareas_creadas}


async def aceptar(con: psycopg.AsyncConnection, cfg: Config, *, empr_id: int, plan_id: str,
                  usuario: str, autorizacion: str, destino: Destino | None = None) -> dict:
    """El administrador toco "Aceptar". Se crea lo que quedo guardado, con SU token."""
    p = await _pendiente(con, plan_id)
    plan = p["plan"]
    t0 = time.monotonic()
    simulado = destino is None and SIMULADO
    codigo = codigo_de(plan_id, date.today())
    try:
        if destino is not None:
            creado = await crear(destino, plan, codigo=codigo)
        elif SIMULADO:
            sim = DestinoSimulado()
            creado = await crear(sim, plan, codigo=codigo)
            async with con.cursor() as cur:
                await cur.execute(
                    "INSERT INTO agente.simulacion (empr_id, servicio, entidad, clave, datos) "
                    "VALUES (%s, %s, %s, %s, %s::jsonb)",
                    (empr_id, NOMBRE, ENTIDAD_SIMULACION, plan_id,
                     json.dumps({"proceso": PROCESO, **sim.creado}, ensure_ascii=False)))
        else:
            async with ClienteMCP(cfg, autorizacion) as mcp:
                creado = await crear(DestinoMCP(mcp), plan, codigo=codigo)
        estado, resultado = "aceptada", {"creado": creado}
    except PasoFallido as e:
        estado, resultado, creado = "fallida", {"error": str(e)[:1000]}, {}
    resultado["ms"] = int((time.monotonic() - t0) * 1000)
    async with con.cursor() as cur:
        await cur.execute(
            "UPDATE agente.plan_propuesta SET estado = %s, petr_id = %s, simulado = %s, respondido_por = %s, "
            "resultado = %s::jsonb, fec_respuesta = now() WHERE plan_id = %s",
            (estado, creado.get("petr_id"), simulado, usuario,
             json.dumps(resultado, ensure_ascii=False, default=str), plan_id))
    await con.commit()
    await rag.fijar_empresa(con, empr_id)
    out = {"plan_id": plan_id, "estado": estado, "simulado": simulado, **resultado}
    if estado == "aceptada":
        out["petr_id"] = creado["petr_id"]
        # La meta del pedido la carga el panel con la sesion del administrador
        # (Pedidotrabajo/guardarMeta, TAR-METAS), solo si el pedido es real.
        if plan.get("meta") and not simulado:
            out["meta"] = plan["meta"]
    return out


async def descartar(con: psycopg.AsyncConnection, *, empr_id: int, plan_id: str, usuario: str,
                    motivo: str, texto: str | None = None) -> dict:
    if motivo not in MOTIVOS:
        raise PlanNoDisponible("Elegí un motivo de la lista.")
    await _pendiente(con, plan_id)
    async with con.cursor() as cur:
        await cur.execute(
            "UPDATE agente.plan_propuesta SET estado = 'descartada', motivo_descarte = %s, texto_descarte = %s, "
            "respondido_por = %s, fec_respuesta = now() WHERE plan_id = %s",
            (motivo, _texto(texto, 1000) or None, usuario, plan_id))
    await con.commit()
    await rag.fijar_empresa(con, empr_id)
    return {"plan_id": plan_id, "estado": "descartada", "motivo": motivo}


async def descartados_recientes(con: psycopg.AsyncConnection, dias: int = 90) -> list[dict]:
    """Lo que el administrador no quiso, con el motivo: Kuntur lo lee para no repetirlo."""
    async with con.cursor() as cur:
        await cur.execute(
            "SELECT plan->'pedido'->>'nombre' AS pedido, motivo_descarte AS motivo, texto_descarte AS texto "
            "FROM agente.plan_propuesta WHERE estado = 'descartada' "
            "AND fec_respuesta > now() - make_interval(days => %s) ORDER BY fec_respuesta DESC LIMIT 10", (dias,))
        return [dict(f) for f in await cur.fetchall()]
