#!/usr/bin/env python3
"""
MCP OAuth Proxy — demo/dev bridge para Claude.ai + WSO2 APIM 4.6.0

Problema: Claude.ai implementa el spec MCP 2025-06-18 que requiere OAuth discovery
y un OAuth client pre-registrado. El gateway de WSO2 en puerto 8243 no expone esos
endpoints. Claude.ai NO hace Dynamic Client Registration automáticamente — espera
que el usuario le dé un Client ID pre-configurado.

Este proxy:
  1. Sirve los endpoints OAuth discovery
  2. Tiene un cliente pre-registrado con ID conocido (DEMO_CLIENT_ID)
  3. Muestra una página de consent mínima cuando Claude.ai hace el auth code flow
  4. Emite tokens opacos válidos para el handshake
  5. Reenvía todas las llamadas MCP al gateway de WSO2 en puerto 8243

Uso:
  python3 mcp-oauth-proxy.py <ngrok-url> [puerto-local]

  Ejemplo: python3 mcp-oauth-proxy.py https://2a0c-35-237-63-54.ngrok-free.app 8000

Workflow:
  1. Correr este proxy (ngrok apuntando al puerto-local)
  2. Copiar el DEMO_CLIENT_ID que imprime al arrancar
  3. En Claude.ai → editar el conector MCP → "OAuth Client ID" → pegar el ID
  4. Claude.ai redirige al browser a la página de consent de este proxy
  5. Click "Permitir acceso"
  6. Claude.ai recibe el token y empieza a usar el MCP server

SOLO PARA DEV/DEMO — no usar en producción.
"""

import hashlib
import html
import json
import os
import secrets
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

NGROK_URL     = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "http://localhost:8000"
PROXY_PORT    = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
WSO2_GATEWAY  = "https://localhost:8243"

# Cliente pre-registrado — este ID es el que hay que ingresar en Claude.ai
DEMO_CLIENT_ID     = "trazalog-mcp-dev"
DEMO_CLIENT_SECRET = "trazalog-dev-secret-2026"

# TLS sin verificación para WSO2 local (cert autofirmado)
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

# WSO2 devuelve request headers dentro de la response (bug de eco).
# Se filtran para no confundir a Claude.ai.
_RESPONSE_HEADERS_STRIP = {
    "transfer-encoding", "connection", "content-length",
    "authorization", "accept", "accept-encoding",
    "accept-language", "host", "user-agent", "te", "trailers",
}

# Estado en memoria
_clients: dict = {
    DEMO_CLIENT_ID: {
        "client_secret": DEMO_CLIENT_SECRET,
        "redirect_uris": [],       # acepta cualquier redirect_uri
        "grant_types": ["authorization_code", "client_credentials"],
        "client_name": "Trazalog MCP Dev",
    }
}
_codes:  dict = {}    # auth_code  → {client_id, redirect_uri, code_challenge}
_tokens: dict = {}    # token      → {client_id}


def _make_token() -> str:
    return secrets.token_urlsafe(32)


class MCPOAuthProxy(BaseHTTPRequestHandler):
    # HTTP/1.1 para que Claude.ai pueda reusar conexiones correctamente
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        print(f"[proxy] {self.command:6} {self.path:<55} {fmt % args}")

    # ── helpers ────────────────────────────────────────────────────────────

    def _read_body(self) -> bytes:
        n = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(n) if n else b""

    def _send_json(self, data, status: int = 200):
        body = json.dumps(data, indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, body_html: str, status: int = 200):
        body = body_html.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _redirect(self, url: str):
        self.send_response(302)
        self.send_header("Location", url)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def handle(self):
        # Suprimir BrokenPipeError cuando Claude.ai cierra la conexión prematuramente
        try:
            super().handle()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _proxy_to_gateway(self, path: str, body=None):
        target = f"{WSO2_GATEWAY}{path}"
        is_mcp = "/mcp" in path

        # Construir headers primero (necesitamos Content-Length para actualizar)
        headers = {
            k: v for k, v in self.headers.items()
            if k.lower() not in ("host", "transfer-encoding", "connection")
        }

        # ── Protocol version shim (solo request) ──────────────────────────
        # Claude.ai manda MCP "2025-11-25"; WSO2 APIM 4.6.0 tira error con versiones
        # que no conoce en vez de negociar hacia abajo. Bajamos la versión SOLO en el
        # request. La respuesta sale tal cual (WSO2 negocia a 2025-06-18 y Claude se
        # adapta — negociación estándar del protocolo MCP).
        if is_mcp and body:
            try:
                req_json = json.loads(body)
                if req_json.get("method") == "initialize":
                    params = req_json.get("params", {})
                    orig_client_version = params.get("protocolVersion", "2025-06-18")
                    if orig_client_version != "2025-06-18":
                        params["protocolVersion"] = "2025-06-18"
                        body = json.dumps(req_json, separators=(',', ':')).encode()
                        headers["Content-Length"] = str(len(body))
                        print(f"[proxy] VERSION SHIM REQ: {orig_client_version} → 2025-06-18")
            except (json.JSONDecodeError, KeyError):
                pass

        if is_mcp and body:
            try:
                rj = json.loads(body)
                print(f"[proxy] MCP REQ ▶ method={rj.get('method')!r} id={rj.get('id')!r} | {body.decode()[:200]}")
            except Exception:
                print(f"[proxy] MCP REQ ▶ {body.decode('utf-8', errors='replace')[:250]}")

        req = urllib.request.Request(target, data=body, headers=headers, method=self.command)
        try:
            with urllib.request.urlopen(req, context=SSL_CTX, timeout=30) as resp:
                resp_body = resp.read()
                if is_mcp:
                    print(f"[proxy] MCP RESP ◀ HTTP {resp.status} | {resp_body.decode('utf-8', errors='replace')[:300]}")
                # NO shimear la versión en la respuesta: dejamos que WSO2 negocie a
                # 2025-06-18 y que Claude se adapte (negociación estándar del protocolo).
                self.send_response(resp.status)
                for k, v in resp.getheaders():
                    if k.lower() not in _RESPONSE_HEADERS_STRIP:
                        self.send_header(k, v)
                self.send_header("Content-Length", str(len(resp_body)))
                self.end_headers()
                self.wfile.write(resp_body)
        except urllib.error.HTTPError as exc:
            resp_body = exc.read()
            if is_mcp:
                print(f"[proxy] MCP ERROR ◀ HTTP {exc.code} | {resp_body.decode('utf-8', errors='replace')[:300]}")
            self.send_response(exc.code)
            for k, v in exc.headers.items():
                if k.lower() not in _RESPONSE_HEADERS_STRIP:
                    self.send_header(k, v)
            self.send_header("Content-Length", str(len(resp_body)))
            self.end_headers()
            self.wfile.write(resp_body)
        except Exception as exc:
            print(f"[proxy] ERROR proxy_to_gateway: {exc}")
            self.send_response(502)
            self.send_header("Content-Length", "0")
            self.end_headers()

    # ── OAuth endpoints ────────────────────────────────────────────────────

    def _handle_protected_resource(self):
        self._send_json({
            "resource": f"{NGROK_URL}/trazalog-equipos/1.0/mcp",
            "authorization_servers": [NGROK_URL],
            "bearer_methods_supported": ["header"],
            "scopes_supported": ["openid", "profile"],
        })

    def _handle_auth_server_metadata(self):
        self._send_json({
            "issuer": NGROK_URL,
            "authorization_endpoint": f"{NGROK_URL}/oauth2/authorize",
            "token_endpoint":         f"{NGROK_URL}/oauth2/token",
            "registration_endpoint":  f"{NGROK_URL}/register",
            "jwks_uri":               f"{NGROK_URL}/oauth2/jwks",
            "response_types_supported":          ["code"],
            "grant_types_supported":             ["authorization_code", "client_credentials", "refresh_token"],
            "token_endpoint_auth_methods_supported": ["client_secret_basic", "client_secret_post", "none"],
            "code_challenge_methods_supported":  ["S256", "plain"],
            "scopes_supported":                  ["openid", "profile"],
        })

    def _handle_jwks(self):
        # Tokens son opacos, no JWTs — JWKS vacío es válido
        self._send_json({"keys": []})

    def _handle_register(self, body: bytes):
        try:
            req_data = json.loads(body) if body else {}
        except json.JSONDecodeError:
            req_data = {}

        client_id     = f"claude-{secrets.token_hex(8)}"
        client_secret = secrets.token_urlsafe(24)
        _clients[client_id] = {
            "client_secret": client_secret,
            "redirect_uris": req_data.get("redirect_uris", []),
            "grant_types":   req_data.get("grant_types", ["authorization_code"]),
            "client_name":   req_data.get("client_name", "MCP Client"),
        }
        print(f"[proxy] DCR: nuevo cliente registrado → {client_id}")
        self._send_json({
            "client_id":              client_id,
            "client_secret":          client_secret,
            "client_id_issued_at":    0,
            "client_secret_expires_at": 0,
            "redirect_uris":          _clients[client_id]["redirect_uris"],
            "grant_types":            _clients[client_id]["grant_types"],
            "client_name":            _clients[client_id]["client_name"],
            "token_endpoint_auth_method": "client_secret_basic",
        }, status=201)

    def _handle_authorize(self, qs: str):
        params      = urllib.parse.parse_qs(qs)
        redirect_uri   = params.get("redirect_uri",  [""])[0]
        state          = params.get("state",          [""])[0]
        client_id      = params.get("client_id",      ["?"])[0]
        code_challenge = params.get("code_challenge", [""])[0]

        client_name = _clients.get(client_id, {}).get("client_name", client_id)

        code = _make_token()
        _codes[code] = {
            "client_id":      client_id,
            "redirect_uri":   redirect_uri,
            "code_challenge": code_challenge,
        }
        print(f"[proxy] AUTHORIZE: client={client_id} → code generado, mostrando consent")

        safe_name  = html.escape(client_name)
        safe_code  = html.escape(code)
        safe_state = html.escape(state)
        safe_redir = html.escape(redirect_uri)

        self._send_html(f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Trazalog v3 — Autorizar acceso MCP</title>
<style>
  body {{ font-family: system-ui, sans-serif; max-width: 480px; margin: 80px auto;
          padding: 0 20px; color: #1a1a2e; background: #f4f6fb; }}
  .card {{ background: #fff; border: 1px solid #dde3ee; border-radius: 14px;
           padding: 36px; box-shadow: 0 4px 20px rgba(0,0,0,.06); }}
  .logo {{ font-size: 1.6rem; font-weight: 700; color: #1565c0; margin-bottom: 4px; }}
  .sub  {{ color: #888; font-size: .85rem; margin-bottom: 28px; }}
  h2   {{ margin: 0 0 8px; font-size: 1.15rem; color: #222; }}
  p    {{ color: #555; font-size: .9rem; margin: 0 0 24px; }}
  .badge {{ display: inline-block; background: #fff3e0; color: #e65100;
             padding: 3px 10px; border-radius: 20px; font-size: .75rem;
             margin-bottom: 18px; font-weight: 600; }}
  button {{ background: #1565c0; color: #fff; border: none; border-radius: 8px;
            padding: 13px; font-size: 1rem; cursor: pointer; width: 100%;
            font-weight: 600; letter-spacing: .02em; }}
  button:hover {{ background: #0d47a1; }}
  .note {{ font-size: .72rem; color: #aaa; margin-top: 14px; text-align: center; }}
</style>
</head>
<body>
<div class="card">
  <div class="logo">Trazalog v3</div>
  <div class="sub">MCP Server — Equipos &amp; Órdenes de Trabajo</div>
  <span class="badge">DEV / DEMO</span>
  <h2>Autorizar acceso</h2>
  <p><strong>{safe_name}</strong> solicita acceso al MCP Server de Trazalog v3
     para consultar equipos y crear órdenes de trabajo.</p>
  <form method="GET" action="/oauth2/authorize/allow">
    <input type="hidden" name="code"         value="{safe_code}">
    <input type="hidden" name="state"        value="{safe_state}">
    <input type="hidden" name="redirect_uri" value="{safe_redir}">
    <button type="submit">Permitir acceso</button>
  </form>
  <p class="note">Entorno de desarrollo · sin autenticación real</p>
</div>
</body>
</html>""")

    def _handle_authorize_allow(self, qs: str):
        params       = urllib.parse.parse_qs(qs)
        code         = params.get("code",         [""])[0]
        state        = params.get("state",        [""])[0]
        redirect_uri = params.get("redirect_uri", [""])[0]

        if not redirect_uri:
            self._send_html("<p>Error: falta redirect_uri</p>", 400)
            return

        sep = "&" if "?" in redirect_uri else "?"
        location = f"{redirect_uri}{sep}code={urllib.parse.quote(code, safe='')}"
        if state:
            location += f"&state={urllib.parse.quote(state, safe='')}"

        print(f"[proxy] ALLOW → redirect a Claude.ai con code={code[:12]}...")
        self._redirect(location)

    def _handle_token(self, body: bytes):
        body_str = body.decode(errors="replace")
        params    = urllib.parse.parse_qs(body_str)
        grant_type = params.get("grant_type", [""])[0]

        print(f"[proxy] TOKEN: grant_type={grant_type}")

        if grant_type == "authorization_code":
            code = params.get("code", [""])[0]
            if code not in _codes:
                print(f"[proxy] TOKEN ERROR: code inválido o expirado")
                self._send_json({"error": "invalid_grant", "error_description": "Code not found or expired"}, 400)
                return
            client_id = _codes.pop(code)["client_id"]

        elif grant_type == "client_credentials":
            client_id = params.get("client_id", ["demo"])[0]

        elif grant_type == "refresh_token":
            client_id = "refresh-client"

        else:
            self._send_json({"error": "unsupported_grant_type"}, 400)
            return

        token   = _make_token()
        refresh = _make_token()
        _tokens[token] = {"client_id": client_id}
        print(f"[proxy] TOKEN OK: client={client_id} token={token[:12]}...")

        self._send_json({
            "access_token":  token,
            "token_type":    "bearer",
            "expires_in":    3600,
            "refresh_token": refresh,
            "scope":         "openid profile",
        })

    # ── routing ────────────────────────────────────────────────────────────

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin",  "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path   = parsed.path
        qs     = parsed.query

        if path in (
            "/.well-known/oauth-protected-resource",
            "/.well-known/oauth-protected-resource/trazalog-equipos/1.0/mcp",
        ):
            self._handle_protected_resource()

        elif path in (
            "/.well-known/oauth-authorization-server",
            "/.well-known/openid-configuration",
            "/oauth2/token/.well-known/openid-configuration",
        ):
            self._handle_auth_server_metadata()

        elif path == "/oauth2/jwks":
            self._handle_jwks()

        elif path == "/oauth2/authorize":
            self._handle_authorize(qs)

        elif path == "/oauth2/authorize/allow":
            self._handle_authorize_allow(qs)

        else:
            self._proxy_to_gateway(self.path)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path   = parsed.path
        body   = self._read_body()

        # Log ALL MCP POST requests (method + id) antes de cualquier procesamiento
        if "/mcp" in path and body:
            try:
                msg = json.loads(body)
                print(f"[proxy] ▶ POST {path} | method={msg.get('method')!r} id={msg.get('id')!r}")
            except Exception:
                print(f"[proxy] ▶ POST {path} | (body no-JSON len={len(body)})")

        if path in ("/register", "/oauth2/register"):
            self._handle_register(body)

        elif path == "/oauth2/token":
            self._handle_token(body)

        else:
            self._proxy_to_gateway(self.path, body=body)


# ── main ───────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    print("=" * 60)
    print("  MCP OAuth Proxy — DEV/DEMO")
    print("=" * 60)
    print(f"  Puerto local  : {PROXY_PORT}")
    print(f"  URL externa   : {NGROK_URL}")
    print(f"  Gateway WSO2  : {WSO2_GATEWAY}")
    print()
    print("  ╔══════════════════════════════════════════════╗")
    print("  ║  ACCIÓN REQUERIDA EN CLAUDE.AI               ║")
    print("  ║                                              ║")
    print(f"  ║  Connector → editar → OAuth Client ID:       ║")
    print(f"  ║  {DEMO_CLIENT_ID:<44}║")
    print("  ╚══════════════════════════════════════════════╝")
    print()
    print("  Después de ingresar el Client ID, Claude.ai")
    print("  abrirá una página de consent en el browser.")
    print("  Hacer click en 'Permitir acceso'.")
    print()
    print("  Ctrl+C para detener")
    print("=" * 60)

    server = HTTPServer(("0.0.0.0", PROXY_PORT), MCPOAuthProxy)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[proxy] Detenido.")
