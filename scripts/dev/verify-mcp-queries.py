"""Extrae las queries MCP de los .dbs y las ejecuta contra las bases reales,
comparando el resultado contra un conteo de control independiente."""
import os
# Credenciales por variables de entorno — NO hardcodear.
#   export MCP_DB_HOST=10.142.0.13 MCP_MYSQL_PASS=... MCP_PG_PASS=...
MYSQL_HOST = os.environ.get("MCP_DB_HOST", "10.142.0.13")
MYSQL_USER = os.environ.get("MCP_MYSQL_USER", "rootremote")
MYSQL_PASS = os.environ.get("MCP_MYSQL_PASS", "")
PG_PASS    = os.environ.get("MCP_PG_PASS", "")
import xml.etree.ElementTree as ET, subprocess, re, sys

D = "_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services"
def local(t): return t.split('}')[-1]

def get_sql(f, qid):
    root = ET.parse(f"{D}/{f}").getroot()
    for q in root.iter():
        if local(q.tag) == "query" and q.get("id") == qid:
            for c in q:
                if local(c.tag) == "sql":
                    return " ".join((c.text or "").split())
    return None

def mysql(sql):
    r = subprocess.run(["mysql","-h",MYSQL_HOST,"-P","3306","-u",MYSQL_USER,
                        f"-p{MYSQL_PASS}","assetv2","-N","-e",sql],
                       capture_output=True, timeout=60)
    out = r.stdout.decode('utf-8','replace').splitlines()
    err = [l for l in r.stderr.decode('utf-8','replace').splitlines() if 'Using a password' not in l]
    return out, err

def pg(sql):
    import os
    env = dict(os.environ, PGPASSWORD=PG_PASS)
    r = subprocess.run(["psql","-h",MYSQL_HOST,"-p","5432","-U","postgres",
                        "-d","tools_prod_t","-t","-A","-c",sql],
                       capture_output=True, timeout=60, env=env)
    return [l for l in r.stdout.decode('utf-8','replace').splitlines() if l.strip()], r.stderr.decode('utf-8','replace').strip()

print("="*78)
print("VERIFICACION DE QUERIES MCP CONTRA DATOS REALES (base de desarrollo)")
print("="*78)

fails = 0

# ---- MAN: getEquipos ----
sql = get_sql("MANEquiposDataService.dbs", "getEquipos")
for E in [8,6,1,17,9]:
    q = sql.replace(":id_empresa", str(E))
    rows, err = mysql(f"SELECT count(*) FROM ({q}) _c")
    ctrl,_ = mysql(f"SELECT count(*) FROM equipos WHERE id_empresa={E} AND estado!='AN';")
    ok = int(rows[0]) == int(ctrl[0])
    fails += 0 if ok else 1
    print(f"man_get_equipos      empr={E:<4} devuelve={rows[0]:<5} esperado={ctrl[0]:<5} {'OK' if ok else '*** FALLA ***'}")
    if err: print("   ERR:", err[:2])

# ---- MAN: getOTsByEmpresa ----
sql = get_sql("MANDataService.dbs", "getOTsByEmpresa")
for E in [8,6,1,17,9]:
    q = sql.replace(":id_empresa", str(E)).replace(":estado", "''")
    rows, err = mysql(f"SELECT count(*) FROM ({q}) _c")
    ctrl,_ = mysql(f"SELECT count(*) FROM solicitud_reparacion WHERE id_empresa={E} AND estado!='AN';")
    ok = int(rows[0]) == int(ctrl[0])
    fails += 0 if ok else 1
    print(f"man_get_ots          empr={E:<4} devuelve={rows[0]:<5} esperado={ctrl[0]:<5} {'OK' if ok else '*** FALLA ***'}")
    if err: print("   ERR:", err[:2])

# ---- MAN: getSolicitudServicioById (las 3 que duplicaban) ----
sql = get_sql("MANDataService.dbs", "getSolicitudServicioById")
for sid in [75,117,127]:
    q = sql.replace(":id_empresa", "6").replace(":id_solicitud", str(sid))
    rows, err = mysql(f"SELECT count(*) FROM ({q}) _c")
    ok = int(rows[0]) == 1
    fails += 0 if ok else 1
    print(f"man_get_ot           sol={sid:<5} devuelve={rows[0]:<5} esperado=1     {'OK' if ok else '*** FALLA ***'}")
    if err: print("   ERR:", err[:2])

# ---- MAN: getEquipoIsolated (los 2 equipos con grupo roto) ----
sql = get_sql("MANDataService.dbs", "getEquipoIsolated")
for eq,emp in [(2,8),(3,8)]:
    q = sql.replace(":equi_id", str(eq)).replace(":id_empresa", str(emp))
    rows, err = mysql(f"SELECT count(*) FROM ({q}) _c")
    ok = int(rows[0]) == 1
    fails += 0 if ok else 1
    print(f"man_get_equipo       equi={eq:<4} devuelve={rows[0]:<5} esperado=1     {'OK' if ok else '*** FALLA ***'}")
    if err: print("   ERR:", err[:2])

# ---- ALM: getArticulos2 ----
sql = get_sql("ALMDataService.dbs", "getArticulos2")
for E in [1,87,777,9,4]:
    q = sql.replace(":empr_id", f"'{E}'")
    rows, err = pg(f"SELECT count(*) FROM ({q}) _c")
    ctrl,_ = pg(f"SELECT count(*) FROM alm.alm_articulos WHERE empr_id={E} AND eliminado=false;")
    ok = int(rows[0]) == int(ctrl[0])
    fails += 0 if ok else 1
    print(f"alm_get_stock        empr={E:<4} devuelve={rows[0]:<5} esperado={ctrl[0]:<5} {'OK' if ok else '*** FALLA ***'}")
    if err: print("   ERR:", err[:200])

# ---- ALM: pedidos ----
sql = get_sql("ALMDataService.dbs", "getPedidosMaterialesEmpresa")
for E in [1,777,87]:
    q = sql.replace(":empr_id", f"'{E}'")
    rows, err = pg(f"SELECT count(*) FROM ({q}) _c")
    ctrl,_ = pg(f"SELECT count(*) FROM alm.alm_pedidos_materiales WHERE empr_id={E} AND not eliminado;")
    ok = int(rows[0]) == int(ctrl[0])
    fails += 0 if ok else 1
    print(f"alm_get_pedidos      empr={E:<4} devuelve={rows[0]:<5} esperado={ctrl[0]:<5} {'OK' if ok else '*** FALLA ***'}")
    if err: print("   ERR:", err[:200])

print("="*78)
print(f"RESULTADO: {'TODO OK' if fails==0 else str(fails)+' FALLAS'}")
sys.exit(1 if fails else 0)
