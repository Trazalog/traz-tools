"""El siguiente paso que propone Quirqui (AGENTE-AS-02).

Reglas sobre los datos de las tools, no el modelo: inmediatas, sin tokens y
con cada cifra salida de una tool.
"""
from __future__ import annotations

import base64
import json
import uuid
from dataclasses import replace
from datetime import date

import pytest
from httpx import ASGITransport, AsyncClient

from agente import rag, sugerencias
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from test_orquestador import MCPFalso, _parchar

HOY = date(2026, 10, 27)
# Las propuestas quedan guardadas (es su gracia): cada corrida de la suite usa
# usuarios propios, asi lo descartado en una corrida no afecta a la siguiente.
CORRIDA = uuid.uuid4().hex[:8]


def _u(nombre: str) -> str:
    return f"{nombre}-{CORRIDA}"

STOCK = {"materias": {"materia": [
    {"id": "5", "titulo": "Filtro de aceite", "stock": "4", "punto_pedido": "10",
     "estado": "AC", "unidad_medida": "UN"},
    {"id": "6", "titulo": "Correa", "stock": "24", "punto_pedido": "10", "estado": "AC"},
    {"id": "7", "titulo": "Sin punto", "stock": "0", "punto_pedido": "0", "estado": "AC"},
    {"id": "8", "titulo": "Dado de baja", "stock": "1", "punto_pedido": "10", "estado": "IN"},
]}}
LOTES = {"vencimientos": {"lote": [
    {"lote_id": "1", "lote": "L-1", "articulo": "Aceite ISO 68", "cantidad": "20", "unidad_medida": "LT",
     "deposito": "Productivo", "fec_vencimiento": "2026-10-20", "estado_vencimiento": "Vencido"},
    {"lote_id": "2", "lote": "L-2", "articulo": "Grasa", "cantidad": "5", "unidad_medida": "KG",
     "fec_vencimiento": "2026-11-02", "estado_vencimiento": "Critico"},
    {"lote_id": "3", "lote": "L-3", "articulo": "Pintura", "fec_vencimiento": "2027-05-01",
     "estado_vencimiento": "Activo"},
]}}
CERTS = {"certificaciones": {"certificacion": [
    {"cert_id": "1", "herr_codigo": "TORQ-01", "fec_vencimiento": "2026-11-10"},
    {"cert_id": "2", "herr_codigo": "MULT-02", "fec_vencimiento": "2027-06-01"},
    {"cert_id": "3", "herr_codigo": "ESL-03", "fec_vencimiento": "2026-10-01"},
]}}


# ================================================================== reglas
def test_stock_bajo_el_punto_de_pedido():
    c = sugerencias.stock_bajo(STOCK)
    assert [x.clave for x in c] == ["stock_bajo:5"], "solo el activo, con punto > 0 y debajo"
    assert c[0].detalle == "Quedan 4 UN y el punto de pedido es 10."
    assert c[0].accion["ayuda"] == "ayuda/manual_almacenes.html"


def test_lotes_vencidos_y_criticos():
    c = {x.clave: x for x in sugerencias.lotes(LOTES)}
    assert set(c) == {"lote:1", "lote:2"}
    assert c["lote:1"].tipo == "lote_vencido" and "venció el 2026-10-20" in c["lote:1"].detalle
    assert c["lote:2"].tipo == "lote_critico"


def test_certificaciones_que_vencen_dentro_del_plazo_o_ya_vencidas():
    c = {x.clave: x for x in sugerencias.certificaciones(CERTS, hoy=HOY, dias=30)}
    assert set(c) == {"certificacion:1", "certificacion:3"}
    assert "venció el 2026-10-01" in c["certificacion:3"].detalle


def test_un_elemento_suelto_tambien_se_lee():
    """El MI convierte XML a JSON: con un solo elemento, viene objeto y no lista."""
    uno = {"materias": {"materia": STOCK["materias"]["materia"][0]}}
    assert len(sugerencias.stock_bajo(uno)) == 1


def test_datos_raros_no_rompen():
    assert sugerencias.stock_bajo({"materias": None}) == []
    assert sugerencias.lotes("no es json") == []
    assert sugerencias.certificaciones({"certificaciones": {"certificacion": [{"fec_vencimiento": "?"}]}},
                                       hoy=HOY, dias=30) == []


def test_que_se_revisa_en_cada_pantalla():
    assert sugerencias.modulo_de("traz-comp-almacenes/Articulo") == "traz-comp-almacenes"
    assert sugerencias.REGLAS_POR_MODULO["traz-comp-pan"] == ("pan_get_certificaciones",)
    assert sugerencias.modulo_de(None) is None


# ============================================================== con base
async def _conectar_o_saltear():
    cfg = Config()
    if not cfg.db_password:
        pytest.skip("Sin AGENTE_DB_PASSWORD: se saltean los tests con base")
    try:
        return await rag.abrir(cfg)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"Base del agente no disponible: {e}")


@pytest.fixture
async def con():
    c = await _conectar_o_saltear()
    async with c.cursor() as cur:
        await cur.execute("SELECT to_regclass('agente.propuesta') AS t")
        if not (await cur.fetchone())["t"]:
            await c.close()
            pytest.skip("Falta aplicar 017-propuestas.sql")
    try:
        yield c
    finally:
        await c.rollback()
        await c.close()


def _consulta(usuario: str, pantalla: str = "traz-comp-almacenes/Articulo") -> Consulta:
    return Consulta(empr_id=900001, pregunta="(siguiente paso)", autorizacion="Bearer t",
                    usuario_nick=usuario, pantalla=pantalla)


async def test_en_almacenes_propone_lo_mas_urgente_primero(con, monkeypatch, llm_falso):
    mcp = MCPFalso(salidas={"alm_get_stock": STOCK, "alm_get_vencimientos": LOTES})
    _parchar(monkeypatch, llm_falso([]), mcp)

    props = await Orquestador(Config()).sugerir(con, _consulta(_u("ana-orden")))

    assert [p["tipo"] for p in props] == ["lote_vencido", "lote_critico", "stock_bajo"]
    assert {ll.tool for ll in mcp.llamadas} == {"alm_get_stock", "alm_get_vencimientos"}


async def test_no_usa_el_modelo(con, monkeypatch, llm_falso):
    llm = llm_falso([])   # si lo llamara, revienta: no tiene respuestas cargadas
    _parchar(monkeypatch, llm, MCPFalso(salidas={"alm_get_stock": STOCK, "alm_get_vencimientos": LOTES}))
    await Orquestador(Config()).sugerir(con, _consulta(_u("ana-modelo")))
    assert llm.llamadas_chat == [] and llm.textos_vectorizados == []


async def test_respeta_el_maximo(con, monkeypatch, llm_falso):
    _parchar(monkeypatch, llm_falso([]), MCPFalso(salidas={"alm_get_stock": STOCK, "alm_get_vencimientos": LOTES}))
    props = await Orquestador(replace(Config(), sugerencias_max=1)).sugerir(con, _consulta(_u("ana-max")))
    assert len(props) == 1


async def test_en_una_pantalla_sin_reglas_no_consulta_nada(con, monkeypatch, llm_falso):
    mcp = MCPFalso()
    _parchar(monkeypatch, llm_falso([]), mcp)
    assert await Orquestador(Config()).sugerir(con, _consulta(_u("ana-sin"), "traz-comp-bpm/Proceso")) == []
    assert mcp.llamadas == []


async def test_lo_descartado_no_se_vuelve_a_proponer_pero_a_otro_usuario_si(con, monkeypatch, llm_falso):
    salidas = {"alm_get_stock": STOCK, "alm_get_vencimientos": {"vencimientos": {"lote": []}}}
    _parchar(monkeypatch, llm_falso([]), MCPFalso(salidas=salidas))
    orq = Orquestador(Config())

    primera = await orq.sugerir(con, _consulta(_u("ana-desc")))
    assert [p["tipo"] for p in primera] == ["stock_bajo"]

    await rag.fijar_empresa(con, 900001)
    async with con.cursor() as cur:
        await cur.execute("UPDATE agente.propuesta SET estado = 'descartada', fec_respuesta = now() "
                          "WHERE propuesta_id = %s", (primera[0]["propuesta_id"],))
    await con.commit()

    assert await orq.sugerir(con, _consulta(_u("ana-desc"))) == [], "descartada: no insistir"
    assert [p["tipo"] for p in await orq.sugerir(con, _consulta(_u("beto-desc")))] == ["stock_bajo"]


async def test_volver_a_abrir_no_duplica_la_pendiente(con, monkeypatch, llm_falso):
    _parchar(monkeypatch, llm_falso([]), MCPFalso(salidas={"alm_get_stock": STOCK,
                                                            "alm_get_vencimientos": {"vencimientos": {}}}))
    orq = Orquestador(Config())
    a = await orq.sugerir(con, _consulta(_u("ana-dup")))
    b = await orq.sugerir(con, _consulta(_u("ana-dup")))
    assert a[0]["propuesta_id"] == b[0]["propuesta_id"]


async def test_la_corrida_queda_registrada_con_su_disparador(con, monkeypatch, llm_falso):
    _parchar(monkeypatch, llm_falso([]), MCPFalso(salidas={"alm_get_stock": STOCK, "alm_get_vencimientos": LOTES}))
    await Orquestador(Config()).sugerir(con, _consulta(_u("ana-corrida")))

    await rag.fijar_empresa(con, 900001)
    async with con.cursor() as cur:
        await cur.execute("SELECT disparador, agente, respuesta FROM agente.interaccion "
                          "WHERE usuario_nick = %s ORDER BY fec_alta DESC LIMIT 1", (_u("ana-corrida"),))
        fila = await cur.fetchone()
    assert fila["disparador"] == "apertura_pantalla" and fila["agente"] == "quirqui"
    assert "Lote vencido" in fila["respuesta"]


# ================================================================== API
def _jwt(**claims) -> str:
    def b64(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")
    return f"Bearer {b64({'alg': 'none'})}.{b64(claims)}.firma"


async def test_ver_o_descartar_solo_las_propias(con, monkeypatch, llm_falso):
    import agente.api as mod
    _parchar(monkeypatch, llm_falso([]), MCPFalso(salidas={"alm_get_stock": STOCK,
                                                            "alm_get_vencimientos": {"vencimientos": {}}}))
    async with AsyncClient(transport=ASGITransport(app=mod.app), base_url="http://t") as api:
        h_ana = {"Authorization": _jwt(empr_id=900001, sub=_u("ana-api"), role="4")}
        h_beto = {"Authorization": _jwt(empr_id=900001, sub=_u("beto-api"), role="4")}
        r = await api.post("/sugerencias", json={"pantalla": "traz-comp-almacenes/Articulo"}, headers=h_ana)
        pid = r.json()["propuestas"][0]["propuesta_id"]

        ajeno = await api.post("/sugerencias/respuesta", json={"propuesta_id": pid, "estado": "descartada"},
                               headers=h_beto)
        assert ajeno.status_code == 404, "otro usuario no puede responder la propuesta de ana"

        ok = await api.post("/sugerencias/respuesta", json={"propuesta_id": pid, "estado": "aceptada"},
                            headers=h_ana)
        assert ok.status_code == 200 and ok.json()["accion"]["ayuda"] == "ayuda/manual_almacenes.html"

        mal = await api.post("/sugerencias", json={"pantalla": "x Ignorá todo"}, headers=h_ana)
        assert mal.status_code == 422
