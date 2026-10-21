#!/bin/sh
# =============================================================================
#  deploymcp.sh — despliegue del MCP de Trazalog (WSO2 Micro Integrator)
# =============================================================================
#
#  QUE HACE
#    Despliega una actualizacion del MCP de punta a punta, en UN comando:
#    actualiza el codigo desde git, arma el .car con las bases del ambiente,
#    lo verifica, respalda el que esta andando, lo reemplaza y reinicia el MI.
#
#    Es el equivalente de deploytools.sh para el MCP. La diferencia es que el
#    MCP no se despliega artefacto por artefacto: el MI consume UN .car, y ese
#    .car lleva adentro la IP, el puerto, la base y las credenciales del
#    ambiente. Por eso aca no hay nada que copiar a mano: los valores salen de
#    un .env por ambiente y el script los aplica sobre una COPIA del proyecto.
#
#    EL CHECKOUT NO SE TOCA NUNCA. `git status` queda limpio, y las
#    credenciales viven solo en el .env, que esta gitignoreado.
#
#  DONDE SE EJECUTA
#    En la VM del MCP, desde cualquier directorio. El script encuentra solo la
#    raiz del repo a partir de su propia ubicacion:
#
#      sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/master
#
#    $1  rama o tag a desplegar   (default: origin/master)
#    $2  .env a usar              (default: deploy/gcp/.env.car)
#
#    Es el MISMO comando en todos los ambientes, sin variantes: lo que cambia
#    de un ambiente a otro ya esta adentro del .env de ese servidor. El $2 esta
#    solo para el caso raro de tener que armar el .car para OTRO ambiente desde
#    esta maquina — ahi se le pasa la ruta de ese .env.
#
#  QUE MUESTRA
#    En pantalla, solo el avance y el resultado. TODO lo demas —la salida de
#    cada comando, el log de Maven, sus errores— va al log, que se informa al
#    terminar.
#
#  QUE NO HACE, A PROPOSITO
#    · No republica la API ni el MCP Server del APIM. Eso solo hace falta
#      cuando cambia el NUMERO DE OPERACIONES, no en una actualizacion comun.
#      El script lo detecta y lo avisa al final. Ver doc/mcp/republicar-mcp-server.md
#    · No toca apiconfig.xml ni el dataservices_url de bpmconf: son el MI
#      llamandose a si mismo (localhost:8290) y valen igual en todo ambiente.
#    · No toca resources/registry/conf/: esa carpeta es huerfana, no entra al
#      .car y editarla no produce ningun efecto.
#    · No hace rollback solo. Si algo falla deja el respaldo y te imprime el
#      comando exacto para volver atras.
#
#  VARIABLES DE ENTORNO (para casos raros, no hacen falta normalmente)
#    MI_HOME        ruta del Micro Integrator (default: autodeteccion)
#    SIN_PREGUNTAR  =1 no pide confirmacion (para correrlo desatendido)
#    SOLO_BUILD     =1 arma y verifica el .car pero NO lo despliega
#
#  @author rruiz
#  v1.0  equivalente de deploytools.sh para el MCP: un comando, cualquier ambiente
# =============================================================================

CAR="ToolsAPIProject_1.0.0.car"
PROY_REL="_backend/api/ToolsAPIProject/ToolsAPIProject"
API_MCP="src/main/wso2mi/artifacts/apis/toolsMCPAPI.xml"

# Las 13 variables que tiene que traer el .env. Si falta una, no se buildea:
# el MI arranca igual con un dato incompleto y la tool devuelve vacio, que es
# el sintoma mas dificil de diagnosticar.
VARS_ENV="PG_HOST PG_PORT PG_DB PG_USER PG_PASS \
          MY_HOST MY_PORT MY_DB MY_USER MY_PASS \
          BPM_URL BPM_USER BPM_PASS"

# ── Salida ───────────────────────────────────────────────────────────────────
# En pantalla va el avance; al log va todo. Con `>>LOG 2>&1` y no `2>&1 >>LOG`,
# que manda los errores a la pantalla en vez del log.

LOG=""
ERRORES=0
OPS_ANTES=""
OPS_AHORA=""
RESPALDO=""
DESPLEGADO=0

log()   { [ -n "$LOG" ] && printf '%s\n' "$*" >> "$LOG"; }
paso()  { printf '  %s\n' "$*"; log "--- $*"; }
ok()    { printf '     ok   %s\n' "$*"; log "    OK: $*"; }
aviso() { printf '     !    %s\n' "$*"; log "    AVISO: $*"; }
nota()  { printf '     ·    %s\n' "$*"; log "    NOTA: $*"; }
falla() { printf '     ERROR %s\n' "$*"; log "    ERROR: $*"; ERRORES=$((ERRORES + 1)); }

correr() {
    log "\$ $*"
    "$@" >> "$LOG" 2>&1
}

# El script necesita root para escribir en carbonapps/ y para systemctl. Si ya
# corre como root, `sudo` sobra; si no esta instalado, se avisa en el preflight.
SUDO=""
elegir_sudo() {
    if [ "$(id -u)" = "0" ]; then
        SUDO=""
    elif command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        SUDO=""
        aviso "no sos root y no hay sudo: el despliegue va a fallar al copiar el .car"
    fi
}

# ── 1. Entorno ───────────────────────────────────────────────────────────────

buscar_mi() {
    [ -n "$MI_HOME" ] && { echo "$MI_HOME"; return 0; }
    for base in /opt/wso2/wso2mi-* /usr/lib64/wso2/wso2mi/* /usr/lib/wso2/wso2mi/*; do
        [ -d "$base/repository/deployment/server/carbonapps" ] && { echo "$base"; return 0; }
    done
    return 1
}

preflight() {
    [ -d "$REPO/.git" ] || { falla "'$REPO' no es un repositorio git"; return 1; }
    [ -d "$PROY" ]      || { falla "no existe el proyecto Maven en $PROY"; return 1; }
    ok "repo en $REPO"

    for h in git mvn unzip python3; do
        command -v "$h" >/dev/null 2>&1 || { falla "falta '$h' en esta maquina"; return 1; }
    done

    [ -f "$ENVFILE" ] || {
        falla "no existe '$ENVFILE'"
        printf '           Crealo asi:\n'
        printf '             cp %s/deploy/gcp/.env.car.example %s\n' "$REPO" "$ENVFILE"
        printf '             chmod 600 %s\n' "$ENVFILE"
        printf '           Y completalo: es a donde va a apuntar el MCP de ESTE servidor.\n'
        return 1
    }

    PERMS=$(stat -c '%a' "$ENVFILE" 2>/dev/null)
    case "$PERMS" in
        600|400) ok "permisos del .env: $PERMS" ;;
        *) falla "el .env tiene permisos $PERMS y lleva credenciales en texto plano — corregilo con: chmod 600 $ENVFILE"
           return 1 ;;
    esac

    # El .env se LEE, no se ejecuta. Si se hiciera `. "$ENVFILE"`, una password
    # con " < > & $ o un espacio rompe el script con "Unterminated quoted string"
    # —o peor, ejecuta lo que diga—. Las passwords de produccion son dato ajeno:
    # no se puede asumir que sean shell-safe. Asi que lo parsea python y devuelve
    # asignaciones ya escapadas, que recien ahi el shell evalua.
    ASIGNA=$(python3 - "$ENVFILE" "$VARS_ENV" <<'PY_ENV'
import sys, shlex
ruta, requeridas = sys.argv[1], sys.argv[2].split()
valores, malas = {}, []
with open(ruta, encoding="utf-8") as f:
    for n, linea in enumerate(f, 1):
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        if "=" not in linea:
            malas.append("linea %d: no tiene la forma CLAVE=valor" % n)
            continue
        clave, valor = linea.split("=", 1)
        clave = clave.strip()
        valor = valor.rstrip()
        # Se aceptan los valores con o sin comillas: si estan, se sacan.
        if len(valor) >= 2 and valor[0] == valor[-1] and valor[0] in "'\"":
            valor = valor[1:-1]
        valores[clave] = valor
faltan = [v for v in requeridas if not valores.get(v)]
if malas or faltan:
    if malas:
        sys.stderr.write("ERROR_ENV " + "; ".join(malas) + "\n")
    if faltan:
        sys.stderr.write("ERROR_FALTAN " + " ".join(faltan) + "\n")
    sys.exit(1)
for v in requeridas:
    print("%s=%s" % (v, shlex.quote(valores[v])))
PY_ENV
    ) || {
        falla "el .env no se pudo leer — detalle arriba. Si una password lleva \" < > & o espacios, ponela entre comillas simples: PG_PASS='"'"'...'"'"'"
        return 1
    }
    eval "$ASIGNA"
    for v in $VARS_ENV; do eval "export $v"; done
    ok "las 13 variables del .env estan completas"

    if [ "${SOLO_BUILD:-}" = "1" ]; then
        nota "SOLO_BUILD=1: se arma y verifica el .car, no se despliega"
    else
        MI=$(buscar_mi) || {
            falla "no se encuentra el Micro Integrator. Pasalo con MI_HOME=/ruta/al/wso2mi-4.5.0"
            return 1
        }
        CARBONAPPS="$MI/repository/deployment/server/carbonapps"
        ok "Micro Integrator en $MI"
    fi
    return 0
}

# ── 2. Codigo ────────────────────────────────────────────────────────────────

actualizar_codigo() {
    # `fetch` + `reset --hard` en vez de `pull`: misma intencion, pero `pull`
    # intenta mergear y puede fallar sobre un arbol sucio o una rama divergida.
    ( cd "$REPO" || exit 1
      log "\$ git fetch --all --prune"; git fetch --all --prune >> "$LOG" 2>&1
      log "\$ git reset --hard $TAG";   git reset --hard "$TAG" >> "$LOG" 2>&1
    ) || { falla "no se pudo actualizar el codigo a $TAG"; return 1; }

    REVISION=$(cd "$REPO" && git rev-parse --short HEAD 2>/dev/null)
    ok "codigo en $TAG ($REVISION)"

    if [ -f "$REPO/.gitmodules" ]; then
        ( cd "$REPO" || exit 1
          log "\$ git submodule update --init"
          git submodule update --init >> "$LOG" 2>&1
        ) && ok "submodulos actualizados" || aviso "no se pudieron actualizar los submodulos (el .car no los usa)"
    fi
    return 0
}

# Cuenta las operaciones MCP de un .car descomprimido.
#
# NO alcanza con contar `uri-template="/mcp/` en todo el .car: toolsMANAPI
# declara 5 rutas que empiezan con /mcp/ pero cuelgan de su propio context
# (/tools/man), y no son operaciones del MCP — contarlas daba 30 donde hay 25.
# La cuenta buena es la del unico artefacto cuyo context es /tools/mcp, que es
# el que el APIM publica como MCP Server. Verificado contra la OpenAPI:
# doc/api/trazalog-operaciones.yaml declara 24 paths y 25 operaciones.
contar_ops() {
    for f in "$1"/*/*.xml; do
        [ -f "$f" ] || continue
        ctx=$(grep -o 'context="[^"]*"' "$f" 2>/dev/null | head -1 | sed 's/context="//;s/"$//')
        [ "$ctx" = "/tools/mcp" ] || continue
        grep -o 'uri-template="/mcp/' "$f" 2>/dev/null | wc -l | tr -d ' '
        return 0
    done
    echo ""
}

# ── 3. Respaldo ──────────────────────────────────────────────────────────────

respaldar_car() {
    if [ "${SOLO_BUILD:-}" = "1" ]; then
        nota "sin despliegue, no hay nada que respaldar"
        return 0
    fi
    if [ ! -f "$CARBONAPPS/$CAR" ]; then
        aviso "no hay un .car desplegado todavia: este es el primer despliegue"
        return 0
    fi
    RESPALDO="$HOME/$CAR.antes-de-$STAMP"
    correr $SUDO cp "$CARBONAPPS/$CAR" "$RESPALDO" || { falla "no se pudo respaldar el .car desplegado"; return 1; }
    correr $SUDO chown "$(id -un)" "$RESPALDO"
    ok "respaldo en $RESPALDO"

    # A donde apunta el que esta andando, y cuantas operaciones MCP expone. Las
    # dos cosas se comparan despues contra el nuevo.
    rm -rf "$BUILD/car-antes"; mkdir -p "$BUILD/car-antes"
    if unzip -qo "$RESPALDO" -d "$BUILD/car-antes" >> "$LOG" 2>&1; then
        log "--- a donde apunta el .car que estaba desplegado:"
        grep -rh "jdbc:" "$BUILD/car-antes" 2>/dev/null | sed 's/^[[:space:]]*//' >> "$LOG"
        OPS_ANTES=$(contar_ops "$BUILD/car-antes")
        [ -n "$OPS_ANTES" ] && nota "el .car desplegado expone $OPS_ANTES operaciones MCP"
    fi
    return 0
}

# ── 4. Build ─────────────────────────────────────────────────────────────────

# Reemplazo textual quirurgico sobre la COPIA: cambia SOLO el contenido de los
# tags pedidos y deja el resto del archivo byte por byte igual.
#
# Por que no se usa un parser DOM: estos tres archivos vienen de produccion y
# tienen rarezas que un round-trip por minidom "corrige" sin necesidad —
# bpmconf.xml arranca con la declaracion XML COMENTADA y asi funciona hoy, y
# los dos datasources no tienen declaracion y usan indentacion distinta entre
# si. Reescribirlos cambia archivos que hoy andan en produccion.
SUSTITUIR=$(cat <<'PY_EOF'
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
    # Que el texto no cambie es un resultado valido: pasa cuando el .env dice lo
    # mismo que el checkout. La red de seguridad es que el tag exista, no el diff.
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(texto)
    md.parse(ruta)          # si no quedo XML valido, revienta aca y no se buildea

def valor_de(ruta, tag):
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
# los ambientes. Viene del archivo ya escapado (&amp;), asi que no se lo vuelve
# a escapar.
ruta = os.path.join(wso2, "artifacts/data-sources/AssetPlannerDataSource.xml")
params = valor_de(ruta, "url").split("?", 1)
nueva = escape("jdbc:mysql://%s:%s/%s" % (e["MY_HOST"], e["MY_PORT"], e["MY_DB"]))
if len(params) > 1:
    nueva += "?" + params[1]
with open(ruta, encoding="utf-8") as f:
    texto = f.read()
texto = re.sub(r"(<url>)(.*?)(</url>)", lambda m: m.group(1) + nueva + m.group(3),
               texto, count=1, flags=re.S)
with open(ruta, "w", encoding="utf-8") as f:
    f.write(texto)
reemplazar(ruta, [("username", e["MY_USER"]), ("password", e["MY_PASS"])])
print("    AssetPlannerDataSource.xml -> %s:%s/%s" % (e["MY_HOST"], e["MY_PORT"], e["MY_DB"]))

# -- bpmconf: Bonita. dataservices_url NO se toca --
ruta = os.path.join(wso2, "resources/conf/tools/bpmconf.xml")
reemplazar(ruta, [
    ("bpm_url", e["BPM_URL"]),
    ("usuario", e["BPM_USER"]),
    ("password", e["BPM_PASS"]),
])
print("    bpmconf.xml                -> %s" % e["BPM_URL"])
PY_EOF
)

buildear() {
    mkdir -p "$BUILD" || { falla "no se pudo crear $BUILD"; return 1; }
    correr cp -r "$PROY" "$BUILD/ToolsAPIProject" || { falla "no se pudo copiar el proyecto"; return 1; }
    rm -rf "$BUILD/ToolsAPIProject/target"
    ok "proyecto copiado a la carpeta de build — el checkout no se toca"

    if ! printf '%s' "$SUSTITUIR" | python3 - "$BUILD/ToolsAPIProject/src/main/wso2mi" 2>> "$LOG"; then
        falla "no se pudieron reescribir los datasources — ver el log"
        return 1
    fi
    ok "datasources y bpmconf de la copia reescritos con los valores del .env"

    printf '     ..   mvn clean install (tarda un rato)\n'
    if ! ( cd "$BUILD/ToolsAPIProject" && mvn clean install ) >> "$LOG" 2>&1; then
        falla "el build de Maven fallo. Ultimas 30 lineas:"
        tail -30 "$LOG"
        return 1
    fi
    NUEVO=$(ls -1 "$BUILD/ToolsAPIProject/target/"*.car 2>/dev/null | head -1)
    [ -n "$NUEVO" ] || { falla "el build no dejo ningun .car en target/"; return 1; }
    ok "build OK — $(basename "$NUEVO")"
    return 0
}

# ── 5. Verificacion del .car, ANTES de desplegarlo ───────────────────────────

verificar_car() {
    DESC="$BUILD/car-nuevo"
    rm -rf "$DESC"; mkdir -p "$DESC"
    correr unzip -qo "$NUEVO" -d "$DESC" || { falla "no se pudo abrir el .car que se acaba de armar"; return 1; }

    contiene() {
        if grep -rhq -- "$1" "$DESC" 2>/dev/null; then
            ok "apunta a $1"
        else
            falla "el .car NO contiene '$1'"
        fi
    }
    contiene "jdbc:postgresql://$PG_HOST:$PG_PORT/$PG_DB"
    contiene "jdbc:mysql://$MY_HOST:$MY_PORT/$MY_DB"
    contiene "$BPM_URL"

    # El MI llamandose a si mismo tiene que seguir ahi.
    if grep -rhq -- "localhost:8290" "$DESC" 2>/dev/null; then
        ok "el MI sigue apuntandose a si mismo (localhost:8290)"
    else
        falla "se perdio el localhost:8290 de apiconfig/bpmconf"
    fi

    # Que no haya quedado ninguna IP de otro ambiente. Se compara contra lo que
    # dicen los datasources del checkout, no contra una IP escrita aca.
    for ip in $(grep -rhoE 'jdbc:(postgresql|mysql)://[0-9.]+' \
                  "$PROY/src/main/wso2mi/artifacts/data-sources/" 2>/dev/null |
                grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u); do
        [ "$ip" = "$PG_HOST" ] && continue
        [ "$ip" = "$MY_HOST" ] && continue
        if grep -rhq -- "$ip" "$DESC" 2>/dev/null; then
            falla "quedo adentro del .car una IP de otro ambiente: $ip"
        else
            ok "no quedo rastro de $ip"
        fi
    done

    OPS_AHORA=$(contar_ops "$DESC")
    if [ -n "$OPS_AHORA" ]; then
        ok "el .car nuevo expone $OPS_AHORA operaciones MCP"
    else
        falla "no se encontro en el .car el API con context=/tools/mcp"
    fi

    [ "$ERRORES" -eq 0 ] || return 1
    return 0
}

# ── 6. Despliegue ────────────────────────────────────────────────────────────

# La ruta con la que se comprueba que el MI levanto. Sale del propio artefacto
# (context + primer uri-template), asi que no queda hardcodeada en el script.
ruta_de_prueba() {
    xml="$REPO/$PROY_REL/$API_MCP"
    [ -f "$xml" ] || return 1
    ctx=$(grep -oE 'context="[^"]*"' "$xml" | head -1 | sed -E 's/context="([^"]*)"/\1/')
    tpl=$(grep -oE 'uri-template="/mcp/[^"]*"' "$xml" | head -1 | sed -E 's/uri-template="([^"]*)"/\1/')
    [ -n "$ctx" ] && [ -n "$tpl" ] || return 1
    echo "http://localhost:8290${ctx}${tpl}"
}

desplegar() {
    correr $SUDO cp "$NUEVO" "$CARBONAPPS/$CAR" || { falla "no se pudo copiar el .car a carbonapps/"; return 1; }
    DESPLEGADO=1
    ok "$CAR copiado a carbonapps/"

    correr $SUDO systemctl restart wso2mi || { falla "fallo el restart de wso2mi"; return 1; }
    printf '     ..   esperando que el MI levante\n'

    URL=$(ruta_de_prueba)
    i=0
    while [ "$i" -lt 60 ]; do
        sleep 3
        i=$((i + 1))
        if [ -n "$URL" ]; then
            codigo=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL" 2>/dev/null)
            case "$codigo" in
                000|404) continue ;;
                *) ok "el MI responde en $(echo "$URL" | sed 's|http://localhost:8290||') (HTTP $codigo)"
                   return 0 ;;
            esac
        else
            if $SUDO journalctl -u wso2mi --since "-10 min" 2>/dev/null | grep -q "Successfully Deployed Carbon Application"; then
                ok "el MI desplego el Carbon Application"
                return 0
            fi
        fi
    done
    falla "el MI no respondio despues de 3 minutos — revisar: journalctl -u wso2mi -n 80"
    return 1
}

# ── 7. Verificacion de lo desplegado ─────────────────────────────────────────

verificar_desplegado() {
    inst="$BUILD/car-instalado"
    rm -rf "$inst"; mkdir -p "$inst"
    if ! $SUDO unzip -qo "$CARBONAPPS/$CAR" -d "$inst" >> "$LOG" 2>&1; then
        aviso "no se pudo abrir el .car instalado para verificarlo"
        return 0
    fi
    if grep -rhq -- "jdbc:postgresql://$PG_HOST:$PG_PORT/$PG_DB" "$inst" 2>/dev/null; then
        ok "el .car instalado apunta a $PG_HOST:$PG_PORT/$PG_DB"
    else
        falla "el .car instalado NO apunta a donde dice el .env"
    fi

    errs=$($SUDO journalctl -u wso2mi --since "-10 min" 2>/dev/null |
             grep -icE "ERROR.*(datasource|DataService)")
    if [ "${errs:-0}" -gt 0 ]; then
        $SUDO journalctl -u wso2mi --since "-10 min" 2>/dev/null |
            grep -iE "ERROR.*(datasource|DataService)" | head -10 >> "$LOG"
        falla "$errs errores de datasource en el log del MI — estan en el log, y en: journalctl -u wso2mi -n 80"
    else
        ok "sin errores de datasource en el log del MI"
    fi
    return 0
}

# ── Programa ─────────────────────────────────────────────────────────────────

main() {
    AQUI=$(cd "$(dirname "$0")" && pwd)
    REPO=$(cd "$AQUI/../.." && pwd)
    PROY="$REPO/$PROY_REL"

    TAG="${1:-origin/master}"
    STAMP=$(date +%Y%m%d-%H%M%S)
    BUILD="$HOME/.cache/traz-mcp-build/$STAMP"
    LOG="$HOME/deploymcp-$STAMP.log"

    # Un .env por servidor, no uno por "ambiente": el servidor ES el ambiente.
    # El $2 se acepta como ruta —tal cual, o relativa a la raiz del repo— para
    # el caso de armar el .car para otro ambiente desde esta maquina.
    if [ -z "$2" ]; then
        ENVFILE="$REPO/deploy/gcp/.env.car"
    elif [ -f "$2" ]; then
        ENVFILE="$2"
    else
        ENVFILE="$REPO/$2"
    fi

    mkdir -p "$(dirname "$LOG")" 2>/dev/null
    {
        echo "==================================================================="
        echo " DESPLIEGUE MCP $(date '+%Y-%m-%d %H:%M:%S')  tag=$TAG  env=$ENVFILE"
        echo "==================================================================="
    } >> "$LOG" 2>&1

    echo "=============== TRAZALOG · despliegue del MCP ==============="
    echo "  .env     : $ENVFILE"
    echo "  rama/tag : $TAG"
    echo ""

    elegir_sudo
    paso "1/7  verificando el entorno"
    preflight || { resumen; return 1; }

    # Lo ultimo que se ve antes de empezar es a donde va a apuntar el MCP. Es el
    # dato que, equivocado, no falla: las tools responden 200 con datos del
    # ambiente de al lado.
    echo ""
    echo "  Este despliegue va a dejar el MCP leyendo:"
    printf '    PostgreSQL  %s:%s/%s  (usuario %s)\n' "$PG_HOST" "$PG_PORT" "$PG_DB" "$PG_USER"
    printf '    MariaDB     %s:%s/%s  (usuario %s)\n' "$MY_HOST" "$MY_PORT" "$MY_DB" "$MY_USER"
    printf '    Bonita      %s  (usuario %s)\n' "$BPM_URL" "$BPM_USER"
    echo ""
    if [ "${SIN_PREGUNTAR:-}" != "1" ]; then
        printf '  ¿Es correcto? [s/N] '
        read -r RTA
        case "$RTA" in
            s|S|si|SI|y|Y) ;;
            *) echo "  cancelado — no se toco nada"; return 1 ;;
        esac
    fi
    echo ""

    paso "2/7  actualizando codigo"
    actualizar_codigo || { resumen; return 1; }

    paso "3/7  respaldando el .car desplegado"
    respaldar_car || { resumen; return 1; }

    paso "4/7  armando el .car"
    buildear || { resumen; return 1; }

    paso "5/7  verificando el .car antes de desplegarlo"
    verificar_car || { resumen; return 1; }

    if [ "${SOLO_BUILD:-}" = "1" ]; then
        paso "6/7  despliegue omitido (SOLO_BUILD=1)"
        paso "7/7  verificacion omitida (SOLO_BUILD=1)"
        resumen
        return $?
    fi

    paso "6/7  desplegando y reiniciando el MI"
    desplegar || { resumen; return 1; }

    paso "7/7  verificando lo desplegado"
    verificar_desplegado

    resumen
}

resumen() {
    echo ""
    echo "----------------------------------------------------"
    if [ "$ERRORES" -eq 0 ]; then
        if [ "${SOLO_BUILD:-}" = "1" ]; then
            echo "  CAR OK — no desplegado (SOLO_BUILD=1)"
            echo "  archivo                : $NUEVO"
        else
            echo "  DESPLIEGUE OK"
        fi
    else
        echo "  DESPLIEGUE CON $ERRORES ERROR(ES) — revisar el log"
    fi
    [ -n "$REVISION" ]  && echo "  revision               : $REVISION ($TAG)"
    echo "  .env                   : $ENVFILE"
    [ -n "$OPS_AHORA" ] && echo "  operaciones MCP        : $OPS_AHORA"
    [ -n "$RESPALDO" ]  && echo "  respaldo del anterior  : $RESPALDO"
    echo "  log completo           : $LOG"
    echo "----------------------------------------------------"

    # Lo unico que este script no puede hacer solo. Se avisa solo cuando cambio
    # el numero de operaciones, que es exactamente cuando hace falta.
    if [ -n "$OPS_ANTES" ] && [ -n "$OPS_AHORA" ] && [ "$OPS_ANTES" != "$OPS_AHORA" ]; then
        echo ""
        echo "  !! CAMBIO EL NUMERO DE OPERACIONES MCP: $OPS_ANTES -> $OPS_AHORA"
        echo "     Falta el paso del APIM, que no se puede automatizar:"
        echo "     subir la OpenAPI y recrear el MCP Server."
        echo "     Ver doc/mcp/republicar-mcp-server.md"
    fi

    if [ "$ERRORES" -ne 0 ] && [ "$DESPLEGADO" = "1" ] && [ -n "$RESPALDO" ]; then
        echo ""
        echo "  Para volver atras:"
        echo ""
        echo "    $SUDO cp $RESPALDO \\"
        echo "      $CARBONAPPS/$CAR && \\"
        echo "    $SUDO systemctl restart wso2mi"
    fi
    echo ""

    log "RESULTADO: $ERRORES errores, $OPS_AHORA operaciones MCP"
    [ "$ERRORES" -eq 0 ] || return 1
    return 0
}

# La llamada va al final y todo lo de arriba son funciones a proposito: `sh` lee
# el script de a pedazos mientras lo ejecuta, y este script hace `git reset --hard`
# sobre el repo donde el propio script vive. Definiendo todo como funciones, el
# archivo entero queda parseado antes de que se ejecute la primera linea.
main "$@"
