#!/usr/bin/env python3
"""
Genera un valor para el header X-JWT-Assertion, simulando el backend JWT que el
APIM genera y firma tras validar el JWT de Dnato (ADR-008/ADR-009) — el que
EmprIdFromHeader.xml (MI) decodifica para derivar empr_id/empr_id_mysql.

No firma con una clave real: EmprIdFromHeader.xml todavía no valida la firma de
la assertion (ver su propio comentario "PROD: validar la firma..."), solo hace
Base64.decode() del segundo segmento y parsea el JSON — por eso alcanza con
armar el shape header.payload.signature (3 segmentos) que el parser espera.

Uso:
    python3 scripts/dev/mint-backend-jwt.py [empr_id] [empr_id_mysql]
    python3 scripts/dev/mint-backend-jwt.py 42 42

Imprime solo el valor en stdout (apto para X-JWT-Assertion: $(...)).

SOLO DEV/testing — no reemplaza el backend JWT real que firma el APIM en producción.
"""
import base64
import json
import sys
import time

empr_id = int(sys.argv[1]) if len(sys.argv) > 1 else 42
empr_id_mysql = int(sys.argv[2]) if len(sys.argv) > 2 else empr_id


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _seg(obj: dict) -> str:
    return _b64url(json.dumps(obj, separators=(",", ":")).encode())


now = int(time.time())
header = {"alg": "none", "typ": "JWT"}
payload = {"empr_id": empr_id, "empr_id_mysql": empr_id_mysql, "iat": now}

# tercer segmento vacío (sin firma) — EmprIdFromHeader solo exige 3 partes separadas por "."
print(f"{_seg(header)}.{_seg(payload)}.")
