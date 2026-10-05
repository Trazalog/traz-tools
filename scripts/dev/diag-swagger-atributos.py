#!/usr/bin/env python3
"""
Compara, dentro de la definicion OpenAPI de la API, los atributos de una
operacion que SI mapea contra una que NO. Si las 8 rotas carecen de alguna
extension WSO2 (x-auth-type, x-throttling-tier, x-wso2-*), eso explicaria
por que fallan siempre las mismas, por cualquier camino.

USO:  python3 diag-swagger-atributos.py /tmp/api-swagger.json
"""
import json, sys

SANAS = ["/mcp/man/equipos", "/mcp/alm/stock", "/mcp/man/ot"]
ROTAS = ["/mcp/man/kpi/mttr", "/mcp/man/lecturas", "/mcp/alm/depositos"]

d = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/api-swagger.json"))
paths = d.get("paths", {})

def attrs(p):
    v = paths.get(p)
    if not v: return None
    m = "get" if "get" in v else next(iter(v))
    return m, v[m]

print("=== claves de cada operacion ===\n")
todas = {}
for grupo, lst in (("SANA", SANAS), ("ROTA", ROTAS)):
    for p in lst:
        a = attrs(p)
        if not a:
            print(f"  {grupo:5} {p:34} NO ESTA EN LA DEFINICION"); continue
        m, body = a
        ks = sorted(body.keys())
        todas[(grupo, p)] = set(ks)
        print(f"  {grupo:5} {p:34} [{m}] {ks}")

sanas = [v for (g, _), v in todas.items() if g == "SANA"]
rotas = [v for (g, _), v in todas.items() if g == "ROTA"]
if sanas and rotas:
    comun_sanas = set.intersection(*sanas)
    comun_rotas = set.intersection(*rotas)
    falta = comun_sanas - comun_rotas
    sobra = comun_rotas - comun_sanas
    print()
    print("=== DIFERENCIA ===")
    print(f"  presente en TODAS las sanas y en NINGUNA rota: {sorted(falta) or 'nada'}")
    print(f"  presente en TODAS las rotas y en NINGUNA sana: {sorted(sobra) or 'nada'}")
    if falta:
        print("\n  >>> Eso es lo que hay que agregarle a las 8 operaciones nuevas.")
    else:
        print("\n  Sin diferencias estructurales: la definicion no explica el corte.")

print("\n=== ejemplo completo de una SANA y una ROTA ===")
for g, p in (("SANA", SANAS[0]), ("ROTA", ROTAS[0])):
    a = attrs(p)
    if a:
        print(f"\n--- {g} {p}")
        print(json.dumps(a[1], indent=2, ensure_ascii=False)[:900])
