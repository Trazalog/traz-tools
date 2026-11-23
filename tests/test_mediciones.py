"""Mediciones: el contrato Kuntur <-> Quirqui (AGENTE-AS-04 y AGENTE-CO-06).

Las reglas (que numero sale de cada tool, el avance de una tarea, la
validacion de lo que pide Kuntur) corren sin base. Las que guardan necesitan
la base de prueba (AGENTE_DB_* y AGENTE_TEST_DB_ADMIN_DSN).
"""
from __future__ import annotations

import base64
import json
from datetime import date, timedelta
from decimal import Decimal

import pytest
from httpx import ASGITransport, AsyncClient

from agente import mediciones as m
from agente import rag
from agente.config import Config
from conftest import respuesta_texto, respuesta_tool
from test_orquestador import MCPFalso, _conectar_o_saltear, _parchar

EMPRESA = 900401
OTRA = 900402
HOY = date(2026, 11, 22)
MEDIBLES = frozenset({"kpi_get_valor", "tar_get_atrasadas", "tar_get_tareas", "tar_get_pedido",
                      "man_get_kpi_disponibilidad"})


# ================================================================ sin base
@pytest.mark.parametrize("tool,data,esperado", [
    ("tar_get_atrasadas", {"atrasadas": {"tarea": []}, "total": 7}, Decimal("7")),
    ("tar_get_tareas", {"tareas": {"tarea": []}, "total": "3", "sin_responsable": 1}, Decimal("3")),
    ("kpi_get_valor", {"kpi": {"nombre": "alm_reorder", "valor": "37,5"}}, Decimal("37.5")),
    ("kpi_get_valor", {"kpi": [{"nombre": "alm_reorder", "valor": "4"}]}, Decimal("4")),
    ("kpi_get_valor", {"kpi": [{"valor": "1"}, {"valor": "2"}]}, None),   # varios: no es un numero
    ("man_get_kpi_disponibilidad", {"respuesta": {"disponibilidad": "99.74"}}, Decimal("99.74")),
    ("tar_get_atrasadas", {"error": "x"}, None),
    ("web_buscar", {"total": 3}, None),                                    # no se sabe leer
])
def test_el_numero_sale_de_cada_tool_con_su_regla(tool, data, esperado):
    assert m.valor_de(tool, data) == esperado


def test_los_kpi_de_mantenimiento_llevan_la_ventana_y_se_descartan_parametros_ajenos():
    a = m.argumentos_de("man_get_kpi_disponibilidad", {"equipo_id": "5", "sql": "x"}, HOY)
    assert a == {"equipo_id": "5", "fec_inicio": "2026-10-23", "fec_fin": "2026-11-22"}
    assert m.argumentos_de("tar_get_atrasadas", {"hito_id": 3}, HOY) == {}


@pytest.mark.parametrize("tarea,estado,resultado", [
    ({"estado": "creada", "fin": "", "fecha": ""}, "creada", None),                            # sin fecha
    ({"estado": "iniciada", "fin": "20-11-2026 18:00:00"}, "iniciada", "atrasada"),            # paso y sigue
    ({"estado": "planificada", "fin": "25-11-2026 18:00:00"}, "planificada", "en_plazo"),
    ({"estado": "finalizada", "fin": "21-11-2026 10:00:00"}, "finalizada", "en_plazo"),
    ({"estado": "eliminada", "fin": "21-11-2026"}, "eliminada", "cancelada"),
    ({"estado": "rara", "fecha": "01-11-2026"}, "creada", "atrasada"),                         # sin fin: la asignada
])
def test_el_avance_de_una_tarea_del_plan(tarea, estado, resultado):
    a = m.avance_de_tarea({"tapl_id": "10", "responsable": "sin asignar", **tarea}, HOY)
    assert a["estado"] == estado and a["resultado"] == resultado
    assert a["responsable"] is None


def test_avance_toma_el_responsable_y_descarta_tareas_sin_id():
    assert m.avance_de_tarea({"tapl_id": "x"}, HOY) is None
    a = m.avance_de_tarea({"tapl_id": "11", "estado": "finalizada", "fin": "21-11-2026", "responsable": "juan"}, HOY)
    assert a["responsable"] == "juan" and a["fec_real"] == date(2026, 11, 21)


def _pedido():
    return {"pedido": {"petr_id": "77"}, "hitos": [
        {"hito_id": "1", "tareas": [
            {"tapl_id": "10", "estado": "finalizada", "fin": "21-11-2026 10:00:00", "responsable": "juan"},
            {"tapl_id": "11", "estado": "iniciada", "fin": "20-11-2026 10:00:00", "responsable": "ana"}]},
        {"hito_id": "2", "tareas": [{"tapl_id": "12", "estado": "creada", "fin": "", "fecha": "",
                                     "responsable": "sin asignar"}]}]}


def test_las_tareas_del_pedido_se_juntan_de_todos_los_hitos():
    assert [t["tapl_id"] for t in m.tareas_del_pedido(_pedido())] == ["10", "11", "12"]
    assert m.tareas_del_pedido({"error": "x"}) == []


def _args(**kw):
    a = {"indicador": "tar_get_atrasadas", "frecuencia": "semanal", "hasta": (HOY + timedelta(days=30)).isoformat()}
    a.update(kw)
    return a


@pytest.mark.parametrize("cambio,error", [
    ({"indicador": "alm_crear_pedido_materiales"}, "no es algo que Quirqui pueda medir"),
    ({"indicador": "web_buscar"}, "no es algo que Quirqui pueda medir"),
    ({"indicador": "man_get_kpi_mttr"}, "no es algo que Quirqui pueda medir"),    # no esta en MEDIBLES
    ({"frecuencia": "cada hora"}, "diaria, semanal o mensual"),
    ({"hasta": "2027-12-31"}, "180 días"),
    ({"hasta": "2026-11-01"}, "180 días"),
    ({"hasta": "mañana"}, "AAAA-MM-DD"),
    ({"alcance": "empresa"}, "actividad, equipo o persona"),
    ({"alcance": "equipo"}, "alcance_id"),
    ({"alcance_id": "5"}, "alcance_id"),
    ({"petr_id": "abc"}, "número"),
])
def test_lo_que_pide_kuntur_se_valida(cambio, error):
    with pytest.raises(m.MedicionInvalida, match=error):
        m.validar(_args(**cambio), hoy=HOY, medibles=MEDIBLES)


def test_una_medicion_valida_limpia_los_parametros():
    f = m.validar(_args(indicador="kpi_get_valor", parametros={"kpi": "alm_reorder", "otro": "x"},
                        alcance="equipo", alcance_id="P-01", petr_id="77"), hoy=HOY, medibles=MEDIBLES)
    assert f["parametros"] == {"kpi": "alm_reorder"}
    assert f["petr_id"] == 77 and f["alcance_id"] == "P-01" and f["desde"] == HOY


def test_la_tool_solo_ofrece_lo_que_se_sabe_medir():
    enum = m.DEFINICION["function"]["parameters"]["properties"]["indicador"]["enum"]
    assert set(enum) == set(m.EXTRACTORES)
    assert all(not t.startswith(("alm_crear", "man_create", "web_")) for t in enum)


# ================================================================ con base
@pytest.fixture
async def con(con_admin):
    """Usuario del servicio (RLS de verdad). Se limpia antes: las funciones hacen commit."""
    async with con_admin.cursor() as cur:
        for t in ("avance_plan", "medicion_resultado", "medicion_pedida"):
            await cur.execute(f"DELETE FROM agente.{t} WHERE empr_id IN (%s, %s)", (EMPRESA, OTRA))
    await con_admin.commit()
    co = await _conectar_o_saltear()
    try:
        yield co
    finally:
        await co.rollback()
        await co.close()


async def _pedir(con, empr, **kw):
    await rag.fijar_empresa(con, empr)
    r = await m.pedir(con, empr, _args(**kw), hoy=HOY)
    await con.commit()
    return r


async def test_kuntur_pide_y_no_duplica(con):
    r1 = await _pedir(con, EMPRESA)
    r2 = await _pedir(con, EMPRESA)
    assert r1["ya_existia"] is False and r2["ya_existia"] is True
    assert r1["medicion_id"] == r2["medicion_id"]


async def test_una_empresa_no_ve_ni_cancela_las_mediciones_de_otra(con):
    r = await _pedir(con, EMPRESA)
    await rag.fijar_empresa(con, OTRA)
    assert await m.listar(con) == []
    assert await m.cancelar(con, r["medicion_id"]) is False
    await con.rollback()
    await rag.fijar_empresa(con, EMPRESA)
    assert [x["medicion_id"] for x in await m.listar(con)] == [r["medicion_id"]]


async def test_el_trabajo_mide_solo_lo_que_toca_y_refresca_el_plan(con, monkeypatch, llm_falso):
    diaria = await _pedir(con, EMPRESA, frecuencia="diaria", petr_id=77)
    semanal = await _pedir(con, EMPRESA, indicador="kpi_get_valor", parametros={"kpi": "alm_reorder"})
    # La semanal ya se midio hace 3 dias: no toca. La diaria nunca: toca.
    await rag.fijar_empresa(con, EMPRESA)
    async with con.cursor() as cur:
        await cur.execute("""INSERT INTO agente.medicion_resultado (medicion_id, empr_id, fecha, valor, tool)
                             VALUES (%s, %s, %s, 30, 'kpi_get_valor')""",
                          (semanal["medicion_id"], EMPRESA, HOY - timedelta(days=3)))
    await con.commit()

    mcp = MCPFalso(salidas={"tar_get_atrasadas": {"atrasadas": {"tarea": []}, "total": 4},
                            "tar_get_pedido": _pedido()})
    _parchar(monkeypatch, llm_falso([]), mcp)
    monkeypatch.setattr("agente.mediciones.ClienteMCP", lambda cfg, auth: mcp)

    r = await m.medir_empresa(con, Config(), EMPRESA, "Bearer maquina", hoy=HOY)
    assert r["error"] is None and r["medidas"] == 1 and r["avances"] == 3
    assert [ll.tool for ll in mcp.llamadas] == ["tar_get_atrasadas", "tar_get_pedido"]

    await rag.fijar_empresa(con, EMPRESA)
    lista = {x["medicion_id"]: x for x in await m.listar(con)}
    assert lista[diaria["medicion_id"]]["resultados"] == [{"fecha": "2026-11-22", "valor": 4.0}]
    assert lista[diaria["medicion_id"]]["avance_plan"] == {"tareas": 3, "finalizadas": 1, "atrasadas": 1}

    # Corre de nuevo el mismo dia: no vuelve a medir ni duplica el avance.
    mcp.llamadas.clear()
    r = await m.medir_empresa(con, Config(), EMPRESA, "Bearer maquina", hoy=HOY)
    assert r["medidas"] == 0 and mcp.llamadas == []
    async with con.cursor() as cur:
        await rag.fijar_empresa(con, EMPRESA)
        await cur.execute("SELECT count(*) AS n FROM agente.avance_plan WHERE petr_id = 77")
        assert (await cur.fetchone())["n"] == 3


async def test_vencida_la_vigencia_pasa_a_vencida(con, monkeypatch, llm_falso):
    r = await _pedir(con, EMPRESA, hasta=(HOY + timedelta(days=1)).isoformat())
    mcp = MCPFalso()
    _parchar(monkeypatch, llm_falso([]), mcp)
    monkeypatch.setattr("agente.mediciones.ClienteMCP", lambda cfg, auth: mcp)
    res = await m.medir_empresa(con, Config(), EMPRESA, "Bearer m", hoy=HOY + timedelta(days=5))
    assert res["vencidas"] == 1 and mcp.llamadas == []
    await rag.fijar_empresa(con, EMPRESA)
    assert [x["estado"] for x in await m.listar(con) if x["medicion_id"] == r["medicion_id"]] == ["vencida"]


async def test_kuntur_pide_la_medicion_desde_la_charla(con, monkeypatch, llm_falso):
    from agente import agentes
    from agente.orquestador import Consulta, Orquestador
    llm = llm_falso([
        respuesta_tool(m.NOMBRE, json.dumps(_args(petr_id=77))),
        respuesta_texto("Listo: voy a medir las tareas atrasadas cada semana."),
    ])
    mcp = MCPFalso()
    _parchar(monkeypatch, llm, mcp)
    kuntur = await agentes.obtener(con, "kuntur", solo_activos=False)
    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="Medí si el plan anda", autorizacion="Bearer t", agente=kuntur))
    assert res.error is None
    assert [t["tool"] for t in res.tools_llamadas] == [m.NOMBRE]
    await rag.fijar_empresa(con, EMPRESA)
    assert [x["petr_id"] for x in await m.listar(con)] == [77]


# ================================================================== la API
def _jwt(**claims) -> str:
    def b64(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")
    return f"Bearer {b64({'alg': 'none'})}.{b64(claims)}.firma"


@pytest.fixture
async def api(con):
    import agente.api as mod
    async with AsyncClient(transport=ASGITransport(app=mod.app), base_url="http://t") as cliente:
        yield cliente


@pytest.mark.parametrize("metodo,ruta", [("GET", "/kuntur/mediciones"), ("POST", "/kuntur/mediciones/1/cancelar")])
async def test_un_empleado_no_ve_ni_cancela_mediciones(api, metodo, ruta):
    r = await api.request(metodo, ruta, headers={"Authorization": _jwt(empr_id=EMPRESA, role="4")})
    assert r.status_code == 404, "R1: para un empleado, Kuntur no existe"


async def test_el_administrador_ve_y_cancela(api, con):
    pedida = await _pedir(con, EMPRESA)
    h = {"Authorization": _jwt(empr_id=EMPRESA, role="1", preferred_username="admin@empresa")}
    r = await api.get("/kuntur/mediciones", headers=h)
    assert r.status_code == 200
    assert [x["medicion_id"] for x in r.json()["mediciones"]] == [pedida["medicion_id"]]
    # Otra empresa no la puede cancelar.
    otra = {"Authorization": _jwt(empr_id=OTRA, role="1", preferred_username="admin@otra")}
    assert (await api.post(f"/kuntur/mediciones/{pedida['medicion_id']}/cancelar", headers=otra)).status_code == 404
    r = await api.post(f"/kuntur/mediciones/{pedida['medicion_id']}/cancelar", headers=h)
    assert r.status_code == 200 and r.json()["estado"] == "cancelada"
    assert (await api.post(f"/kuntur/mediciones/{pedida['medicion_id']}/cancelar", headers=h)).status_code == 404
