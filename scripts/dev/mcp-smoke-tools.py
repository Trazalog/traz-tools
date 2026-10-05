#!/usr/bin/env python3
"""
Smoke test individual de cada tool del MCP Server publicado.

Que hace: llama tools/list, y despues tools/call sobre CADA tool, e
interpreta el codigo de respuesta. Sirve con o sin JWT:

  SIN token  -> distingue las tools sanas de las rotas:
                  401  la tool esta bien mapeada y el gateway pide auth
                  500 "existingAPIOperationMapping is null"
                       la tool existe en el MCP Server pero NO tiene
                       asociada la operacion del backend (campo Operation)
  CON token  -> ademas valida que devuelvan datos reales.

USO:
  python3 scripts/dev/mcp-smoke-tools.py
  python3 scripts/dev/mcp-smoke-tools.py --url https://otro-host/ctx/1.0/mcp
  python3 scripts/dev/mcp-smoke-tools.py --jwt "$JWT"
"""
import argparse, json, subprocess, sys

URL_DEFAULT = "https://mcp.cloudtrazalog.com/trazalog/mcp/1.0/mcp"

# argumentos de ejemplo por tool (solo los que necesitan parametros)
ARGS = {
    "man_get_equipo":              {"equi_id": "1"},
    "man_get_ot":                  {"id_solicitud": "1"},
    "alm_get_pedido_material":     {"pema_id": "1"},
    "man_get_kpi_disponibilidad":  {"fec_inicio": "2026-07-01", "fec_fin": "2026-07-31"},
    "man_get_kpi_mttr":            {"fec_inicio": "2026-07-01", "fec_fin": "2026-07-31"},
    "man_get_kpi_mttf":            {"fec_inicio": "2026-07-01", "fec_fin": "2026-07-31"},
    "man_get_kpi_fallas":          {"fec_inicio": "2026-07-01", "fec_fin": "2026-07-31"},
}


def rpc(url, payload, jwt=None, timeout=90):
    cmd = ["curl", "-sS", "-m", str(timeout), "-w", "\n%{http_code}",
           "-X", "POST", url, "-H", "Content-Type: application/json"]
    if jwt:
        cmd += ["-H", f"Authorization: Bearer {jwt}"]
    cmd += ["-d", json.dumps(payload)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    body, _, code = r.stdout.rpartition("\n")
    return code.strip(), body


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default=URL_DEFAULT)
    ap.add_argument("--jwt", default=None, help="JWT real de Dnato (opcional)")
    a = ap.parse_args()

    print(f"MCP Server: {a.url}")
    print(f"Token     : {'si' if a.jwt else 'NO (se valida el mapeo, no los datos)'}\n")

    code, body = rpc(a.url, {"jsonrpc": "2.0", "method": "initialize", "id": 1,
                             "params": {"protocolVersion": "2025-06-18", "capabilities": {},
                                        "clientInfo": {"name": "smoke", "version": "1.0"}}}, a.jwt)
    if code != "200":
        print(f"initialize fallo: HTTP {code}\n{body[:300]}")
        return 2
    print("initialize        OK")

    code, body = rpc(a.url, {"jsonrpc": "2.0", "method": "tools/list", "id": 2}, a.jwt)
    try:
        tools = [t["name"] for t in json.loads(body)["result"]["tools"]]
    except Exception:
        print(f"tools/list fallo: HTTP {code}\n{body[:300]}")
        return 2
    print(f"tools/list        OK — {len(tools)} tools publicadas\n")

    sanas, rotas, otras = [], [], []
    for name in sorted(tools):
        code, body = rpc(a.url, {"jsonrpc": "2.0", "method": "tools/call", "id": 3,
                                 "params": {"name": name, "arguments": ARGS.get(name, {})}}, a.jwt)
        if "existingAPIOperationMapping" in body:
            estado, grupo = "SIN MAPEO — falta asociar la Operation", rotas
        elif code == "401":
            estado, grupo = "ok (mapeada; el gateway pide auth)", sanas
        elif code == "200":
            err = '"error"' in body or '"isError":true' in body
            estado, grupo = ("responde con error de negocio", otras) if err else ("OK con datos", sanas)
        else:
            estado, grupo = f"revisar (HTTP {code})", otras
        grupo.append(name)
        print(f"  {name:30} {code:>4}  {estado}")

    print(f"\n  sanas : {len(sanas)}")
    print(f"  rotas : {len(rotas)}")
    for t in rotas:
        print(f"     - {t}")
    if rotas:
        print("\n  Las 'rotas' existen en el MCP Server pero no tienen operacion de backend")
        print("  asociada. Ver doc/mcp/republicar-mcp-server.md paso C / C-bis.")
    return 1 if rotas else 0


if __name__ == "__main__":
    sys.exit(main())
