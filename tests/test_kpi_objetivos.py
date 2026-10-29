"""Historia, objetivos y desvios del motor de KPIs (KPI-HIST, KPI-OBJ).

Arma una base descartable con el motor de produccion (v2.8.1.4) y le aplica
v2.8.1.6, siguiendo el plan de prueba del analisis de impacto
(doc/agente/analisis-impacto-kpi-objetivos.md, seccion 6). Idealmente contra
PostgreSQL 11, la version de produccion. Se saltea sin KPI_TEST_ADMIN_DSN, ej.:

    KPI_TEST_ADMIN_DSN="host=127.0.0.1 port=55411 dbname=postgres user=postgres password=..."
"""
from __future__ import annotations

import os
import random
from datetime import date, timedelta
from pathlib import Path

import psycopg
import pytest
from psycopg.rows import dict_row

ADMIN = os.environ.get("KPI_TEST_ADMIN_DSN")
pytestmark = pytest.mark.skipif(not ADMIN, reason="Sin KPI_TEST_ADMIN_DSN: se saltean los tests del motor de KPIs")

VERSIONES = Path(__file__).resolve().parents[1] / "_backend/database/scripts/versiones"
MOTOR = VERSIONES / "v2.8.1.4/kpi_cache_engine.sql"
CAMBIO = VERSIONES / "v2.8.1.6/kpi_objetivos.sql"
ROLLBACK = VERSIONES / "v2.8.1.6/kpi_objetivos.rollback.sql"

A, B = 900001, 900002


def _dsn(base: str) -> str:
    partes = [p for p in ADMIN.split() if not p.startswith("dbname=")]
    return " ".join(partes + [f"dbname={base}"])


@pytest.fixture
def db():
    """Una base nueva por test, con el motor de produccion y dos KPIs de prueba."""
    nombre = f"kpi_prueba_{random.randint(0, 10**8)}"
    with psycopg.connect(ADMIN, autocommit=True) as adm:
        adm.execute(f"CREATE DATABASE {nombre}")
    con = psycopg.connect(_dsn(nombre), autocommit=True, row_factory=dict_row)
    try:
        con.execute("CREATE SCHEMA core; CREATE TABLE core.empresas (empr_id integer PRIMARY KEY, empr_id_mysql integer)")
        con.execute(f"INSERT INTO core.empresas VALUES ({A}, NULL), ({B}, NULL), (9000, NULL)")
        con.execute(MOTOR.read_text())
        # Dos KPIs que dependen de una tabla que el test controla.
        con.execute("CREATE TABLE public.dato (empr_id integer, kpi text, valor numeric)")
        con.execute("""
            INSERT INTO kpi.definiciones (nombre, descripcion, modulo, sql_template, refresh_seg) VALUES
            ('cumplimiento', 'Cumplimiento del preventivo', 'man',
             'SELECT (SELECT valor FROM public.dato WHERE empr_id = $1 AND kpi = ''cumplimiento'') AS valor, NULL::jsonb AS valor_json', 300),
            ('atraso', 'Ordenes atrasadas', 'man',
             'SELECT (SELECT valor FROM public.dato WHERE empr_id = $1 AND kpi = ''atraso'') AS valor, NULL::jsonb AS valor_json', 300)""")
        yield con
    finally:
        con.close()
        with psycopg.connect(ADMIN, autocommit=True) as adm:
            adm.execute(f"DROP DATABASE IF EXISTS {nombre}")


def _datos(con, **valores):
    """valores: {'cumplimiento_A': 80, ...}"""
    con.execute("DELETE FROM public.dato")
    for clave, v in valores.items():
        kpi, emp = clave.rsplit("_", 1)
        con.execute("INSERT INTO public.dato VALUES (%s, %s, %s)", ({"A": A, "B": B}[emp], kpi, v))


def _correr(con):
    con.execute("UPDATE kpi.cache SET vence_en = now() - interval '1 second'")
    con.execute("SELECT kpi.correr()")


def _cache(con):
    return {(r["nombre"], r["empr_id"]): r["valor"]
            for r in con.execute("SELECT nombre, empr_id, valor FROM kpi.cache").fetchall()}


def _aplicar(con):
    con.execute(CAMBIO.read_text())


def _objetivo(con, empr, kpi, op, meta, hasta=None, desde=None, usuario="admin", propuesto="usuario"):
    return con.execute("SELECT kpi.objetivo_guardar(%s, %s, 'tools', %s, %s, %s, %s, 'Jefe', %s, %s) AS id",
                       (empr, kpi, op, meta, desde, hasta or date.today() + timedelta(days=60),
                        propuesto, usuario)).fetchone()["id"]


# ------------------------------------------------------------------- historia
def test_el_cache_queda_igual_que_con_el_motor_de_produccion(db):
    _datos(db, cumplimiento_A=80, atraso_A=3, cumplimiento_B=95)
    _correr(db)
    referencia = _cache(db)
    _aplicar(db)
    _correr(db)
    assert _cache(db) == referencia, "el Tablero tiene que ver exactamente lo mismo"


def test_una_fila_por_kpi_empresa_y_dia(db):
    _aplicar(db)
    _datos(db, cumplimiento_A=80, atraso_A=3)
    _correr(db)
    _datos(db, cumplimiento_A=82, atraso_A=4)
    _correr(db)
    filas = db.execute("SELECT nombre, empr_id, fecha, valor FROM kpi.historico WHERE empr_id = %s ORDER BY nombre",
                       (A,)).fetchall()
    assert [(f["nombre"], f["valor"]) for f in filas] == [("atraso", 4), ("cumplimiento", 82)], \
        "la segunda corrida del dia pisa el valor, no suma filas"
    assert all(f["fecha"] == date.today() for f in filas)


def test_si_la_historia_falla_el_tablero_se_publica_igual(db):
    _aplicar(db)
    db.execute("ALTER TABLE kpi.historico ADD CONSTRAINT rompe CHECK (false) NOT VALID")
    _datos(db, cumplimiento_A=70)
    _correr(db)
    assert _cache(db)[("cumplimiento", A)] == 70
    assert db.execute("SELECT count(*) AS n FROM kpi.historico").fetchone()["n"] == 0
    err = db.execute("SELECT detalle FROM kpi.event_log WHERE nombre = 'kpi.historico' AND estado = 'ERROR'").fetchall()
    assert err and "rompe" in err[0]["detalle"]
    assert db.execute("SELECT count(*) AS n FROM kpi.cache_tmp").fetchone()["n"] == 0, "el staging se limpia igual"


def test_se_retienen_dos_anos(db):
    _aplicar(db)
    viejo = date.today() - timedelta(days=731)
    limite = date.today() - timedelta(days=730)
    db.execute("INSERT INTO kpi.historico VALUES ('cumplimiento', %s, %s, 1, NULL, now()), "
               "('cumplimiento', %s, %s, 2, NULL, now())", (A, viejo, A, limite))
    _datos(db, cumplimiento_A=80)
    _correr(db)
    fechas = {r["fecha"] for r in db.execute("SELECT fecha FROM kpi.historico").fetchall()}
    assert viejo not in fechas and limite in fechas


# ------------------------------------------------------------ objetivos y desvios
def test_un_objetivo_incumplido_es_desvio_y_uno_cumplido_no(db):
    _aplicar(db)
    _datos(db, cumplimiento_A=72, atraso_A=2)
    _correr(db)
    incumplido = _objetivo(db, A, "cumplimiento", ">=", 85)
    _objetivo(db, A, "atraso", "<=", 5)
    desvios = db.execute("SELECT * FROM kpi.desvios(%s)", (A,)).fetchall()
    assert [(d["objetivo_id"], d["kpi"], d["valor_actual"]) for d in desvios] == [(incumplido, "cumplimiento", 72)]


def test_la_tendencia_compara_con_hace_30_dias(db):
    _aplicar(db)
    _datos(db, cumplimiento_A=72)
    _correr(db)
    db.execute("INSERT INTO kpi.historico VALUES ('cumplimiento', %s, %s, 80, NULL, now())",
               (A, date.today() - timedelta(days=35)))
    _objetivo(db, A, "cumplimiento", ">=", 85)
    d = db.execute("SELECT * FROM kpi.desvios(%s)", (A,)).fetchone()
    assert (d["valor_hace_30"], d["tendencia"]) == (80, "empeora")


def test_los_desvios_no_cruzan_empresas(db):
    _aplicar(db)
    _datos(db, cumplimiento_A=50, cumplimiento_B=50)
    _correr(db)
    _objetivo(db, A, "cumplimiento", ">=", 85)
    assert db.execute("SELECT * FROM kpi.desvios(%s)", (B,)).fetchall() == []
    assert db.execute("SELECT * FROM kpi.objetivos_de(%s)", (B,)).fetchall() == []


def test_no_se_carga_un_kpi_que_no_existe_ni_dos_vigentes_del_mismo(db):
    _aplicar(db)
    with pytest.raises(psycopg.errors.RaiseException, match="no existe"):
        _objetivo(db, A, "inventado", ">=", 1)
    _objetivo(db, A, "cumplimiento", ">=", 85)
    with pytest.raises(psycopg.errors.RaiseException, match="ya hay un objetivo vigente"):
        _objetivo(db, A, "cumplimiento", ">=", 90)
    _objetivo(db, B, "cumplimiento", ">=", 90)   # otra empresa, sin problema


def test_cancelar_solo_en_la_propia_empresa(db):
    _aplicar(db)
    oid = _objetivo(db, A, "cumplimiento", ">=", 85)
    assert db.execute("SELECT kpi.objetivo_cancelar(%s, %s, 'otro') AS n", (B, oid)).fetchone()["n"] == 0
    assert db.execute("SELECT kpi.objetivo_cancelar(%s, %s, 'admin') AS n", (A, oid)).fetchone()["n"] == 1
    assert db.execute("SELECT * FROM kpi.objetivos_de(%s)", (A,)).fetchall() == []
    todos = db.execute("SELECT estado FROM kpi.objetivos_de(%s, false)", (A,)).fetchall()
    assert [t["estado"] for t in todos] == ["cancelado"]
    _objetivo(db, A, "cumplimiento", ">=", 90)   # cancelado el anterior, se puede cargar otro


def test_un_vigente_con_plazo_vencido_se_informa_como_vencido(db):
    _aplicar(db)
    ayer = date.today() - timedelta(days=1)
    db.execute("INSERT INTO kpi.objetivos (empr_id, kpi, operador, meta, desde, hasta, usuario_alta) "
               "VALUES (%s, 'cumplimiento', '>=', 85, %s, %s, 'admin')", (A, ayer - timedelta(days=30), ayer))
    assert db.execute("SELECT * FROM kpi.objetivos_de(%s)", (A,)).fetchall() == []
    assert db.execute("SELECT estado FROM kpi.objetivos_de(%s, false)", (A,)).fetchone()["estado"] == "vencido"
    assert db.execute("SELECT * FROM kpi.desvios(%s)", (A,)).fetchall() == []
    _objetivo(db, A, "cumplimiento", ">=", 90)   # el vencido no bloquea uno nuevo


def test_objetivos_de_trae_el_valor_actual_y_si_cumple(db):
    _aplicar(db)
    _datos(db, cumplimiento_A=90)
    _correr(db)
    _objetivo(db, A, "cumplimiento", ">=", 85, propuesto="kuntur")
    o = db.execute("SELECT * FROM kpi.objetivos_de(%s)", (A,)).fetchone()
    assert (o["valor_actual"], o["cumple"], o["propuesto_por"], o["descripcion"]) == \
        (90, True, "kuntur", "Cumplimiento del preventivo")


# ------------------------------------------------------------ idempotencia y rollback
def test_aplicar_dos_veces_y_volver_atras(db):
    _aplicar(db)
    _aplicar(db)
    db.execute(ROLLBACK.read_text())
    assert db.execute("SELECT to_regclass('kpi.historico') AS t").fetchone()["t"] is None
    _datos(db, cumplimiento_A=80)
    _correr(db)
    assert _cache(db)[("cumplimiento", A)] == 80, "el motor de produccion sigue andando"
