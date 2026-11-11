"""Simulador de COREDataService para probar toolsMCPAPI en una copia del MI.

Uso (terminal local, en una carpeta temporal, NO dentro del repo):
    python3 -I scripts/dev/simulador-core-ds.py 18766
La copia del MI tiene que apuntar a http://127.0.0.1:18766/services
(registry/config/tools/apiconfig.xml). Lo usa tests/security/mcp-alta-configuracion.hurl.


Imita SOLO los recursos que usan las tres altas de Kuntur, con las formas de
respuesta de WSO2 (fila unica = objeto, no lista). Guarda cada llamada en
llamadas.jsonl (o SIMULADOR_LOG) para verificar que el MI mando lo correcto.
Empresa 42 tiene el establecimiento 7; la 99 tiene el 1. El valor
"Provocar error" en una lista responde 500, como un error de SQL.
Las listas imitan el disparador core.set_tabla_id_trg de DEV.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

LOG = Path(os.environ.get("SIMULADOR_LOG", "llamadas.jsonl"))  # en la carpeta actual
ESTAS = {"42": [{"esta_id": "7", "nombre": "Planta Norte"}], "99": [{"esta_id": "1", "nombre": "Ajena"}]}
TABLAS = {}  # (empr, lista) -> [{"tabl_id","valor"}]


class H(BaseHTTPRequestHandler):
    def _r(self, cuerpo, code=200):
        b = json.dumps(cuerpo).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _log(self, cuerpo=None):
        with LOG.open("a") as f:
            f.write(json.dumps({"m": self.command, "p": self.path, "b": cuerpo}) + "\n")

    def do_GET(self):
        self._log()
        partes = self.path.split("?")[0].strip("/").split("/")
        # services/COREDataService/establecimientos/{empr}
        if partes[2:3] == ["establecimientos"]:
            l = ESTAS.get(partes[3], [])
            fila = l[0] if len(l) == 1 else l  # WSO2: una sola fila viene como objeto
            return self._r({"establecimientos": {"establecimiento": fila}} if l else {"establecimientos": {}})
        # services/COREDataService/tabla/{lista}/empresa/{empr}
        if partes[2:3] == ["tabla"]:
            l = TABLAS.get((partes[5], partes[3]), [])
            fila = l[0] if len(l) == 1 else l
            return self._r({"tablas": {"tabla": fila}} if l else {"tablas": {}})
        self._r({"error": "no simulado"}, 404)

    def do_POST(self):
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            crudo = b""
            while True:
                largo = int(self.rfile.readline().strip().split(b";")[0], 16)
                if largo == 0:
                    self.rfile.readline()
                    break
                crudo += self.rfile.read(largo)
                self.rfile.readline()
        else:
            crudo = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        cuerpo = json.loads(crudo or b"{}")
        self._log(cuerpo)
        if self.path.endswith("/COREDataService/tablas"):
            t = cuerpo["_post_tablas"]
            if t["valor"] == "Provocar error":  # como un error de SQL del servicio de datos
                return self._r({"Fault": {"faultstring": "duplicate key value violates unique constraint"}}, 500)
            # Como el disparador core.set_tabla_id_trg de DEV: tabla = empr-tabla, tabl_id = tabla+valor
            tabla = f'{t["empr_id"]}-{t["tabla"]}'
            TABLAS.setdefault((t["empr_id"], t["tabla"]), []).append({"tabl_id": tabla + t["valor"], "valor": t["valor"]})
            return self._r({"GeneratedKeys": {"Entry": [{"ID": tabla + t["valor"]}]}})
        if self.path.endswith("/COREDataService/establecimiento"):
            return self._r({"GeneratedKeys": {"Entry": [{"ID": "501"}]}})
        if self.path.endswith("/COREDataService/deposito/establecimiento"):
            return self._r({"GeneratedKeys": {"Entry": [{"ID": "601"}]}})
        self._r({"error": "no simulado"}, 404)

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    LOG.write_text("")
    HTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 18766), H).serve_forever()
