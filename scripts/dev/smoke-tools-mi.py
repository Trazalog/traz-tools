#!/usr/bin/env python3
"""
Prueba de humo de las 17 tools MCP contra el MI directo (localhost:8290),
salteando el APIM. Devuelve datos REALES, no solo el mapeo.

Por que contra el MI: EmprIdFromHeader.xml no valida la firma del
X-JWT-Assertion, solo decodifica el payload y lee empr_id / empr_id_mysql.
Eso permite probar la logica de cada tool sin depender de Dnato ni del
gateway, y aisla si un fallo es del backend o del APIM.

ESCRITURAS: alm_crear_pedido_materiales y man_create_ot crean registros
reales e instancian procesos en Bonita. Por defecto NO se ejecutan.
Con --escrituras se ejecutan, encadenando los datos que necesitan
(deposito y articulo reales tomados de las tools de lectura).

USO (por SSH en la VM):
  python3 smoke-tools-mi.py
  python3 smoke-tools-mi.py --empresa 15
  python3 smoke-tools-mi.py --escrituras          # OJO: crea datos
  python3 smoke-tools-mi.py --url https://mcp.cloudtrazalog.com/trazalog/mcp/1.0/mcp --jwt "$JWT"
"""
import argparse, base64, json, subprocess, sys

def b64(o):
    return base64.urlsafe_b64encode(json.dumps(o, separators=(',', ':')).encode()).decode().rstrip('=')

def jwt_sintetico(empr_id, empr_id_mysql):
    h = b64({"alg": "RS256", "typ": "JWT"})
    p = b64({"empr_id": str(empr_id), "empr_id_mysql": str(empr_id_mysql), "sub": "smoke@trazalog"})
    return f"{h}.{p}.smoke"

def get(url, jwt, timeout=120):
    cmd = ["curl", "-sS", "-k", "-m", str(timeout), "-w", "\n%{http_code}",
           "-H", "Accept: application/json", "-H", f"X-JWT-Assertion: {jwt}", url]
    r = subprocess.run(cmd, capture_output=True, text=True)
    body, _, code = r.stdout.rpartition("\n")
    return code.strip(), body

def post(url, jwt, payload, timeout=180):
    cmd = ["curl", "-sS", "-k", "-m", str(timeout), "-w", "\n%{http_code}", "-X", "POST", url,
           "-H", "Content-Type: application/json", "-H", f"X-JWT-Assertion: {jwt}",
           "-d", json.dumps(payload)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    body, _, code = r.stdout.rpartition("\n")
    return code.strip(), body

def resumen(body, n=110):
    try:
        d = json.loads(body)
    except Exception:
        return body[:n].replace("\n", " ")
    if isinstance(d, dict) and len(d) == 1:
        k = next(iter(d))
        v = d[k]
        if isinstance(v, dict) and len(v) == 1:
            vv = next(iter(v.values()))
            if isinstance(vv, list):
                return f"{k}: {len(vv)} registro(s)"
            return f"{k}: {json.dumps(v, ensure_ascii=False)[:n]}"
        if isinstance(v, list):
            return f"{k}: {len(v)} registro(s)"
    return json.dumps(d, ensure_ascii=False)[:n]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://localhost:8290/tools/mcp")
    ap.add_argument("--empresa", default="15", help="empr_id_mysql (assetv2)")
    ap.add_argument("--empresa-pg", default=None, help="empr_id de Postgres; por defecto igual")
    ap.add_argument("--ini", default="2024-01-01")
    ap.add_argument("--fin", default="2026-07-31")
    ap.add_argument("--escrituras", action="store_true", help="ejecutar POSTs (crea datos reales)")
    a = ap.parse_args()
    pg = a.empresa_pg or a.empresa
    jwt = jwt_sintetico(pg, a.empresa)
    B = a.base.rstrip("/")

    print(f"MI     : {B}")
    print(f"empresa: empr_id={pg} (postgres)  empr_id_mysql={a.empresa} (assetv2)")
    print(f"periodo: {a.ini} .. {a.fin}\n")

    LECTURA = [
        ("man_get_equipos",             f"{B}/mcp/man/equipos"),
        ("man_get_ots",                 f"{B}/mcp/man/ot"),
        ("man_get_lecturas",            f"{B}/mcp/man/lecturas"),
        ("man_get_preventivos",         f"{B}/mcp/man/preventivos"),
        ("man_get_kpi_disponibilidad",  f"{B}/mcp/man/kpi/disponibilidad?fec_inicio={a.ini}&fec_fin={a.fin}"),
        ("man_get_kpi_mttr",            f"{B}/mcp/man/kpi/mttr?fec_inicio={a.ini}&fec_fin={a.fin}"),
        ("man_get_kpi_mttf",            f"{B}/mcp/man/kpi/mttf?fec_inicio={a.ini}&fec_fin={a.fin}"),
        ("man_get_kpi_fallas",          f"{B}/mcp/man/kpi/fallas?fec_inicio={a.ini}&fec_fin={a.fin}"),
        ("alm_get_stock",               f"{B}/mcp/alm/stock"),
        ("alm_get_depositos",           f"{B}/mcp/alm/depositos"),
        ("alm_get_vencimientos",        f"{B}/mcp/alm/vencimientos"),
        ("alm_get_pedidos_materiales",  f"{B}/mcp/alm/pedidos"),
    ]

    ok = fail = 0
    datos = {}
    print("=== LECTURA ===")
    for nombre, url in LECTURA:
        code, body = get(url, jwt)
        bien = code == "200" and "identity_missing" not in body and '"error"' not in body[:200]
        print(f"  {'OK ' if bien else 'FAIL'} {nombre:28} {code:4} {resumen(body)}")
        datos[nombre] = body
        ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)

    # detalle por id, encadenando desde los listados
    print("\n=== DETALLE (encadenado) ===")
    def primer_id(clave, *rutas):
        try:
            d = json.loads(datos.get(clave, "{}"))
            for r in rutas:
                d = d[r] if not isinstance(d, list) else d[0][r]
            return (d[0] if isinstance(d, list) else d)
        except Exception:
            return None

    equi = primer_id("man_get_equipos", "equipos", "equipo", "id_equipo")
    if equi:
        code, body = get(f"{B}/mcp/man/equipo/{equi}", jwt)
        bien = code == "200"
        print(f"  {'OK ' if bien else 'FAIL'} {'man_get_equipo':28} {code:4} id={equi} {resumen(body, 70)}")
        ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)
    else:
        print("  --  man_get_equipo               sin equipos para encadenar")

    ot = primer_id("man_get_ots", "solicitudes", "solicitud", "id_solicitud")
    if ot:
        code, body = get(f"{B}/mcp/man/ot/{ot}", jwt)
        bien = code == "200"
        print(f"  {'OK ' if bien else 'FAIL'} {'man_get_ot':28} {code:4} id={ot} {resumen(body, 70)}")
        ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)
    else:
        print("  --  man_get_ot                   sin OTs para encadenar")

    ped = primer_id("alm_get_pedidos_materiales", "pedidos", "pedido", "pema_id")
    if ped:
        code, body = get(f"{B}/mcp/alm/pedido/{ped}", jwt)
        bien = code == "200"
        print(f"  {'OK ' if bien else 'FAIL'} {'alm_get_pedido_material':28} {code:4} id={ped} {resumen(body, 70)}")
        ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)
    else:
        print("  --  alm_get_pedido_material      sin pedidos para encadenar")

    print("\n=== ESCRITURA ===")
    if not a.escrituras:
        print("  omitidas (crean registros reales e instancian procesos en Bonita).")
        print("  Para ejecutarlas:  --escrituras")
    else:
        depo = primer_id("alm_get_depositos", "depositos", "deposito", "depo_id")
        arti = primer_id("alm_get_stock", "materias", "materia", "id")
        print(f"  usando depo_id={depo}  arti_id={arti}")
        if depo and arti:
            payload = {"justificacion": "Prueba de humo automatica - ignorar",
                       "articulos": [{"arti_id": str(arti), "cantidad": "1", "depo_id": str(depo)}]}
            code, body = post(f"{B}/mcp/alm/pedido", jwt, payload)
            bien = code in ("200", "201")
            print(f"  {'OK ' if bien else 'FAIL'} {'alm_crear_pedido_materiales':28} {code:4} {resumen(body)}")
            ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)
        else:
            print("  FAIL alm_crear_pedido_materiales  faltan deposito o articulo para armar el pedido")
            fail += 1
        if equi:
            payload = {"equipo_id": str(equi), "descripcion": "Prueba de humo automatica - ignorar"}
            code, body = post(f"{B}/mcp/man/ot", jwt, payload)
            bien = code in ("200", "201")
            print(f"  {'OK ' if bien else 'FAIL'} {'man_create_ot':28} {code:4} {resumen(body)}")
            ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)

    print(f"\n  OK: {ok}   FAIL: {fail}")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
