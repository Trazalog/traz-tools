#!/usr/bin/env python3
"""
Escenarios encadenados de uso real de las tools MCP — suite de regresión.

Cada escenario reproduce una secuencia que un usuario haría con Claude, pasando
el resultado de una tool a la siguiente igual que lo haría el agente. No prueba
tools sueltas: prueba que se puedan *encadenar*, que es donde aparecen los
huecos (un dato que una tool exige y ninguna otra devuelve).

USO:
    python3 scripts/dev/mcp_escenarios.py              # solo lectura (seguro)
    python3 scripts/dev/mcp_escenarios.py --escrituras # incluye crear OT/pedido
    python3 scripts/dev/mcp_escenarios.py --lista      # lista los escenarios
    python3 scripts/dev/mcp_escenarios.py --solo E7    # uno solo (E7 no necesita el MI)

REQUISITOS: WSO2 MI local corriendo en :8290 con el CAR de ToolsAPIProject, y
acceso a las bases de desarrollo (VPN). MI_URL para apuntar a otro host.

Exit code != 0 si algún escenario falla -> apto para CI.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp_tools_client import MCP, ToolError, lista  # noqa: E402

# Empresa de prueba. En desarrollo, Empresa_Test tiene datos en ambas bases:
#   PostgreSQL empr_id=1 -> 311 artículos, 25 depósitos, 371 pedidos
#   MySQL  id_empresa=1  -> 4 equipos, 52 solicitudes
EMPR_ID = int(os.environ.get("EMPR_ID", "1"))
EMPR_ID_MYSQL = int(os.environ.get("EMPR_ID_MYSQL", "1"))
# Segunda empresa, para las pruebas de aislamiento
OTRA_EMPR = int(os.environ.get("OTRA_EMPR", "87"))
OTRA_EMPR_MYSQL = int(os.environ.get("OTRA_EMPR_MYSQL", "8"))

VERDE, ROJO, AMAR, GRIS, FIN = "\033[92m", "\033[91m", "\033[93m", "\033[90m", "\033[0m"

_resultados = []


class Fallo(Exception):
    pass


def afirmar(cond, msg):
    if not cond:
        raise Fallo(msg)


def paso(txt):
    print(f"    {GRIS}·{FIN} {txt}")


def escenario(id_, titulo, requiere_escritura=False):
    def deco(fn):
        fn._esc = (id_, titulo, requiere_escritura)
        return fn
    return deco


# ===========================================================================
# E1 — Reposición de stock por punto de pedido
#      El caso que falló en producción: sin alm_get_depositos, el agente no
#      puede completar el pedido porque no sabe qué depo_id usar.
# ===========================================================================
@escenario("E1", "Reponer un artículo bajo punto de pedido", requiere_escritura=True)
def e1(m):
    stock = lista(m.alm_get_stock(), "materias", "materia")
    afirmar(stock, "alm_get_stock no devolvió artículos")
    paso(f"alm_get_stock -> {len(stock)} artículos")

    def num(v):
        try:
            return float(v)
        except (TypeError, ValueError):
            return 0.0

    bajos = [a for a in stock
             if num(a.get("punto_pedido")) > 0
             and num(a.get("stock")) < num(a.get("punto_pedido"))]
    afirmar(bajos, "ningún artículo bajo punto de pedido (no se puede seguir el escenario)")
    paso(f"filtrado por el agente -> {len(bajos)} bajo punto de pedido")
    art = bajos[0]
    paso(f"elegido: {art['titulo'][:38]!r} stock={art['stock']} punto={art['punto_pedido']}")

    # --- el eslabón que faltaba -------------------------------------------
    deps = lista(m.alm_get_depositos(), "depositos", "deposito")
    afirmar(deps, "alm_get_depositos no devolvió depósitos: el pedido no se puede armar")
    paso(f"alm_get_depositos -> {len(deps)} depósitos (ej. {deps[0]['descripcion'][:28]!r})")

    for d in deps:
        afirmar(d.get("depo_id"), "un depósito vino sin depo_id")

    if not m._escrituras:
        paso(f"{AMAR}[--escrituras desactivado: no se crea el pedido]{FIN}")
        return

    faltante = num(art["punto_pedido"]) - num(art["stock"])
    r = m.alm_crear_pedido_materiales(
        articulos=[{"arti_id": art["id"], "cantidad": str(int(faltante) or 1),
                    "depo_id": deps[0]["depo_id"]}],
        justificacion=f"[TEST E1 descartable] reposicion automatica de {art['titulo'][:40]}")
    afirmar(r.get("resultado") == "ok", f"el alta no devolvió ok: {r}")
    paso(f"alm_crear_pedido_materiales -> pema_id={r.get('pema_id')} estado={r.get('estado')}")

    det = m.alm_get_pedido_material(r["pema_id"])
    ped = lista(det, "pedidos", "pedido")
    afirmar(ped, "el pedido recién creado no se puede recuperar")
    paso(f"alm_get_pedido_material({r['pema_id']}) -> confirmado")


# ===========================================================================
# E2 — Equipo en falla: diagnóstico y orden de trabajo
# ===========================================================================
@escenario("E2", "Revisar equipos en reparación y abrir una OT", requiere_escritura=True)
def e2(m):
    eqs = lista(m.man_get_equipos(), "equipos", "equipo")
    afirmar(eqs, "man_get_equipos no devolvió equipos")
    paso(f"man_get_equipos -> {len(eqs)} equipos")

    en_rep = [e for e in eqs if e.get("estado") == "RE"]
    paso(f"filtrado por el agente -> {len(en_rep)} en reparación (estado RE)")

    objetivo = (en_rep or eqs)[0]
    det = m.man_get_equipo(objetivo["id_equipo"])
    eq = lista(det, "equipo")
    afirmar(eq, f"man_get_equipo({objetivo['id_equipo']}) no devolvió detalle")
    paso(f"man_get_equipo({objetivo['id_equipo']}) -> {objetivo['codigo']} "
         f"({objetivo.get('marca')}) criticidad={eq[0].get('criticidad')}")

    if not m._escrituras:
        paso(f"{AMAR}[--escrituras desactivado: no se crea la OT]{FIN}")
        return

    r = m.man_create_ot(objetivo["id_equipo"],
                        "[TEST E2 descartable] vibracion excesiva detectada en control")
    afirmar(r.get("resultado") == "ok", f"el alta de OT no devolvió ok: {r}")
    paso(f"man_create_ot -> ot_id={r.get('ot_id')} case_id={r.get('case_id')}")

    d = lista(m.man_get_ot(r["ot_id"]), "solicitudes", "solicitud")
    afirmar(d, "la OT recién creada no se puede recuperar")
    paso(f"man_get_ot({r['ot_id']}) -> estado={d[0].get('estado')}")


# ===========================================================================
# E3 — Auditoría de órdenes de trabajo abiertas
# ===========================================================================
@escenario("E3", "Auditar OTs abiertas y ubicar sus equipos")
def e3(m):
    ots = lista(m.man_get_ots(), "solicitudes", "solicitud")
    paso(f"man_get_ots -> {len(ots)} solicitudes")
    afirmar(ots, "man_get_ots no devolvió solicitudes")

    abiertas = [o for o in ots if o.get("estado") == "S"]
    paso(f"filtrado por el agente -> {len(abiertas)} abiertas (estado S)")

    # el agente cruza cada OT con su equipo para dar contexto
    o = (abiertas or ots)[0]
    det = lista(m.man_get_ot(o["id_solicitud"]), "solicitudes", "solicitud")
    afirmar(det, f"man_get_ot({o['id_solicitud']}) no devolvió detalle")
    paso(f"man_get_ot({o['id_solicitud']}) -> equipo={det[0].get('equipo')} "
         f"ubicacion={str(det[0].get('ubicacion'))[:28]!r}")

    # filtro por estado en la misma tool
    filtradas = lista(m.man_get_ots(estado="S"), "solicitudes", "solicitud")
    afirmar(all(x.get("estado") == "S" for x in filtradas),
            "man_get_ots?estado=S devolvió solicitudes de otro estado")
    paso(f"man_get_ots(estado=S) -> {len(filtradas)} y todas en estado S")


# ===========================================================================
# E4 — Seguimiento de pedidos de materiales
# ===========================================================================
@escenario("E4", "Seguir el estado de los pedidos de materiales")
def e4(m):
    peds = lista(m.alm_get_pedidos_materiales(), "pedidos", "pedido")
    afirmar(peds, "alm_get_pedidos_materiales no devolvió pedidos")
    paso(f"alm_get_pedidos_materiales -> {len(peds)} pedidos")

    estados = {}
    for p in peds:
        estados[p.get("estado")] = estados.get(p.get("estado"), 0) + 1
    top = sorted(estados.items(), key=lambda x: -x[1])[:3]
    paso("agrupado por el agente -> " + ", ".join(f"{e}:{n}" for e, n in top))

    p = peds[0]
    det = lista(m.alm_get_pedido_material(p["pema_id"]), "pedidos", "pedido")
    afirmar(det, f"alm_get_pedido_material({p['pema_id']}) no devolvió el pedido")
    paso(f"alm_get_pedido_material({p['pema_id']}) -> estado={det[0].get('estado')}")

    # GAP conocido: el detalle no incluye los artículos pedidos
    tiene_lineas = any(k in det[0] for k in ("articulos", "detalle", "detalles", "lineas"))
    if not tiene_lineas:
        paso(f"{AMAR}GAP: el detalle no trae los artículos del pedido "
             f"(campos: {', '.join(list(det[0].keys())[:6])}...){FIN}")


# ===========================================================================
# E5 — Aislamiento multi-tenant (ADR-012)
# ===========================================================================
@escenario("E5", "Aislamiento: no ver datos de otra empresa")
def e5(m):
    otra = MCP(OTRA_EMPR, OTRA_EMPR_MYSQL)
    otra._escrituras = False

    mis_art = {a["id"] for a in lista(m.alm_get_stock(), "materias", "materia")}
    sus_art = {a["id"] for a in lista(otra.alm_get_stock(), "materias", "materia")}
    afirmar(not (mis_art & sus_art),
            f"FUGA: {len(mis_art & sus_art)} artículos compartidos entre empresas")
    paso(f"stock: {len(mis_art)} vs {len(sus_art)} artículos, 0 en común")

    mis_dep = {d["depo_id"] for d in lista(m.alm_get_depositos(), "depositos", "deposito")}
    sus_dep = {d["depo_id"] for d in lista(otra.alm_get_depositos(), "depositos", "deposito")}
    afirmar(not (mis_dep & sus_dep), "FUGA: depósitos compartidos entre empresas")
    paso(f"depósitos: {len(mis_dep)} vs {len(sus_dep)}, 0 en común")

    # pedir por id un recurso ajeno tiene que devolver vacío, no error ni datos
    peds = lista(m.alm_get_pedidos_materiales(), "pedidos", "pedido")
    if peds:
        ajeno = lista(otra.alm_get_pedido_material(peds[0]["pema_id"]), "pedidos", "pedido")
        afirmar(not ajeno,
                f"FUGA: la empresa {OTRA_EMPR} accedió al pedido {peds[0]['pema_id']} ajeno")
        paso(f"pedido {peds[0]['pema_id']} pedido por la otra empresa -> vacío")

    eqs = lista(m.man_get_equipos(), "equipos", "equipo")
    if eqs:
        ajeno = lista(otra.man_get_equipo(eqs[0]["id_equipo"]), "equipo")
        afirmar(not ajeno,
                f"FUGA: la empresa {OTRA_EMPR_MYSQL} accedió al equipo {eqs[0]['id_equipo']} ajeno")
        paso(f"equipo {eqs[0]['id_equipo']} pedido por la otra empresa -> vacío")


# ===========================================================================
# E6 — Coherencia de datos entre tools
# ===========================================================================
@escenario("E6", "Coherencia: el detalle coincide con el listado")
def e6(m):
    eqs = lista(m.man_get_equipos(), "equipos", "equipo")
    afirmar(eqs, "sin equipos para comparar")
    e = eqs[0]
    det = lista(m.man_get_equipo(e["id_equipo"]), "equipo")
    afirmar(det, "sin detalle de equipo")
    for campo in ("codigo", "descripcion", "estado"):
        afirmar(str(e.get(campo)) == str(det[0].get(campo)),
                f"equipo {e['id_equipo']}: '{campo}' difiere entre listado "
                f"({e.get(campo)!r}) y detalle ({det[0].get(campo)!r})")
    paso(f"equipo {e['id_equipo']}: codigo/descripcion/estado coinciden en ambas tools")

    peds = lista(m.alm_get_pedidos_materiales(), "pedidos", "pedido")
    if peds:
        p = peds[0]
        d = lista(m.alm_get_pedido_material(p["pema_id"]), "pedidos", "pedido")
        afirmar(d and str(d[0].get("estado")) == str(p.get("estado")),
                f"pedido {p['pema_id']}: estado difiere entre listado y detalle")
        paso(f"pedido {p['pema_id']}: estado coincide en ambas tools")

    # los acentos tienen que sobrevivir el viaje desde la base
    con_mojibake = [e for e in eqs if "Ã" in str(e.get("descripcion", ""))]
    if con_mojibake:
        paso(f"{AMAR}GAP de encoding: {len(con_mojibake)} equipos con mojibake, "
             f"ej. {con_mojibake[0]['descripcion'][:38]!r}{FIN}")


# ===========================================================================
# E8 — Gestión del plan preventivo (M1, M2, M3 de casos-de-uso-mineria)
#      El caso que el jefe de mantenimiento hace todos los días.
# ===========================================================================
@escenario("E8", "Preventivos vencidos y cobertura del plan")
def e8(m):
    prevs = lista(m.man_get_preventivos(), "preventivos", "preventivo")
    afirmar(prevs, "man_get_preventivos no devolvió planes "
                   "(¿hay preventivos con id_empresa coincidente con el del equipo?)")
    paso(f"man_get_preventivos -> {len(prevs)} planes")

    # M2: los vencidos. 'VE' es el estado que calcula v2 al superar el intervalo.
    vencidos = [p for p in prevs if p.get("estadoprev") == "VE"]
    paso(f"filtrado por el agente -> {len(vencidos)} vencidos (estadoprev=VE)")

    # M3: priorización por criticidad — la trae el mismo registro
    for p in prevs:
        afirmar("criticidad" in p, f"el plan {p.get('prevId')} no trae la criticidad del equipo")
    criticos = [p for p in prevs if p.get("criticidad") in ("Alta", "Muy Alta")]
    paso(f"de esos, {len(criticos)} son en equipos de criticidad Alta/Muy Alta")

    # los planes por uso tienen que traer con qué compararse
    por_uso = [p for p in prevs if p.get("periodicidad") in ("Horas", "Kilómetros", "Ciclos")]
    for p in por_uso:
        afirmar(p.get("intervalo"), f"el plan {p['prevId']} es por {p['periodicidad']} sin intervalo")
        afirmar("lectura_actual" in p,
                f"el plan {p['prevId']} es por uso pero no trae la lectura actual del equipo")
    if por_uso:
        paso(f"{len(por_uso)} planes por uso, todos con intervalo y lectura actual")

    # la tarea en lenguaje natural es lo que permite inferir el insumo (caso C1)
    con_tarea = [p for p in prevs if p.get("tarea")]
    paso(f"{len(con_tarea)}/{len(prevs)} con descripción de tarea "
         f"(ej. {(con_tarea[0]['tarea'][:46] + '…') if con_tarea else '-'})")

    # M1: cobertura — se resuelve cruzando con man_get_equipos, sin tool extra
    eqs = lista(m.man_get_equipos(), "equipos", "equipo")
    afirmar(eqs, "man_get_equipos no devolvió equipos")
    con_plan = {p["id_equipo"] for p in prevs}
    sin_plan = [e for e in eqs if e["id_equipo"] not in con_plan]
    paso(f"cruce con man_get_equipos -> {len(sin_plan)}/{len(eqs)} equipos SIN plan")
    sin_plan_criticos = [e for e in sin_plan if e.get("criticidad") in ("Alta", "Muy Alta")]
    if sin_plan_criticos:
        paso(f"  {AMAR}de esos, {len(sin_plan_criticos)} son CRÍTICOS: "
             f"{', '.join(e['codigo'] for e in sin_plan_criticos[:4])}{FIN}")


# ===========================================================================
# E9 — Aislamiento de los preventivos
#      Además del cruce entre empresas, verifica que no se filtren los planes
#      cuyo id_empresa no coincide con el del equipo (datos basura conocidos).
# ===========================================================================
@escenario("E9", "Aislamiento del plan preventivo")
def e9(m):
    otra = MCP(OTRA_EMPR, OTRA_EMPR_MYSQL)
    otra._escrituras = False
    mios = lista(m.man_get_preventivos(), "preventivos", "preventivo")
    suyos = lista(otra.man_get_preventivos(), "preventivos", "preventivo")
    ids_m = {p["prevId"] for p in mios}
    ids_o = {p["prevId"] for p in suyos}
    afirmar(not (ids_m & ids_o),
            f"FUGA: {len(ids_m & ids_o)} preventivos compartidos entre empresas")
    paso(f"{len(ids_m)} vs {len(suyos)} planes, 0 en común")

    # cada plan debe referirse a un equipo de la propia empresa
    mis_eq = {e["id_equipo"] for e in lista(m.man_get_equipos(), "equipos", "equipo")}
    ajenos = [p for p in mios if p["id_equipo"] not in mis_eq]
    # el detalle se arma solo si hay fallo: un f-string se evalúa siempre, y
    # ajenos[0] revienta con la lista vacía (o sea, justo cuando todo está bien)
    afirmar(not ajenos,
            "FUGA: {} planes sobre equipos que no son de la empresa (ej. plan {} sobre el equipo {})".format(
                len(ajenos), ajenos[0]["prevId"], ajenos[0]["id_equipo"]) if ajenos else "")
    paso(f"los {len(mios)} planes son sobre equipos propios")


# ===========================================================================
# E10 — Stock focalizado: por depósito, por tipo y por texto (I2, I3)
#       "¿tengo filtros de aire en el depósito de la faena?" — el agente aporta
#       qué insumos son clave en minería y la tool tiene que dejarlo buscarlos.
# ===========================================================================
@escenario("E10", "Stock filtrado por depósito, tipo y búsqueda")
def e10(m):
    todo = lista(m.alm_get_stock(), "materias", "materia")
    afirmar(todo, "alm_get_stock sin filtros no devolvió nada")
    paso(f"sin filtros -> {len(todo)} artículos (catálogo completo)")

    deps = lista(m.alm_get_depositos(), "depositos", "deposito")
    afirmar(deps, "sin depósitos para filtrar")
    # el depósito con más artículos, para que el caso sea significativo
    mejor, mejor_n = None, -1
    for d in deps[:12]:
        n = len(lista(m.alm_get_stock(depo_id=d["depo_id"]), "materias", "materia"))
        if n > mejor_n:
            mejor, mejor_n = d, n
    afirmar(mejor_n > 0, "ningún depósito devolvió artículos con el filtro depo_id")
    afirmar(mejor_n <= len(todo), "el filtro por depósito devolvió MÁS que el catálogo completo")
    paso(f"depo_id={mejor['depo_id']} ({mejor['descripcion'][:20]!r}) -> {mejor_n} artículos")

    # por tipo: tiene que devolver solo ese tipo
    tipos = {a.get("tipo_articulo") for a in todo if a.get("tipo_articulo")}
    afirmar(tipos, "ningún artículo trae tipo_articulo")
    t = "Insumo" if "Insumo" in tipos else sorted(tipos)[0]
    por_tipo = lista(m.alm_get_stock(tipo=t), "materias", "materia")
    afirmar(por_tipo, f"el filtro tipo={t} no devolvió nada")
    distintos = [a for a in por_tipo if a.get("tipo_articulo") != t]
    afirmar(not distintos,
            "el filtro por tipo devolvió {} artículos de otro tipo".format(len(distintos))
            if distintos else "")
    paso(f"tipo={t!r} -> {len(por_tipo)} artículos, todos de ese tipo")

    # búsqueda por texto: así encuentra el agente los insumos que releva por su cuenta
    termino = None
    for cand in ("aceite", "filtro", "ajo", "acero"):
        if any(cand in (a.get("descripcion") or "").lower() for a in todo):
            termino = cand
            break
    afirmar(termino, "no hay ningún término de búsqueda con resultados en este catálogo")
    hallados = lista(m.alm_get_stock(buscar=termino), "materias", "materia")
    afirmar(hallados, f"buscar={termino!r} no devolvió nada")
    fuera = [a for a in hallados if termino not in (a.get("descripcion") or "").lower()]
    afirmar(not fuera,
            "la búsqueda devolvió {} artículos que no contienen el término".format(len(fuera))
            if fuera else "")
    paso(f"buscar={termino!r} -> {len(hallados)} artículos, todos coinciden")

    # combinados: el resultado no puede ser mayor que cada filtro por separado
    combo = lista(m.alm_get_stock(tipo=t, buscar=termino), "materias", "materia")
    afirmar(len(combo) <= min(len(por_tipo), len(hallados)),
            "combinar filtros devolvió más que cada uno por separado")
    paso(f"tipo + buscar -> {len(combo)} (≤ {min(len(por_tipo), len(hallados))}, se acumulan)")


# ===========================================================================
# E11 — Vencimiento de lotes (I4)
# ===========================================================================
@escenario("E11", "Lotes vencidos y por vencer")
def e11(m):
    lotes = lista(m.alm_get_vencimientos(), "vencimientos", "lote")
    afirmar(lotes, "alm_get_vencimientos no devolvió lotes")
    paso(f"alm_get_vencimientos -> {len(lotes)} lotes con fecha de vencimiento")

    validos = {"Vencido", "Critico", "Activo"}
    malos = [l for l in lotes if l.get("estado_vencimiento") not in validos]
    afirmar(not malos,
            "estado_vencimiento inesperado: {}".format(
                {l.get("estado_vencimiento") for l in malos}) if malos else "")

    from collections import Counter
    c = Counter(l["estado_vencimiento"] for l in lotes)
    paso("clasificación -> " + " · ".join(f"{k}:{v}" for k, v in c.most_common()))

    # la clasificación tiene que ser coherente con los días restantes
    for l in lotes:
        d = int(float(l["dias_restantes"]))
        esperado = "Vencido" if d <= 0 else ("Critico" if d < 10 else "Activo")
        afirmar(l["estado_vencimiento"] == esperado,
                f"lote {l['lote_id']}: {d} días pero clasificado {l['estado_vencimiento']}")
    paso("la clasificación coincide con los días restantes en los "
         f"{len(lotes)} lotes")

    # aislamiento
    otra = MCP(OTRA_EMPR, OTRA_EMPR_MYSQL)
    otra._escrituras = False
    suyos = {l["lote_id"] for l in lista(otra.alm_get_vencimientos(), "vencimientos", "lote")}
    mios = {l["lote_id"] for l in lotes}
    afirmar(not (mios & suyos), "FUGA: lotes compartidos entre empresas")
    paso(f"aislamiento OK ({len(mios)} vs {len(suyos)} lotes, 0 en común)")


# ===========================================================================
# E12 — Control del horómetro (M4)
#       Un preventivo por Horas/Km/Ciclos no se puede evaluar si nadie toma la
#       lectura: esto audita el plan de medición, no el de mantenimiento.
# ===========================================================================
@escenario("E12", "Equipos sin control de lecturas")
def e12(m):
    eqs_lect = lista(m.man_get_lecturas(), "lecturas", "equipo")
    afirmar(eqs_lect, "man_get_lecturas no devolvió equipos")
    paso(f"man_get_lecturas -> {len(eqs_lect)} equipos")

    # tiene que cubrir TODOS los equipos, incluidos los que nunca tuvieron lectura
    eqs = lista(m.man_get_equipos(), "equipos", "equipo")
    afirmar(len(eqs_lect) == len(eqs),
            f"devuelve {len(eqs_lect)} equipos pero man_get_equipos tiene {len(eqs)}: "
            "los que nunca tuvieron lectura tienen que aparecer igual")
    paso(f"cubre los mismos {len(eqs)} equipos que man_get_equipos")

    def n(v):
        try:
            return int(float(v))
        except (TypeError, ValueError):
            return 0

    sin_ninguna = [e for e in eqs_lect if n(e.get("cantidad_lecturas")) == 0]
    paso(f"{len(sin_ninguna)} equipos sin ninguna lectura registrada")

    desactualizados = [e for e in eqs_lect
                       if e.get("dias_sin_lectura") and n(e["dias_sin_lectura"]) > 90]
    paso(f"{len(desactualizados)} con más de 90 días sin lectura")

    criticos = [e for e in desactualizados if e.get("criticidad") in ("Alta", "Muy Alta")]
    if criticos:
        peor = max(criticos, key=lambda e: n(e["dias_sin_lectura"]))
        paso(f"{AMAR}{len(criticos)} de esos son críticos — el peor: "
             f"{peor['equipo']} ({peor['criticidad']}, {peor['dias_sin_lectura']} días){FIN}")

    # coherencia: si tiene lecturas, tiene fecha; si no tiene, no puede tener días
    for e in eqs_lect:
        if n(e.get("cantidad_lecturas")) > 0:
            afirmar(e.get("fecha_ultima_lectura"),
                    f"{e['equipo']} dice tener lecturas pero no trae la fecha de la última")
        else:
            afirmar(not e.get("dias_sin_lectura"),
                    f"{e['equipo']} no tiene lecturas pero reporta días sin lectura")
    paso("coherencia entre cantidad, fecha y días verificada")

    # cruce con preventivos: los planes por uso necesitan lectura al día
    prevs = lista(m.man_get_preventivos(), "preventivos", "preventivo")
    por_uso = [p for p in prevs if p.get("periodicidad") in ("Horas", "Kilómetros", "Ciclos")]
    if por_uso:
        lect_por_eq = {e["id_equipo"]: e for e in eqs_lect}
        ciegos = [p for p in por_uso
                  if n(lect_por_eq.get(p["id_equipo"], {}).get("cantidad_lecturas")) == 0]
        paso(f"{len(ciegos)}/{len(por_uso)} planes por uso sobre equipos SIN lecturas "
             f"(no se puede saber si vencieron)")


# ===========================================================================
# E13 — Trazabilidad de un lote por el historial de movimientos
#       El caso real: "algo desapareció del depósito, ¿qué pasó?"
# ===========================================================================
@escenario("E13", "Rastrear qué le pasó a un lote y a un depósito")
def e13(m):
    RANGO = dict(desde="2020-01-01", hasta="2026-12-31")
    movs = lista(m.alm_get_movimientos(**RANGO), "movimientos", "movimiento")
    afirmar(movs, "alm_get_movimientos no devolvió nada en un rango de 6 años")
    paso(f"alm_get_movimientos -> {len(movs)} movimientos")

    tipos = sorted({x["tipo_mov"] for x in movs})
    paso(f"tipos presentes: {', '.join(tipos)}")
    # Los valores NO llevan espacio ('MOV.SALIDA', no 'MOV. SALIDA'). El DDL
    # versionado del repo dice lo contrario y esta desactualizado: si alguien
    # "corrige" la OpenAPI segun ese DDL, el filtro deja de traer nada.
    con_espacio = [t for t in tipos if ". " in t or t.startswith("MOV. ")]
    afirmar(not con_espacio,
            f"tipo_mov con espacio: {con_espacio} — hay que actualizar la OpenAPI")

    # el filtro por tipo devuelve solo ese tipo
    aj = lista(m.alm_get_movimientos(tipo="AJUSTE", **RANGO), "movimientos", "movimiento")
    afirmar(aj, "no hay AJUSTE en 6 años, o el filtro por tipo no anda")
    afirmar(all(x["tipo_mov"] == "AJUSTE" for x in aj),
            "el filtro tipo=AJUSTE devolvió movimientos de otro tipo")
    paso(f"tipo=AJUSTE -> {len(aj)} y todos son AJUSTE")

    # un valor mal escrito devuelve vacío, no error: es la trampa que la
    # OpenAPI le advierte al agente
    mal = lista(m.alm_get_movimientos(tipo="MOV. SALIDA", **RANGO), "movimientos", "movimiento")
    afirmar(not mal, "'MOV. SALIDA' con espacio devolvió filas: cambió el dato")
    bien = lista(m.alm_get_movimientos(tipo="MOV.SALIDA", **RANGO), "movimientos", "movimiento")
    afirmar(bien, "'MOV.SALIDA' sin espacio no devolvió nada")
    paso(f"'MOV. SALIDA' -> 0 · 'MOV.SALIDA' -> {len(bien)} (la OpenAPI lo advierte)")

    # el filtro por fecha respeta el rango
    jun = lista(m.alm_get_movimientos(desde="2026-06-01", hasta="2026-06-30"),
                "movimientos", "movimiento")
    fuera = [x["fec_alta"][:10] for x in jun
             if not ("2026-06-01" <= x["fec_alta"][:10] <= "2026-06-30")]
    afirmar(not fuera, f"el filtro de fechas dejó pasar {len(fuera)} fuera del rango")
    paso(f"rango junio-2026 -> {len(jun)} movimientos, todos dentro")

    # trazabilidad: dado un lote, su recorrido completo
    con_lote = [x for x in movs if x.get("lote")]
    afirmar(con_lote, "ningún movimiento trae lote: no se puede trazar")
    paso(f"{len(con_lote)}/{len(movs)} movimientos con lote identificable")


# ===========================================================================
# E14 — Entregas y traslados: lo pedido contra lo que realmente se movió
# ===========================================================================
@escenario("E14", "Cruzar entregas con pedidos y vigilar traslados en tránsito")
def e14(m):
    ent = lista(m.alm_get_entregas(), "historicosEntrega", "historicoEntrega")
    afirmar(ent, "alm_get_entregas no devolvió nada")
    paso(f"alm_get_entregas -> {len(ent)} entregas")

    # cada entrega referencia un pedido, y ese pedido tiene que existir:
    # es el cruce que permite responder "¿me entregaron lo que pedí?"
    pedidos = {p["pema_id"] for p in
               lista(m.alm_get_pedidos_materiales(), "pedidos", "pedido")}
    refs = {e["pema_id"] for e in ent if e.get("pema_id")}
    afirmar(refs, "ninguna entrega referencia un pedido")
    huerfanas = refs - pedidos
    paso(f"{len(refs)} pedidos referenciados; {len(refs & pedidos)} existen en "
         f"alm_get_pedidos_materiales")
    afirmar(len(refs & pedidos) > 0,
            f"ninguno de los {len(refs)} pema_id de las entregas aparece en los "
            "pedidos: el cruce entre las dos tools no funciona")

    # detalle de un pedido efectivamente entregado
    cruzado = sorted(refs & pedidos)[0]
    det = lista(m.alm_get_pedido_material(cruzado), "pedidos", "pedido")
    afirmar(det, f"el pedido {cruzado}, que tiene entregas, no se puede recuperar")
    paso(f"pedido {cruzado}: entregado y recuperable por alm_get_pedido_material")

    # --- traslados internos ---
    mi = lista(m.alm_get_movimientos_internos(), "movimientosInternos", "movimientoInterno")
    afirmar(mi, "alm_get_movimientos_internos no devolvió nada")
    con_det = [x for x in mi if x.get("detallesMovimientosInternos")]
    paso(f"alm_get_movimientos_internos -> {len(mi)} traslados, "
         f"{len(con_det)} con detalle anidado")
    afirmar(con_det, "ningún traslado trae el detalle anidado: se rompió "
                     "@getDetalleMovimientoInterno y haría falta una 2da llamada")

    def lineas(x):
        d = (x.get("detallesMovimientosInternos") or {}).get("detalleMovimientoInterno")
        return d if isinstance(d, list) else [d] if d else []

    curso = lista(m.alm_get_movimientos_internos(estado="EN_CURSO"),
                  "movimientosInternos", "movimientoInterno")
    afirmar(all(x["estado"] == "EN_CURSO" for x in curso),
            "el filtro estado=EN_CURSO devolvió traslados de otro estado")
    paso(f"estado=EN_CURSO -> {len(curso)} en tránsito")

    # cantidad_recibida es null mientras no se recibio: NO es un faltante.
    # Si esto cambiara, el agente empezaria a reportar faltantes inexistentes.
    en_curso_no_nulos = [l for x in curso for l in lineas(x)
                         if l.get("cantidad_recibida") is not None]
    afirmar(not en_curso_no_nulos,
            f"{len(en_curso_no_nulos)} líneas EN_CURSO traen cantidad_recibida "
            "cargada: la OpenAPI dice que ahí siempre es null")
    paso("las líneas EN_CURSO traen cantidad_recibida=null (no son faltantes)")

    recibidos = [x for x in mi if x["estado"] == "RECIBIDO"]
    faltantes = [(x["moin_id"], l) for x in recibidos for l in lineas(x)
                 if l.get("cantidad_recibida") is not None
                 and float(l.get("cantidad_cargada") or 0) != float(l["cantidad_recibida"])]
    paso(f"traslados RECIBIDO con faltante real: {len(faltantes)} líneas "
         f"(cargada != recibida, ambas cargadas)")


# ===========================================================================
# E15 — La sesion sabe con que empresa esta conectada
# ===========================================================================
@escenario("E15", "Identificar la empresa de la sesión")
def e15(m):
    r = m.core_get_empresa_actual()
    emp = lista(r, "empresa")
    afirmar(emp, "core_get_empresa_actual no devolvió ninguna empresa")
    e = emp[0]
    paso(f"core_get_empresa_actual -> empr_id={e.get('empr_id')} "
         f"{str(e.get('descripcion'))[:40]!r}")

    # tiene que ser LA del token, no otra
    afirmar(str(e.get("empr_id")) == str(EMPR_ID),
            f"devolvió la empresa {e.get('empr_id')} pero el token es de la {EMPR_ID}")
    afirmar(e.get("descripcion"), "la empresa vino sin descripcion: el agente no puede nombrarla")

    # y con otro token tiene que dar otra empresa: es la prueba de que sale
    # del JWT y no de un valor fijo en la fachada
    otra = MCP(OTRA_EMPR, OTRA_EMPR_MYSQL)
    otra._escrituras = False
    eo = lista(otra.core_get_empresa_actual(), "empresa")
    afirmar(eo, f"con el token de la empresa {OTRA_EMPR} no devolvió nada")
    afirmar(str(eo[0].get("empr_id")) == str(OTRA_EMPR),
            f"con el token de la {OTRA_EMPR} devolvió la {eo[0].get('empr_id')}: "
            "la empresa no sale del token")
    paso(f"con otro token -> empr_id={eo[0].get('empr_id')} "
         f"{str(eo[0].get('descripcion'))[:32]!r} (sale del JWT, no es fijo)")

    # el empr_id_mysql explica si las tools de mantenimiento van a traer datos
    if not e.get("empr_id_mysql"):
        paso(f"{AMAR}[la empresa no tiene empr_id_mysql: las tools man_* "
             f"pueden venir vacías]{FIN}")


# ===========================================================================
# E7 — El contrato publicado y lo implementado no se desincronizan
#      La OpenAPI es lo que consume el Virtual MCP Server del APIM: si declara
#      una operación que el MI no implementa, la tool aparece en Claude y falla
#      con 404 al usarla. Y al revés, lo implementado sin declarar es invisible.
# ===========================================================================
@escenario("E7", "Contrato OpenAPI ↔ implementación del MI")
def e7(_m):
    import re
    # scripts/dev/este.py -> hay que subir TRES niveles para llegar a la raíz
    raiz = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    spec_path = os.path.join(raiz, "doc/api/trazalog-operaciones.yaml")
    xml_path = os.path.join(
        raiz, "_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/"
              "artifacts/apis/toolsMCPAPI.xml")
    if not (os.path.exists(spec_path) and os.path.exists(xml_path)):
        paso(f"{AMAR}[se omite: no se encontró el repo]{FIN}")
        return
    try:
        import yaml
    except ImportError:
        paso(f"{AMAR}[se omite: falta pyyaml]{FIN}")
        return

    norm = lambda s: re.sub(r"\{[^}]+\}", "{}", s)
    spec = yaml.safe_load(open(spec_path, encoding="utf-8"))
    en_spec = {norm(p) for p in spec["paths"]}
    xml = open(xml_path, encoding="utf-8").read()
    en_mi = {norm(p.split("?")[0]) for p in re.findall(r'uri-template="([^"]+)"', xml)
             if p.startswith("/mcp/")}

    solo_spec, solo_mi = sorted(en_spec - en_mi), sorted(en_mi - en_spec)
    afirmar(not solo_spec,
            f"declaradas en la OpenAPI pero NO implementadas (darían 404): {solo_spec}")
    afirmar(not solo_mi,
            f"implementadas pero NO declaradas (invisibles para el agente): {solo_mi}")
    paso(f"{len(en_spec)} rutas declaradas y todas implementadas")

    ops = [o.get("operationId") for ms in spec["paths"].values() for o in ms.values()]
    afirmar(len(ops) == len(set(ops)), f"operationId duplicados: {ops}")
    paso(f"{len(ops)} operationId únicos: {', '.join(sorted(ops)[:4])}…")

    # --- la spec tiene que ser 3.0 valida, o el APIM la rechaza al subirla ---
    # Son los dos errores que devolvio el Publisher la primera vez. Se chequean
    # sin dependencias: el validador de OpenAPI no esta instalado en todos lados
    # y esto igual cubre el caso concreto que rompio.
    crudo = open(spec_path, encoding="utf-8").read()
    afirmar(spec.get("openapi", "").startswith("3.0"),
            f"la spec dice openapi {spec.get('openapi')}: los chequeos de abajo asumen 3.0")

    listas = [ln.strip() for ln in crudo.split("\n") if re.search(r"type:\s*\[", ln)]
    afirmar(not listas,
            "`type` como lista es sintaxis 3.1 y el APIM la rechaza; en 3.0 se "
            f"escribe `type: string` + `nullable: true`. Lineas: {listas}")

    # Una propiedad puede estar definida en varios schemas (lectura_actual esta
    # en dos). Se exige que TODOS la declaren nullable: agrupar por nombre y
    # darse por satisfecho con uno deja pasar el error en el otro.
    con_null = {m for m in re.findall(r"^\s+([a-z_]+): null\s*$", crudo, re.M)}
    sin_nullable = sorted(
        f"{nom}.{prop}"
        for nom, sc in (spec.get("components", {}).get("schemas") or {}).items()
        for prop, v in (sc.get("properties") or {}).items()
        if prop in con_null and isinstance(v, dict) and not v.get("nullable"))
    afirmar(not sin_nullable,
            "estas propiedades aparecen con `null` en algun ejemplo pero su "
            "schema no las declara `nullable: true`, y el APIM rechaza la spec "
            f"por eso: {sin_nullable}")
    paso(f"spec {spec['openapi']} sin `type` en lista; {len(con_null)} campos con "
         f"ejemplo null, todos declarados nullable")


# ===========================================================================
def main():
    escrituras = "--escrituras" in sys.argv
    todos = [v for v in globals().values() if callable(v) and hasattr(v, "_esc")]
    todos.sort(key=lambda f: int(f._esc[0][1:]))   # numérico: E2 antes que E10

    # --solo E7,E13 : corre solo esos. E7 no necesita el MI ni la base, asi que
    # sirve para validar la OpenAPI antes de subirla al Publisher.
    if "--solo" in sys.argv:
        pedidos = {x.strip().upper()
                   for x in sys.argv[sys.argv.index("--solo") + 1].split(",")}
        desconocidos = pedidos - {f._esc[0] for f in todos}
        if desconocidos:
            print(f"no existen: {', '.join(sorted(desconocidos))}")
            return 2
        todos = [f for f in todos if f._esc[0] in pedidos]

    if "--lista" in sys.argv:
        for f in todos:
            i, t, w = f._esc
            print(f"  {i}  {t}{'   [escribe datos]' if w else ''}")
        return 0

    print("=" * 76)
    print(f"ESCENARIOS MCP ENCADENADOS — empresa {EMPR_ID} (pg) / {EMPR_ID_MYSQL} (mysql)")
    print(f"escrituras: {'SI' if escrituras else 'no (solo lectura)'}   MI: "
          f"{os.environ.get('MI_URL','http://localhost:8290')}")
    print("=" * 76)

    m = MCP(EMPR_ID, EMPR_ID_MYSQL)
    m._escrituras = escrituras
    fallos = 0

    for f in todos:
        id_, titulo, req_w = f._esc
        print(f"\n{id_} — {titulo}")
        try:
            f(m)
            print(f"  {VERDE}PASA{FIN}")
            _resultados.append((id_, "PASA", ""))
        except Fallo as e:
            print(f"  {ROJO}FALLA{FIN}  {e}")
            _resultados.append((id_, "FALLA", str(e)))
            fallos += 1
        except ToolError as e:
            print(f"  {ROJO}ERROR DE TOOL{FIN}  {e}")
            _resultados.append((id_, "ERROR", str(e)))
            fallos += 1

    print("\n" + "=" * 76)
    for i, estado, msg in _resultados:
        color = VERDE if estado == "PASA" else ROJO
        print(f"  {i}  {color}{estado:6}{FIN} {msg[:60]}")
    print(f"\n  {len(_resultados)-fallos}/{len(_resultados)} escenarios OK")
    print("=" * 76)
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
