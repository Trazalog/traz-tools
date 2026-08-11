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


# ===========================================================================
def main():
    escrituras = "--escrituras" in sys.argv
    todos = [v for v in globals().values() if callable(v) and hasattr(v, "_esc")]
    todos.sort(key=lambda f: f._esc[0])

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
