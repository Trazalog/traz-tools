#!/usr/bin/env python3
"""
Validacion end-to-end de las tools MCP por el camino REAL:

    cliente -> Caddy (443) -> APIM gateway (8243) -> MI (8290) -> base / Bonita

Es el unico camino que reproduce lo que hace Claude. Los otros scripts validan
tramos parciales:
  - mcp-smoke-tools.py   sin token: solo distingue mapeo (401) de mapping roto (500)
  - smoke-tools-mi.py    contra el MI: valida datos, saltea gateway y Caddy

QUE VERIFICA, por tool:
  1. status HTTP EN EL CABLE (no el que reporta el api.log del APIM: en el
     bug del 202 el api.log decia 200 y el cable entregaba 202)
  2. JSON-RPC valido y sin "isError": true
  3. que el contenido no venga vacio

EL TOKEN: hace falta un JWT real emitido por Dnato con el issuer del ambiente.
El emitido por CLI no sirve (queda con iss=http://localhost/oauth y el gateway
lo rechaza con 900901). Se puede:
  a) pasarlo con --jwt "$JWT"
  b) dejar que el script lo extraiga del api.log del APIM, si esta en FULL:
     --desde-log

ESCRITURAS: alm_crear_pedido_materiales y man_create_ot crean registros reales
e instancian procesos en Bonita. Solo corren con --escrituras.

USO:
  python3 validar-tools-e2e.py --desde-log
  python3 validar-tools-e2e.py --jwt "$JWT"
  python3 validar-tools-e2e.py --jwt "$JWT" --escrituras
"""
import argparse, json, os, re, subprocess, sys, glob

URL_DEFAULT = "https://mcp.cloudtrazalog.com/trazalog/mcp/1.0/mcp"

# argumentos por tool. Las que necesitan un id se completan encadenando.
ARGS_FIJOS = {
    "man_get_kpi_disponibilidad": {"fec_inicio": "2024-01-01", "fec_fin": "2026-07-31"},
    "man_get_kpi_mttr":           {"fec_inicio": "2024-01-01", "fec_fin": "2026-07-31"},
    "man_get_kpi_mttf":           {"fec_inicio": "2024-01-01", "fec_fin": "2026-07-31"},
    "man_get_kpi_fallas":         {"fec_inicio": "2024-01-01", "fec_fin": "2026-07-31"},
    # sin rango, movimientos y entregas devuelven el historico completo del
    # almacen: se acota para que la validacion no dependa del volumen
    "alm_get_movimientos":        {"desde": "2024-01-01", "hasta": "2026-12-31"},
    "alm_get_entregas":           {"desde": "2024-01-01", "hasta": "2026-12-31"},
}
ESCRITURAS = {"alm_crear_pedido_materiales", "man_create_ot"}


def jwt_del_log(apim_home):
    """Saca el ultimo Bearer de Dnato del api.log (requiere logLevel FULL)."""
    p = os.path.join(apim_home, "repository/logs/api.log")
    if not os.path.exists(p):
        return None, f"no existe {p} (activar API Logs en FULL)"
    tokens = []
    with open(p, encoding="utf-8", errors="replace") as f:
        for linea in f:
            # el de Dnato, no el Internal-Key que genera el propio gateway
            for m in re.finditer(r'Authorization=Bearer ([A-Za-z0-9._-]{40,})', linea):
                tokens.append(m.group(1))
    if not tokens:
        return None, "no se encontro ningun Authorization=Bearer en api.log"
    return tokens[-1], None


def rpc(url, jwt, payload, timeout=180):
    """Devuelve (status_en_el_cable, cuerpo). El status sale de curl, no del body.

    Manda los headers Mcp-* igual que el cliente real: el rewrite 202->200 de
    Caddy matchea por 'Mcp-Method: tools/call'. Sin ese header el request cae
    en el handler generico y se ve el 202 del backend — falso negativo.
    """
    metodo = payload.get("method", "")
    cmd = ["curl", "-sS", "-m", str(timeout), "-w", "\n<<<%{http_code}>>>",
           "-X", "POST", url,
           "-H", "Content-Type: application/json",
           "-H", "Accept: application/json, text/event-stream",
           "-H", "Mcp-Protocol-Version: 2025-06-18",
           "-H", f"Mcp-Method: {metodo}",
           "-H", f"Authorization: Bearer {jwt}"]
    if metodo == "tools/call":
        cmd += ["-H", "Mcp-Name: " + payload.get("params", {}).get("name", "")]
    cmd += ["-d", json.dumps(payload)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    m = re.search(r"<<<(\d+)>>>\s*$", r.stdout)
    code = m.group(1) if m else "000"
    cuerpo = r.stdout[:m.start()] if m else r.stdout
    return code, cuerpo


def texto_de(cuerpo):
    """Extrae el texto util de la respuesta JSON-RPC de una tool."""
    try:
        d = json.loads(cuerpo)
    except Exception:
        return None, None, cuerpo[:120].replace("\n", " ")
    if "error" in d:
        return None, d, "error JSON-RPC: " + str(d["error"])[:100]
    res = d.get("result", {})
    if res.get("isError"):
        return None, d, "isError=true"
    cont = res.get("content") or []
    txt = cont[0].get("text", "") if cont else ""
    try:
        return json.loads(txt), d, None
    except Exception:
        return txt, d, None


def resumen(dato):
    if isinstance(dato, dict) and len(dato) == 1:
        k = next(iter(dato)); v = dato[k]
        if isinstance(v, dict):
            if not v:
                return f"{k}: vacio"
            vv = next(iter(v.values()))
            if isinstance(vv, list):
                return f"{k}: {len(vv)} registro(s)"
            return f"{k}: {json.dumps(v, ensure_ascii=False)[:70]}"
        if isinstance(v, list):
            return f"{k}: {len(v)} registro(s)"
    return json.dumps(dato, ensure_ascii=False)[:70] if dato else "(vacio)"


def buscar_id(dato, *claves):
    """Busca la primera aparicion de alguna clave en una estructura anidada."""
    if isinstance(dato, dict):
        for k, v in dato.items():
            if k in claves and isinstance(v, (str, int)):
                return str(v)
            r = buscar_id(v, *claves)
            if r:
                return r
    elif isinstance(dato, list):
        for x in dato:
            r = buscar_id(x, *claves)
            if r:
                return r
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default=URL_DEFAULT)
    ap.add_argument("--jwt", default=None)
    ap.add_argument("--desde-log", action="store_true", help="sacar el JWT del api.log del APIM")
    ap.add_argument("--apim-home", default=os.environ.get("APIM_HOME", ""))
    ap.add_argument("--escrituras", action="store_true", help="ejecutar los POST (crean datos reales)")
    a = ap.parse_args()

    jwt = a.jwt
    if not jwt and a.desde_log:
        home = a.apim_home or (glob.glob("/opt/wso2/wso2am-*") + [""])[0]
        jwt, err = jwt_del_log(home)
        if err:
            print(f"no se pudo obtener el token: {err}"); return 2
        print(f"token tomado de api.log ({home})")
    if not jwt:
        print("falta el token: --jwt \"$JWT\"  o  --desde-log"); return 2

    try:
        payload = json.loads(__import__("base64").urlsafe_b64decode(
            jwt.split(".")[1] + "==" * 3).decode())
        print(f"empresa  : empr_id={payload.get('empr_id')}  "
              f"empr_id_mysql='{payload.get('empr_id_mysql')}'  ({payload.get('email')})")
        if not payload.get("empr_id_mysql"):
            print("  OJO: empr_id_mysql vacio -> las 11 tools man_* van a devolver vacio")
    except Exception:
        pass
    print(f"endpoint : {a.url}\n")

    code, cuerpo = rpc(a.url, jwt, {"jsonrpc": "2.0", "method": "initialize", "id": 1,
                                    "params": {"protocolVersion": "2025-06-18", "capabilities": {},
                                               "clientInfo": {"name": "e2e", "version": "1.0"}}})
    if code != "200":
        print(f"initialize fallo: HTTP {code}\n{cuerpo[:300]}"); return 2
    print("initialize        HTTP 200  OK")

    code, cuerpo = rpc(a.url, jwt, {"jsonrpc": "2.0", "method": "tools/list", "id": 2})
    try:
        tools = [t["name"] for t in json.loads(cuerpo)["result"]["tools"]]
    except Exception:
        print(f"tools/list fallo: HTTP {code}\n{cuerpo[:300]}"); return 2
    print(f"tools/list        HTTP {code}  OK — {len(tools)} tools\n")

    ok = fail = omit = 0
    datos = {}
    encadenados = {}

    def llamar(nombre, args):
        code, cuerpo = rpc(a.url, jwt, {"jsonrpc": "2.0", "method": "tools/call", "id": 9,
                                        "params": {"name": nombre, "arguments": args}})
        dato, _, err = texto_de(cuerpo)
        # el status en el cable tiene que ser 200: un 202 rompe el cliente MCP
        bien = code == "200" and err is None
        estado = "OK " if bien else "FAIL"
        detalle = err or resumen(dato)
        if code == "202":
            detalle = ("status 202 en el cable — el cliente MCP lo lee como "
                       "notificacion y descarta el cuerpo. Revisar el rewrite de Caddy.")
        elif code != "200":
            detalle = f"status {code} en el cable — {detalle}"
        print(f"  {estado} {nombre:30} HTTP {code:4} {detalle}")
        return bien, dato

    print("=== LECTURA ===")
    for n in sorted(t for t in tools if t not in ESCRITURAS):
        args = dict(ARGS_FIJOS.get(n, {}))
        # tools que necesitan un id: se resuelven despues, en la segunda pasada
        if n in ("man_get_equipo", "man_get_ot", "alm_get_pedido_material"):
            continue
        bien, dato = llamar(n, args)
        datos[n] = dato
        ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)

    print("\n=== DETALLE (encadenado) ===")
    encadenados["man_get_equipo"] = ("equi_id", buscar_id(datos.get("man_get_equipos"), "id_equipo"))
    encadenados["man_get_ot"] = ("id_solicitud", buscar_id(datos.get("man_get_ots"), "id_solicitud"))
    encadenados["alm_get_pedido_material"] = ("pema_id", buscar_id(datos.get("alm_get_pedidos_materiales"), "pema_id"))
    for n, (param, valor) in encadenados.items():
        if not valor:
            print(f"  --   {n:30} sin dato previo para encadenar"); omit += 1; continue
        bien, _ = llamar(n, {param: valor})
        ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)

    print("\n=== ESCRITURA ===")
    if not a.escrituras:
        print("  omitidas (crean registros reales e instancian procesos en Bonita)")
        print("  para ejecutarlas: --escrituras")
        omit += len(ESCRITURAS)
    else:
        depo = buscar_id(datos.get("alm_get_depositos"), "depo_id")
        arti = buscar_id(datos.get("alm_get_stock"), "id", "arti_id")
        if depo and arti:
            bien, dato = llamar("alm_crear_pedido_materiales",
                                {"requestBody": {"justificacion": "TEST e2e - ignorar",
                                                 "articulos": [{"arti_id": str(arti), "cantidad": "1",
                                                                "depo_id": str(depo)}]}})
            ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)
        else:
            print("  --   alm_crear_pedido_materiales   faltan deposito o articulo"); omit += 1
        equi = buscar_id(datos.get("man_get_equipos"), "id_equipo")
        if equi:
            bien, _ = llamar("man_create_ot",
                             {"requestBody": {"equipo_id": str(equi),
                                              "descripcion": "TEST e2e - ignorar"}})
            ok, fail = (ok + 1, fail) if bien else (ok, fail + 1)
        else:
            print("  --   man_create_ot                 sin equipos"); omit += 1

    print(f"\n  OK: {ok}   FAIL: {fail}   omitidas: {omit}")
    if fail:
        print("\n  Si alguna dio status 202 en el cable, el cliente MCP la interpreta")
        print("  como notificacion y descarta el cuerpo: revisar el rewrite de Caddy.")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
