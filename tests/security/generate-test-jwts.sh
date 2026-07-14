#!/usr/bin/env bash
# Genera claves y JWTs de prueba para los tests de seguridad E9-IDENT-05.
#
# ADR-008 (Mayo 2026): la validación JWT ocurre en el APIM (Key Manager Dnato), no en el MI.
# Los tests apuntan al APIM (:8243). Ver jwt-validation.hurl y ot-mcp.hurl.
#
# Este script genera:
#   - Par de claves RSA de PRUEBA (NO son las claves reales de Dnato)
#   - JWTs inválidos para test: expirado, clave diferente, sin empr_id
#
# Para JWT VÁLIDOS (VALID_JWT, EMPRESA_A_JWT, EMPRESA_B_JWT):
#   Usar el CLI de Dnato en el host de Dnato:
#     VALID_JWT=$(php index.php cli issue_test_token <email> <empr_id>)
#   El APIM valida la firma contra el JWKS real de Dnato — los JWT del script
#   generan una clave que NO está en el JWKS, por lo que serían rechazados.
#   Solo EXPIRED_JWT, WRONG_KEY_JWT y NO_EMPRID_JWT se generan aquí
#   (el APIM los rechaza por exp o por firma inválida — exactamente lo que queremos testear).
#
# Requiere: openssl, python3
# Uso: ./generate-test-jwts.sh
# Salida: test-env.vars (completar VALID_JWT/EMPRESA_A_JWT/EMPRESA_B_JWT/APIM_HOST manualmente)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_ENV="$SCRIPT_DIR/test-env.vars"

echo "=== Generando par de claves RSA para tests ==="

# Clave principal de prueba (simula la clave de Dnato)
openssl genrsa -out "$SCRIPT_DIR/test-dnato-private.pem" 2048 2>/dev/null
openssl rsa -in "$SCRIPT_DIR/test-dnato-private.pem" \
            -pubout -out "$SCRIPT_DIR/test-dnato-public.pem" 2>/dev/null

# Clave alternativa (para test de "firmado con clave diferente")
openssl genrsa -out "$SCRIPT_DIR/test-other-private.pem" 2048 2>/dev/null

echo "=== Generando JWTs de prueba ==="

# Helper: genera un JWT firmado con RS256
# Args: private_key_file, payload_json
make_jwt() {
    local privkey="$1"
    local payload="$2"

    local header
    header=$(printf '{"alg":"RS256","typ":"JWT"}' | \
             python3 -c "import sys,base64; d=sys.stdin.buffer.read(); print(base64.urlsafe_b64encode(d).rstrip(b'=').decode())")

    local body
    body=$(printf '%s' "$payload" | \
           python3 -c "import sys,base64; d=sys.stdin.buffer.read(); print(base64.urlsafe_b64encode(d).rstrip(b'=').decode())")

    local signing_input="${header}.${body}"
    local signature
    signature=$(printf '%s' "$signing_input" | \
                openssl dgst -sha256 -sign "$privkey" | \
                python3 -c "import sys,base64; d=sys.stdin.buffer.read(); print(base64.urlsafe_b64encode(d).rstrip(b'=').decode())")

    echo "${signing_input}.${signature}"
}

NOW=$(date +%s)
FUTURE=$((NOW + 3600))
PAST=$((NOW - 3600))

# JWT válido
VALID_JWT=$(make_jwt "$SCRIPT_DIR/test-dnato-private.pem" \
    "{\"iss\":\"trazalog-dnato\",\"aud\":\"trazalog-mcp\",\"sub\":\"user1\",\"empr_id\":\"42\",\"exp\":$FUTURE,\"iat\":$NOW}")

# JWT expirado
EXPIRED_JWT=$(make_jwt "$SCRIPT_DIR/test-dnato-private.pem" \
    "{\"iss\":\"trazalog-dnato\",\"aud\":\"trazalog-mcp\",\"sub\":\"user1\",\"empr_id\":\"42\",\"exp\":$PAST,\"iat\":$NOW}")

# JWT firmado con clave diferente
WRONG_KEY_JWT=$(make_jwt "$SCRIPT_DIR/test-other-private.pem" \
    "{\"iss\":\"trazalog-dnato\",\"aud\":\"trazalog-mcp\",\"sub\":\"user1\",\"empr_id\":\"42\",\"exp\":$FUTURE,\"iat\":$NOW}")

# JWT con iss incorrecto
WRONG_ISS_JWT=$(make_jwt "$SCRIPT_DIR/test-dnato-private.pem" \
    "{\"iss\":\"otro-emisor\",\"aud\":\"trazalog-mcp\",\"sub\":\"user1\",\"empr_id\":\"42\",\"exp\":$FUTURE,\"iat\":$NOW}")

# JWT sin empr_id
NO_EMPRID_JWT=$(make_jwt "$SCRIPT_DIR/test-dnato-private.pem" \
    "{\"iss\":\"trazalog-dnato\",\"aud\":\"trazalog-mcp\",\"sub\":\"user1\",\"exp\":$FUTURE,\"iat\":$NOW}")

# JWT válido empresa A (empr_id=42)
EMPRESA_A_JWT=$(make_jwt "$SCRIPT_DIR/test-dnato-private.pem" \
    "{\"iss\":\"trazalog-dnato\",\"aud\":\"trazalog-mcp\",\"sub\":\"userA\",\"empr_id\":\"42\",\"exp\":$FUTURE,\"iat\":$NOW}")

# JWT válido empresa B (empr_id=99)
EMPRESA_B_JWT=$(make_jwt "$SCRIPT_DIR/test-dnato-private.pem" \
    "{\"iss\":\"trazalog-dnato\",\"aud\":\"trazalog-mcp\",\"sub\":\"userB\",\"empr_id\":\"99\",\"exp\":$FUTURE,\"iat\":$NOW}")

cat > "$OUT_ENV" <<EOF
# APIM_HOST: completar con el host:port del APIM gateway
APIM_HOST=localhost:8243

# JWTs inválidos generados con claves de prueba (NO son la clave real de Dnato)
# El APIM los rechaza porque la clave de prueba no está en el JWKS de Dnato.
EXPIRED_JWT=$EXPIRED_JWT
WRONG_KEY_JWT=$WRONG_KEY_JWT
WRONG_ISS_JWT=$WRONG_ISS_JWT
NO_EMPRID_JWT=$NO_EMPRID_JWT

# JWTs válidos: COMPLETAR con el CLI de Dnato (en el host de Dnato):
#   VALID_JWT=\$(php index.php cli issue_test_token <email> 42)
#   EMPRESA_A_JWT=\$(php index.php cli issue_test_token <email_A> 42)
#   EMPRESA_B_JWT=\$(php index.php cli issue_test_token <email_B> 99)
VALID_JWT=COMPLETAR_CON_CLI_DNATO
EMPRESA_A_JWT=COMPLETAR_CON_CLI_DNATO
EMPRESA_B_JWT=COMPLETAR_CON_CLI_DNATO
EOF

echo ""
echo "=== ADR-008: Tests ahora apuntan al APIM (:8243), no al MI (:8280) ==="
echo ""
echo "SIGUIENTE PASO: completar los JWT válidos en $OUT_ENV"
echo "En el host de Dnato:"
echo "  VALID_JWT=\$(php index.php cli issue_test_token <email> 42)"
echo "  EMPRESA_A_JWT=\$(php index.php cli issue_test_token <email_A> 42)"
echo "  EMPRESA_B_JWT=\$(php index.php cli issue_test_token <email_B> 99)"
echo ""
echo "Luego ejecutar:"
echo "  hurl -k --variables-file $OUT_ENV jwt-validation.hurl"
echo "  hurl -k --variables-file $OUT_ENV ot-mcp.hurl"
echo ""
echo "ADVERTENCIA: Las claves en tests/security/ son SOLO para testing."
echo "NO usar en producción."
