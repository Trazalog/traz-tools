"""Simulador de los servicios de datos que usan las escrituras del plan de acción
(toolsMCPAPI: tar_alta_pedido, tar_alta_hito, tar_alta_tarea, tar_baja_pedido,
tar_baja_tarea — AGENTE-CO-04), para probarlas en una copia del MI sin base ni DEV.

Uso (terminal local, en una carpeta temporal, NO dentro del repo):
    python3 -I scripts/dev/simulador-plan-ds.py 18778
La copia del MI tiene que apuntar a http://127.0.0.1:18778/services
(registry/config/tools/apiconfig.xml). Lo usa tests/security/mcp-plan-accion.hurl.

Imita SOLO los recursos que llaman esas cinco escrituras, con las formas de
respuesta de WSO2 (fila única = objeto, no lista) y el filtro por empresa que
tienen desde #640/#645:
  * empresa 42: cliente 5, tipo de pedido General, establecimiento 3, y un
    pedido 171 de un proceso propio (no Estándar) para probar el rechazo;
  * empresa 99: pedido 170 del Proceso Estándar con el hito 909;
  * empresa 77: sin clientes ni establecimientos.
Disparadores de error: una descripción de pedido o un nombre de tarea con
"Provocar error" responde 500; una tarea llamada "Falla origen" hace fallar el
vínculo con el hito (para probar que la tarea se da de baja).
Guarda cada llamada (método, ruta y cuerpo) en llamadas.jsonl (o SIMULADOR_LOG).
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

LOG = Path(os.environ.get("SIMULADOR_LOG", "llamadas.jsonl"))

CLIENTES = {"42": [{"clie_id": "5", "nombre": "Minera Norte", "estado": "ACTIVO"}],
            "99": [{"clie_id": "50", "nombre": "Ajena SA", "estado": "ACTIVO"}]}
ESTABLECIMIENTOS = {"42": [{"esta_id": "3", "nombre": "Planta"}], "99": [{"esta_id": "30", "nombre": "Ajena"}]}
UMTI = [{"tabl_id": "unidad_medida_tiempoHoras", "valor": "Horas"},
        {"tabl_id": "unidad_medida_tiempoDias", "valor": "Días"},
        {"tabl_id": "unidad_medida_tiempoSemanas", "valor": "Semanas"}]
PEDIDOS = {  # petr_id -> pedido
    "170": {"petr_id": "170", "empr_id": "99", "proc_id": "PROCESO-STANDAR", "eliminado": False},
    "171": {"petr_id": "171", "empr_id": "42", "proc_id": "YUDICA-PROCESO", "eliminado": False},
}
HITOS = {"909": {"hito_id": "909", "petr_id": "170", "nro": "1", "numero": "H01", "descripcion": "Ajeno"}}
TAREAS = {}
SIG = {"petr": 500, "hito": 900, "tapl": 7000}


def _uno_o_lista(l):
    return l[0] if len(l) == 1 else l  # WSO2: una sola fila viene como objeto


def _nuevo(clave):
    SIG[clave] += 1
    return str(SIG[clave])


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):  # silencio en la consola
        pass

    def _cuerpo(self):
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            datos = b""
            while True:
                tam = int(self.rfile.readline().strip().split(b";")[0], 16)
                if tam == 0:
                    self.rfile.readline()
                    break
                datos += self.rfile.read(tam)
                self.rfile.readline()
        else:
            datos = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        try:
            return json.loads(datos or b"{}")
        except ValueError:
            return {"_crudo": datos.decode("utf-8", "replace")}

    def _r(self, cuerpo=None, code=200):
        b = json.dumps(cuerpo).encode() if cuerpo is not None else b""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _log(self, metodo, cuerpo=None):
        with LOG.open("a") as f:
            f.write(json.dumps({"m": metodo, "p": self.path, "b": cuerpo}, ensure_ascii=False) + "\n")

    def _partes(self):
        u = urlsplit(self.path)
        q = {k: v[0] for k, v in parse_qs(u.query, keep_blank_values=True).items()}
        return [unquote(p) for p in u.path.split("/")][2:], q  # [DS, ...]

    # ------------------------------------------------------------------ GET
    def do_GET(self):
        self._log("GET")
        p, q = self._partes()
        if p[:3] == ["COREDataService", "clientes", "porEmpresa"]:
            l = CLIENTES.get(p[3], [])
            return self._r({"cliente": {"clientes": _uno_o_lista(l)} if l else {}})
        if p[:3] == ["COREDataService", "tabla", "tipos_pedidos_trabajo"]:
            empr = p[4]
            if empr == "77":
                return self._r({"tablas": {}})
            return self._r({"tablas": {"tabla": {"tabl_id": f"{empr}-tipos_pedidos_trabajoGeneral", "valor": "General"}}})
        if p[:3] == ["COREDataService", "tablas", "unidad_medida_tiempo"]:
            return self._r({"tablas": {"tabla": UMTI}})
        if p[:2] == ["COREDataService", "establecimientos"]:
            l = ESTABLECIMIENTOS.get(p[2], [])
            return self._r({"establecimientos": {"establecimiento": _uno_o_lista(l)} if l else {}})
        if p[:2] == ["PRODataService", "pedidoTrabajo"] and len(p) == 4:
            empr, clave = p[2], p[3]
            l = [x for x in PEDIDOS.values() if x["empr_id"] == empr and not x["eliminado"] and clave in x["petr_id"]]
            return self._r({"pedidos_trabajo": {"pedido_trabajo": _uno_o_lista(l)} if l else {}})
        if p[:3] == ["TARDataService", "pedidostrabajo", "hitos"]:
            petr, empr = p[3], q.get("empr_id", "")
            ped = PEDIDOS.get(petr)
            l = [h for h in HITOS.values() if h["petr_id"] == petr] if ped and ped["empr_id"] == empr else []
            return self._r({"hitos": {"hito": _uno_o_lista(l)} if l else {}})
        if p[:2] == ["TARDataService", "hitos"] and len(p) == 3:
            h = HITOS.get(p[2])
            ok = h is not None and PEDIDOS.get(h["petr_id"], {}).get("empr_id") == q.get("empr_id", "")
            return self._r({"hitos": {"hito": h} if ok else {}})
        return self._r({"error": "ruta no simulada"}, 404)

    # ----------------------------------------------------------------- POST
    def do_POST(self):
        b = self._cuerpo()
        self._log("POST", b)
        p, _ = self._partes()
        if p == ["PRODataService", "pedidoTrabajo"]:
            d = b.get("_post_pedidotrabajo", {})
            if "Provocar error" in str(d.get("descripcion", "")):
                return self._r({"Fault": {"faultstring": "error de SQL simulado"}}, 500)
            petr = _nuevo("petr")
            PEDIDOS[petr] = {"petr_id": petr, "empr_id": str(d.get("empr_id")), "proc_id": d.get("proc_id"), "eliminado": False}
            return self._r({"respuesta": {"petr_id": petr}})
        if p == ["TARDataService", "hitos"]:
            d = b.get("_post_hitos", {})
            petr = str(d.get("petr_id"))
            nro = str(1 + sum(1 for h in HITOS.values() if h["petr_id"] == petr))
            hid = _nuevo("hito")
            HITOS[hid] = {"hito_id": hid, "petr_id": petr, "nro": nro, "numero": d.get("numero"), "descripcion": d.get("descripcion")}
            return self._r(None, 202)
        if p == ["TARDataService", "tarea", "planificar"]:
            d = b.get("_post_tarea_planificar", {})
            if "Provocar error" in str(d.get("nombre", "")):
                return self._r({"Fault": {"faultstring": "error de SQL simulado"}}, 500)
            tapl = _nuevo("tapl")
            TAREAS[tapl] = {"tapl_id": tapl, "nombre": d.get("nombre"), "empr_id": str(d.get("empr_id")), "eliminado": False}
            return self._r({"respuesta": {"tapl_id": tapl}})
        if p == ["TARDataService", "tarea", "origen"]:
            d = b.get("_post_tarea_origen", {})
            if TAREAS.get(str(d.get("tapl_id")), {}).get("nombre") == "Falla origen":
                return self._r({"Fault": {"faultstring": "error de SQL simulado en origen"}}, 500)
            return self._r(None, 202)
        return self._r({"error": "ruta no simulada"}, 404)

    # --------------------------------------------------------------- DELETE
    def do_DELETE(self):
        b = self._cuerpo()
        self._log("DELETE", b)
        p, _ = self._partes()
        if p == ["PRODataService", "pedidoTrabajo"]:
            d = b.get("_delete_pedidotrabajo", {})
            ped = PEDIDOS.get(str(d.get("petr_id")))
            if ped and ped["empr_id"] == str(d.get("empr_id")):  # #640: filtra por empresa
                ped["eliminado"] = True
            return self._r(None, 202)
        if p == ["TARDataService", "tarea", "planificar"]:
            d = b.get("delete_tarea_planificar", {})
            t = TAREAS.get(str(d.get("tapl_id")))
            if t and t["empr_id"] == str(d.get("empr_id")):
                t["eliminado"] = True
            return self._r(None, 202)
        return self._r({"error": "ruta no simulada"}, 404)


if __name__ == "__main__":
    puerto = int(sys.argv[1]) if len(sys.argv) > 1 else 18778
    HTTPServer(("127.0.0.1", puerto), H).serve_forever()
