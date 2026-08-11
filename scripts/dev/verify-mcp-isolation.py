"""Verifica aislamiento multi-tenant (ADR-012): ninguna query MCP puede
devolver una fila que pertenezca a otra empresa."""
import os
# Credenciales por variables de entorno — NO hardcodear.
#   export MCP_DB_HOST=10.142.0.13 MCP_MYSQL_PASS=... MCP_PG_PASS=...
MYSQL_HOST = os.environ.get("MCP_DB_HOST", "10.142.0.13")
MYSQL_USER = os.environ.get("MCP_MYSQL_USER", "rootremote")
MYSQL_PASS = os.environ.get("MCP_MYSQL_PASS", "")
PG_PASS    = os.environ.get("MCP_PG_PASS", "")
import xml.etree.ElementTree as ET, subprocess, os, sys
D = "_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services"
def local(t): return t.split('}')[-1]
def get_sql(f, qid):
    for q in ET.parse(f"{D}/{f}").getroot().iter():
        if local(q.tag)=="query" and q.get("id")==qid:
            for c in q:
                if local(c.tag)=="sql": return " ".join((c.text or "").split())
def my(sql):
    r=subprocess.run(["mysql","-h",MYSQL_HOST,"-P","3306","-u",MYSQL_USER,f"-p{MYSQL_PASS}","assetv2","-N","-e",sql],capture_output=True,timeout=60)
    return r.stdout.decode('utf-8','replace').strip()
def pg(sql):
    env=dict(os.environ,PGPASSWORD=PG_PASS)
    r=subprocess.run(["psql","-h",MYSQL_HOST,"-p","5432","-U","postgres","-d","tools_prod_t","-t","-A","-c",sql],capture_output=True,timeout=60,env=env)
    return r.stdout.decode('utf-8','replace').strip()

print("="*78); print("AISLAMIENTO MULTI-TENANT (ADR-012)"); print("="*78)
fails=0

# man_get_equipos: ninguna fila con empr_id != solicitado
sql=get_sql("MANEquiposDataService.dbs","getEquipos")
for E in [8,6,1,17,9]:
    q=sql.replace(":id_empresa",str(E))
    n=my(f"SELECT count(*) FROM ({q}) _c WHERE empr_id <> {E}")
    ok = n=="0"; fails += 0 if ok else 1
    print(f"man_get_equipos  empr={E:<4} filas_ajenas={n:<4} {'OK' if ok else '*** FUGA ***'}")

# man_get_ots
sql=get_sql("MANDataService.dbs","getOTsByEmpresa")
for E in [8,6,1,9]:
    q=sql.replace(":id_empresa",str(E)).replace(":estado","''")
    n=my(f"SELECT count(*) FROM ({q}) _c WHERE id_empresa <> {E}")
    ok = n=="0"; fails += 0 if ok else 1
    print(f"man_get_ots      empr={E:<4} filas_ajenas={n:<4} {'OK' if ok else '*** FUGA ***'}")

# man_get_equipo: pedir un equipo de OTRA empresa debe dar 0 filas
sql=get_sql("MANDataService.dbs","getEquipoIsolated")
eq_de_8 = my("SELECT id_equipo FROM equipos WHERE id_empresa=8 AND estado!='AN' LIMIT 1")
q=sql.replace(":equi_id",eq_de_8).replace(":id_empresa","6")
n=my(f"SELECT count(*) FROM ({q}) _c")
ok = n=="0"; fails += 0 if ok else 1
print(f"man_get_equipo   equipo {eq_de_8} (empr 8) pedido por empr 6 -> {n} filas {'OK' if ok else '*** FUGA ***'}")

# man_get_ot: solicitud de otra empresa
sql=get_sql("MANDataService.dbs","getSolicitudServicioById")
sol6 = my("SELECT id_solicitud FROM solicitud_reparacion WHERE id_empresa=6 AND estado!='AN' LIMIT 1")
q=sql.replace(":id_solicitud",sol6).replace(":id_empresa","8")
n=my(f"SELECT count(*) FROM ({q}) _c")
ok = n=="0"; fails += 0 if ok else 1
print(f"man_get_ot       solicitud {sol6} (empr 6) pedida por empr 8 -> {n} filas {'OK' if ok else '*** FUGA ***'}")

# alm_get_stock: filas ajenas + stock contaminado por lotes de otra empresa
sql=get_sql("ALMDataService.dbs","getArticulos2")
for E in [1,87,777]:
    q=sql.replace(":empr_id",f"'{E}'")
    n=pg(f"SELECT count(*) FROM ({q}) _c WHERE empr_id <> {E}")
    ok = n=="0"; fails += 0 if ok else 1
    print(f"alm_get_stock    empr={E:<4} filas_ajenas={n:<4} {'OK' if ok else '*** FUGA ***'}")
    # el stock reportado debe coincidir con la suma de lotes PROPIOS
    d=pg(f"""SELECT count(*) FROM ({q}) _c
             JOIN (SELECT l.arti_id, coalesce(sum(l.cantidad),0) s FROM alm.alm_lotes l
                    WHERE l.empr_id={E} GROUP BY l.arti_id) t ON t.arti_id=_c.arti_id
            WHERE _c.stock::numeric <> t.s""")
    ok2 = d=="0"; fails += 0 if ok2 else 1
    print(f"                       stock_contaminado={d:<4} {'OK' if ok2 else '*** STOCK AJENO ***'}")

# alm_get_pedidos
sql=get_sql("ALMDataService.dbs","getPedidosMaterialesEmpresa")
for E in [1,777]:
    q=sql.replace(":empr_id",f"'{E}'")
    n=pg(f"SELECT count(*) FROM ({q}) _c WHERE empr_id <> {E}")
    ok = n=="0"; fails += 0 if ok else 1
    print(f"alm_get_pedidos  empr={E:<4} filas_ajenas={n:<4} {'OK' if ok else '*** FUGA ***'}")

print("="*78); print(f"RESULTADO: {'AISLAMIENTO OK' if fails==0 else str(fails)+' FUGAS'}")
sys.exit(1 if fails else 0)
