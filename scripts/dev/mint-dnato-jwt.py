#!/usr/bin/env python3
"""
Emite un JWT de DEV firmado como el issuer `trazalog-dnato` para probar el MCP server.

Firma con `tests/security/test-dnato-private.pem` y kid `dnato-rs256-v1`, de modo que
valide contra el JWKS que publica scripts/dev/dnato-jwks-server.py (puerto 8090), que es
el JWKS que el APIM tiene configurado (deployment.toml → [[apim.jwt.issuer]] trazalog-dnato).

Claims alineados con ADR-008:
    iss = trazalog-dnato
    aud = trazalog-mcp
    azp = z_CtMHRzWPSgY8aXWYxFuzsOli4a   (consumer_key_claim del APIM — app TrazalogDnatoMCP)
    empr_id = <id de empresa>            (lo inyecta EmprIdInjectorPolicy en el backend)

Uso:
    python3 scripts/dev/mint-dnato-jwt.py [empr_id] [sub] [ttl_seg]
    python3 scripts/dev/mint-dnato-jwt.py 42 userA@test.com 3600

Imprime sólo el JWT en stdout (apto para  TOKEN=$(python3 ... ) ).

SOLO DEV — la clave NO es la clave real de Dnato.
"""
import base64
import json
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PRIV = REPO / "tests" / "security" / "test-dnato-private.pem"
KID = "dnato-rs256-v1"
AZP = "z_CtMHRzWPSgY8aXWYxFuzsOli4a"

empr_id       = int(sys.argv[1]) if len(sys.argv) > 1 else 42
sub           = sys.argv[2] if len(sys.argv) > 2 else "userA@test.com"
ttl           = int(sys.argv[3]) if len(sys.argv) > 3 else 3600
empr_id_mysql = int(sys.argv[4]) if len(sys.argv) > 4 else empr_id


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _seg(obj: dict) -> str:
    return _b64url(json.dumps(obj, separators=(",", ":")).encode())


now = int(time.time())
header = {"alg": "RS256", "typ": "JWT", "kid": KID}
payload = {
    "iss": "trazalog-dnato",
    "aud": "trazalog-mcp",
    "sub": sub,
    "azp": AZP,
    "empr_id": empr_id,
    "empr_id_mysql": empr_id_mysql,
    "exp": now + ttl,
    "iat": now,
}

signing_input = f"{_seg(header)}.{_seg(payload)}"
signature = subprocess.run(
    ["openssl", "dgst", "-sha256", "-sign", str(PRIV)],
    input=signing_input.encode(), capture_output=True, check=True,
).stdout

print(f"{signing_input}.{_b64url(signature)}")
