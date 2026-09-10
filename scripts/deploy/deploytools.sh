#!/bin/sh
# =============================================================================
#  deploytools.sh — despliegue de Trazalog Tools
# =============================================================================
#
#  QUE HACE
#    Actualiza el codigo desde git y despliega en WSO2 los DataServices y los
#    artefactos Synapse (APIs, sequences, templates, local-entries).
#
#    Todo sale de UNA sola copia, la del proyecto Maven:
#      _backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/
#
#    Sirve tambien para productos que NO tienen backend WSO2 —traz-comp-dnato es
#    todo PHP—: en ese caso avisa y despliega solo el codigo, sin marcar error.
#
#  DONDE SE EJECUTA
#    En el servidor, parado en el directorio que contiene al producto — el
#    htdocs de Apache, por ejemplo /var/www/html:
#
#      cd /var/www/html
#      sh traz-tools/scripts/deploy/deploytools.sh origin/develop traz-tools
#
#    $1  rama o tag a desplegar   (default: origin/master)
#    $2  producto                 (default: traz-tools)
#
#  QUE MUESTRA
#    En pantalla, solo el avance y el resultado. TODO lo demas —la salida de
#    cada comando, sus errores— va al log, que se informa al terminar.
#
#  QUE NO HACE, A PROPOSITO
#    · No despliega `data-sources/`: esos XML llevan la IP y las credenciales de
#      la base embebidas. Desplegarlos automaticamente repuntaria el ambiente a
#      otra base. Van a mano.
#    · No despliega el registry. Va a mano, por decision del PM.
#    · No borra artefactos viejos del servidor: copia y pisa. Ver "MEJORAS
#      PROPUESTAS" al pie.
#
#  @author rruiz
#  v3.2  cero artefactos desplegados es ERROR, no exito silencioso
#  v3.1  copia unica de artefactos: todo sale del proyecto Maven
#  v3.0  APIs y artefactos Synapse, salida limpia, log completo, verificaciones
#  v2.0  agregador de deploy de dss, deteccion de distribucion y mejoras varias
# =============================================================================

WSO2VER="6.5.0"

# Orden de despliegue de los artefactos Synapse. NO es alfabetico y no da igual:
# si una API referencia una sequence que todavia no esta desplegada, el deploy de
# la API falla y queda fuera del runtime. Las dependencias van primero.
ARTEFACTOS_ORDEN="local-entries templates sequences apis"

# origen (en el proyecto Maven)     ->  destino (bajo synapse-configs/default)
destino_de() {
    case "$1" in
        local-entries) echo "local-entries" ;;
        templates)     echo "templates" ;;
        sequences)     echo "sequences" ;;
        apis)          echo "api" ;;          # el server lo llama `api`, en singular
        *)             echo "" ;;
    esac
}

# ── Salida ───────────────────────────────────────────────────────────────────
# En pantalla va el avance; al log va todo. Con `>>LOG 2>&1` y no `2>&1 >>LOG`,
# que es lo que tenia la v2 y mandaba los errores a la pantalla en vez del log.

LOG=""
ERRORES=0
DESPLEGADOS=0
TOTAL_SYN=0

log()   { [ -n "$LOG" ] && printf '%s\n' "$*" >> "$LOG"; }
paso()  { printf '  %s\n' "$*"; log "--- $*"; }
ok()    { printf '     ok   %s\n' "$*"; log "    OK: $*"; }
aviso() { printf '     !    %s\n' "$*"; log "    AVISO: $*"; }
# Para lo que es asi por diseno y sale en todos los despliegues. Va con marca neutra
# a proposito: si se usa `!` para algo invariante, se termina ignorando los `!` de verdad.
nota()  { printf '     ·    %s\n' "$*"; log "    NOTA: $*"; }
falla() { printf '     ERROR %s\n' "$*"; log "    ERROR: $*"; ERRORES=$((ERRORES + 1)); }

# Ejecuta un comando mandando toda su salida al log. Devuelve su codigo.
correr() {
    log "\$ $*"
    "$@" >> "$LOG" 2>&1
}

# ── Verificaciones previas ───────────────────────────────────────────────────

buscar_wso2() {
    for base in "/usr/lib64/wso2/wso2ei/$WSO2VER" "/usr/lib/wso2/wso2ei/$WSO2VER"; do
        [ -d "$base" ] && { echo "$base"; return 0; }
    done
    return 1
}

preflight() {
    [ -d "$PRODUCTO" ] || { falla "no existe el directorio '$PRODUCTO' — ¿estas parado en el htdocs?"; return 1; }
    [ -d "$PRODUCTO/.git" ] || { falla "'$PRODUCTO' no es un repositorio git"; return 1; }

    WSO2HOME=$(buscar_wso2) || {
        falla "no se encuentra WSO2 $WSO2VER ni en /usr/lib64 ni en /usr/lib"
        return 1
    }
    WSO2DSS="$WSO2HOME/repository/deployment/server/dataservices"
    WSO2SYN="$WSO2HOME/repository/deployment/server/synapse-configs/default"
    ARTEFACTOS="$PRODUCTO/_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts"
    ok "WSO2 $WSO2VER en $WSO2HOME"
    return 0
}

# ── Backup de la configuracion del producto ──────────────────────────────────

respaldar_config() {
    mkdir -p "bk/$PRODUCTO"
    for f in application/config/database.php application/config/config.php \
             application/config/constants.php .htaccess manifest.json; do
        [ -f "$PRODUCTO/$f" ] && correr cp "$PRODUCTO/$f" "bk/$PRODUCTO/"
    done
    for sw in "$PRODUCTO"/sw*.js; do
        [ -f "$sw" ] && correr cp "$sw" "bk/$PRODUCTO/"
    done
    ok "configuracion respaldada en bk/$PRODUCTO/"
}

restaurar_config() {
    for f in database.php config.php constants.php; do
        [ -f "bk/$PRODUCTO/$f" ] && correr cp "bk/$PRODUCTO/$f" "$PRODUCTO/application/config/"
    done
    [ -f "bk/$PRODUCTO/.htaccess" ]     && correr cp "bk/$PRODUCTO/.htaccess" "$PRODUCTO/"
    [ -f "bk/$PRODUCTO/manifest.json" ] && correr cp "bk/$PRODUCTO/manifest.json" "$PRODUCTO/"
    for sw in "bk/$PRODUCTO"/sw*.js; do
        [ -f "$sw" ] && correr cp "$sw" "$PRODUCTO/"
    done
    ok "configuracion restaurada"
}

# ── Codigo ───────────────────────────────────────────────────────────────────

actualizar_codigo() {
    # `fetch` + `reset --hard` en vez de `pull` + `reset`: es exactamente la misma
    # intencion, pero `pull` intenta mergear y puede fallar sobre un arbol sucio o
    # una rama divergida — y en la v2 ese error se iba a la pantalla sin frenar nada.
    ( cd "$PRODUCTO" || exit 1
      log "\$ git fetch --all --prune"; git fetch --all --prune >> "../$LOG" 2>&1
      log "\$ git reset --hard $TAG";   git reset --hard "$TAG" >> "../$LOG" 2>&1
    ) || { falla "no se pudo actualizar el codigo a $TAG"; return 1; }

    REVISION=$(cd "$PRODUCTO" && git rev-parse --short HEAD 2>/dev/null)
    ok "codigo en $TAG ($REVISION)"

    if [ -d "$PRODUCTO/application/modules" ]; then
        ( cd "$PRODUCTO" || exit 1
          log "\$ git submodule foreach git reset --hard"
          git submodule foreach git reset --hard >> "../$LOG" 2>&1
          log "\$ git submodule update --init"
          git submodule update --init >> "../$LOG" 2>&1
        ) && ok "submodulos actualizados" || falla "fallo la actualizacion de submodulos"
    fi
    return 0
}

# ── Despliegue ───────────────────────────────────────────────────────────────

# Como validar XML, segun lo que haya en el servidor. Se resuelve una sola vez.
# Si no hay ninguna herramienta se avisa EN PANTALLA: una validacion que se saltea
# en silencio es peor que no tenerla, porque da confianza sin darla.
VALIDADOR=""
elegir_validador() {
    if command -v xmllint >/dev/null 2>&1; then
        VALIDADOR="xmllint"
    elif command -v python3 >/dev/null 2>&1; then
        VALIDADOR="python3"
    else
        VALIDADOR="ninguno"
        aviso "sin xmllint ni python3: los XML se copian SIN validar"
    fi
}

xml_bien_formado() {
    case "$VALIDADOR" in
        xmllint) xmllint --noout "$1" >> "$LOG" 2>&1 ;;
        python3) python3 -c 'import sys,xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$1" >> "$LOG" 2>&1 ;;
        *)       return 0 ;;
    esac
}

# Synapse identifica el artefacto por su atributo `name`, NO por el nombre del
# archivo. Si no coinciden, el archivo viejo con ese mismo `name` sigue registrado y
# el nuevo queda huerfano fallando en cada barrido del deployer con
# "Duplicate resource definition by the name". Paso con toolsBPMAPI.xml, que
# declaraba name="toolsbpmAPI".
# Devuelve el `name` que declara un artefacto Synapse, o vacio si no declara.
nombre_declarado() {
    grep -oE '<(api|sequence|template|localEntry)[^>]*name="[^"]*"' "$1" 2>/dev/null |
        head -1 | sed -E 's/.*name="([^"]*)".*/\1/'
}

nombre_coincide() {
    archivo="$1"; destino="$2"; base=$(basename "$archivo" .xml)
    declarado=$(nombre_declarado "$archivo")
    [ -z "$declarado" ] && return 0          # no declara nombre: nada que verificar
    [ "$declarado" = "$base" ] && return 0

    # El desajuste POR SI SOLO no rompe nada: rompe cuando en el servidor ya hay OTRO
    # archivo declarando ese mismo `name`. Antes esto se avisaba en pantalla en cada
    # despliegue "por si acaso", lo que dejaba cuatro lineas de alarma permanentes sobre
    # artefactos que funcionan — y un aviso que sale siempre es un aviso que se deja de
    # leer. Como el script corre EN el servidor, no hay que suponer: se mira.
    conflicto=""
    for otro in "$destino"/*.xml; do
        [ -f "$otro" ] || continue
        [ "$(basename "$otro")" = "$(basename "$archivo")" ] && continue
        if [ "$(nombre_declarado "$otro")" = "$declarado" ]; then
            conflicto=$(basename "$otro"); break
        fi
    done

    if [ -n "$conflicto" ]; then
        falla "$(basename "$archivo"): declara name=\"$declarado\" y en el servidor \"$conflicto\" ya declara ese mismo name. Los dos van a fallar con \"Duplicate resource definition\" — hay que borrar el viejo del servidor. NO se despliega"
        return 1
    fi

    # Sin conflicto no hay nada que hacer hoy, pero queda en el log para el dia que
    # aparezca un segundo archivo con ese name.
    log "    nota: $(basename "$archivo") declara name=\"$declarado\" (no coincide con el archivo, pero hoy no hay conflicto en $destino)"
    return 0
}

# Copia un XML validando que este bien formado y que su nombre coincida con el
# `name` declarado. Un artefacto roto que llega al servidor no se despliega y
# ademas ensucia el log del WSO2 en cada arranque.
copiar_artefacto() {
    origen="$1"; destino="$2"; nombre=$(basename "$origen")
    case "$nombre" in
        *.xml)
            if ! xml_bien_formado "$origen"; then
                falla "$nombre: XML mal formado, NO se despliega"
                return 1
            fi
            nombre_coincide "$origen" "$destino" || return 1 ;;
    esac
    if correr cp "$origen" "$destino/"; then
        DESPLEGADOS=$((DESPLEGADOS + 1)); log "    desplegado: $nombre -> $destino"
        return 0
    fi
    falla "$nombre: no se pudo copiar a $destino"
    return 1
}

desplegar_dataservices() {
    mkdir -p "$WSO2DSS" || { falla "no se pudo crear $WSO2DSS"; return 1; }

    # Hay que separar dos situaciones que se parecen y no son lo mismo:
    #
    #   a) el producto NO tiene backend WSO2 (traz-comp-dnato es todo PHP). No hay
    #      nada que desplegar y eso es lo correcto: se avisa y se sigue, igual que
    #      hace el paso de Synapse. Marcarlo como error hacia que un despliegue
    #      perfecto terminara en "1 errores".
    #   b) el producto SI lo tiene, pero el directorio quedo vacio o la ruta cambio.
    #      Eso es un despliegue que no hizo nada y hay que gritarlo: paso exactamente
    #      cuando se unifico la copia de artefactos y el servidor todavia corria el
    #      script viejo, que leia de `_backend/api/dataservice/` — ese `cp` fallaba y
    #      el DEMO se quedaba con los dataservices de antes, sin que nada lo dijera.
    #
    # Los dataservices de los submodulos se buscan siempre, exista o no el proyecto
    # Maven del producto: hay submodulos que traen los suyos (ddpe-tools-pro,
    # sein-tools-almpantar).
    n=0
    if [ -d "$ARTEFACTOS/data-services" ]; then
        # Copia unica: los .dbs viven en el proyecto Maven junto al resto de los
        # artefactos. Hasta v2.5 estaban duplicados tambien en `_backend/api/dataservice/`,
        # y las dos copias venian divergiendo — de ahi salieron dos incidentes.
        for f in "$ARTEFACTOS"/data-services/*.dbs; do
            [ -f "$f" ] && { copiar_artefacto "$f" "$WSO2DSS" && n=$((n + 1)); }
        done
        if [ "$n" -eq 0 ]; then
            falla "NINGUN dataservice desplegado — $ARTEFACTOS/data-services/ existe pero esta vacio"
            return 1
        fi
        ok "$n dataservices del producto"
    elif [ -d "$ARTEFACTOS" ]; then
        falla "no se encuentra $ARTEFACTOS/data-services/ — la ruta de los artefactos cambio"
        return 1
    else
        aviso "el producto no tiene backend WSO2 propio, se omiten los dataservices"
    fi

    m=0
    for dire in "$PRODUCTO"/application/modules/*; do
        [ -d "$dire/api/dataservice" ] || continue
        for f in "$dire/api/dataservice"/*.dbs; do
            [ -f "$f" ] && { copiar_artefacto "$f" "$WSO2DSS" && m=$((m + 1)); }
        done
    done
    [ "$m" -gt 0 ] && ok "$m dataservices de submodulos"
    return 0
}

desplegar_synapse() {
    if [ ! -d "$ARTEFACTOS" ]; then
        aviso "el producto no tiene backend WSO2 propio, se omiten las APIs y sequences"
        return 0
    fi

    for tipo in $ARTEFACTOS_ORDEN; do
        sub=$(destino_de "$tipo")
        [ -n "$sub" ] || continue
        origen="$ARTEFACTOS/$tipo"
        [ -d "$origen" ] || continue

        destino="$WSO2SYN/$sub"
        mkdir -p "$destino" || { falla "no se pudo crear $destino"; continue; }

        n=0
        for f in "$origen"/*.xml; do
            [ -f "$f" ] && { copiar_artefacto "$f" "$destino" && n=$((n + 1)); }
        done
        if [ "$n" -gt 0 ]; then
            ok "$n en $sub/"
            TOTAL_SYN=$((TOTAL_SYN + n))
        else
            aviso "$tipo/ existe pero no tiene XML que desplegar"
        fi
    done

    # Las APIs son lo que el resto referencia: si no se desplego ninguna, el
    # despliegue no sirvio de nada aunque los otros tipos hayan copiado bien.
    if [ "$TOTAL_SYN" -eq 0 ]; then
        falla "NINGUN artefacto Synapse desplegado — revisar $ARTEFACTOS"
        return 1
    fi

    nota "data-sources y registry no se despliegan por diseno: van a mano"
    return 0
}

ajustar_permisos() {
    DISTRO=$(cat /etc/*-release 2>/dev/null | grep DISTRIB_ID)
    case "$DISTRO" in
        *Ubuntu*) duenio="www-data:www-data" ;;
        *)        duenio="apache:apache" ;;
    esac
    correr chown "$duenio" "$PRODUCTO" -R || falla "no se pudieron cambiar los duenios a $duenio"
    correr chmod ugo+rx "$PRODUCTO" -R
    [ -d "$PRODUCTO/assets" ] && correr chmod 777 "$PRODUCTO/assets" -R
    ok "permisos ajustados ($duenio)"
}

# ── Programa ─────────────────────────────────────────────────────────────────

main() {
    TAG="${1:-origin/master}"
    PRODUCTO="${2:-traz-tools}"
    LOG="./$PRODUCTO.log"
    INICIO=$(date '+%Y-%m-%d %H:%M:%S')

    {
        echo ""
        echo "==================================================================="
        echo " DESPLIEGUE $INICIO   producto=$PRODUCTO   tag=$TAG"
        echo "==================================================================="
    } >> "$LOG" 2>&1

    echo "=============== TRAZALOG · despliegue ==============="
    echo "  producto : $PRODUCTO"
    echo "  rama/tag : $TAG"
    echo ""

    paso "1/6  verificando el entorno"
    preflight || { resumen; return 1; }
    elegir_validador

    paso "2/6  respaldando configuracion"
    respaldar_config

    paso "3/6  actualizando codigo"
    actualizar_codigo || { resumen; return 1; }

    paso "4/6  desplegando dataservices"
    desplegar_dataservices

    paso "5/6  desplegando APIs y artefactos Synapse"
    desplegar_synapse

    paso "6/6  restaurando configuracion y permisos"
    restaurar_config
    ajustar_permisos

    resumen
}

resumen() {
    echo ""
    echo "----------------------------------------------------"
    if [ "$ERRORES" -eq 0 ]; then
        echo "  DESPLIEGUE OK"
    else
        echo "  DESPLIEGUE CON $ERRORES ERROR(ES) — revisar el log"
    fi
    echo "  artefactos desplegados : $DESPLEGADOS"
    [ -n "$REVISION" ] && echo "  revision               : $REVISION"
    echo "  log completo           : $LOG"
    echo "----------------------------------------------------"
    log "RESULTADO: $DESPLEGADOS artefactos, $ERRORES errores"
    [ "$ERRORES" -eq 0 ] || return 1
    return 0
}

# La llamada va al final y todo lo de arriba son funciones a proposito: `sh` lee
# el script de a pedazos mientras lo ejecuta, y este script hace `git reset --hard`
# sobre el repo donde el propio script vive. Definiendo todo como funciones, el
# archivo entero queda parseado antes de que se ejecute la primera linea.
main "$@"
