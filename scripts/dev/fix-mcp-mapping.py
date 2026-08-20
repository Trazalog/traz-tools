#!/usr/bin/env python3
"""
Repara el apiOperationMapping de las tools del MCP Server que quedaron en null
por el bug wso2/api-manager#5106.

CONTEXTO
  La UI del Publisher no abre la pantalla Tools (revienta con
  "Cannot read properties of undefined (reading 'toLowerCase')"), asi que el
  mapping no se puede reparar desde ahi. Este script lo hace por el Publisher
  REST API: lee el MCP Server, completa el apiOperationMapping de cada tool
  rota apuntando al recurso REAL de la API fuente, y hace el PUT.

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

    print("\ncreando y desplegando revision nueva...")
    rev = json.loads(curl(["-X", "POST", f"{base}/mcp-servers/{sid}/revisions",
                           "-H", "Content-Type: application/json"] + auth,
                          json.dumps({"description": "fix apiOperationMapping"})))
    rid = rev.get("id")
    if not rid:
        print("no se pudo crear la revision:", json.dumps(rev)[:300]); return 2
    envs = json.loads(curl([f"https://{H}:9443/api/am/admin/v4/environments"] + auth)).get("list", [])
    gw = envs[0] if envs else {"name": "Default", "vhosts": [{"host": H}]}
    body = [{"name": gw["name"], "vhost": (gw.get("vhosts") or [{"host": H}])[0]["host"],
             "displayOnDevportal": True}]
    dep = curl(["-X", "POST", f"{base}/mcp-servers/{sid}/deploy-revision?revisionId={rid}",
                "-H", "Content-Type: application/json"] + auth, json.dumps(body))
    print("revision desplegada:", dep[:200])
    print("\nAhora verificar:  python3 scripts/dev/mcp-smoke-tools.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
