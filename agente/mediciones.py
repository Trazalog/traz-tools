"""Mediciones: el contrato Kuntur <-> Quirqui (AGENTE-AS-04 y AGENTE-CO-06).

Kuntur PIDE una medicion (tool kuntur_pedir_medicion): que indicador, con que
parametros, cada cuanto y hasta cuando. Quirqui la EJECUTA en el trabajo
programado: llama a la tool de lectura del indicador con el token de maquina de
la empresa y guarda el numero. Si la medicion es de un plan (petr_id), ademas
refresca el avance de cada tarea del pedido.

    python -m agente.mediciones                 todas las empresas con credencial
    python -m agente.mediciones --empresa 191   una sola

Reglas:

  * Solo tools de lectura que esten en la lista blanca de Quirqui (el que mide)
    y que este modulo sepa leer (EXTRACTORES). La tool queda guardada al lado
    del valor (R4).
  * Nunca viaja contenido de conversaciones (R3): el contrato es de numeros y
    estados cortos, y la base lo vigila (019, test de estructura).
  * Una medicion corre si esta activa, dentro de su vigencia y su ultimo
    resultado es mas viejo que su frecuencia (diaria 1 dia, semanal 7,
    mensual 30). Vencida la vigencia, pasa a 'vencida'.
  * El administrador ve y cancela todo lo pedido (R11): /kuntur/mediciones.
  * Cada empresa es una corrida registrada (R8), con disparador
    'medicion_pedida' y canal 'scheduler'.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import re
import time
import uuid
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation

from . import agentes, credenciales, evaluacion, rag
from .config import Config, cargar
from .mcp_client import ClienteMCP, MCPError

log = logging.getLogger("agente.mediciones")

NOMBRE = "kuntur_pedir_medicion"
QUIEN_MIDE = "quirqui"    # el Asistente ejecuta las mediciones (contrato R3)
FRECUENCIAS = {"diaria": 1, "semanal": 7, "mensual": 30}
ALCANCES = ("actividad", "equipo", "persona")
MAX_DIAS = 180
MAX_ACTIVAS = 20          # por empresa: un tope para que Kuntur no pida de mas
TOOL_PEDIDO = "tar_get_pedido"
DIAS_KPI_MAN = 30         # ventana de los KPI de Mantenimiento (piden fechas)


class MedicionInvalida(ValueError):
    pass


# ============================================================ leer un numero
def _numero(v) -> Decimal | None:
    if v is None or isinstance(v, bool):
        return None
    try:
        d = Decimal(str(v).strip().replace(",", "."))
    except (InvalidOperation, ValueError):
        return None
    return d if d.is_finite() else None


def _total(data) -> Decimal | None:
    return _numero(data.get("total")) if isinstance(data, dict) else None


def _kpi_valor(data) -> Decimal | None:
    """kpi_get_valor: {"kpi": {"nombre": ..., "valor": "37"}} (o una lista de un solo kpi)."""
    if not isinstance(data, dict):
        return None
    k = data.get("kpi", data)
    if isinstance(k, list):
        k = k[0] if len(k) == 1 and isinstance(k[0], dict) else {}
    return _numero(k.get("valor")) if isinstance(k, dict) else None


def _kpi_man(data) -> Decimal | None:
    """man_get_kpi_*: {"respuesta": {"disponibilidad": "99.74"}}: el primer numero."""
    if not isinstance(data, dict):
        return None
    r = data.get("respuesta", data)
    if not isinstance(r, dict):
        return None
    for v in r.values():
        n = _numero(v)
        if n is not None:
            return n
    return None


# indicador -> como se saca el numero de lo que devuelve la tool
EXTRACTORES = {
    "kpi_get_valor": _kpi_valor,
    "tar_get_atrasadas": _total,
    "tar_get_tareas": _total,
    "tar_get_pedidos": _total,
    "man_get_kpi_disponibilidad": _kpi_man,
    "man_get_kpi_mttr": _kpi_man,
    "man_get_kpi_mttf": _kpi_man,
    "man_get_kpi_fallas": _kpi_man,
}
# Parametros que el modelo puede pasar a cada tool (el resto se descarta).
PARAMETROS = {
    "kpi_get_valor": {"kpi"},
    "tar_get_atrasadas": set(),
    "tar_get_tareas": {"hito_id", "estado"},
    "tar_get_pedidos": {"buscar", "todos"},
    "man_get_kpi_disponibilidad": {"equipo_id"},
    "man_get_kpi_mttr": {"equipo_id"},
    "man_get_kpi_mttf": {"equipo_id"},
    "man_get_kpi_fallas": {"equipo_id"},
}


def valor_de(indicador: str, data) -> Decimal | None:
    f = EXTRACTORES.get(indicador)
    return f(data) if f else None


def argumentos_de(indicador: str, parametros: dict, hoy: date) -> dict:
    """Lo que se le pasa a la tool. Los KPI de Mantenimiento piden fechas: los
    ultimos DIAS_KPI_MAN dias hasta hoy."""
    args = {k: v for k, v in (parametros or {}).items() if k in PARAMETROS.get(indicador, set())}
    if indicador.startswith("man_get_kpi_"):
        args["fec_inicio"] = (hoy - timedelta(days=DIAS_KPI_MAN)).isoformat()
        args["fec_fin"] = hoy.isoformat()
    return args


# ======================================================= avance de un plan
_ESTADOS_AVANCE = {"propuesta", "creada", "planificada", "iniciada", "finalizada", "eliminada"}


def _fecha(s) -> date | None:
    m = re.match(r"^(\d{2})-(\d{2})-(\d{4})", str(s or ""))
    if m:
        try:
            return date(int(m.group(3)), int(m.group(2)), int(m.group(1)))
        except ValueError:
            return None
    try:
        return date.fromisoformat(str(s or "")[:10])
    except ValueError:
        return None


def avance_de_tarea(t: dict, hoy: date) -> dict | None:
    """Una tarea de tar_get_pedido -> una fila de agente.avance_plan.

    fec_plan: el fin planificado y, si no tiene, la fecha asignada (el mismo
    criterio que tar_get_atrasadas). fec_real: el fin, solo si esta finalizada.
    resultado (D-66): cancelada si se elimino; atrasada si termino despues de
    lo planificado o si sigue abierta con la fecha pasada; en_plazo si no; sin
    fecha planificada, sin resultado.
    """
    try:
        tarea_id = int(str(t.get("tapl_id")))
    except (TypeError, ValueError):
        return None
    estado = str(t.get("estado") or "").strip().lower()
    if estado not in _ESTADOS_AVANCE:
        estado = "creada"
    plan = _fecha(t.get("fin")) or _fecha(t.get("fecha"))
    real = _fecha(t.get("fin")) if estado == "finalizada" else None
    if estado == "eliminada":
        resultado = "cancelada"
    elif plan is None:
        resultado = None
    elif estado == "finalizada":
        resultado = "atrasada" if real and real > plan else "en_plazo"
    else:
        resultado = "atrasada" if hoy > plan else "en_plazo"
    responsable = str(t.get("responsable") or "").strip()
    return {"tarea_id": tarea_id, "estado": estado, "fec_plan": plan, "fec_real": real,
            "responsable": None if responsable in ("", "sin asignar") else responsable[:100],
            "resultado": resultado}


def tareas_del_pedido(data) -> list[dict]:
    salida = []
    for h in (data.get("hitos") or []) if isinstance(data, dict) else []:
        if isinstance(h, dict):
            salida += [t for t in (h.get("tareas") or []) if isinstance(t, dict)]
    return salida


async def _guardar_avance(con, empr_id: int, petr_id: int, filas: list[dict]) -> int:
    n = 0
    async with con.cursor() as cur:
        for f in filas:
            p = {"empr_id": empr_id, "petr_id": petr_id, **f}
            await cur.execute(
                """UPDATE agente.avance_plan
                      SET estado = %(estado)s, fec_plan = %(fec_plan)s, fec_real = %(fec_real)s,
                          responsable = %(responsable)s, resultado = %(resultado)s
                    WHERE empr_id = %(empr_id)s AND petr_id = %(petr_id)s AND tarea_id = %(tarea_id)s""", p)
            if cur.rowcount == 0:
                await cur.execute(
                    """INSERT INTO agente.avance_plan
                           (empr_id, petr_id, tarea_id, estado, fec_plan, fec_real, responsable, resultado)
                       VALUES (%(empr_id)s, %(petr_id)s, %(tarea_id)s, %(estado)s, %(fec_plan)s,
                               %(fec_real)s, %(responsable)s, %(resultado)s)""", p)
            n += 1
    return n


# ============================================================ que corre hoy
async def vencer(con, hoy: date) -> int:
    async with con.cursor() as cur:
        await cur.execute("""UPDATE agente.medicion_pedida SET estado = 'vencida', fec_mod = now()
                              WHERE estado = 'activa' AND hasta < %s""", (hoy,))
        return cur.rowcount


async def pendientes(con, hoy: date) -> list[dict]:
    """Las activas, vigentes hoy, cuyo ultimo resultado es mas viejo que su frecuencia."""
    async with con.cursor() as cur:
        await cur.execute(
            """SELECT m.medicion_id, m.indicador, m.parametros, m.alcance, m.alcance_id,
                      m.frecuencia, m.petr_id,
                      (SELECT max(r.fecha) FROM agente.medicion_resultado r
                        WHERE r.medicion_id = m.medicion_id) AS ultima
                 FROM agente.medicion_pedida m
                WHERE m.estado = 'activa' AND m.desde <= %s AND m.hasta >= %s
                ORDER BY m.medicion_id""", (hoy, hoy))
        filas = await cur.fetchall()
    return [f for f in filas
            if f["ultima"] is None or (hoy - f["ultima"]).days >= FRECUENCIAS.get(f["frecuencia"], 1)]


async def medir_empresa(con, cfg: Config, empr_id: int, autorizacion: str,
                        *, hoy: date | None = None) -> dict:
    """Ejecuta las mediciones que tocan hoy en una empresa. Devuelve un resumen."""
    # Import tardio: el orquestador importa este modulo (la tool de Kuntur).
    from .orquestador import Consulta, Orquestador, Resultado

    hoy = hoy or date.today()
    t0 = time.monotonic()
    agente = await agentes.obtener(con, QUIEN_MIDE)
    consulta = Consulta(empr_id=empr_id, pregunta="(mediciones pedidas por Kuntur)",
                        autorizacion=autorizacion, canal="scheduler",
                        disparador="medicion_pedida", agente=agente,
                        usuario_nick="agente:mediciones")
    res = Resultado(interaccion_id=str(uuid.uuid4()), respuesta="")
    resumen = {"empr_id": empr_id, "vencidas": 0, "medidas": 0, "sin_valor": 0, "avances": 0, "errores": 0}
    await rag.fijar_empresa(con, empr_id)
    try:
        resumen["vencidas"] = await vencer(con, hoy)
        lista = await pendientes(con, hoy)
        permitidas = await agentes.tools_permitidas(con, agente.clave)
        if lista:
            async with ClienteMCP(cfg, autorizacion) as mcp:
                for m in lista:
                    ind = m["indicador"]
                    if ind not in EXTRACTORES or ind not in permitidas:
                        resumen["errores"] += 1
                        res.incidentes.append({"tipo": "medicion_no_ejecutable", "medicion_id": m["medicion_id"],
                                               "detalle": f"{ind} no es una tool de lectura que Quirqui pueda medir"})
                        continue
                    args = argumentos_de(ind, m["parametros"] or {}, hoy)
                    try:
                        data = await mcp.llamar(ind, args)
                    except MCPError as e:
                        resumen["errores"] += 1
                        log.warning("Mediciones %s: %s fallo: %s", empr_id, ind, e)
                        continue
                    res.contenidos_tools.append(json.dumps(data, ensure_ascii=False)[:8000])
                    valor = valor_de(ind, data)
                    if valor is None:
                        resumen["sin_valor"] += 1
                    async with con.cursor() as cur:
                        await cur.execute(
                            """INSERT INTO agente.medicion_resultado (medicion_id, empr_id, fecha, valor, detalle, tool)
                               VALUES (%s, %s, %s, %s, %s, %s)
                               ON CONFLICT (medicion_id, fecha) DO UPDATE
                                   SET valor = EXCLUDED.valor, detalle = EXCLUDED.detalle, tool = EXCLUDED.tool""",
                            (m["medicion_id"], empr_id, hoy, valor,
                             json.dumps({"argumentos": args}, ensure_ascii=False), ind))
                    resumen["medidas"] += 1
                    if m["petr_id"] and TOOL_PEDIDO in permitidas:
                        try:
                            ped = await mcp.llamar(TOOL_PEDIDO, {"petr_id": m["petr_id"]})
                        except MCPError as e:
                            log.warning("Mediciones %s: %s fallo: %s", empr_id, TOOL_PEDIDO, e)
                            continue
                        filas = [a for a in (avance_de_tarea(t, hoy) for t in tareas_del_pedido(ped)) if a]
                        resumen["avances"] += await _guardar_avance(con, empr_id, int(m["petr_id"]), filas)
                res.tools_llamadas = [ll.a_dict() for ll in mcp.llamadas]
        # Planes cuya medicion termino: evaluar, avisar y proponer practica (AGENTE-CO-05).
        if await evaluacion.por_evaluar(con) or await evaluacion.sin_avisar(con):
            kuntur = await agentes.obtener(con, "kuntur")
            async with ClienteMCP(cfg, autorizacion) as mcp_ev:
                async def leer_pedido(petr_id: int):
                    if TOOL_PEDIDO not in permitidas:
                        return None
                    return await mcp_ev.llamar(TOOL_PEDIDO, {"petr_id": petr_id})
                ev = await evaluacion.evaluar_empresa(con, cfg, empr_id, autorizacion,
                                                     leer_pedido=leer_pedido, emisor=kuntur.nombre)
                res.tools_llamadas += [ll.a_dict() for ll in mcp_ev.llamadas]
            resumen["planes_evaluados"] = ev["evaluadas"]
            res.controles.append({"control": "evaluacion_planes", **ev})
        res.respuesta = (f"{resumen['medidas']} medición(es), {resumen['avances']} avance(s) de plan, "
                         f"{resumen['vencidas']} vencida(s), {resumen['errores']} con error"
                         + (f", {resumen['planes_evaluados']} plan(es) evaluado(s)" if resumen.get("planes_evaluados") else ""))
        res.controles.append({"control": "mediciones", **resumen})
        await con.commit()
        await rag.fijar_empresa(con, empr_id)
    except Exception as e:  # noqa: BLE001 - se registra y se sigue con la proxima empresa
        res.error = f"{type(e).__name__}: {e}"
        res.respuesta = "(mediciones con error)"
        await con.rollback()
        await rag.fijar_empresa(con, empr_id)
    res.latencia_ms = int((time.monotonic() - t0) * 1000)
    await Orquestador(cfg)._registrar(con, consulta, res)
    resumen["error"] = res.error
    return resumen


async def correr(cfg: Config, *, empresa: int | None = None) -> list[dict]:
    tokens = credenciales.TokenMaquina(cfg)
    con = await rag.abrir(cfg)
    salida = []
    try:
        lista = [empresa] if empresa else await credenciales.empresas(con)
        for empr_id in lista:
            try:
                autorizacion = await tokens.autorizacion(con, empr_id)
                await con.commit()
            except credenciales.CredencialError as e:
                await con.rollback()
                salida.append({"empr_id": empr_id, "error": str(e)})
                continue
            salida.append(await medir_empresa(con, cfg, empr_id, autorizacion))
            await con.commit()
    finally:
        await con.close()
    return salida


# ===================================================== lado Kuntur (CO-06)
DEFINICION = {
    "type": "function",
    "function": {
        "name": NOMBRE,
        "description": (
            "Le pide a Quirqui que mida un indicador cada cierto tiempo, para seguir un plan de "
            "acción aceptado o un desvío que querés vigilar. Queda activa enseguida y el "
            "administrador la ve en 'Lo que estoy midiendo', donde la puede cancelar. Solo "
            "indicadores numéricos de lectura: " + ", ".join(sorted(EXTRACTORES)) + "."),
        "parameters": {
            "type": "object",
            "properties": {
                "indicador": {"type": "string", "enum": sorted(EXTRACTORES),
                              "description": "La tool de lectura que da el número."},
                "parametros": {"type": "object", "description": (
                    "Parámetros de esa tool: kpi_get_valor {kpi}; tar_get_tareas {hito_id, estado}; "
                    "tar_get_pedidos {buscar, todos}; KPI de Mantenimiento {equipo_id}. "
                    "Para un plan, sumá mejor: 'subir' o 'bajar' (hacia dónde mejora el número); "
                    "si no lo decís, se usa el sentido habitual del indicador.")},
                "frecuencia": {"type": "string", "enum": list(FRECUENCIAS)},
                "hasta": {"type": "string", "description": f"Fecha final, AAAA-MM-DD, hasta {MAX_DIAS} días."},
                "alcance": {"type": "string", "enum": list(ALCANCES),
                            "description": "actividad (toda la empresa), equipo o persona."},
                "alcance_id": {"type": "string", "description": "El equipo o la persona, si el alcance no es actividad."},
                "petr_id": {"type": "integer", "description": "El pedido de trabajo del plan, si es de un plan."},
            },
            "required": ["indicador", "frecuencia", "hasta"],
        },
    },
}


def validar(argumentos: dict, *, hoy: date, medibles: frozenset[str] | set[str]) -> dict:
    """Valida lo que pidio el modelo y devuelve la fila a insertar."""
    ind = str(argumentos.get("indicador") or "").strip()
    if ind not in EXTRACTORES or ind not in medibles:
        raise MedicionInvalida(f"{ind or 'el indicador'} no es algo que Quirqui pueda medir. "
                               f"Opciones: {', '.join(sorted(set(EXTRACTORES) & set(medibles)))}")
    frecuencia = str(argumentos.get("frecuencia") or "").strip()
    if frecuencia not in FRECUENCIAS:
        raise MedicionInvalida("La frecuencia tiene que ser diaria, semanal o mensual")
    try:
        hasta = date.fromisoformat(str(argumentos.get("hasta") or "")[:10])
    except ValueError as e:
        raise MedicionInvalida("hasta tiene que ser una fecha AAAA-MM-DD") from e
    if hasta < hoy or hasta > hoy + timedelta(days=MAX_DIAS):
        raise MedicionInvalida(f"hasta tiene que estar entre hoy y {MAX_DIAS} días")
    alcance = str(argumentos.get("alcance") or "actividad").strip()
    if alcance not in ALCANCES:
        raise MedicionInvalida("alcance tiene que ser actividad, equipo o persona")
    alcance_id = str(argumentos.get("alcance_id") or "").strip()[:100] or None
    if (alcance == "actividad") != (alcance_id is None):
        raise MedicionInvalida("alcance_id va solo (y es obligatorio) si el alcance es equipo o persona")
    parametros = argumentos.get("parametros") or {}
    if not isinstance(parametros, dict):
        raise MedicionInvalida("parametros tiene que ser un objeto")
    mejor = parametros.get("mejor")
    if mejor not in (None, "", "subir", "bajar"):
        raise MedicionInvalida("mejor tiene que ser subir o bajar")
    parametros = {k: v for k, v in parametros.items()
                  if k in PARAMETROS[ind] and isinstance(v, (str, int, float, bool))}
    if mejor:
        # Hacia donde mejora el indicador: lo usa la evaluacion del plan (AGENTE-CO-05).
        # No se le pasa a la tool (argumentos_de filtra por PARAMETROS).
        parametros["mejor"] = mejor
    petr_id = argumentos.get("petr_id")
    if petr_id not in (None, ""):
        try:
            petr_id = int(petr_id)
        except (TypeError, ValueError) as e:
            raise MedicionInvalida("petr_id tiene que ser un número") from e
        if petr_id <= 0:
            raise MedicionInvalida("petr_id tiene que ser positivo")
    else:
        petr_id = None
    return {"indicador": ind, "parametros": parametros, "alcance": alcance, "alcance_id": alcance_id,
            "frecuencia": frecuencia, "desde": hoy, "hasta": hasta, "petr_id": petr_id}


async def pedir(con, empr_id: int, argumentos: dict, *, hoy: date | None = None) -> dict:
    """Valida y deja la medicion activa (solo escribe la base del agente)."""
    hoy = hoy or date.today()
    medibles = await agentes.tools_permitidas(con, QUIEN_MIDE)
    fila = validar(argumentos, hoy=hoy, medibles=medibles)
    async with con.cursor() as cur:
        await cur.execute("SELECT count(*) AS n FROM agente.medicion_pedida WHERE estado = 'activa'")
        if (await cur.fetchone())["n"] >= MAX_ACTIVAS:
            raise MedicionInvalida(f"Ya hay {MAX_ACTIVAS} mediciones activas: cancelá alguna antes")
        await cur.execute(
            """SELECT medicion_id FROM agente.medicion_pedida
                WHERE estado = 'activa' AND indicador = %s AND parametros = %s::jsonb
                  AND alcance = %s AND alcance_id IS NOT DISTINCT FROM %s
                  AND petr_id IS NOT DISTINCT FROM %s""",
            (fila["indicador"], json.dumps(fila["parametros"]), fila["alcance"], fila["alcance_id"],
             fila["petr_id"]))
        ya = await cur.fetchone()
        if ya:
            return {"medicion_id": ya["medicion_id"], "ya_existia": True, **_serializable(fila)}
        await cur.execute(
            """INSERT INTO agente.medicion_pedida
                   (empr_id, indicador, parametros, alcance, alcance_id, frecuencia, desde, hasta, petr_id)
               VALUES (%s, %s, %s::jsonb, %s, %s, %s, %s, %s, %s) RETURNING medicion_id""",
            (empr_id, fila["indicador"], json.dumps(fila["parametros"]), fila["alcance"], fila["alcance_id"],
             fila["frecuencia"], fila["desde"], fila["hasta"], fila["petr_id"]))
        mid = (await cur.fetchone())["medicion_id"]
    return {"medicion_id": mid, "ya_existia": False, **_serializable(fila)}


def _serializable(fila: dict) -> dict:
    return {k: (v.isoformat() if isinstance(v, date) else v) for k, v in fila.items()}


def _num(v):
    return float(v) if isinstance(v, Decimal) else v


async def listar(con) -> list[dict]:
    """Lo que esta midiendo Kuntur en esta empresa (RLS fijado): activas y las
    ultimas 10 terminadas, con sus ultimos resultados y el avance del plan."""
    async with con.cursor() as cur:
        await cur.execute(
            """SELECT medicion_id, indicador, parametros, alcance, alcance_id, frecuencia,
                      desde, hasta, petr_id, estado, fec_alta
                 FROM agente.medicion_pedida
                ORDER BY (estado = 'activa') DESC, fec_alta DESC LIMIT 30""")
        meds = await cur.fetchall()
        salida = []
        for m in meds:
            await cur.execute(
                """SELECT fecha, valor FROM agente.medicion_resultado
                    WHERE medicion_id = %s ORDER BY fecha DESC LIMIT 5""", (m["medicion_id"],))
            resultados = [{"fecha": r["fecha"].isoformat(), "valor": _num(r["valor"])} for r in await cur.fetchall()]
            avance = None
            if m["petr_id"]:
                await cur.execute(
                    """SELECT count(*) AS tareas,
                              count(*) FILTER (WHERE estado = 'finalizada') AS finalizadas,
                              count(*) FILTER (WHERE resultado = 'atrasada') AS atrasadas
                         FROM agente.avance_plan WHERE petr_id = %s""", (m["petr_id"],))
                avance = await cur.fetchone()
            await cur.execute(
                """SELECT resultado, valor_inicial, fecha_inicial, valor_final, fecha_final, tool
                     FROM agente.evaluacion_plan WHERE medicion_id = %s""", (m["medicion_id"],))
            e = await cur.fetchone()
            evaluado = None if not e else {
                "resultado": e["resultado"], "valor_inicial": _num(e["valor_inicial"]),
                "fecha_inicial": e["fecha_inicial"].isoformat() if e["fecha_inicial"] else None,
                "valor_final": _num(e["valor_final"]),
                "fecha_final": e["fecha_final"].isoformat() if e["fecha_final"] else None, "tool": e["tool"]}
            salida.append({
                "evaluacion": evaluado,
                "medicion_id": m["medicion_id"], "indicador": m["indicador"], "parametros": m["parametros"],
                "alcance": m["alcance"], "alcance_id": m["alcance_id"], "frecuencia": m["frecuencia"],
                "desde": m["desde"].isoformat(), "hasta": m["hasta"].isoformat(), "petr_id": m["petr_id"],
                "estado": m["estado"], "resultados": resultados, "avance_plan": avance,
            })
    return salida


async def cancelar(con, medicion_id: int) -> bool:
    async with con.cursor() as cur:
        await cur.execute(
            """UPDATE agente.medicion_pedida SET estado = 'cancelada', fec_mod = now()
                WHERE medicion_id = %s AND estado = 'activa'""", (medicion_id,))
        return cur.rowcount == 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Mediciones pedidas por Kuntur, ejecutadas por Quirqui.")
    ap.add_argument("--empresa", type=int, default=None, help="Solo esta empresa")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    salida = asyncio.run(correr(cargar(), empresa=args.empresa))
    print(json.dumps(salida, ensure_ascii=False, default=str))
    return 1 if any(s.get("error") for s in salida) else 0


if __name__ == "__main__":
    raise SystemExit(main())
