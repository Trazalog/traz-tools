#!/usr/bin/env python3
"""
Cliente de las tools MCP contra el MI local, para pruebas encadenadas.

Llama a `toolsMCPAPI` (la fachada real, con identidad) inyectando el header
`X-JWT-Assertion` igual que lo haría el gateway del APIM. La sequence
`emprIdFromHeader` del MI decodifica ese JWT y deriva `empr_id` /
`empr_id_mysql`, así que las tools se ejercitan por el mismo camino que en
producción — incluido el aislamiento multi-tenant.

No firma el token: el MI decodifica la assertion sin validar la firma (es el
gateway el que la valida en el flujo real). Por eso esto sirve para DEV
únicamente.

Uso como librería:
    from mcp_tools_client import MCP
    mcp = MCP(empr_id=1, empr_id_mysql=1)
    stock = mcp.alm_get_stock()

Uso por consola:
    python3 scripts/dev/mcp_tools_client.py alm_get_stock
    python3 scripts/dev/mcp_tools_client.py man_get_equipo 131
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

MI_URL = os.environ.get("MI_URL", "http://localhost:8290")
BASE = f"{MI_URL}/tools/mcp/mcp"


def _b64url(d: bytes) -> str:
    return base64.urlsafe_b64encode(d).decode().rstrip("=")


def make_assertion(empr_id, empr_id_mysql=None, sub="test@trazalog.dev"):
    """Arma un X-JWT-Assertion con los claims que lee emprIdFromHeader."""
    header = {"alg": "RS256", "typ": "JWT", "kid": "dev-test"}
    payload = {
        "iss": "trazalog-dnato",
        "sub": sub,
        "aud": "trazalog-mcp",
        "empr_id": str(empr_id),
        "empr_id_mysql": str(empr_id_mysql if empr_id_mysql is not None else ""),
    }
    return ".".join([
        _b64url(json.dumps(header).encode()),
        _b64url(json.dumps(payload).encode()),
        _b64url(b"dev-signature-not-validated-by-mi"),
    ])


class ToolError(Exception):
    def __init__(self, tool, status, body):
        self.tool, self.status, self.body = tool, status, body
        super().__init__(f"{tool} -> HTTP {status}: {str(body)[:300]}")


class MCP:
    """Cada método es una tool. Devuelve el JSON parseado o levanta ToolError."""

    def __init__(self, empr_id, empr_id_mysql=None, sub="test@trazalog.dev"):
        self.empr_id = empr_id
        self.empr_id_mysql = empr_id_mysql
        self.assertion = make_assertion(empr_id, empr_id_mysql, sub)
        self.calls = []          # traza de lo invocado, para los reportes

    # ---------------------------------------------------------------- interno
    def _call(self, method, path, body=None, tool=None):
        url = BASE + path
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("X-JWT-Assertion", self.assertion)
        req.add_header("Accept", "application/json")
        if data:
            req.add_header("Content-Type", "application/json")
        name = tool or path
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read().decode("utf-8", "replace")
                status = r.status
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            status = e.code
        except Exception as e:
            self.calls.append((name, "ERR", str(e)[:120]))
            raise ToolError(name, 0, str(e))
        self.calls.append((name, status, raw[:120]))
        try:
            parsed = json.loads(raw) if raw.strip() else {}
        except json.JSONDecodeError:
            raise ToolError(name, status, raw)
        # el MI devuelve 200 con {"respuesta":{"codigo":"1000",...}} en errores
        if isinstance(parsed, dict) and "respuesta" in parsed and \
           isinstance(parsed["respuesta"], dict) and parsed["respuesta"].get("error"):
            raise ToolError(name, status, parsed["respuesta"])
        if status >= 400:
            raise ToolError(name, status, parsed)
        return parsed

    # ------------------------------------------------------------ mantenimiento
    def man_get_equipos(self):
        return self._call("GET", "/man/equipos", tool="man_get_equipos")

    def man_get_equipo(self, equi_id):
        return self._call("GET", f"/man/equipo/{equi_id}", tool="man_get_equipo")

    def man_get_ots(self, estado=None):
        q = f"?estado={estado}" if estado else ""
        return self._call("GET", f"/man/ot{q}", tool="man_get_ots")

    def man_get_ot(self, id_solicitud):
        return self._call("GET", f"/man/ot/{id_solicitud}", tool="man_get_ot")

    def man_get_lecturas(self):
        return self._call("GET", "/man/lecturas", tool="man_get_lecturas")

    def man_get_preventivos(self):
        return self._call("GET", "/man/preventivos", tool="man_get_preventivos")

    def man_create_ot(self, equipo_id, descripcion):
        return self._call("POST", "/man/ot",
                          {"equipo_id": str(equipo_id), "descripcion": descripcion},
                          tool="man_create_ot")

    # ---------------------------------------------------------------- almacenes
    def alm_get_stock(self, depo_id=None, tipo=None, buscar=None):
        """Filtros opcionales: sin ninguno devuelve el catálogo completo."""
        q = []
        if depo_id: q.append(f"depo_id={depo_id}")
        if tipo:    q.append(f"tipo={urllib.parse.quote(str(tipo))}")
        if buscar:  q.append(f"buscar={urllib.parse.quote(str(buscar))}")
        qs = ("?" + "&".join(q)) if q else ""
        return self._call("GET", f"/alm/stock{qs}", tool="alm_get_stock")

    def _qs(self, **kw):
        q = [f"{k}={urllib.parse.quote(str(v))}" for k, v in kw.items() if v]
        return ("?" + "&".join(q)) if q else ""

    def alm_get_movimientos(self, tipo=None, desde=None, hasta=None,
                            depo_id=None, arti_id=None, lote_id=None):
        """Historial de stock. Sin desde/hasta devuelve TODO el historico."""
        qs = self._qs(tipo=tipo, desde=desde, hasta=hasta,
                      depo_id=depo_id, arti_id=arti_id, lote_id=lote_id)
        return self._call("GET", "/alm/movimientos" + qs, tool="alm_get_movimientos")

    def alm_get_entregas(self, desde=None, hasta=None, obra=None, depo_id=None):
        qs = self._qs(desde=desde, hasta=hasta, obra=obra, depo_id=depo_id)
        return self._call("GET", "/alm/entregas" + qs, tool="alm_get_entregas")

    def alm_get_movimientos_internos(self, estado=None, origen=None,
                                     destino=None, moin_id=None):
        qs = self._qs(estado=estado, origen=origen, destino=destino, moin_id=moin_id)
        return self._call("GET", "/alm/movimientos-internos" + qs,
                          tool="alm_get_movimientos_internos")

    def alm_get_vencimientos(self):
        return self._call("GET", "/alm/vencimientos", tool="alm_get_vencimientos")

    def alm_get_depositos(self):
        return self._call("GET", "/alm/depositos", tool="alm_get_depositos")

    def alm_get_pedidos_materiales(self):
        return self._call("GET", "/alm/pedidos", tool="alm_get_pedidos_materiales")

    def alm_get_pedido_material(self, pema_id):
        return self._call("GET", f"/alm/pedido/{pema_id}", tool="alm_get_pedido_material")

    def alm_crear_pedido_materiales(self, articulos, justificacion, ortr_id=None):
        body = {"justificacion": justificacion, "articulos": articulos}
        if ortr_id:
            body["ortr_id"] = str(ortr_id)
        return self._call("POST", "/alm/pedido", body,
                          tool="alm_crear_pedido_materiales")


# ------------------------------------------------------------------ helpers
def lista(resp, *camino):
    """Extrae una lista de una respuesta anidada, tolerando el wrapper vacío {}.

    Los DataServices devuelven {"materias":{"materia":[...]}} con datos, pero
    {"materias":{}} cuando no hay ninguno — y un objeto suelto (no lista)
    cuando hay exactamente uno.
    """
    cur = resp
    for k in camino:
        if not isinstance(cur, dict):
            return []
        cur = cur.get(k)
        if cur is None:
            return []
    if isinstance(cur, list):
        return cur
    return [cur] if cur else []


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    empr = int(os.environ.get("EMPR_ID", "1"))
    empr_my = int(os.environ.get("EMPR_ID_MYSQL", "1"))
    m = MCP(empr, empr_my)
    fn = getattr(m, sys.argv[1], None)
    if fn is None:
        print(f"tool desconocida: {sys.argv[1]}")
        sys.exit(1)
    try:
        print(json.dumps(fn(*sys.argv[2:]), indent=2, ensure_ascii=False)[:4000])
    except ToolError as e:
        print(f"ERROR {e}")
        sys.exit(1)
