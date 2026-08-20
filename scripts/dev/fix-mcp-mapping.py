#!/usr/bin/env python3
"""
Repara el apiOperationMapping de las tools del MCP Server que quedaron en null
por el bug wso2/api-manager#5106.

CONTEXTO
  CAUSA RAIZ (verificada 2026-08-20): la API fuente tenia 17 recursos en su
  working copy pero solo 9 en la revision DESPLEGADA. El Publisher muestra la
  working copy; el gateway sirve la revision desplegada. Un mapping contra un
  recurso que el gateway no tiene se guarda en null sin protestar (bug
  wso2/api-manager#5106), y ese null rompe la pantalla Tools del Publisher y
  hace fallar la tool con 500.

  Por eso el orden importa y este script lo respeta:
     PASO 1  desplegar una revision NUEVA de la API  <-- sin esto nada funciona
     PASO 2  reparar el apiOperationMapping del MCP Server
     PASO 3  desplegar una revision NUEVA del MCP Server

  Solo repara tools cuyo recurso EXISTE en la API fuente. Si un recurso no
  esta, la tool se deja como esta y se avisa: reparar contra un recurso
  inexistente es exactamente lo que produce el bug.

SEGURIDAD
  - Por defecto NO escribe: hay que pasar --apply.
  - Guarda un backup del JSON antes de cualquier PUT.
  - Despues del PUT crea y despliega una revision nueva (obligatorio: el
    gateway sirve la ultima revision desplegada, no lo guardado).

USO (por SSH en la VM):
  python3 fix-mcp-mapping.py                 # dry-run, muestra que haria
  python3 fix-mcp-mapping.py --apply         # repara de verdad
"""
import argparse, json, subprocess, sys, os

# tool -> (verb, target en la API fuente). Explicito a proposito: sin heuristica.
MAPEO = {
    "man_get_lecturas":            ("GET", "/mcp/man/lecturas"),
    "man_get_preventivos":         ("GET", "/mcp/man/preventivos"),
    "man_get_kpi_disponibilidad":  ("GET", "/mcp/man/kpi/disponibilidad"),
    "man_get_kpi_mttr":            ("GET", "/mcp/man/kpi/mttr"),
    "man_get_kpi_mttf":            ("GET", "/mcp/man/kpi/mttf"),
    "man_get_kpi_fallas":          ("GET", "/mcp/man/kpi/fallas"),
    "alm_get_depositos":           ("GET", "/mcp/alm/depositos"),
    "alm_get_vencimientos":        ("GET", "/mcp/alm/vencimientos"),
}


def curl(args, data=None):
    cmd = ["curl", "-sS", "-k"] + args
    if data is not None:
        cmd += ["-d", data]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout


def token(host, user, pwd):
    reg = curl(["-X", "POST", f"https://{host}:9443/client-registration/v0.17/register",
                "-u", f"{user}:{pwd}", "-H", "Content-Type: application/json"],
               json.dumps({"callbackUrl": "http://localhost", "clientName": "mcp_fix",
                           "owner": user, "grantType": "client_credentials password refresh_token",
                           "saasApp": True}))
    c = json.loads(reg)
    tok = curl(["-X", "POST", f"https://{host}:9443/oauth2/token",
                "-u", f"{c['clientId']}:{c['clientSecret']}"],
               f"grant_type=password&username={user}&password={pwd}"
               "&scope=apim:api_view apim:api_manage apim:mcp_server_view apim:mcp_server_manage")
    return json.loads(tok)["access_token"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default=os.environ.get("APIM_HOST", "localhost"))
    ap.add_argument("--user", default=os.environ.get("APIM_USER", "admin"))
    ap.add_argument("--pass", dest="pwd", default=os.environ.get("APIM_PASS", "admin"))
    ap.add_argument("--apply", action="store_true", help="escribe de verdad (sin esto, dry-run)")
    a = ap.parse_args()

    H, TK = a.host, None
    TK = token(H, a.user, a.pwd)
    auth = ["-H", f"Authorization: Bearer {TK}"]
    base = f"https://{H}:9443/api/am/publisher/v4"

    # ---------------------------------------------------------------
    # PASO 1 — la revision desplegada de la API debe tener TODOS los recursos
    # ---------------------------------------------------------------
    def revision_desplegada(kind, oid):
        revs = json.loads(curl([f"{base}/{kind}/{oid}/revisions"] + auth)).get("list", [])
        return next((r for r in revs if r.get("deploymentInfo")), None), revs

    def desplegar(kind, oid, desc):
        _, revs = revision_desplegada(kind, oid)
        if len(revs) >= 5:
            viejas = [r for r in revs if not r.get("deploymentInfo")]
            if not viejas:
                print(f"    !! {kind}: 5 revisiones y todas desplegadas — borrar una a mano")
                return None
            curl(["-X", "DELETE", f"{base}/{kind}/{oid}/revisions/{viejas[0]['id']}"] + auth)
            print(f"    (borrada la revision {viejas[0].get('displayName')} para hacer lugar)")
        rev = json.loads(curl(["-X", "POST", f"{base}/{kind}/{oid}/revisions",
                               "-H", "Content-Type: application/json"] + auth,
                              json.dumps({"description": desc})))
        rid = rev.get("id")
        if not rid:
            print("    no se pudo crear la revision:", json.dumps(rev)[:250]); return None
        envs = json.loads(curl([f"https://{H}:9443/api/am/admin/v4/environments"] + auth)).get("list", [])
        gw = envs[0] if envs else {"name": "Default", "vhosts": [{"host": H}]}
        body = [{"name": gw["name"], "vhost": (gw.get("vhosts") or [{"host": H}])[0]["host"],
                 "displayOnDevportal": True}]
        curl(["-X", "POST", f"{base}/{kind}/{oid}/deploy-revision?revisionId={rid}",
              "-H", "Content-Type: application/json"] + auth, json.dumps(body))
        return rid

    lst = json.loads(curl([f"{base}/mcp-servers"] + auth)).get("list", [])
    if not lst:
        print("no hay MCP Servers"); return 1
    sid = lst[0]["id"]
    srv = json.loads(curl([f"{base}/mcp-servers/{sid}"] + auth))
    print(f"MCP Server: {srv['name']} v{srv['version']}  ctx={srv['context']}")

    # datos de la API fuente, tomados de una tool que SI tiene mapping
    ref = next((o["apiOperationMapping"] for o in srv["operations"] if o.get("apiOperationMapping")), None)
    if not ref:
        print("ninguna tool tiene mapping: no se puede deducir la API fuente"); return 1
    api = json.loads(curl([f"{base}/apis/{ref['apiId']}"] + auth))
    recursos = {(o["verb"], o["target"]) for o in api.get("operations", [])}
    print(f"API fuente: {api['name']} v{api['version']}  ctx={api['context']}  ({len(recursos)} recursos)\n")

    dep, _ = revision_desplegada("apis", ref["apiId"])
    n_desp = 0
    if dep:
        rev_api = json.loads(curl([f"{base}/apis/{dep['id']}"] + auth))
        n_desp = len(rev_api.get("operations", []))
    print(f"  revision desplegada de la API: {n_desp} recursos"
          f"{'  <-- INCOMPLETA' if n_desp < len(recursos) else '  (completa)'}")

    if n_desp < len(recursos):
        if not a.apply:
            print(f"\n  PASO 1 pendiente: desplegar revision nueva de la API"
                  f" ({n_desp} -> {len(recursos)} recursos). Se hace con --apply.\n")
        else:
            print("\n  PASO 1 — desplegando revision nueva de la API...")
            if desplegar("apis", ref["apiId"], "recursos completos para el MCP Server"):
                dep2, _ = revision_desplegada("apis", ref["apiId"])
                n2 = len(json.loads(curl([f"{base}/apis/{dep2['id']}"] + auth)).get("operations", [])) if dep2 else 0
                print(f"    ok — la revision desplegada ahora tiene {n2} recursos")
                if n2 < len(recursos):
                    print("    *** sigue incompleta: parar y revisar a mano ***"); return 2
            else:
                return 2
    print()

    cambios = 0
    for op in srv["operations"]:
        if op.get("apiOperationMapping"):
            continue
        t = op.get("target")
        if t not in MAPEO:
            print(f"  ?? {t:30} sin regla de mapeo — se deja como esta"); continue
        verb, target = MAPEO[t]
        if (verb, target) not in recursos:
            print(f"  !! {t:30} {verb} {target} NO existe en la API fuente — se deja como esta")
            continue
        op["apiOperationMapping"] = {
            "apiId":      ref["apiId"],
            "apiName":    ref["apiName"],
            "apiVersion": ref["apiVersion"],
            "apiContext": ref["apiContext"],
            "backendOperation": {"target": target, "verb": verb},
        }
        print(f"  -> {t:30} {verb} {target}")
        cambios += 1

    print(f"\n{cambios} tool(s) a reparar")
    if not cambios:
        return 0
    if not a.apply:
        print("\nDRY-RUN. Nada se escribio. Volver a correr con --apply para aplicarlo.")
        return 0

    with open("/tmp/mcp-server-backup.json", "w") as f:
        json.dump(json.loads(curl([f"{base}/mcp-servers/{sid}"] + auth)), f, indent=2)
    print("backup en /tmp/mcp-server-backup.json")

    r = curl(["-X", "PUT", f"{base}/mcp-servers/{sid}", "-H", "Content-Type: application/json"] + auth,
             json.dumps(srv))
    try:
        upd = json.loads(r)
    except Exception:
        print("respuesta inesperada del PUT:", r[:400]); return 2
    if upd.get("code"):
        print("el PUT fallo:", r[:400]); return 2
    faltan = [o["target"] for o in upd.get("operations", []) if not o.get("apiOperationMapping")]
    print(f"PUT ok — tools sin mapping despues del PUT: {len(faltan)} {faltan}")

    print("\nPASO 3 — desplegando revision nueva del MCP Server...")
    if not desplegar("mcp-servers", sid, "fix apiOperationMapping"):
        return 2
    print("    ok")

    print("\nAhora verificar:  python3 scripts/dev/mcp-smoke-tools.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
