"""Medicion del plan y practicas (AGENTE-CO-05).

Cuando termina la ventana de una medicion de un plan de accion (medicion_pedida
con petr_id que paso a 'vencida'), el trabajo diario de mediciones:

  1. Compara el PRIMER valor medido con el ULTIMO (medicion_resultado) y decide
     con una regla, no con el modelo: funciono / no_funciono / sin_datos (menos
     de dos mediciones con valor). Queda una fila en agente.evaluacion_plan, una
     sola vez por medicion.
  2. Le avisa al administrador por los avisos de Tools (ADR-015), firmado por
     Kuntur. El texto es una plantilla con los dos numeros, sus fechas y la tool
     de la que salieron (R4). Si el aviso no se pudo publicar, se reintenta en
     la proxima corrida (la dedupe_key evita duplicados).
  3. Si funciono, propone una practica a la cola de curaduria (agente.candidato,
     origen 'plan_accion'): que se hizo (hitos y tareas del pedido), SIN cifras
     y SIN datos de la empresa, porque es conocimiento compartido y lo aprueba
     un curador (ADR-A4).

Hacia donde mejora el indicador: parametros.mejor de la medicion ('subir' o
'bajar'); si no lo dice, el sentido habitual del indicador (MEJOR_POR_TOOL); si
tampoco, 'subir'. Igual o peor = no funciono.
"""
from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from . import avisos

log = logging.getLogger("agente.evaluacion")

TIPO_AVISO = "plan_accion_resultado"
FUNCIONO, NO_FUNCIONO, SIN_DATOS = "funciono", "no_funciono", "sin_datos"
ORIGEN_CANDIDATO = "plan_accion"

# Sentido habitual de cada indicador medible (agente/mediciones.EXTRACTORES).
MEJOR_POR_TOOL = {
    "tar_get_atrasadas": "bajar",
    "man_get_kpi_fallas": "bajar",
    "man_get_kpi_mttr": "bajar",
    "man_get_kpi_disponibilidad": "subir",
    "man_get_kpi_mttf": "subir",
}

# Como se nombra cada indicador en el aviso y en la practica.
NOMBRE_INDICADOR = {
    "tar_get_atrasadas": "las tareas atrasadas",
    "tar_get_tareas": "las tareas",
    "tar_get_pedidos": "los pedidos de trabajo",
    "man_get_kpi_disponibilidad": "la disponibilidad de los equipos",
    "man_get_kpi_mttr": "el tiempo medio de reparación",
    "man_get_kpi_mttf": "el tiempo medio entre fallas",
    "man_get_kpi_fallas": "las fallas",
}


@dataclass
class Evaluacion:
    medicion_id: int
    empr_id: int
    petr_id: int
    indicador: str
    nombre: str
    mejor: str
    resultado: str
    mediciones: int
    valor_inicial: Decimal | None = None
    fecha_inicial: date | None = None
    valor_final: Decimal | None = None
    fecha_final: date | None = None
    tool: str | None = None


# ==================================================================== reglas
def mejor_de(indicador: str, parametros: dict | None) -> str:
    m = (parametros or {}).get("mejor")
    if m in ("subir", "bajar"):
        return m
    return MEJOR_POR_TOOL.get(indicador, "subir")


def nombre_de(indicador: str, parametros: dict | None) -> str:
    if indicador == "kpi_get_valor" and (parametros or {}).get("kpi"):
        return f"el indicador «{parametros['kpi']}»"
    return NOMBRE_INDICADOR.get(indicador, f"el indicador {indicador}")


def decidir(inicial: Decimal, final: Decimal, mejor: str) -> str:
    """Mejoro estrictamente en el sentido pedido: funciono. Igual o peor: no."""
    return FUNCIONO if (final > inicial if mejor == "subir" else final < inicial) else NO_FUNCIONO


def evaluar(m: dict, resultados: list[dict]) -> Evaluacion:
    """m: fila de medicion_pedida. resultados: sus medicion_resultado ordenados por fecha."""
    con_valor = [r for r in resultados if r.get("valor") is not None]
    mejor = mejor_de(m["indicador"], m.get("parametros"))
    ev = Evaluacion(medicion_id=m["medicion_id"], empr_id=m["empr_id"], petr_id=m["petr_id"],
                    indicador=m["indicador"], nombre=nombre_de(m["indicador"], m.get("parametros")),
                    mejor=mejor, resultado=SIN_DATOS, mediciones=len(con_valor))
    if len(con_valor) < 2:
        return ev
    a, b = con_valor[0], con_valor[-1]
    ev.valor_inicial, ev.fecha_inicial = Decimal(a["valor"]), a["fecha"]
    ev.valor_final, ev.fecha_final = Decimal(b["valor"]), b["fecha"]
    ev.tool = b.get("tool") or m["indicador"]
    ev.resultado = decidir(ev.valor_inicial, ev.valor_final, mejor)
    return ev


def _numero(d: Decimal) -> str:
    return format(d.normalize(), "f").replace(".", ",")


def _fecha(d: date | None) -> str:
    return d.strftime("%d/%m/%Y") if d else ""


def aviso_de(ev: Evaluacion, *, emisor: str) -> avisos.Aviso:
    """El aviso al administrador. Todo numero sale de medicion_resultado (R4)."""
    if ev.resultado == SIN_DATOS:
        titulo = f"No pude saber si funcionó el plan del pedido {ev.petr_id}"
        cuerpo = (f"Terminó la medición de {ev.nombre}, pero tengo {ev.mediciones} valor(es) y "
                  "necesito al menos dos para comparar. Si querés, pedime medirlo de nuevo.")
    else:
        tramo = (f"{ev.nombre} pasó de {_numero(ev.valor_inicial)} el {_fecha(ev.fecha_inicial)} "
                 f"a {_numero(ev.valor_final)} el {_fecha(ev.fecha_final)} (según {ev.tool})")
        if ev.resultado == FUNCIONO:
            titulo = f"El plan del pedido {ev.petr_id} funcionó"
            cuerpo = (f"{tramo[0].upper()}{tramo[1:]}. Lo propuse como práctica para que la revise "
                      "un experto, sin datos de tu empresa.")
        else:
            titulo = f"El plan del pedido {ev.petr_id} no movió el indicador"
            cuerpo = (f"{tramo[0].upper()}{tramo[1:]}. Conviene revisar la causa: entrá a la pestaña "
                      "Kuntur y buscamos otra.")
    return avisos.Aviso(
        tipo=TIPO_AVISO, titulo=titulo, cuerpo=cuerpo,
        severidad="info" if ev.resultado == FUNCIONO else "aviso",
        entidad_tipo="pedido_trabajo", entidad_id=str(ev.petr_id), emisor=emisor,
        dedupe_key=f"{TIPO_AVISO}:{ev.medicion_id}",
    )


_CIFRA = re.compile(r"\d+(?:[.,]\d+)*\s*%?")


def sin_cifras(texto: str) -> str:
    """Saca numeros (y porcentajes) de un texto: una practica compartida no lleva
    cifras de una empresa (ADR-A4)."""
    return re.sub(r"\s{2,}", " ", _CIFRA.sub("", texto or "")).strip(" -·:,;")


def nombres_del_pedido(data) -> tuple[list[str], list[str]]:
    """Hitos y tareas de lo que devuelve tar_get_pedido, sin cifras."""
    from .mediciones import tareas_del_pedido

    hitos = []
    lista = data.get("hitos") if isinstance(data, dict) else None
    for h in lista if isinstance(lista, list) else []:
        if isinstance(h, dict):
            n = sin_cifras(str(h.get("descripcion") or h.get("nombre") or ""))
            if n and n not in hitos:
                hitos.append(n)
    tareas = []
    for t in tareas_del_pedido(data):
        n = sin_cifras(str(t.get("nombre") or ""))
        if n and n not in tareas:
            tareas.append(n)
    return hitos[:6], tareas[:20]


def candidato_de(ev: Evaluacion, *, hitos: list[str], tareas: list[str], vertical: str | None) -> tuple[str, dict]:
    """Contenido y evidencia de la practica candidata. Sin cifras, sin empresa,
    sin pedido: el curador ve que se hizo y para que indicador."""
    partes = [f"Plan de acción que mejoró {sin_cifras(ev.nombre)} en una empresa"
              + (f" de {vertical.replace('_', ' & ')}" if vertical and vertical != "general" else "") + "."]
    if hitos:
        partes.append("Etapas: " + "; ".join(hitos) + ".")
    if tareas:
        partes.append("Tareas: " + "; ".join(tareas) + ".")
    if not hitos and not tareas:
        partes.append("No se pudo leer el detalle del pedido: hay que completarlo al curar.")
    evidencia = {"origen": ORIGEN_CANDIDATO, "indicador": ev.indicador, "mejor": ev.mejor,
                 "resultado": ev.resultado, "vertical": vertical or "general"}
    return " ".join(partes), evidencia


# ============================================================ base de datos
async def por_evaluar(con) -> list[dict]:
    """Mediciones de un plan ya vencidas y sin evaluar (RLS fijado en la empresa)."""
    async with con.cursor() as cur:
        await cur.execute(
            """SELECT m.medicion_id, m.empr_id, m.petr_id, m.indicador, m.parametros
                 FROM agente.medicion_pedida m
                WHERE m.petr_id IS NOT NULL AND m.estado = 'vencida'
                  AND NOT EXISTS (SELECT 1 FROM agente.evaluacion_plan e WHERE e.medicion_id = m.medicion_id)
                ORDER BY m.medicion_id""")
        return await cur.fetchall()


async def resultados_de(con, medicion_id: int) -> list[dict]:
    async with con.cursor() as cur:
        await cur.execute("""SELECT fecha, valor, tool FROM agente.medicion_resultado
                              WHERE medicion_id = %s ORDER BY fecha""", (medicion_id,))
        return await cur.fetchall()


async def vertical_de(con, empr_id: int) -> str | None:
    async with con.cursor() as cur:
        await cur.execute("SELECT vertical FROM agente.perfil_empresa WHERE empr_id = %s", (empr_id,))
        f = await cur.fetchone()
    return f["vertical"] if f else None


async def guardar(con, ev: Evaluacion) -> bool:
    """Una sola vez por medicion: si ya estaba, no hace nada y devuelve False."""
    async with con.cursor() as cur:
        await cur.execute(
            """INSERT INTO agente.evaluacion_plan
                   (medicion_id, empr_id, petr_id, mejor, valor_inicial, fecha_inicial,
                    valor_final, fecha_final, mediciones, tool, resultado)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
               ON CONFLICT (medicion_id) DO NOTHING""",
            (ev.medicion_id, ev.empr_id, ev.petr_id, ev.mejor, ev.valor_inicial, ev.fecha_inicial,
             ev.valor_final, ev.fecha_final, ev.mediciones, ev.tool, ev.resultado))
        return cur.rowcount == 1


async def proponer_practica(con, ev: Evaluacion, contenido: str, evidencia: dict) -> int:
    async with con.cursor() as cur:
        await cur.execute(
            """INSERT INTO agente.candidato (contenido, origen, evidencia, situacion)
               VALUES (%s, %s, %s::jsonb, %s) RETURNING candidato_id""",
            (contenido, ORIGEN_CANDIDATO, json.dumps(evidencia, ensure_ascii=False), "plan_accion_que_funciono"))
        cid = (await cur.fetchone())["candidato_id"]
        await cur.execute("UPDATE agente.evaluacion_plan SET candidato_id = %s, fec_mod = now() WHERE medicion_id = %s",
                          (cid, ev.medicion_id))
    return cid


async def sin_avisar(con) -> list[dict]:
    async with con.cursor() as cur:
        await cur.execute(
            """SELECT e.*, m.indicador, m.parametros
                 FROM agente.evaluacion_plan e JOIN agente.medicion_pedida m USING (medicion_id)
                WHERE e.aviso_id IS NULL ORDER BY e.medicion_id""")
        return await cur.fetchall()


def desde_fila(f: dict) -> Evaluacion:
    return Evaluacion(medicion_id=f["medicion_id"], empr_id=f["empr_id"], petr_id=f["petr_id"],
                      indicador=f["indicador"], nombre=nombre_de(f["indicador"], f.get("parametros")),
                      mejor=f["mejor"], resultado=f["resultado"], mediciones=f["mediciones"],
                      valor_inicial=f["valor_inicial"], fecha_inicial=f["fecha_inicial"],
                      valor_final=f["valor_final"], fecha_final=f["fecha_final"], tool=f["tool"])


async def evaluar_empresa(con, cfg, empr_id: int, autorizacion: str, *, leer_pedido=None,
                          emisor: str = "Kuntur") -> dict:
    """Evalua los planes que terminaron, propone practicas y publica los avisos
    pendientes. `leer_pedido(petr_id)` es una corrutina que devuelve lo de
    tar_get_pedido (o None). RLS ya fijado en la empresa."""
    resumen = {"evaluadas": 0, "funciono": 0, "no_funciono": 0, "sin_datos": 0,
               "practicas": 0, "avisos": 0, "sin_publicar": 0}
    vertical = None
    for m in await por_evaluar(con):
        ev = evaluar(m, await resultados_de(con, m["medicion_id"]))
        if not await guardar(con, ev):
            continue
        resumen["evaluadas"] += 1
        resumen[ev.resultado] += 1
        if ev.resultado == FUNCIONO:
            data = None
            if leer_pedido is not None:
                try:
                    data = await leer_pedido(ev.petr_id)
                except Exception as e:  # noqa: BLE001 - la practica sale igual, sin detalle
                    log.warning("Evaluacion %s: no se leyo el pedido %s: %s", empr_id, ev.petr_id, e)
            hitos, tareas = nombres_del_pedido(data)
            if vertical is None:
                vertical = await vertical_de(con, empr_id) or "general"
            contenido, evidencia = candidato_de(ev, hitos=hitos, tareas=tareas, vertical=vertical)
            await proponer_practica(con, ev, contenido, evidencia)
            resumen["practicas"] += 1
    for f in await sin_avisar(con):
        if not avisos.habilitado(cfg):
            resumen["sin_publicar"] += 1
            continue
        try:
            aviso_id = await avisos.publicar(cfg, autorizacion, aviso_de(desde_fila(f), emisor=emisor))
        except avisos.AvisoError as e:
            log.warning("Evaluacion %s: no se publico el aviso de %s: %s", empr_id, f["medicion_id"], e)
            resumen["sin_publicar"] += 1
            continue
        async with con.cursor() as cur:
            await cur.execute("UPDATE agente.evaluacion_plan SET aviso_id = %s, fec_mod = now() WHERE medicion_id = %s",
                              (aviso_id, f["medicion_id"]))
        resumen["avisos"] += 1
    return resumen
