#!/usr/bin/env bash
# Genera claves y JWTs de prueba para los tests de seguridad E9-IDENT-05.
# Requiere: openssl, python3 (para construir JWT), jq
# Uso: ./generate-test-jwts.sh
# Salida: crea tests/security/test-env.hurl con las variables de entorno para jwt-validation.hurl

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
VALID_JWT=$VALID_JWT
EXPIRED_JWT=$EXPIRED_JWT
WRONG_KEY_JWT=$WRONG_KEY_JWT
WRONG_ISS_JWT=$WRONG_ISS_JWT
NO_EMPRID_JWT=$NO_EMPRID_JWT
EMPRESA_A_JWT=$EMPRESA_A_JWT
EMPRESA_B_JWT=$EMPRESA_B_JWT
EOF

echo ""
echo "=== IMPORTANTE: Cargar la clave pública en WSO2 registry ==="
echo "Copiar el contenido de test-dnato-public.pem al registry de WSO2:"
echo "  /_system/config/identity/dnato-public-key.pem"
echo ""
echo "Variables generadas en: $OUT_ENV"
echo "Usar con: hurl --variables-file $OUT_ENV jwt-validation.hurl"
echo ""
echo "ADVERTENCIA: Las claves en tests/security/ son SOLO para testing."
echo "NO usar en producción. Destruir después de los tests."
