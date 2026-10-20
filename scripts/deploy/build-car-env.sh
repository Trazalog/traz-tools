#!/bin/bash
# =============================================================================
#  build-car-env.sh — construye el .car de ToolsAPIProject con las IPs y las
#                     credenciales de un archivo .env, SIN tocar nada de git
# =============================================================================
#
#  POR QUE EXISTE
#    El .car no es agnostico del ambiente: empaqueta los datasources y el
#    bpmconf tal como estan commiteados, apuntando a desarrollo. Hasta ahora,
#    para desplegar en produccion habia que editar a mano tres archivos
#    versionados y dejarlos modificados para siempre en el working tree —con
#    las credenciales de produccion en texto plano adentro del checkout—.
#
#    Este script hace lo mismo pero sobre una COPIA del proyecto: el checkout
#    queda intacto (`git status` limpio) y las credenciales viven solo en el
#    .env, que esta gitignoreado.
#
#  DONDE SE EJECUTA
#    En la VM del MCP, desde cualquier lado. El script encuentra solo la raiz
#    del repo a partir de su propia ubicacion:
#
#      bash ~/git/traz-tools/scripts/deploy/build-car-env.sh deploy/gcp/.env.car.demo
#      bash ~/git/traz-tools/scripts/deploy/build-car-env.sh deploy/gcp/.env.car.prod
#
#    $1  archivo .env a usar   (default: <repo>/deploy/gcp/.env.car)
#
#    Un archivo por ambiente, los dos gitignoreados. Es el MISMO comando para
#    desplegar en el DEMO, para repuntar a produccion y para devolver un clon
#    a desarrollo: lo unico que cambia es que .env se le pasa.
#
#  QUE NO HACE, A PROPOSITO
#    · No copia el .car a carbonapps/ ni reinicia el MI. El despliegue lo
#      hace una persona, mirando la verificacion. Ver el apendice A del
#      runbook (doc/v3/runbook-demo-a-produccion.md).
#    · No toca apiconfig.xml ni el dataservices_url de bpmconf: son el MI
#      llamandose a si mismo (localhost:8290) y valen igual en todo ambiente.
#    · No toca resources/registry/conf/: esa carpeta es huerfana, no entra al
#      .car.
#
#  @author rruiz
#  v1.0
# =============================================================================

set -euo pipefail

# ── Ubicacion ────────────────────────────────────────────────────────────────

AQUI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$AQUI/../.." && pwd)
PROY="$REPO/_backend/api/ToolsAPIProject/ToolsAPIProject"
ENVFILE="${1:-$REPO/deploy/gcp/.env.car}"
STAMP=$(date +%Y%m%d-%H%M%S)
BUILD="${BUILD_DIR:-$HOME/.cache/traz-car-build}/$STAMP"
SALIDA="${SALIDA:-$HOME}"

# ── Salida en pantalla ───────────────────────────────────────────────────────

ok()    { printf '  \033[32m[ok]\033[0m   %s\n' "$*"; }
info()  { printf '  \033[36m[..]\033[0m   %s\n' "$*"; }
falla() { printf '  \033[31m[MAL]\033[0m  %s\n' "$*" >&2; }
muere() { falla "$*"; exit 1; }

echo "=============== TRAZALOG · build del .car por ambiente ==============="
echo "  repo    : $REPO"
echo "  .env    : $ENVFILE"
echo "  build   : $BUILD"
echo "======================================================================"
echo ""

# ── 1. El .env ───────────────────────────────────────────────────────────────

[ -f "$ENVFILE" ] || muere "no existe '$ENVFILE'. Copiá deploy/gcp/.env.car.example y completalo."

PERMS=$(stat -c '%a' "$ENVFILE")
case "$PERMS" in
    600|400) ok "permisos del .env: $PERMS" ;;
    *) falla "el .env tiene permisos $PERMS y lleva credenciales en texto plano."
       muere "corregilo con:  chmod 600 $ENVFILE" ;;
esac

set -a
# shellcheck disable=SC1090
. "$ENVFILE"
set +a

VARS="PG_HOST PG_PORT PG_DB PG_USER PG_PASS \
      MY_HOST MY_PORT MY_DB MY_USER MY_PASS \
      BPM_URL BPM_USER BPM_PASS"
FALTAN=""
for v in $VARS; do
    [ -n "${!v:-}" ] || FALTAN="$FALTAN $v"
done
[ -z "$FALTAN" ] || muere "faltan estas variables en el .env:$FALTAN"
ok "las 13 variables estan completas"

echo ""
echo "  A donde va a apuntar este .car:"
printf '    PostgreSQL  %s:%s/%s  (usuario %s)\n' "$PG_HOST" "$PG_PORT" "$PG_DB" "$PG_USER"
printf '    MariaDB     %s:%s/%s  (usuario %s)\n' "$MY_HOST" "$MY_PORT" "$MY_DB" "$MY_USER"
printf '    Bonita      %s  (usuario %s)\n' "$BPM_URL" "$BPM_USER"
echo ""
if [ "${SIN_PREGUNTAR:-}" != "1" ]; then
    read -r -p "  ¿Es correcto? [s/N] " RTA
    case "$RTA" in s|S|si|SI|y|Y) ;; *) muere "cancelado" ;; esac
    echo ""
fi

# ── 2. Copia del proyecto ────────────────────────────────────────────────────

[ -d "$PROY" ] || muere "no existe el proyecto Maven en $PROY"
info "copiando el proyecto a la carpeta de build"
mkdir -p "$BUILD"
cp -r "$PROY" "$BUILD/ToolsAPIProject"
rm -rf "$BUILD/ToolsAPIProject/target"
ok "copia hecha — el checkout no se toca"

# ── 3. Sustitucion ───────────────────────────────────────────────────────────

info "reescribiendo los datasources y el bpmconf de la copia"
WSO2="$BUILD/ToolsAPIProject/src/main/wso2mi"
python3 - "$WSO2" <<'PY_EOF'
# Reemplazo textual quirurgico: cambia SOLO el contenido de los tags que se
# piden y deja el resto del archivo byte por byte igual.
#
# Por que no se usa un parser DOM: estos tres archivos vienen de produccion y
# tienen rarezas que un round-trip por minidom "corrige" y no deberia tocar
#   · bpmconf.xml arranca con la declaracion XML COMENTADA
#     (<!--?xml version="1.0" encoding="UTF-8"?-->) y asi funciona hoy
#   · los dos datasources no tienen declaracion XML, y usan indentacion
#     distinta entre si (2 y 4 espacios)
# Reescribirlos cambia archivos que hoy andan en produccion, sin necesidad.
import sys, os, re
from xml.sax.saxutils import escape
import xml.dom.minidom as md

wso2 = sys.argv[1]
e = os.environ

def reemplazar(ruta, cambios):
    with open(ruta, encoding="utf-8") as f:
        texto = f.read()
    for tag, valor in cambios:
        patron = re.compile(r"(<%s>)(.*?)(</%s>)" % (tag, tag), re.S)
        if not patron.search(texto):
            sys.exit("ERROR: no se encontro <%s> en %s" % (tag, os.path.basename(ruta)))
        texto = patron.sub(
            lambda m: m.group(1) + escape(valor) + m.group(3), texto, count=1)
    # Que el texto no cambie es un resultado valido: pasa cuando el .env dice
    # lo mismo que el checkout, o sea al buildear para desarrollo. La red de
    # seguridad es el chequeo de arriba (que el tag exista), no el diff.
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(texto)
    md.parse(ruta)          # si no es XML valido, revienta aca y no se buildea

def url_actual(ruta, tag="url"):
    with open(ruta, encoding="utf-8") as f:
        m = re.search(r"<%s>(.*?)</%s>" % (tag, tag), f.read(), re.S)
    return m.group(1) if m else ""

# -- ToolsDataSource: PostgreSQL --
ruta = os.path.join(wso2, "artifacts/data-sources/ToolsDataSource.xml")
reemplazar(ruta, [
    ("url", "jdbc:postgresql://%s:%s/%s" % (e["PG_HOST"], e["PG_PORT"], e["PG_DB"])),
    ("username", e["PG_USER"]),
    ("password", e["PG_PASS"]),
])
print("    ToolsDataSource.xml        -> %s:%s/%s" % (e["PG_HOST"], e["PG_PORT"], e["PG_DB"]))

# -- AssetPlannerDataSource: MySQL/MariaDB --
# El query string (?useSSL=false&...) se conserva tal cual: es igual en todos
# los ambientes, y el driver com.mysql.cj.jdbc.Driver tampoco cambia.
ruta = os.path.join(wso2, "artifacts/data-sources/AssetPlannerDataSource.xml")
viejo = url_actual(ruta)
params = viejo.split("?", 1)[1] if "?" in viejo else ""
nueva = "jdbc:mysql://%s:%s/%s" % (e["MY_HOST"], e["MY_PORT"], e["MY_DB"])
if params:
    nueva += "?" + params
# params viene del archivo ya escapado (&amp;); escape() lo volveria a escapar
nueva_esc = escape("jdbc:mysql://%s:%s/%s" % (e["MY_HOST"], e["MY_PORT"], e["MY_DB"]))
if params:
    nueva_esc += "?" + params
with open(ruta, encoding="utf-8") as f:
    texto = f.read()
texto = re.sub(r"(<url>)(.*?)(</url>)", lambda m: m.group(1) + nueva_esc + m.group(3),
               texto, count=1, flags=re.S)
with open(ruta, "w", encoding="utf-8") as f:
    f.write(texto)
reemplazar(ruta, [("username", e["MY_USER"]), ("password", e["MY_PASS"])])
print("    AssetPlannerDataSource.xml -> %s:%s/%s" % (e["MY_HOST"], e["MY_PORT"], e["MY_DB"]))

# -- bpmconf: Bonita --
# dataservices_url NO se toca: es el MI llamandose a si mismo (localhost:8290).
ruta = os.path.join(wso2, "resources/conf/tools/bpmconf.xml")
reemplazar(ruta, [
    ("bpm_url", e["BPM_URL"]),
    ("usuario", e["BPM_USER"]),
    ("password", e["BPM_PASS"]),
])
print("    bpmconf.xml                -> %s" % e["BPM_URL"])
PY_EOF
ok "los tres archivos de la copia quedaron reescritos"

# ── 4. Build ─────────────────────────────────────────────────────────────────

echo ""
info "buildeando (mvn clean install) — esto tarda un rato"
LOG="$BUILD/mvn.log"
if ! (cd "$BUILD/ToolsAPIProject" && mvn clean install) > "$LOG" 2>&1; then
    falla "el build fallo. Las ultimas 30 lineas:"
    tail -30 "$LOG" >&2
    muere "log completo en $LOG"
fi
CAR=$(ls -1 "$BUILD/ToolsAPIProject/target/"*.car 2>/dev/null | head -1)
[ -n "$CAR" ] || muere "el build no dejo ningun .car en target/ (log: $LOG)"
ok "build OK — $(basename "$CAR")"

# ── 5. Verificacion del .car ─────────────────────────────────────────────────

echo ""
info "verificando el contenido del .car"
DESC="$BUILD/car-descomprimido"
mkdir -p "$DESC"
unzip -q -o "$CAR" -d "$DESC"

esperar() {
    if grep -rhq -- "$1" "$DESC"; then
        ok "contiene: $1"
    else
        falla "NO contiene: $1"
        return 1
    fi
}

MAL=0
esperar "jdbc:postgresql://$PG_HOST:$PG_PORT/$PG_DB" || MAL=1
esperar "jdbc:mysql://$MY_HOST:$MY_PORT/$MY_DB"      || MAL=1
esperar "$BPM_URL"                                    || MAL=1

# Que no haya quedado nada del ambiente anterior. Se compara contra lo que
# dicen los archivos del checkout, no contra una IP hardcodeada aca.
VIEJAS=$(grep -rhoE 'jdbc:(postgresql|mysql)://[0-9.]+' \
           "$PROY/src/main/wso2mi/artifacts/data-sources/" \
         | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u)
for ip in $VIEJAS; do
    [ "$ip" = "$PG_HOST" ] && continue
    [ "$ip" = "$MY_HOST" ] && continue
    if grep -rhq -- "$ip" "$DESC"; then
        falla "quedo la IP del checkout adentro del .car: $ip"
        MAL=1
    else
        ok "no quedo rastro de $ip"
    fi
done

# El MI llamandose a si mismo tiene que seguir ahi.
esperar "localhost:8290" || MAL=1

echo ""
if [ "$MAL" -ne 0 ]; then
    falla "CAR MAL — NO desplegar. Revisá el .env y volvé a correr."
    echo "  El .car sospechoso quedo en: $CAR"
    exit 1
fi

# ── 6. Entrega ───────────────────────────────────────────────────────────────

DESTINO="$SALIDA/$(basename "${CAR%.car}")-$STAMP.car"
cp "$CAR" "$DESTINO"
chmod 600 "$DESTINO"

echo "=============== CAR OK ==============="
echo ""
echo "  Apunta a donde dice el .env, y no quedo nada del ambiente anterior:"
echo ""
printf '    PostgreSQL  %s:%s/%s\n' "$PG_HOST" "$PG_PORT" "$PG_DB"
printf '    MariaDB     %s:%s/%s\n' "$MY_HOST" "$MY_PORT" "$MY_DB"
printf '    Bonita      %s\n'       "$BPM_URL"
echo ""
echo "  Archivo : $DESTINO"
echo "  Build   : $BUILD   (borralo cuando no lo necesites: lleva el .env expandido)"
echo ""
echo "  Para desplegarlo (apendice A.3 del runbook):"
echo ""
echo "    sudo cp \"$DESTINO\" \\"
echo "      /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car && \\"
echo "    sudo systemctl restart wso2mi"
echo ""
echo "  Antes, guardá el que esta andando:"
echo ""
echo "    sudo cp /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car \\"
echo "      ~/ToolsAPIProject_1.0.0.car.antes-de-$STAMP"
echo ""
