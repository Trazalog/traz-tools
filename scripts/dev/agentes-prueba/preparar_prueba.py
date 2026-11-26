"""Deja listo el punto de partida de la prueba manual de los agentes.

DÓNDE SE CORRE: terminal local, desde la raíz del repo, con la conexión a DEV
levantada y el motor de los agentes APAGADO (la base se recrea):

    set -a && . ~/.agente-minero.env && . ~/.agentes-prueba.env && set +a && \
      .venv-agente/bin/python scripts/dev/agentes-prueba/preparar_prueba.py --borrar

QUÉ HACE (todo con empresas de prueba; nunca toca otras):
  1. Base de agentes de prueba (`agentes_manual` en el contenedor
     agentes-pg-prueba): con --borrar la recrea desde los scripts db/agente/,
     y carga el conocimiento (ayudas de Tools, casos de uso de DocTest y los
     hechos de ejemplo de archivos/). La primera vez gasta unos centavos de
     OpenRouter; después reusa una copia guardada en ~/.cache/agentes-prueba/.
  2. Perfiles de empresa y expertos de Faustino.
  3. Base de Tools de DEV: la empresa nueva ELECTRICA DEL SUR TEST, los
     usuarios de prueba con su menú, y su usuario de Bonita.
  4. Datos del día a día de la empresa 191 en DEV, con fechas relativas a hoy.
  5. Imprime el punto de partida para compararlo con el guion.

Las claves salen de ~/.agentes-prueba.env (fuera del repo). Nada de esto va
a archivos versionados.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import http.cookiejar
import json
import os
import pathlib
import secrets
import subprocess
import sys
import urllib.parse
import urllib.request

import psycopg

RAIZ = pathlib.Path(__file__).resolve().parents[3]
AQUI = pathlib.Path(__file__).resolve().parent
CACHE = pathlib.Path.home() / ".cache" / "agentes-prueba"

# 📅 Todas las fechas cuelgan de acá (lección de portal_t4).
HOY = dt.date.today()

EMPRESA_MINERA = 191                     # ya existe: AGENTE MINERO TEST
GRUPO_MINERA = "AGENTE MINERO TEST"
EMPRESA_NUEVA = "ELECTRICA DEL SUR TEST"  # se crea si no está
CUIT_NUEVA = "30-99999998-9"

# usuario, nombre, apellido, nick, grupo (empresa), rol de la empresa, rol Dnato (1 = administrador)
USUARIOS = [
    ("agente.minero.test@trazalog.local", "Agente", "Prueba", "agenteminero", GRUPO_MINERA, "Administrador", "1"),
    ("experto.minero@trazalog.local", "Juan", "Pérez", "expertominero", GRUPO_MINERA, f"Experto {GRUPO_MINERA}", "4"),
    ("experta.minera@trazalog.local", "Marta", "Gómez", "expertaminera", GRUPO_MINERA, f"Experto {GRUPO_MINERA}", "4"),
    ("operario.minero@trazalog.local", "Pedro", "Ríos", "operariominero", GRUPO_MINERA,
     f"Responsable de Almacén {GRUPO_MINERA}", "4"),
    ("admin.electrica@trazalog.local", "Laura", "Méndez", "adminelectrica", EMPRESA_NUEVA, "Administrador", "1"),
]
# Menú del agente por rol: (grupo, rol, opciones de seg.menues)
MENUES = [
    (GRUPO_MINERA, f"Experto {GRUPO_MINERA}", ["core", "agente_minero", "agente_entrevista"]),
    (GRUPO_MINERA, f"Responsable de Almacén {GRUPO_MINERA}", ["agente_minero"]),
    (EMPRESA_NUEVA, "Administrador", ["core", "agente_minero", "agente_feedback", "agente_entrevista"]),
]
# Expertos de Faustino: nombre, nick del usuario, especialidad
EXPERTOS = [
    ("Juan Pérez (jefe de planta)", "expertominero", "Chancado y molienda"),
    ("Marta Gómez (supervisora de mantenimiento)", "expertaminera", "Mantenimiento de equipos móviles"),
]


def env(k: str) -> str:
    v = os.environ.get(k)
    if not v:
        sys.exit(f"Falta {k}: cargá ~/.agente-minero.env y ~/.agentes-prueba.env (ver el encabezado)")
    return v


def paso(t: str) -> None:
    print(f"\n▶ {t}", flush=True)


# ------------------------------------------------------------ base de agentes
def dsn_admin(base: str) -> str:
    u = urllib.parse.urlsplit(env("PRUEBA_AGENTES_ADMIN_DSN"))
    return urllib.parse.urlunsplit(u._replace(path="/" + base))


def recrear_base() -> None:
    base = env("AGENTE_DB_NAME")
    if base != "agentes_manual":
        sys.exit(f"AGENTE_DB_NAME es '{base}': esta preparación solo recrea 'agentes_manual'")
    paso(f"Recreo la base de agentes de prueba '{base}'")
    with psycopg.connect(dsn_admin("postgres"), autocommit=True) as c:
        c.execute("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = %s", (base,))
        c.execute(f'DROP DATABASE IF EXISTS "{base}"')
        c.execute(f'CREATE DATABASE "{base}"')
    scripts = sorted(p for p in (RAIZ / "db/agente").glob("[0-9][0-9][0-9]-*.sql") if "rollback" not in p.name)
    for s in scripts:
        r = subprocess.run(["psql", "-q", "-v", "ON_ERROR_STOP=1", dsn_admin(base), "-f", str(s)],
                           capture_output=True, text=True)
        if r.returncode:
            sys.exit(f"falló {s.name}:\n{r.stderr[-800:]}")
    print(f"  {len(scripts)} scripts aplicados ({scripts[0].name[:3]} a {scripts[-1].name[:3]})")


def huella_conocimiento() -> str:
    """Cambia si cambian las ayudas, los casos de uso o los hechos de ejemplo."""
    h = hashlib.sha256()
    for carpeta, patron in (("ayuda", "*.html"), ("doctest/catalogo", "*-UC-*.yaml")):
        for p in sorted((RAIZ / carpeta).rglob(patron)):
            h.update(p.read_bytes())
    for p in sorted((AQUI / "archivos").glob("conocimiento-*.md")):
        h.update(p.read_bytes())
    return h.hexdigest()[:16]


def cargar_conocimiento() -> None:
    paso("Cargo el conocimiento compartido")
    CACHE.mkdir(parents=True, exist_ok=True)
    copia = CACHE / f"conocimiento-{huella_conocimiento()}.sql"
    if copia.exists():
        r = subprocess.run(["psql", "-q", "-v", "ON_ERROR_STOP=1", dsn_admin(env("AGENTE_DB_NAME")),
                            "-f", str(copia)], capture_output=True, text=True)
        if r.returncode:
            sys.exit(f"no pude restaurar {copia}:\n{r.stderr[-800:]}")
        print(f"  restaurado de {copia} (sin gastar tokens)")
        return
    curador = dict(os.environ, AGENTE_DB_USER=env("PRUEBA_CURADOR_USER"),
                   AGENTE_DB_PASSWORD=env("PRUEBA_CURADOR_PASSWORD"))
    py = sys.executable

    def ingesta(*args: str) -> None:
        r = subprocess.run([py, "-m", "agente.ingesta", *args], cwd=RAIZ, env=curador, text=True,
                           capture_output=True)
        print("  " + (r.stdout.strip().splitlines() or ["(sin salida)"])[-1])
        if r.returncode:
            sys.exit(f"falló la ingesta {args}:\n{r.stderr[-800:]}")

    ingesta("ayuda/", "doctest/catalogo/")
    for p in sorted((AQUI / "archivos").glob("conocimiento-*.md")):
        # conocimiento-<vertical>-<modulo>.md
        _, vertical, modulo = p.stem.split("-", 2)
        ingesta(str(p), "--vertical", vertical, "--modulo", modulo, "--confianza", "0.8",
                "--reemplazar")
    r = subprocess.run(["pg_dump", "--data-only", "--table=agente.fuente", "--table=agente.chunk",
                        dsn_admin(env("AGENTE_DB_NAME"))], capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"no pude guardar la copia del conocimiento:\n{r.stderr[-800:]}")
    copia.write_text(r.stdout)
    print(f"  copia guardada en {copia}")


def sembrar_agentes(usuarios_ids: dict[str, int], empr_nueva: int) -> None:
    paso("Perfiles de empresa y expertos de Faustino")
    with psycopg.connect(dsn_admin(env("AGENTE_DB_NAME"))) as c:
        for e in (EMPRESA_MINERA, empr_nueva):
            c.execute("SELECT agente.crear_particion_empresa(%s)", (e,))
        c.execute("SELECT set_config('agente.empr_id', %s, true)", (str(EMPRESA_MINERA),))
        c.execute("""
            INSERT INTO agente.perfil_empresa (empr_id, vertical, modulos, operadora, operadora_nombre,
                                               preocupaciones, confirmado_por, fec_confirmacion)
            VALUES (%s, 'mineria', ARRAY['almacenes','mantenimiento','herramientas','tareas'], true,
                    'Minera Veladero (inventada)', ARRAY['Que no paren los equipos críticos'],
                    'agenteminero', now())
            ON CONFLICT (empr_id) DO NOTHING""", (EMPRESA_MINERA,))
        for nombre, nick, esp in EXPERTOS:
            c.execute("""INSERT INTO agente.experto (nombre, usr_id, especialidad)
                         SELECT %s, %s, %s WHERE NOT EXISTS (SELECT 1 FROM agente.experto WHERE nombre = %s)""",
                      (nombre, usuarios_ids.get(nick), esp, nombre))
    print(f"  191 con perfil de minería; {EMPRESA_NUEVA} ({empr_nueva}) sin perfil; {len(EXPERTOS)} expertos")


# ------------------------------------------------------------- Tools (DEV)
def tools() -> psycopg.Connection:
    return psycopg.connect(host=env("TOOLS_DB_HOST"), port=env("TOOLS_DB_PORT"), dbname=env("TOOLS_DB_NAME"),
                           user=env("TOOLS_DB_USER"), password=env("TOOLS_DB_PASSWORD"), connect_timeout=10)


def hash_dnato(clave: str) -> str:
    """Mismo formato que la librería Password de Dnato: sha256:1000:<sal base64>:<hash base64>.
    Ojo: Dnato usa la sal en base64 (el texto) como sal del PBKDF2."""
    sal = base64.b64encode(secrets.token_bytes(24)).decode()
    h = hashlib.pbkdf2_hmac("sha256", clave.encode(), sal.encode(), 1000, 24)
    return f"sha256:1000:{sal}:{base64.b64encode(h).decode()}"


def sembrar_tools() -> tuple[dict[str, int], int]:
    paso("Empresa, usuarios y menús de prueba en Tools (DEV)")
    clave = env("PRUEBA_CLAVE")
    with tools() as c:
        r = c.execute("SELECT empr_id FROM core.empresas WHERE descripcion = %s", (EMPRESA_NUEVA,)).fetchone()
        if r:
            empr_nueva = r[0]
        else:
            empr_nueva = c.execute("""INSERT INTO core.empresas (descripcion, nombre, cuit, email, eliminado,
                                         estado, estado_plan, uso_plan_gratuito)
                                      VALUES (%s, %s, %s, %s, false, 'activa', 'vigente', false) RETURNING empr_id""",
                                   (EMPRESA_NUEVA, EMPRESA_NUEVA, CUIT_NUEVA, USUARIOS[-1][0])).fetchone()[0]
        ids = {}
        for email, nom, ape, nick, grupo, rol, rol_dnato in USUARIOS:
            u = c.execute("SELECT id FROM seg.users WHERE email = %s", (email,)).fetchone()
            if u:
                # El administrador de la 191 ya existía con su clave: no se la cambio.
                if nick != "agenteminero":
                    c.execute("UPDATE seg.users SET password = %s, role = %s, status = 'approved' WHERE id = %s",
                              (hash_dnato(clave), rol_dnato, u[0]))
                ids[nick] = u[0]
            else:
                ids[nick] = c.execute("""INSERT INTO seg.users (email, first_name, last_name, role, password,
                                            status, usernick, superusuario, cambiar_password)
                                         VALUES (%s,%s,%s,%s,%s,'approved',%s,false,false) RETURNING id""",
                                      (email, nom, ape, rol_dnato, hash_dnato(clave), nick)).fetchone()[0]
            c.execute('DELETE FROM seg.memberships_users WHERE email = %s', (email,))
            c.execute('INSERT INTO seg.memberships_users ("group", role, usuario_app, email) VALUES (%s,%s,%s,%s)',
                      (grupo, rol, nick, email))
        for grupo, rol, opciones in MENUES:
            for op in opciones:
                c.execute("""INSERT INTO seg.memberships_menues (modulo, opcion, "group", role, usuario_app)
                             SELECT 'CORE', %s, %s, %s, 'agentes-prueba'
                             WHERE NOT EXISTS (SELECT 1 FROM seg.memberships_menues
                                               WHERE opcion=%s AND "group"=%s AND role=%s AND eliminado=0)""",
                          (op, grupo, rol, op, grupo, rol))
    print(f"  {EMPRESA_NUEVA}: empr_id {empr_nueva}; {len(USUARIOS)} usuarios")
    sembrar_bonita()
    return ids, empr_nueva


def sembrar_bonita() -> None:
    base = env("BONITA_URL")
    jar = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    op.open(base + "loginservice", urllib.parse.urlencode(
        {"username": env("BONITA_ADMIN_USER"), "password": env("BONITA_ADMIN_PASSWORD"), "redirect": "false"}).encode())
    token = next(c.value for c in jar if c.name == "X-Bonita-API-Token")

    def api(metodo: str, ruta: str, cuerpo: dict | None = None):
        req = urllib.request.Request(base + ruta, method=metodo, headers={
            "X-Bonita-API-Token": token, "Content-Type": "application/json"},
            data=json.dumps(cuerpo).encode() if cuerpo is not None else None)
        with op.open(req) as r:
            t = r.read()
            return json.loads(t) if t else None

    nuevos = 0
    for _, nom, ape, nick, *_ in USUARIOS:
        hay = api("GET", "API/identity/user?p=0&c=10&f=userName%3D" + urllib.parse.quote(nick))
        if hay:
            continue
        # Dnato actúa en Bonita con la clave común de usuarios (BPM_USER_PASS).
        api("POST", "API/identity/user", {"userName": nick, "password": env("BONITA_USER_PASSWORD"),
                                          "password_confirm": env("BONITA_USER_PASSWORD"),
                                          "firstname": nom, "lastname": ape, "enabled": "true"})
        nuevos += 1
    print(f"  Bonita: {nuevos} usuarios nuevos, {len(USUARIOS) - nuevos} ya estaban")


def sembrar_dia_a_dia() -> None:
    paso("Datos del día a día de la 191 en DEV (fechas relativas a hoy)")
    with tools() as c:
        # Lotes: uno vence en 10 días y otro ya venció hace 3; el resto no vence.
        lotes = [r[0] for r in c.execute(
            "SELECT lote_id FROM alm.alm_lotes WHERE empr_id = %s ORDER BY lote_id", (EMPRESA_MINERA,))]
        fechas = [HOY + dt.timedelta(days=10), HOY - dt.timedelta(days=3)]
        for lote, f in zip(lotes, fechas + [dt.date(3000, 12, 31)] * len(lotes)):
            c.execute("UPDATE alm.alm_lotes SET fec_vencimiento = %s WHERE lote_id = %s", (f, lote))
    print(f"  lotes: {len(lotes)} (1 vence el {fechas[0]:%d/%m}, 1 venció el {fechas[1]:%d/%m})")


# ------------------------------------------------------------------ chequeo
def resumen(empr_nueva: int) -> None:
    paso("Punto de partida")
    with psycopg.connect(dsn_admin(env("AGENTE_DB_NAME"))) as c:
        ch = c.execute("SELECT vertical, count(*) FROM agente.chunk GROUP BY 1 ORDER BY 1").fetchall()
        ex = c.execute("SELECT count(*) FROM agente.experto").fetchone()[0]
        te = c.execute("SELECT count(*) FROM agente.tema").fetchone()[0]
    print("  conocimiento: " + ", ".join(f"{v}={n}" for v, n in ch))
    print(f"  temas de Faustino: {te} · expertos: {ex}")
    print(f"  empresas: 191 {GRUPO_MINERA} (minería) · {empr_nueva} {EMPRESA_NUEVA} (sin perfil)")
    print("  usuarios (clave: PRUEBA_CLAVE de ~/.agentes-prueba.env; el administrador de la 191 mantiene la suya):")
    for email, nom, ape, _, grupo, rol, _ in USUARIOS:
        print(f"    {email:40} {nom} {ape:8} {grupo:24} {rol}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--borrar", action="store_true", help="recrea la base de agentes de prueba desde cero")
    a = ap.parse_args()
    if a.borrar:
        recrear_base()
        cargar_conocimiento()
    ids, empr_nueva = sembrar_tools()
    sembrar_agentes(ids, empr_nueva)
    sembrar_dia_a_dia()
    resumen(empr_nueva)
    return 0


if __name__ == "__main__":
    sys.exit(main())
