#!/usr/bin/env python3
"""
JWKS server de DEV para validación JWT en WSO2 APIM 4.6.0 (issuer trazalog-dnato).

El APIM está configurado (deployment.toml) para traer el JWKS desde:
    http://localhost:8090/.well-known/jwks.json

Este server publica la clave pública de `tests/security/test-dnato-public.pem`
como un JWK con kid `dnato-rs256-v1`. Los JWT firmados con la privada correspondiente
(`test-dnato-private.pem`, ver scripts/dev/mint-dnato-jwt.py) validan contra este JWKS.

Reemplaza al viejo /tmp/jwks-server.php (que se perdía en cada reboot).

Uso:
    python3 scripts/dev/dnato-jwks-server.py            # puerto 8090
    python3 scripts/dev/dnato-jwks-server.py 8090       # puerto explícito

SOLO DEV — la clave de tests/security/ NO es la clave real de Dnato.
"""
import base64
import json
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PRIV = REPO / "tests" / "security" / "test-dnato-private.pem"
KID = "dnato-rs256-v1"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8090


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _build_jwks() -> dict:
    """Deriva n,e de la clave pública vía openssl y arma el JWKS."""
    # modulus (n) en hex
    pub = subprocess.run(
        ["openssl", "rsa", "-in", str(PRIV), "-pubout"],
        capture_output=True, check=True,
    ).stdout
    mod_line = subprocess.run(
        ["openssl", "rsa", "-pubin", "-modulus", "-noout"],
        input=pub, capture_output=True, check=True,
    ).stdout.decode().strip()
    modulus_hex = mod_line.split("=", 1)[1]
    n = bytes.fromhex(modulus_hex)
    # exponente: openssl muestra "Exponent: 65537 (0x10001)" — casi siempre AQAB
    e = (65537).to_bytes(3, "big")
    return {
        "keys": [{
            "kty": "RSA",
            "use": "sig",
            "alg": "RS256",
            "kid": KID,
            "n": _b64url(n),
            "e": _b64url(e),
        }]
    }


JWKS = json.dumps(_build_jwks()).encode()


class JWKSHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/.well-known/jwks.json", "/jwks.json"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(JWKS)))
            self.end_headers()
            self.wfile.write(JWKS)
        else:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()

    def log_message(self, fmt, *args):
        print(f"[jwks] {self.address_string()} {fmt % args}")


if __name__ == "__main__":
    print(f"[jwks] sirviendo {KID} desde {PRIV.name}")
    print(f"[jwks] http://localhost:{PORT}/.well-known/jwks.json")
    HTTPServer(("0.0.0.0", PORT), JWKSHandler).serve_forever()
