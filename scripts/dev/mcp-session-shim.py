#!/usr/bin/env python3
"""
mcp-session-shim.py — Reverse proxy que inyecta Mcp-Session-Id en las respuestas MCP.

Problema (jul-2026): El cliente MCP de Claude.ai (protocolVersion 2025-11-25) requiere
que el server devuelva el header `Mcp-Session-Id` en la respuesta al `initialize` para
poder EJECUTAR tools (tools/call). WSO2 APIM 4.6.0 NO genera ese session id: solo hace
echo del que mande el cliente, y Claude no manda ninguno en el primer handshake (por spec
el server debe generarlo). Resultado: Claude enumera tools (tools/list funciona) pero
al invocar una tool hace initialize y aborta, sin llegar a tools/call.

APIM es stateless respecto al session id (acepta cualquiera — verificado: tools/call con
un session id sintético devuelve 200). Así que este shim genera un Mcp-Session-Id y lo
inyecta en la respuesta cuando el server no lo trae. Claude lo usa en las siguientes
requests, APIM lo acepta, y la tool se ejecuta.

Topología:  Claude → ngrok → este shim (8899) → APIM gateway (8280)

Uso:  python3 mcp-session-shim.py [puerto_local] [puerto_apim]
      default: 8899 → 8280
"""

import http.server
import socketserver
import urllib.request
import urllib.error
import json
import os
import sys
import uuid

LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
APIM_PORT   = int(sys.argv[2]) if len(sys.argv) > 2 else 8280
APIM_BASE   = f"http://localhost:{APIM_PORT}"

# APIM 4.6.0 hornea el authorization server URL en la BD al crear la API MCP, y no se
# actualiza al cambiar la URL de ngrok. El PRM nativo (/trazalog-equipos/1.0/.well-known/
# oauth-protected-resource) queda con el host Dnato viejo → Claude no puede hacer OAuth.
# El shim reescribe el host viejo por el actual en respuestas (body + headers).
# Configurable por env: STALE_HOST (viejo) → LIVE_HOST (actual).
STALE_HOST = os.environ.get("SHIM_STALE_HOST", "3928-35-237-63-54.ngrok-free.app")
LIVE_HOST  = os.environ.get("SHIM_LIVE_HOST",  "05b1-35-237-63-54.ngrok-free.app")

# Host público del gateway APIM (para el resource_metadata del WWW-Authenticate).
APIM_PUBLIC_HOST = os.environ.get("SHIM_APIM_HOST", "4ff0-35-237-63-54.ngrok-free.app")

# APIM deja pasar initialize/tools-list SIN auth (solo tools/call exige token). El cliente
# de Claude no hace "lazy auth": si nunca recibe un 401, registra el conector como abierto,
# NUNCA pide login, y al invocar una tool (que sí necesita token) aborta sin autenticar.
# Para forzar el flujo OAuth al conectar, el shim exige auth en TODO el endpoint /mcp:
# sin Authorization → 401 + WWW-Authenticate (apunta al PRM). Así Claude descubre OAuth,
# pide login, y reintenta con token. Se puede desactivar con SHIM_ENFORCE_AUTH=0.
ENFORCE_AUTH = os.environ.get("SHIM_ENFORCE_AUTH", "1") == "1"

# Headers hop-by-hop que no se reenvían
_HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
        "te", "trailers", "transfer-encoding", "upgrade", "host", "content-length"}

# APIM 4.6.0 hace ECO de los headers del REQUEST dentro de la RESPONSE (bug conocido).
# Una respuesta con Authorization/Accept/X-Forwarded-* confunde al cliente MCP de Claude
# (aborta tras initialize sin mandar tools/call). Se eliminan de la respuesta.
_RESP_STRIP = {"authorization", "accept", "accept-encoding", "accept-language",
               "host", "user-agent", "te", "trailers", "x-anthropic-client",
               "x-forwarded-for", "x-forwarded-host", "x-forwarded-proto",
               "x-cloud-trace-context", "traceparent", "content-length",
               "transfer-encoding", "connection", "date", "server"}


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass  # silenciar; ngrok/APIM ya loguean

    def _proxy(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(length) if length else b""

        # ¿Es un initialize? (para saber si hay que garantizar session id)
        is_initialize = b'"method":"initialize"' in body or b'"method": "initialize"' in body

        # Forzar OAuth: si es el endpoint /mcp y no trae token → 401 con WWW-Authenticate.
        # Esto hace que Claude descubra el auth server y pida login al conectar, en vez de
        # registrar el conector como abierto y fallar al invocar tools.
        if (ENFORCE_AUTH and "/mcp" in self.path
                and self.command == "POST"
                and not self.headers.get("Authorization")):
            prm = f'https://{APIM_PUBLIC_HOST}/trazalog-equipos/1.0/.well-known/oauth-protected-resource'
            www = (f'Bearer resource_metadata="{prm}", error="invalid_token", '
                   f'error_description="Access token is missing"')
            payload = b'{"jsonrpc":"2.0","id":null,"error":{"code":-32001,"message":"Authorization required"}}'
            self.send_response(401)
            self.send_header("WWW-Authenticate", www)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return

        # Reenviar a APIM preservando path, método, headers y body
        target = APIM_BASE + self.path
        fwd_headers = {k: v for k, v in self.headers.items() if k.lower() not in _HOP}

        req = urllib.request.Request(target, data=body, method=self.command, headers=fwd_headers)
        try:
            resp = urllib.request.urlopen(req, timeout=60)
            status = resp.status
            resp_headers = resp.getheaders()
            resp_body = resp.read()
        except urllib.error.HTTPError as e:
            status = e.code
            resp_headers = e.headers.items()
            resp_body = e.read()
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(f'{{"error":"shim proxy error: {e}"}}'.encode())
            return

        # Reescribir host Dnato viejo → actual en el body (PRM nativo de APIM trae el viejo)
        if STALE_HOST and STALE_HOST != LIVE_HOST and resp_body:
            resp_body = resp_body.replace(STALE_HOST.encode(), LIVE_HOST.encode())

        # Reconocer la extensión io.modelcontextprotocol/ui en la respuesta del initialize.
        # Claude (2025-11-25) la declara; APIM no la reconoce en capabilities. Si Claude queda
        # en "modo UI" esperando el ack del server, se puede trabar al ejecutar tools. Aquí se
        # inyecta el ack en result.capabilities.extensions. Desactivable con SHIM_ACK_UI=0.
        if (is_initialize and os.environ.get("SHIM_ACK_UI", "1") == "1"
                and resp_body and status == 200):
            try:
                doc = json.loads(resp_body)
                caps = doc.setdefault("result", {}).setdefault("capabilities", {})
                caps.setdefault("extensions", {})["io.modelcontextprotocol/ui"] = {
                    "mimeTypes": ["text/html;profile=mcp-app"]
                }
                resp_body = json.dumps(doc).encode()
            except Exception:
                pass

        # ¿La respuesta ya trae Mcp-Session-Id?
        has_session = any(k.lower() == "mcp-session-id" for k, _ in resp_headers)

        self.send_response(status)
        for k, v in resp_headers:
            # Descartar hop-by-hop y los headers de request que APIM ecoa en la respuesta
            if k.lower() in _HOP or k.lower() in _RESP_STRIP:
                continue
            # También reescribir el host viejo en headers (ej. WWW-Authenticate resource_metadata)
            if STALE_HOST and STALE_HOST != LIVE_HOST:
                v = v.replace(STALE_HOST, LIVE_HOST)
            self.send_header(k, v)

        # Inyectar Mcp-Session-Id si el server no lo trajo.
        # En el initialize es lo que destraba a Claude; en el resto es inofensivo
        # (APIM es stateless y acepta cualquier session id).
        if not has_session:
            session_id = self.headers.get("Mcp-Session-Id") or ("trz-" + uuid.uuid4().hex)
            self.send_header("Mcp-Session-Id", session_id)
            # Asegurar que el cliente pueda leerlo vía CORS
            if not any(k.lower() == "access-control-expose-headers" for k, _ in resp_headers):
                self.send_header("Access-Control-Expose-Headers", "Mcp-Session-Id")

        self.send_header("Content-Length", str(len(resp_body)))
        self.end_headers()
        self.wfile.write(resp_body)

    def do_GET(self):
        self._proxy()

    def do_POST(self):
        self._proxy()

    def do_DELETE(self):
        self._proxy()

    def do_OPTIONS(self):
        self._proxy()


class ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    print(f"MCP session shim: 0.0.0.0:{LISTEN_PORT} → {APIM_BASE}")
    ThreadingServer(("0.0.0.0", LISTEN_PORT), Handler).serve_forever()
