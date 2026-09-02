<?php
/**
 * Verifica que el PKCE que genera el controller del agente sea EXACTAMENTE el
 * que Dnato valida.
 *
 * Es la pieza que no se puede probar a ojo: si el base64url o el hash difieren
 * en un detalle, Dnato rechaza el canje con "code_verifier incorrecto" y el
 * chat nunca obtiene su token. Este test replica las dos implementaciones y
 * las compara.
 *
 *   php tests/agente/test-pkce.php
 */

// --- Como lo genera Tools (application/modules/traz-comp-agente/controllers/Agente.php)
function tools_base64url($bytes) {
    return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
}
function tools_challenge($verifier) {
    return tools_base64url(hash('sha256', $verifier, true));
}

// --- Como lo valida Dnato (traz-comp-dnato/application/controllers/Oauth.php)
function dnato_base64url_encode($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}
function dnato_valida($verifier, $challenge_recibido) {
    return dnato_base64url_encode(hash('sha256', $verifier, true)) === $challenge_recibido;
}

$fallas = 0;
function chequear($ok, $desc) {
    global $fallas;
    echo ($ok ? "OK    " : "FALLA ") . $desc . PHP_EOL;
    if (!$ok) { $fallas++; }
}

// 1. El challenge que genera Tools es el que Dnato acepta.
for ($i = 0; $i < 20; $i++) {
    $verifier  = tools_base64url(random_bytes(48));
    $challenge = tools_challenge($verifier);
    if (!dnato_valida($verifier, $challenge)) {
        chequear(false, "el challenge de Tools no valida en Dnato (intento $i)");
        break;
    }
}
chequear(true, 'el challenge de Tools valida en Dnato (20 verifiers al azar)');

// 2. Un verifier distinto NO valida: si esto fallara, el PKCE no protegeria nada.
$v1 = tools_base64url(random_bytes(48));
$v2 = tools_base64url(random_bytes(48));
chequear(!dnato_valida($v2, tools_challenge($v1)),
         'un code_verifier distinto es rechazado');

// 3. El verifier cumple el largo que exige RFC 7636 (43 a 128 caracteres).
$largo = strlen(tools_base64url(random_bytes(48)));
chequear($largo >= 43 && $largo <= 128,
         "el code_verifier mide $largo caracteres (RFC 7636 pide entre 43 y 128)");

// 4. No quedan caracteres fuera del alfabeto base64url: '+', '/' ni '=' pueden
//    romperse al viajar en una URL.
$muestra = tools_base64url(random_bytes(48)) . tools_challenge('x');
chequear(preg_match('/^[A-Za-z0-9\-_]+$/', $muestra) === 1,
         'verifier y challenge usan solo el alfabeto base64url, seguro en URLs');

// 5. El metodo es S256, el unico que Dnato acepta.
chequear(strlen(base64_decode(strtr(tools_challenge('abc'), '-_', '+/'), true)) === 32,
         'el challenge es un SHA-256 de 32 bytes (code_challenge_method=S256)');

echo PHP_EOL . ($fallas === 0
    ? "PKCE: todo en verde."
    : "PKCE: $fallas control(es) fallaron.") . PHP_EOL;
exit($fallas === 0 ? 0 : 1);
