#!/usr/bin/env bash
# ============================================================================
# check-dnato-mcp-auth.sh
#
# Verifica que estén TODAS las piezas que necesita traz-comp-dnato para el
# flujo de autenticación OAuth 2.1 + PKCE del conector MCP de Claude.
#
# Pensado para correr DESPUÉS de un deploy (sobre todo tras un git reset/pull
# que pueda haber pisado archivos parcheados a mano).
#
# USO (💻 SSH al servidor de Dnato, como root o con sudo):
#     bash check-dnato-mcp-auth.sh
#     DNATO_DIR=/otra/ruta bash check-dnato-mcp-auth.sh
#
# Solo LEE: no modifica nada. Al final imprime un resumen con lo que falta.
# ============================================================================

DNATO_DIR="${DNATO_DIR:-/var/www/html/traz-comp-dnato}"
APP="$DNATO_DIR/application"

OK=0; FAIL=0; WARN=0
ok()   { echo "  [ OK ] $*"; OK=$((OK+1)); }
bad()  { echo "  [FALTA] $*"; FAIL=$((FAIL+1)); }
warn() { echo "  [ ? ] $*"; WARN=$((WARN+1)); }
sec()  { echo ""; echo "=== $* ==="; }

echo "############################################################"
echo "# Verificación del flujo de auth MCP en Dnato"
echo "# Directorio: $DNATO_DIR"
echo "############################################################"

[ -d "$DNATO_DIR" ] || { echo "ERROR: no existe $DNATO_DIR"; exit 1; }

# ---------------------------------------------------------------------------
sec "0. Rama desplegada (el código de identidad vive SOLO en develop-v3)"
if [ -d "$DNATO_DIR/.git" ]; then
  BR=$(git -C "$DNATO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  CM=$(git -C "$DNATO_DIR" log --oneline -1 2>/dev/null)
  echo "  rama: $BR"
  echo "  commit: $CM"
  if [ "$BR" = "develop-v3" ]; then ok "está en develop-v3"
  else bad "está en '$BR' — el código de identidad (Oauth.php, JwtIssuer, etc.) SOLO existe en develop-v3"; fi
  DIRTY=$(git -C "$DNATO_DIR" status --porcelain 2>/dev/null | head -20)
  [ -n "$DIRTY" ] && { echo "  --- archivos modificados/sin trackear (parches locales):"; echo "$DIRTY" | sed 's/^/      /'; }
else
  warn "no es un repo git — deploy por copia de archivos, no se puede verificar la rama"
fi

# ---------------------------------------------------------------------------
sec "1. Archivos de código del flujo OAuth"
for f in \
  application/controllers/Oauth.php \
  application/controllers/Oauthlogin.php \
  application/libraries/JwtIssuer.php \
  application/models/OauthCode_model.php \
  application/models/Empresas.php \
  application/config/jwt.php \
  application/config/oauth_clients.php \
  application/config/routes.php \
  application/config/config.php \
  application/views/oauth/login_step1.php \
  application/views/oauth/login_error.php ; do
  [ -f "$DNATO_DIR/$f" ] && ok "$f" || bad "$f"
done

# ---------------------------------------------------------------------------
sec "2. Métodos que el flujo invoca (si el archivo quedó de una versión vieja)"
chk_fn() { # archivo, patron, descripcion
  if [ -f "$DNATO_DIR/$1" ] && grep -qE "$2" "$DNATO_DIR/$1" 2>/dev/null; then ok "$3"; else bad "$3  (en $1)"; fi
}
chk_fn application/controllers/Oauth.php      'function +authorize'                     'Oauth::authorize()'
chk_fn application/controllers/Oauth.php      'function +token'                         'Oauth::token()'
chk_fn application/controllers/Oauth.php      'function +jwks'                          'Oauth::jwks()'
chk_fn application/controllers/Oauth.php      'function +authorization_server_metadata' 'Oauth::authorization_server_metadata()  (RFC 8414)'
chk_fn application/controllers/Oauth.php      'function +register_client'               'Oauth::register_client()  (RFC 7591 DCR)'
chk_fn application/controllers/Oauth.php      'registration_endpoint'                   'AS metadata publica registration_endpoint'
chk_fn application/controllers/Oauthlogin.php 'function +credentials'                   'Oauthlogin::credentials()'
chk_fn application/models/Empresas.php        'function +getEmpresaById'                'Empresas::getEmpresaById()  (resuelve empr_id_mysql)'
chk_fn application/models/OauthCode_model.php 'empr_id_mysql'                            'OauthCode_model guarda empr_id_mysql'

# ---------------------------------------------------------------------------
sec "3. Rutas OAuth en routes.php  (se pierden con cualquier reset)"
R="$APP/config/routes.php"
for r in \
  "oauth/authorize" \
  "oauth/token" \
  "oauth/.well-known/jwks.json" \
  "oauth/.well-known/oauth-authorization-server" \
  "oauth/.well-known/openid-configuration" \
  "oauth/register" \
  "oauth/login" \
  "oauth/login/credentials" \
  "oauth/resume" ; do
  if [ -f "$R" ] && grep -qF "\$route['$r']" "$R" 2>/dev/null; then ok "\$route['$r']"; else bad "\$route['$r']"; fi
done

# ---------------------------------------------------------------------------
sec "4. config.php — los dos ajustes que rompen el flujo si faltan"
C="$APP/config/config.php"
if grep -qE "^\s*\\\$config\['composer_autoload'\]\s*=\s*FCPATH" "$C" 2>/dev/null; then
  ok "composer_autoload apunta a vendor/autoload.php"
else
  bad "composer_autoload NO configurado -> 'Class Firebase\\JWT\\JWT not found'"
  grep -nE "^\s*\\\$config\['composer_autoload'\]" "$C" 2>/dev/null | sed 's/^/       actual: /'
fi
if grep -E "^\s*\\\$config\['permitted_uri_chars'\]" "$C" 2>/dev/null | grep -q "@"; then
  ok "permitted_uri_chars incluye '@'"
else
  warn "permitted_uri_chars sin '@' — solo afecta al CLI con emails, no al login web"
fi

# ---------------------------------------------------------------------------
sec "5. Compatibilidad PHP 5.6 (este server corre 5.6 — sintaxis PHP 7+ es fatal)"
PHPV=$(php -r 'echo PHP_VERSION;' 2>/dev/null); echo "  PHP: ${PHPV:-desconocido}"
for f in application/controllers/Oauthlogin.php application/controllers/Oauth.php \
         application/controllers/Cli.php application/libraries/JwtIssuer.php \
         application/models/OauthCode_model.php ; do
  P="$DNATO_DIR/$f"; [ -f "$P" ] || continue
  # Ignorar lineas comentadas: en PHP valen //, # y * (bloques /* */).
  # Sin esto, un fix aplicado dejando la linea vieja comentada da falso positivo.
  CODE_ONLY=$(grep -vE '^\s*(//|#|\*|/\*)' "$P" 2>/dev/null)
  N=$(echo "$CODE_ONLY" | grep -c '??')
  RB=$(echo "$CODE_ONLY" | grep -c 'random_bytes')
  if [ "$N" -gt 0 ]; then bad "$(basename $f): $N usos de '??' (PHP 7+) -> Parse error"; fi
  if [ "$RB" -gt 0 ] && ! [ -d "$DNATO_DIR/vendor/paragonie/random_compat" ]; then
    bad "$(basename $f): usa random_bytes() (PHP 7+) sin paragonie/random_compat instalado"
  fi
  # el linter es la prueba definitiva
  if php -l "$P" >/dev/null 2>&1; then ok "$(basename $f): sintaxis válida para este PHP"
  else bad "$(basename $f): PARSE ERROR -> $(php -l "$P" 2>&1 | head -1)"; fi
done

# ---------------------------------------------------------------------------
sec "6. Dependencias de Composer"
[ -d "$DNATO_DIR/vendor" ] && ok "vendor/ presente" || bad "vendor/ ausente -> correr composer install"
[ -d "$DNATO_DIR/vendor/firebase/php-jwt" ] && ok "firebase/php-jwt" || bad "firebase/php-jwt ausente"

# ---------------------------------------------------------------------------
sec "7. Variables de entorno (.htaccess) — NO versionado, se pierde en deploys por clone"
H="$DNATO_DIR/.htaccess"
if [ -f "$H" ]; then
  ok ".htaccess presente"
  for v in DNATO_PUBLIC_URL DNATO_ISSUER JWT_PRIVATE_KEY_PATH JWT_PUBLIC_KEY_PATH JWT_AZP; do
    VAL=$(grep -E "SetEnv +$v " "$H" 2>/dev/null | sed -E 's/.*"(.*)".*/\1/')
    if [ -n "$VAL" ]; then
      ok "$v = $VAL"
      case "$v" in
        JWT_*KEY_PATH) [[ "$VAL" == /* ]] || bad "   ^ la ruta debe ser ABSOLUTA (con / inicial)"
                       [ -f "$VAL" ] || bad "   ^ el archivo no existe" ;;
      esac
    else
      bad "SetEnv $v ausente en .htaccess"
    fi
  done
else
  bad ".htaccess ausente -> el JWT saldrá con issuer 'http://localhost/oauth' y azp incorrecto"
fi

# ---------------------------------------------------------------------------
sec "8. Claves RS256"
KD="$APP/config/keys"
if [ -f "$KD/jwt_private.pem" ]; then
  ok "jwt_private.pem ($(stat -c '%a %U:%G' "$KD/jwt_private.pem" 2>/dev/null))"
  openssl rsa -in "$KD/jwt_private.pem" -check -noout >/dev/null 2>&1 && ok "clave privada válida" || bad "clave privada corrupta"
else bad "$KD/jwt_private.pem"; fi
[ -f "$KD/jwt_public.pem" ] && ok "jwt_public.pem" || bad "$KD/jwt_public.pem"

# ---------------------------------------------------------------------------
sec "9. Endpoints HTTP (lo que Claude realmente consulta)"
ISS=$(grep -E 'SetEnv +DNATO_ISSUER ' "$H" 2>/dev/null | sed -E 's/.*"(.*)".*/\1/')
if [ -z "$ISS" ]; then
  warn "sin DNATO_ISSUER en .htaccess, no se pueden probar los endpoints"
else
  probe() { # url, descripcion, patron-esperado
    B=$(curl -s --max-time 15 "$1" 2>/dev/null)
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$1" 2>/dev/null)
    if [ "$CODE" = "200" ] && echo "$B" | grep -q "$3"; then ok "$2 (200)"
    elif echo "$B" | grep -q "404 Page Not Found"; then bad "$2 -> 404 de CodeIgniter = FALTA LA RUTA en routes.php"
    else bad "$2 -> HTTP $CODE $(echo "$B" | head -c 120)"; fi
  }
  probe "$ISS/.well-known/oauth-authorization-server" "AS metadata (RFC 8414)" "authorization_endpoint"
  probe "$ISS/.well-known/oauth-authorization-server" "  -> incluye registration_endpoint" "registration_endpoint"
  probe "$ISS/.well-known/jwks.json"                  "JWKS" '"kty"'
  RC=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 -X POST "$ISS/register" \
        -H "Content-Type: application/json" \
        -d '{"redirect_uris":["https://claude.ai/api/mcp/auth_callback"],"token_endpoint_auth_method":"none"}' 2>/dev/null)
  [ "$RC" = "201" ] && ok "DCR /register (201)" || bad "DCR /register -> HTTP $RC (se espera 201)"
fi

# ---------------------------------------------------------------------------
sec "10. redirect_uri autorizados (oauth_clients.php)"
OC="$APP/config/oauth_clients.php"
if [ -f "$OC" ]; then
  grep -q "trazalog-mcp-connector" "$OC" && ok "cliente 'trazalog-mcp-connector' registrado" || bad "falta el cliente trazalog-mcp-connector"
  grep -q "https://claude.ai/api/mcp/auth_callback" "$OC" && ok "redirect_uri de Claude.ai Web" || bad "falta redirect_uri https://claude.ai/api/mcp/auth_callback"
  echo "  --- redirect_uris configurados:"; grep -oE "'https?://[^']+'" "$OC" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
sec "11. Base de datos"
if command -v psql >/dev/null 2>&1 && [ -n "${PGHOST:-}" ]; then
  q() { PGPASSWORD="${PGPASSWORD:-}" psql -h "$PGHOST" -p "${PGPORT:-5432}" -U "${PGUSER:-postgres}" -d "${PGDATABASE:-tools_prod_t}" -t -A -c "$1" 2>&1; }
  [ "$(q "SELECT 1 FROM information_schema.tables WHERE table_schema='seg' AND table_name='oauth_codes'")" = "1" ] \
     && ok "tabla seg.oauth_codes" || bad "tabla seg.oauth_codes ausente (correr 001_create_seg_oauth_codes.sql)"
  [ "$(q "SELECT 1 FROM information_schema.columns WHERE table_schema='seg' AND table_name='oauth_codes' AND column_name='empr_id_mysql'")" = "1" ] \
     && ok "seg.oauth_codes.empr_id_mysql" || bad "columna empr_id_mysql ausente en seg.oauth_codes (la migración 001 no la incluye)"
  [ "$(q "SELECT 1 FROM information_schema.columns WHERE table_schema='core' AND table_name='empresas' AND column_name='empr_id_mysql'")" = "1" ] \
     && ok "core.empresas.empr_id_mysql" || bad "columna empr_id_mysql ausente en core.empresas"
else
  warn "chequeo de BD omitido — exportar PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE para incluirlo"
fi

# ---------------------------------------------------------------------------
echo ""
echo "############################################################"
echo "#  OK: $OK    FALTA: $FAIL    A revisar: $WARN"
if [ "$FAIL" -eq 0 ]; then
  echo "#  Todo en su lugar."
else
  echo "#  Hay $FAIL cosas faltando — ver las lineas [FALTA] de arriba."
  echo "#  Referencia: traz-tools/doc/v3/deployment-gcp.md §7.0-bis y §7.0-quater"
fi
echo "############################################################"
exit $([ "$FAIL" -eq 0 ] && echo 0 || echo 1)
