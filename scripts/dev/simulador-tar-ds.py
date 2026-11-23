"""Simulador de PRODataService y TARDataService para probar la lectura de Tareas
de toolsMCPAPI (tar_get_*) en una copia del MI, sin base ni DEV.

Uso (terminal local, en una carpeta temporal, NO dentro del repo):
    python3 -I scripts/dev/simulador-tar-ds.py 18777
La copia del MI tiene que apuntar a http://127.0.0.1:18777/services
(registry/config/tools/apiconfig.xml). Lo usa tests/security/mcp-tar-lectura.hurl.

Imita SOLO los recursos que usan las cuatro tools, con las formas de respuesta
de WSO2 (fila única = objeto, no lista) y el filtro por empresa que tienen
desde #640/#645: la empresa 42 tiene los pedidos 17 (en curso) y 18
(finalizado); la 99 tiene el 170. El pedido 17 tiene dos hitos (3 y 4).
El texto de búsqueda "Provocar error" responde 500, como un error de SQL.
Guarda cada llamada en llamadas.jsonl (o SIMULADOR_LOG).
"""
import json
import os
import sys
from datetime import date, timedelta
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

LOG = Path(os.environ.get("SIMULADOR_LOG", "llamadas.jsonl"))


def _pedido(petr_id, empr, estado, cliente):
    return {"petr_id": str(petr_id), "cod_proyecto": f"PT-{petr_id}", "descripcion": f"Pedido {petr_id}",
            "estado": estado, "objetivo": "", "fec_inicio": "2026-11-01", "fec_entrega": "2026-11-30",
            "usuario": "x", "proc_id": "PROCESO-STANDAR", "empr_id": str(empr), "clie_id": "1",
            "nombre": cliente, "tipo_trabajo": "General", "tipt_id": "t", "dir_entrega": ""}


PEDIDOS = {
    "42": [_pedido(17, 42, "estados_procesosPROC_EN_CURSO", "Minera Norte"),
           _pedido(18, 42, "estados_procesosFINALIZADO", "Minera Norte")],
    "99": [_pedido(170, 99, "estados_procesosPROC_EN_CURSO", "Ajena SA")],
}
HACE3 = (date.today() - timedelta(days=3)).strftime("%d-%m-%Y")


def _tarea(tapl_id, estado, user, fecha):
    return {"tapl_id": str(tapl_id), "nombre": f"Tarea {tapl_id}", "user_id": user, "info_id": "", "case_id": "",
            "tare_id": "", "fecha": fecha, "fec_inicio": "31-12-3000+00:00:00", "fec_fin": "31-12-3000+00:00:00",
            "proc_id": "TST001", "form_id": "", "rece_id": "", "estado": estado, "descripcion": "", "duracion": "1"}


TAREAS = {  # (empr, hito) -> tareas
    ("42", "3"): [_tarea(10, "creada", "", "31-12-3000"), _tarea(11, "iniciada", "juan", HACE3)],
    ("42", "4"): [_tarea(12, "finalizada", "ana", HACE3)],
    ("99", "9"): [_tarea(90, "creada", "pepe", HACE3)],
}
HITOS = {"17": [("3", "1", "Preventivos"), ("4", "2", "Medir")], "170": [("9", "1", "Ajeno")]}


def _uno_o_lista(l):
    return l[0] if len(l) == 1 else l  # WSO2: una sola fila viene como objeto


class H(BaseHTTPRequestHandler):
    def _r(self, cuerpo, code=200):
        b = json.dumps(cuerpo).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        u = urlsplit(self.path)
        q = {k: v[0] for k, v in parse_qs(u.query, keep_blank_values=True).items()}
        partes = [unquote(p) for p in u.path.split("/")]  # ['', 'services', DS, ...]
        with LOG.open("a") as f:
            f.write(json.dumps({"m": "GET", "p": self.path}) + "\n")
        ds, resto = partes[2], partes[3:]
        # PRODataService/pedidoTrabajo/{empr}/{clave}
        if ds == "PRODataService" and resto[:1] == ["pedidoTrabajo"] and len(resto) == 3:
            empr, clave = resto[1], resto[2].upper()
            if clave == "PROVOCAR ERROR":
                return self._r({"Fault": {"faultstring": "error de SQL simulado"}}, 500)
            l = [p for p in PEDIDOS.get(empr, []) if clave in (p["petr_id"] + p["nombre"].upper() + p["estado"].upper()
                                                              + p["cod_proyecto"].upper()) or clave == "%"]
            return self._r({"pedidos_trabajo": {"pedido_trabajo": _uno_o_lista(l)}} if l else {"pedidos_trabajo": {}})
        # TARDataService/pedidostrabajo/hitos/{petr}?empr_id=
        if ds == "TARDataService" and resto[:2] == ["pedidostrabajo", "hitos"]:
            empr, petr = q.get("empr_id", ""), resto[2]
            if not any(p["petr_id"] == petr for p in PEDIDOS.get(empr, [])):
                return self._r({"hitos": {}})
            hs = []
            for hito_id, nro, desc in HITOS.get(petr, []):
                ts = TAREAS.get((empr, hito_id), [])
                hs.append({"nro": nro, "numero": f"H{nro}", "descripcion": desc, "fec_inicio": "", "user_id": "",
                           "objetivo": "", "unidad_tiempo": "", "esta_id": "", "documento": "", "petr_id": petr,
                           "hito_id": hito_id, "tareas": {"tarea": _uno_o_lista(ts)} if ts else {}})
            return self._r({"hitos": {"hito": _uno_o_lista(hs)}} if hs else {"hitos": {}})
        # TARDataService/tareas/planificar/PETR/{orta_id}?empr_id=
        if ds == "TARDataService" and resto[:3] == ["tareas", "planificar", "PETR"]:
            empr, orta = q.get("empr_id", ""), (resto[3] if len(resto) > 3 else "")
            ts = [t for (e, h), l in TAREAS.items() if e == empr and (orta == "" or orta == h) for t in l]
            return self._r({"tareas": {"tarea": _uno_o_lista(ts)}} if ts else {"tareas": {}})
        self._r({"error": "no simulado", "path": self.path}, 404)

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    LOG.write_text("")
    HTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 18777), H).serve_forever()
