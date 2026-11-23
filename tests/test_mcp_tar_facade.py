"""Lectura de Tareas en la fachada MCP (AGENTE-TAR-01).

Los recursos /mcp/tar/* de toolsMCPAPI.xml arman y filtran la respuesta con
scripts JavaScript del mediador. Este test los saca del XML y los corre en
Node con un `mc` de mentira, alimentándolos con respuestas con la forma real
de PRODataService y TARDataService. No reemplaza la prueba en un MI (ver
tests/security/mcp-tar-lectura.hurl): cubre la lógica (empresa del token,
filtros, 404 de un pedido ajeno, atrasadas).

Se saltea si no hay node.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
from datetime import date, timedelta
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parent.parent
API = RAIZ / "_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/apis/toolsMCPAPI.xml"
NS = "{http://ws.apache.org/ns/synapse}"

pytestmark = pytest.mark.skipif(not shutil.which("node"), reason="Hace falta node")


def _scripts(uri: str) -> list[str]:
    """Los scripts del inSequence del recurso, en orden, sin los de vaciar el
    cuerpo ni los que arman el error del servicio de datos."""
    raiz = ET.parse(API).getroot()
    for r in raiz.iter(f"{NS}resource"):
        if r.get("uri-template") == uri:
            seq = r.find(f"{NS}inSequence")
            out = []
            for s in seq.iter(f"{NS}script"):
                cod = s.text or ""
                if cod.strip() == "mc.setPayloadJSON({});":
                    continue
                if '"servicio_de_datos"' in cod:
                    continue
                out.append(cod)
            return out
    raise AssertionError(f"no está el recurso {uri}")


def _correr(pasos: list, props: dict) -> tuple[dict, object]:
    """pasos: ('js', codigo) o ('payload', objeto). Devuelve (propiedades, cuerpo)."""
    js = [
        "var P = " + json.dumps(props) + "; var B = {};",
        "var mc = { getProperty: function (k) { return P.hasOwnProperty(k) ? P[k] : null; },",
        "  setProperty: function (k, v) { P[k] = v; },",
        "  getPayloadJSON: function () { return B; }, setPayloadJSON: function (o) { B = o; } };",
    ]
    for tipo, x in pasos:
        if tipo == "payload":
            js.append("B = " + json.dumps(x) + ";")
        else:
            js.append("(function () {\n" + x + "\n})();")
    js.append("process.stdout.write(JSON.stringify({p: P, b: B}));")
    r = subprocess.run(["node", "-e", "\n".join(js)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    o = json.loads(r.stdout)
    return o["p"], o["b"]


BASE = {"jwt_empr_id": "42", "dataservices_url": "http://ds/services"}


def _pedido(petr_id, estado="estados_procesosPROC_EN_CURSO", **kw):
    p = {"petr_id": str(petr_id), "cod_proyecto": f"PT-{petr_id}", "descripcion": "Reparar pala",
         "estado": estado, "objetivo": "", "fec_inicio": "2026-11-01", "fec_entrega": "2026-11-30",
         "nombre": "Cliente A", "tipo_trabajo": "General", "proc_id": "PROCESO-STANDAR"}
    p.update(kw)
    return p


def _tarea(tapl_id, estado="creada", user_id="", fecha="31-12-3000", fin="31-12-3000+00:00:00"):
    return {"tapl_id": str(tapl_id), "nombre": f"Tarea {tapl_id}", "descripcion": "", "user_id": user_id,
            "estado": estado, "fecha": fecha, "fec_inicio": "31-12-3000+00:00:00", "fec_fin": fin, "duracion": "2"}


# ------------------------------------------------------------ tar_get_pedidos
def test_pedidos_arma_la_ruta_con_la_empresa_del_token():
    s = _scripts("/mcp/tar/pedidos")
    p, _ = _correr([("js", s[0])], {**BASE, "f_buscar": "", "f_todos": ""})
    assert p["tar_error"] == ""
    assert p["uri.var.tar_url"] == "http://ds/services/PRODataService/pedidoTrabajo/42/%25"
    p, _ = _correr([("js", s[0])], {**BASE, "f_buscar": "pala norte", "f_todos": ""})
    assert p["uri.var.tar_url"].endswith("/42/pala%20norte")


@pytest.mark.parametrize("buscar,todos", [("a/b", ""), ("100%", ""), ("x" * 101, ""), ("", "si")])
def test_pedidos_rechaza_parametros_invalidos(buscar, todos):
    p, _ = _correr([("js", _scripts("/mcp/tar/pedidos")[0])], {**BASE, "f_buscar": buscar, "f_todos": todos})
    assert p["tar_error"] != ""


def test_pedidos_saca_los_finalizados_salvo_que_se_pidan():
    s = _scripts("/mcp/tar/pedidos")
    ds = {"pedidos_trabajo": {"pedido_trabajo": [_pedido(1), _pedido(2, "estados_procesosFINALIZADO")]}}
    _, b = _correr([("js", s[0]), ("payload", ds), ("js", s[1])], {**BASE, "f_buscar": "", "f_todos": ""})
    assert [x["petr_id"] for x in b["pedidos"]["pedido"]] == ["1"]
    assert b["pedidos"]["pedido"][0]["estado"] == "proc en curso"
    _, b = _correr([("js", s[0]), ("payload", ds), ("js", s[1])], {**BASE, "f_buscar": "", "f_todos": "true"})
    assert b["total"] == 2 and b["incluye_finalizados"] is True


def test_pedidos_con_una_sola_fila_y_sin_filas():
    s = _scripts("/mcp/tar/pedidos")
    _, b = _correr([("js", s[0]), ("payload", {"pedidos_trabajo": {"pedido_trabajo": _pedido(5)}}), ("js", s[1])],
                   {**BASE, "f_buscar": "", "f_todos": ""})
    assert b["total"] == 1
    _, b = _correr([("js", s[0]), ("payload", {"pedidos_trabajo": {}}), ("js", s[1])],
                   {**BASE, "f_buscar": "", "f_todos": ""})
    assert b["total"] == 0 and b["pedidos"]["pedido"] == []


# ------------------------------------------------------------- tar_get_pedido
def test_pedido_ajeno_no_pide_hitos():
    """La lista de la empresa no trae el pedido: no encontrado (el recurso responde 404)."""
    s = _scripts("/mcp/tar/pedido/{petr_id}")
    ds = {"pedidos_trabajo": {"pedido_trabajo": [_pedido(170), _pedido(1170)]}}   # LIKE '%17%'
    p, _ = _correr([("js", s[0]), ("payload", ds), ("js", s[1])], {**BASE, "uri.var.petr_id": "17"})
    assert p["tar_encontrado"] == "no"
    assert p["uri.var.tar_hitos_url"] == "http://ds/services/TARDataService/pedidostrabajo/hitos/17?empr_id=42"


def test_pedido_rechaza_id_no_numerico():
    p, _ = _correr([("js", _scripts("/mcp/tar/pedido/{petr_id}")[0])], {**BASE, "uri.var.petr_id": "1 or 1=1"})
    assert p["tar_error"] != ""


def test_pedido_con_hitos_y_tareas():
    s = _scripts("/mcp/tar/pedido/{petr_id}")
    lista = {"pedidos_trabajo": {"pedido_trabajo": [_pedido(17), _pedido(170)]}}
    hitos = {"hitos": {"hito": [
        {"hito_id": "3", "nro": "1", "numero": "H1", "descripcion": "Preventivos", "objetivo": "", "fec_inicio": "",
         "user_id": "", "tareas": {"tarea": [_tarea(10, user_id="juan", fecha="05-11-2026"), _tarea(11)]}},
        {"hito_id": "4", "nro": "2", "numero": "H2", "descripcion": "Medir", "objetivo": "", "fec_inicio": "",
         "user_id": "", "tareas": {"tarea": _tarea(12)}},
        {"hito_id": "5", "nro": "3", "numero": "H3", "descripcion": "Vacío", "objetivo": "", "fec_inicio": "",
         "user_id": "", "tareas": {}},
    ]}}
    p, b = _correr([("js", s[0]), ("payload", lista), ("js", s[1]), ("payload", hitos), ("js", s[2])],
                   {**BASE, "uri.var.petr_id": "17"})
    assert p["tar_encontrado"] == "si"
    assert b["pedido"]["petr_id"] == "17"
    assert b["total_hitos"] == 3 and b["total_tareas"] == 3
    t10, t11 = b["hitos"][0]["tareas"]
    assert t10["responsable"] == "juan" and t10["fecha"] == "05-11-2026"
    assert t11["responsable"] == "sin asignar" and t11["fecha"] == "" and t11["fin"] == ""
    assert b["hitos"][2]["tareas"] == []


# ------------------------------------------------------------- tar_get_tareas
def test_tareas_de_toda_la_empresa_o_de_un_hito():
    s = _scripts("/mcp/tar/tareas")
    p, _ = _correr([("js", s[0])], {**BASE, "f_hito": "", "f_estado": ""})
    assert p["uri.var.tar_url"] == "http://ds/services/TARDataService/tareas/planificar/PETR/?empr_id=42"
    p, _ = _correr([("js", s[0])], {**BASE, "f_hito": "3", "f_estado": ""})
    assert p["uri.var.tar_url"] == "http://ds/services/TARDataService/tareas/planificar/PETR/3?empr_id=42"
    p, _ = _correr([("js", s[0])], {**BASE, "f_hito": "3x", "f_estado": ""})
    assert p["tar_error"] != ""


def test_tareas_filtra_por_estado_y_cuenta_sin_responsable():
    s = _scripts("/mcp/tar/tareas")
    ds = {"tareas": {"tarea": [_tarea(1), _tarea(2, "finalizada", "ana"), _tarea(3, "creada", "juan")]}}
    _, b = _correr([("js", s[0]), ("payload", ds), ("js", s[1])], {**BASE, "f_hito": "", "f_estado": "creada"})
    assert [t["tapl_id"] for t in b["tareas"]["tarea"]] == ["1", "3"]
    assert b["sin_responsable"] == 1


# ---------------------------------------------------------- tar_get_atrasadas
def test_atrasadas():
    s = _scripts("/mcp/tar/atrasadas")
    hace5 = (date.today() - timedelta(days=5)).strftime("%d-%m-%Y")
    hace2 = (date.today() - timedelta(days=2)).strftime("%d-%m-%Y")
    manana = (date.today() + timedelta(days=1)).strftime("%d-%m-%Y")
    ds = {"tareas": {"tarea": [
        _tarea(1, "creada", "juan", fecha=hace2),                         # vencida por fecha asignada
        _tarea(2, "iniciada", "ana", fin=f"{hace5}+10:00:00"),             # vencida por fin planificado
        _tarea(3, "finalizada", "ana", fecha=hace5),                      # finalizada: no cuenta
        _tarea(4, "creada", "", fecha=manana),                            # todavía no vence
        _tarea(5, "creada"),                                              # sin fecha: no cuenta
    ]}}
    p, b = _correr([("js", s[0]), ("payload", ds), ("js", s[1])], {**BASE})
    assert p["uri.var.tar_url"].endswith("/tareas/planificar/PETR/?empr_id=42")
    assert [t["tapl_id"] for t in b["atrasadas"]["tarea"]] == ["2", "1"]
    assert b["atrasadas"]["tarea"][0]["dias_atraso"] >= 4
    assert b["total"] == 2
