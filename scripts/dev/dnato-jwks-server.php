<?php
/**
 * JWKS server de DEV que simula el endpoint de Dnato para que WSO2 APIM valide
 * los JWT de test firmados por scripts/dev/mint-dnato-jwt.py.
 *
 * Sirve la clave PÚBLICA de tests/security/test-dnato-public.pem como un JWK
 * RSA con kid `dnato-rs256-v1` (el mismo kid que pone el minter en el header).
 *
 * APIM lo consume en http://localhost:8090/.well-known/jwks.json
 * (ver [[apim.jwt.issuer]] trazalog-dnato en deployment.toml).
 *
 * Uso (mantener corriendo en una terminal):
 *     php -S localhost:8090 scripts/dev/dnato-jwks-server.php
 *
 * SOLO DEV — la clave NO es la clave real de Dnato.
 */

const KID = 'dnato-rs256-v1';
$pubPath = __DIR__ . '/../../tests/security/test-dnato-public.pem';

function b64url(string $bin): string
{
    return rtrim(strtr(base64_encode($bin), '+/', '-_'), '=');
}

$pem = file_get_contents($pubPath);
if ($pem === false) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => "no se pudo leer $pubPath"]);
    exit;
}

$details = openssl_pkey_get_details(openssl_pkey_get_public($pem));
$jwks = [
    'keys' => [[
        'kty' => 'RSA',
        'use' => 'sig',
        'alg' => 'RS256',
        'kid' => KID,
        'n'   => b64url($details['rsa']['n']),
        'e'   => b64url($details['rsa']['e']),
    ]],
];

// Con `php -S ... router.php` todas las rutas caen acá; servimos el JWKS siempre.
header('Content-Type: application/json');
echo json_encode($jwks, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
