#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  findMatchingTemplate() lee AM_API_URL_MAPPING de la base del APIM. Todo lo
#  que consultamos por REST viene de la definicion parseada, que puede estar
#  al dia mientras la tabla no lo esta.
#
#  Esta consulta cuenta las filas reales para la API. SOLO SELECT.
#
#  USO (por SSH en la VM):  bash diag-url-mapping-db.sh
# ---------------------------------------------------------------------------
set -u
APIM="${APIM_HOME:-$(ls -d /opt/wso2am* 2>/dev/null | head -1)}"
TOML="$APIM/repository/conf/deployment.toml"
echo "=== datasource del APIM ($TOML) ==="
sed -n '/\[database.apim_db\]/,/^\[/p' "$TOML" 2>/dev/null | grep -E "type|url|username" | sed 's/password.*/password = ***/'
echo
echo "  Copiar el host/base/usuario de arriba y correr esta consulta:"
cat <<'SQL'

-- ¿cuantas URL mappings tiene realmente la API en la base?
SELECT a.API_NAME, a.API_VERSION, COUNT(*) AS url_mappings
  FROM AM_API_URL_MAPPING m
  JOIN AM_API a ON a.API_ID = m.API_ID
 WHERE a.API_NAME = 'Trazalog MCP API'
 GROUP BY a.API_NAME, a.API_VERSION;

-- el detalle, para ver CUALES estan
SELECT m.HTTP_METHOD, m.URL_PATTERN
  FROM AM_API_URL_MAPPING m
  JOIN AM_API a ON a.API_ID = m.API_ID
 WHERE a.API_NAME = 'Trazalog MCP API'
 ORDER BY m.URL_PATTERN, m.HTTP_METHOD;

SQL
echo "  Si devuelve 9 filas en vez de 17, ESA es la causa: la definicion se"
echo "  actualizo pero las URL mappings de la base no, y por eso"
echo "  findMatchingTemplate no encuentra las 8 operaciones nuevas."
