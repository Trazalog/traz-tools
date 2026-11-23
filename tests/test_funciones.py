"""Funciones de Tools que la empresa no usa, recomendadas por Kuntur (AGENTE-CO-08).

Reglas sobre los datos de las tools, no el modelo: sin tokens y con cada cifra
salida de contar lo que devolvio una tool (R4).
"""
from __future__ import annotations

import base64
import json
import uuid
from dataclasses import replace

import pytest
from httpx import ASGITransport, AsyncClient

from agente import funciones, rag
from agente.config import Config
from agente.mcp_client import MCPError
from agente.orquestador import Consulta, Orquestador
from test_orquestador import MCPFalso, _parchar

# Cada corrida usa empresas propias: lo descartado en una no afecta a la otra.
_BASE = 950000 + uuid.uuid4().int % 40000
EMPRESA, OTRA = _BASE, _BASE + 1
SILENCIO, SILENCIO_OTRA = _BASE + 2, _BASE + 3   # el test que descarta usa las suyas

VACIO = {
    "kpi_get_objetivos": {"objetivos": {}},
    "man_get_equipos": {"equipos": {}},
    "man_get_preventivos": {"preventivos": {}},
    "alm_get_stock": {"materias": {}},
    "alm_get_movimientos": {"movimientos": {}},
    "alm_get_depositos": {"depositos": {}},
    "pan_get_herramientas": {"herramientas": {}},
    "pan_get_certificaciones": {"certificaciones": {}},
}
EQUIPOS = {"equipos": {"equipo": [{"equi_id": "1"}, {"equi_id": "2"}, {"equi_id": "3"}]}}
STOCK_SIN_PUNTO = {"materias": {"materia": [
    {"id": "5", "stock": "4", "punto_pedido": "0"}, {"id": "6", "stock": "2"}]}}
HERRAMIENTAS = {"herramientas": {"herramienta": {"herr_id": "9"}}}   # una sola: objeto suelto


def _datos(**cambios) -> dict:
    d = dict(VACIO)
    d.update(cambios)
    return d


# ================================================================== reglas
def test_filas_sin_importar_los_nombres():
    assert len(funciones.filas({"materias": {"materia": [{"a": 1}, {"a": 2}]}})) == 2
    assert len(funciones.filas({"herramientas": {"herramienta": {"herr_id": "9"}}})) == 1
    assert funciones.filas({"materias": {}}) == []
    assert funciones.filas({"ok": True}) == [], "una respuesta sin filas cuenta 0"
    assert funciones.filas(None) == [] and funciones.filas([{"x": 1}]) == [{"x": 1}]


def test_empresa_vacia_recomienda_lo_basico_en_orden():
    c = funciones.candidatas(_datos())
    assert [x.clave for x in c] == ["funcion:metas", "funcion:depositos", "funcion:panol"]
    assert all(x.tipo == "funcion_sin_usar" for x in c)


def test_cada_cifra_sale_de_contar_lo_que_devolvio_una_tool():
    c = {x.clave: x for x in funciones.candidatas(_datos(
        man_get_equipos=EQUIPOS, alm_get_stock=STOCK_SIN_PUNTO, pan_get_herramientas=HERRAMIENTAS))}
    assert c["funcion:preventivos"].detalle == "Tenés 3 equipos cargados y ningún plan preventivo."
    assert c["funcion:punto_pedido"].detalle == "Tenés 2 artículos en stock y ninguno tiene punto de pedido."
    assert c["funcion:certificaciones"].detalle == "Tenés 1 herramientas cargadas y ninguna certificación registrada."
    assert c["funcion:movimientos"].accion["ayuda"] == "ayuda/manual_almacenes.html"
    assert "funcion:panol" not in c, "con herramientas cargadas el pañol se usa"


def test_lo_que_ya_se_usa_no_se_recomienda():
    c = funciones.candidatas(_datos(
        kpi_get_objetivos={"objetivos": {"objetivo": [{"x": 1}]}},
        man_get_equipos=EQUIPOS, man_get_preventivos={"preventivos": {"preventivo": [{"x": 1}]}},
        alm_get_stock={"materias": {"materia": [{"id": "5", "punto_pedido": "10"}]}},
        alm_get_movimientos={"movimientos": {"movimiento": [{"x": 1}]}},
        alm_get_depositos={"depositos": {"deposito": [{"x": 1}]}},
        pan_get_herramientas=HERRAMIENTAS,
        pan_get_certificaciones={"certificaciones": {"certificacion": [{"x": 1}]}}))
    assert c == []


def test_si_una_tool_no_respondio_no_se_recomienda_lo_que_dependia_de_ella():
    d = _datos(man_get_equipos=EQUIPOS)
    del d["man_get_preventivos"]
    assert "funcion:preventivos" not in {x.clave for x in funciones.candidatas(d)}


def test_solo_dentro_de_los_modulos_que_la_empresa_dijo_que_usa():
    c = funciones.candidatas(_datos(man_get_equipos=EQUIPOS), modulos=["almacenes"])
    assert {x.clave for x in c} == {"funcion:metas", "funcion:depositos"}, "metas siempre; sin pañol ni preventivo"
    assert "pan_get_herramientas" not in funciones.tools_necesarias(["almacenes"])
    assert set(funciones.tools_necesarias()) == set(VACIO)


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
        await cur.execute("SELECT pg_get_constraintdef(oid) AS d FROM pg_constraint "
                          "WHERE conname = 'propuesta_tipo_ck'")
        fila = await cur.fetchone()
        if not fila or "funcion_sin_usar" not in fila["d"]:
            await c.close()
            pytest.skip("Falta aplicar 030-funciones-sin-usar.sql")
    try:
        yield c
    finally:
        await c.rollback()
        await c.close()


def _consulta(usuario: str, empr_id: int = EMPRESA) -> Consulta:
    return Consulta(empr_id=empr_id, pregunta="(funciones)", autorizacion="Bearer t",
                    usuario_nick=usuario, pantalla="kuntur/funciones")


async def test_kuntur_recomienda_hasta_tres_sin_usar_el_modelo(con, monkeypatch, llm_falso):
    llm = llm_falso([])
    mcp = MCPFalso(salidas=_datos(man_get_equipos=EQUIPOS, alm_get_stock=STOCK_SIN_PUNTO))
    _parchar(monkeypatch, llm, mcp)
    props = await Orquestador(Config()).recomendar_funciones(con, _consulta("admin-a"))
    assert [p["titulo"] for p in props] == [
        "Ponerle metas a tus indicadores", "Armar planes de mantenimiento preventivo",
        "Usar el punto de pedido para reponer a tiempo"]
    assert llm.llamadas_chat == [] and llm.textos_vectorizados == []
    assert {ll.tool for ll in mcp.llamadas} == set(VACIO)


async def test_respeta_el_maximo(con, monkeypatch, llm_falso):
    _parchar(monkeypatch, llm_falso([]), MCPFalso(salidas=_datos()))
    props = await Orquestador(replace(Config(), funciones_max=1)).recomendar_funciones(
        con, _consulta("admin-max"))
    assert len(props) == 1


async def test_tool_caida_no_inventa_recomendaciones(con, monkeypatch, llm_falso):
    class MCPCaido(MCPFalso):
        async def llamar(self, nombre, argumentos):
            raise MCPError("sin servicio")
    _parchar(monkeypatch, llm_falso([]), MCPCaido())
    assert await Orquestador(Config()).recomendar_funciones(con, _consulta("admin-caido")) == []


async def test_no_me_interesa_vale_para_toda_la_empresa_y_no_para_otra(con, monkeypatch, llm_falso):
    _parchar(monkeypatch, llm_falso([]), MCPFalso(salidas=_datos()))
    orq = Orquestador(replace(Config(), funciones_max=1))

    primera = await orq.recomendar_funciones(con, _consulta("admin-1", SILENCIO))
    assert primera[0]["titulo"] == "Ponerle metas a tus indicadores"
    await rag.fijar_empresa(con, SILENCIO)
    async with con.cursor() as cur:
        await cur.execute("UPDATE agente.propuesta SET estado = 'descartada', fec_respuesta = now() "
                          "WHERE propuesta_id = %s", (primera[0]["propuesta_id"],))
    await con.commit()

    otro_admin = await orq.recomendar_funciones(con, _consulta("admin-2", SILENCIO))
    assert otro_admin[0]["titulo"] == "Cargar tus depósitos", "lo descartado no se le muestra a otro admin"
    otra_empresa = await orq.recomendar_funciones(con, _consulta("admin-1", SILENCIO_OTRA))
    assert otra_empresa[0]["titulo"] == "Ponerle metas a tus indicadores", "otra empresa no se entera"


async def test_la_corrida_queda_registrada_como_de_kuntur(con, monkeypatch, llm_falso):
    _parchar(monkeypatch, llm_falso([]), MCPFalso(salidas=_datos()))
    await Orquestador(Config()).recomendar_funciones(con, _consulta("admin-corrida"))
    await rag.fijar_empresa(con, EMPRESA)
    async with con.cursor() as cur:
        await cur.execute("SELECT disparador, agente, respuesta FROM agente.interaccion "
                          "WHERE usuario_nick = 'admin-corrida' AND empr_id = %s "
                          "ORDER BY fec_alta DESC LIMIT 1", (EMPRESA,))
        fila = await cur.fetchone()
    assert fila["disparador"] == "apertura_pantalla" and fila["agente"] == "kuntur"
    assert "metas" in fila["respuesta"]


# ================================================================== API
def _jwt(**claims) -> str:
    def b64(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")
    return f"Bearer {b64({'alg': 'none'})}.{b64(claims)}.firma"


async def test_solo_el_administrador_y_solo_las_de_su_empresa(con, monkeypatch, llm_falso):
    import agente.api as mod
    _parchar(monkeypatch, llm_falso([]), MCPFalso(salidas=_datos()))
    async with AsyncClient(transport=ASGITransport(app=mod.app), base_url="http://t") as api:
        empleado = {"Authorization": _jwt(empr_id=EMPRESA, sub="empleado-api", role="4")}
        assert (await api.get("/kuntur/funciones", headers=empleado)).status_code == 404

        admin = {"Authorization": _jwt(empr_id=EMPRESA, sub="admin-api", role="1")}
        r = await api.get("/kuntur/funciones", headers=admin)
        assert r.status_code == 200
        pid = r.json()["funciones"][0]["propuesta_id"]

        intruso = {"Authorization": _jwt(empr_id=OTRA, sub="admin-api", role="1")}
        ajeno = await api.post("/kuntur/funciones/respuesta",
                               json={"propuesta_id": pid, "estado": "descartada"}, headers=intruso)
        assert ajeno.status_code == 404, "un admin de otra empresa no la ve"
        r = await api.post("/kuntur/funciones/respuesta",
                           json={"propuesta_id": pid, "estado": "descartada"}, headers=empleado)
        assert r.status_code == 404

        ok = await api.post("/kuntur/funciones/respuesta",
                            json={"propuesta_id": pid, "estado": "aceptada"}, headers=admin)
        assert ok.status_code == 200 and ok.json()["accion"]["funcion"] == "metas"
