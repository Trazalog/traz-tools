#!/usr/bin/env bash
# Prepara una COPIA del Micro Integrator 4.5 para probar los agentes contra las
# bases de DEV con los artefactos de ESTA rama (APIs, secuencias y servicios de
# datos de ToolsAPIProject), sin tocar el MI de nadie.
#
# Se corre en: terminal local, con la conexion segura (VPN) a DEV levantada.
#
#   scripts/dev/mi-local-agentes.sh <carpeta-de-la-copia-del-mi>
#   JAVA_HOME=~/.wso2-mi/java/jdk-21.0.10+7 <carpeta>/bin/micro-integrator.sh
#
# Queda escuchando en el puerto 8301 (offset 21). La fachada de los agentes
# queda en http://127.0.0.1:8301/tools/mcp/mcp/... y el motor se apunta con
#   AGENTE_MCP_MODO=mi  AGENTE_MCP_URL=http://127.0.0.1:8301/tools/mcp/mcp
#
# OJO: la copia escribe en DEV cuando se acepta un plan de Kuntur (pedido,
# hitos y tareas de la empresa del token). Usar solo con empresas de prueba.
#
# Las claves de las bases salen de los data-sources del proyecto en tiempo de
# ejecucion y quedan SOLO en el deployment.toml de la copia (fuera del repo).
set -euo pipefail

M=${1:?uso: $0 <carpeta-de-la-copia-del-mi>}
RAIZ=$(cd "$(dirname "$0")/../.." && pwd)
A=$RAIZ/_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts
SY=$M/repository/deployment/server/synapse-configs/default

case "$(cd "$M" && pwd)" in
  "$HOME/.wso2-mi/micro-integrator/"*) echo "Eso es un MI instalado, no una copia. No se toca." >&2; exit 2 ;;
esac
[ -f "$M/conf/deployment.toml" ] || { echo "No encuentro $M/conf/deployment.toml" >&2; exit 2; }

# Puerto propio y sin los .car que pudiera traer la copia.
sed -i -E 's/^offset = .*/offset = 21  # COPIA DE PRUEBA DE LOS AGENTES: puerto 8301/' "$M/conf/deployment.toml"
rm -f "$M"/repository/deployment/server/carbonapps/*.car
rm -rf "$M/tmp/carbonapps"

# Todo apunta a la propia copia: las APIs y los servicios de datos son los de esta rama.
mkdir -p "$M/registry/config/tools"
printf '<api>\n\t<api_url>http://127.0.0.1:8301/tools</api_url>\n\t<dataservices_url>http://127.0.0.1:8301/services</dataservices_url>\n</api>\n' \
  > "$M/registry/config/tools/apiconfig.xml"

mkdir -p "$SY/api" "$SY/sequences" "$SY/templates" "$SY/local-entries" "$M/repository/deployment/server/dataservices"
cp "$A"/apis/*.xml "$SY/api/"
cp "$A"/sequences/*.xml "$SY/sequences/"
cp "$A"/templates/*.xml "$SY/templates/"
cp "$A"/local-entries/*.xml "$SY/local-entries/"
cp "$A"/data-services/*.dbs "$M/repository/deployment/server/dataservices/"

# Fuentes de datos (ToolsDataSource y AssetPlannerDataSource) en el deployment.toml.
python3 - "$A/data-sources" "$M/conf/deployment.toml" <<'EOF'
import glob, re, sys, xml.etree.ElementTree as ET
from xml.sax.saxutils import escape
carpeta, toml = sys.argv[1:]
s = re.sub(r'\n# --- DS AGENTE PRUEBA ---.*', '', open(toml).read(), flags=re.S)
s += '\n# --- DS AGENTE PRUEBA ---\n'
for f in sorted(glob.glob(carpeta + '/*.xml')):
    r = ET.parse(f).getroot()
    c = r.find('.//configuration')
    g = lambda k: (c.findtext(k) or '').strip()
    # El MI arma un XML con estos valores: el & de la URL va escapado.
    s += (f'[[datasource]]\nid = "{r.findtext("name")}"\nurl = "{escape(g("url"))}"\n'
          f'username = "{g("username")}"\npassword = "{g("password")}"\ndriver = "{g("driverClassName")}"\n'
          'pool_options.maxActive = 5\npool_options.validationQuery = "SELECT 1"\n')
    print(f'fuente de datos {r.findtext("name")}: {g("url").split("?")[0]}')
open(toml, 'w').write(s)
EOF

# Memoria baja: la maquina de desarrollo ya se colgo una vez por las JVM.
sed -i 's/JVM_MEM_OPTS="-Xms256m -Xmx1024m"/JVM_MEM_OPTS="-Xms128m -Xmx512m"/' "$M/bin/micro-integrator.sh"

echo "Copia lista en $M (puerto 8301). Arrancala con bin/micro-integrator.sh."
