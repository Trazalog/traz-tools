#!/bin/sh
# =============================================================================
#  verificar-artefactos-duplicados.sh
# =============================================================================
#  QUÉ HACE
#    Detecta artefactos Synapse (sequences y APIs) de WSO2 que declaran el MISMO
#    `name` en más de un archivo. Ese es el caso que rompe el despliegue con
#    "Duplicate resource definition" y tira abajo el synapse-config (y con él
#    servicios como COREDataService -> se cae el logo y el menú).
#
#    Pasa porque el deploy COPIA pero NO BORRA: si un artefacto se renombra en el
#    repo (p.ej. toolsFault.xml -> toolsFaultSequence.xml, ambos name="toolsFault"),
#    el archivo viejo queda en el server y choca con el nuevo.
#
#  QUÉ NO HACE
#    No borra nada. Solo reporta. La eliminación la decidís vos: borrás el archivo
#    VIEJO, el que ya NO está en el repo.
#
#  DÓNDE SE EJECUTA
#    En el server de WSO2, DESPUÉS del deploy y ANTES de reiniciar.
#
#  USO
#    sh verificar-artefactos-duplicados.sh [WSO2HOME] [REPO_ARTIFACTS_DIR]
#      WSO2HOME            default: /usr/lib64/wso2/wso2ei/6.5.0
#      REPO_ARTIFACTS_DIR  opcional: .../ToolsAPIProject/src/main/wso2mi/artifacts
#                          Si se pasa, marca cuál duplicado NO está en el repo
#                          (ese es el leftover a borrar).
#
#  CÓDIGO DE SALIDA: 1 si hay duplicados, 0 si está limpio.
# =============================================================================

WSO2="${1:-/usr/lib64/wso2/wso2ei/6.5.0}"
REPO="${2:-}"
BASE="$WSO2/repository/deployment/server/synapse-configs/default"

nombre_de() {
    grep -oE 'name="[^"]+"' "$1" 2>/dev/null | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
}

hubo_dup=0

for sub in sequences api; do
    dir="$BASE/$sub"
    [ -d "$dir" ] || continue

    tmp=$(mktemp)
    for f in "$dir"/*.xml; do
        [ -f "$f" ] || continue
        nm=$(nombre_de "$f")
        [ -n "$nm" ] && printf '%s|%s\n' "$nm" "$(basename "$f")" >> "$tmp"
    done

    dups=$(cut -d'|' -f1 "$tmp" | sort | uniq -d)
    if [ -n "$dups" ]; then
        hubo_dup=1
        echo "=============================================================="
        echo "  DUPLICADOS en $sub/   ($dir)"
        echo "=============================================================="
        printf '%s\n' "$dups" | while IFS= read -r n; do
            [ -z "$n" ] && continue
            echo "  name=\"$n\"  declarado por:"
            awk -F'|' -v n="$n" '$1==n{print $2}' "$tmp" | while IFS= read -r arch; do
                marca=""
                if [ -n "$REPO" ]; then
                    if [ -f "$REPO/sequences/$arch" ] || [ -f "$REPO/apis/$arch" ]; then
                        marca="   (está en el repo -> DEJAR)"
                    else
                        marca="   (NO está en el repo -> BORRAR este)"
                    fi
                fi
                echo "     - $arch$marca"
            done
        done
    fi
    rm -f "$tmp"
done

echo
if [ "$hubo_dup" -eq 1 ]; then
    echo ">> HAY DUPLICADOS. Borrá el archivo VIEJO (el que NO está en el repo) de"
    echo "   $BASE/<sequences|api>/  y recién después reiniciá WSO2."
    exit 1
else
    echo "OK: no hay 'name' duplicados en sequences/ ni api/."
    exit 0
fi
