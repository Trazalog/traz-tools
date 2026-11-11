"""Kuntur graba configuracion solo con confirmacion del administrador (ADR-A12).

  * Una tool de clase 'configuracion' no entra por patrones: hay que nombrarla.
  * En la charla, el motor NO la ejecuta: guarda una carga propuesta y la
    devuelve como tarjeta.
  * Se ejecuta solo con "Cargar", con el token del administrador, una sola vez,
    y si la tool sigue habilitada. Una carga de otra empresa no se ve.

El MCP y el modelo se simulan. La tool de prueba se siembra y se borra al final.
"""
from __future__ import annotations

import base64
import json

import pytest
from httpx import ASGITransport, AsyncClient

from agente import agentes, cargas, rag
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool
from test_orquestador import MCPFalso, _parchar

EMPRESA = 900201
OTRA = 900202
TOOL = "alm_prueba_alta_config"
ARGS = {"filas": [{"nombre": f"Depósito {i}", "establecimiento": "Planta"} for i in range(1, 13)]}


async def _conectar_o_saltear():
    cfg = Config()
    if not cfg.db_password:
        pytest.skip("Sin AGENTE_DB_PASSWORD: se saltean los tests con base")
    try:
        return await rag.abrir(cfg)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"Base del agente no disponible: {e}")


@pytest.fixture
async def con(con_admin):
    """Siembra la tool de prueba (como curador) y se la da a Kuntur, por nombre."""
    async with con_admin.cursor() as cur:
        await cur.execute(
            "INSERT INTO agente.tool (nombre, modulo, clase, riesgo, reversible, descripcion) "
            "VALUES (%s, 'alm', 'configuracion', 'medio', false, 'Alta de depósitos (prueba)') "
            "ON CONFLICT (nombre) DO UPDATE SET clase = 'configuracion'", (TOOL,))
        await cur.execute("UPDATE agente.agente SET tools_configuracion = ARRAY[%s] WHERE clave = 'kuntur'", (TOOL,))
        await cur.execute("UPDATE agente.agente SET tools_permitidas = tools_permitidas || 'alm_prueba_*'::text "
                          "WHERE clave = 'quirqui' AND NOT ('alm_prueba_*' = ANY (tools_permitidas))")
    await con_admin.commit()
    c = await _conectar_o_saltear()
    try:
        yield c
    finally:
        await c.rollback()
        await c.close()
        async with con_admin.cursor() as cur:
            await cur.execute("UPDATE agente.agente SET tools_configuracion = '{}' WHERE clave = 'kuntur'")
            await cur.execute("UPDATE agente.agente SET tools_permitidas = array_remove(tools_permitidas, 'alm_prueba_*') "
                              "WHERE clave = 'quirqui'")
            await cur.execute("DELETE FROM agente.tool_llamada WHERE tool = %s", (TOOL,))
            await cur.execute("DELETE FROM agente.carga_propuesta WHERE tool = %s", (TOOL,))
            await cur.execute("DELETE FROM agente.tool WHERE nombre = %s", (TOOL,))
        await con_admin.commit()


def _definicion() -> dict:
    return {"type": "function", "function": {"name": TOOL, "description": "Alta de depósitos",
                                             "parameters": {"type": "object"}}}


async def _consultar(con, monkeypatch, llm, mcp, clave="kuntur"):
    _parchar(monkeypatch, llm, mcp)
    agente = await agentes.para_consulta(con, clave, "1")
    return await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="Cargá los depósitos", autorizacion="Bearer admin",
        usuario_nick="admin@empresa", agente=agente))


# ============================================================ la lista blanca
async def test_un_patron_no_habilita_una_tool_de_configuracion(con):
    assert TOOL not in await agentes.tools_permitidas(con, "quirqui"), "quirqui tiene 'alm_prueba_*'"
    assert TOOL in await agentes.tools_permitidas(con, "kuntur")
    assert await cargas.de_configuracion(con, "kuntur") == frozenset({TOOL})
    assert await cargas.de_configuracion(con, "quirqui") == frozenset()


# ============================================================ en la charla
async def test_en_la_charla_no_se_ejecuta_se_propone(con, monkeypatch, llm_falso):
    mcp = MCPFalso(tools=[_definicion()])
    llm = llm_falso([respuesta_tool(TOOL, json.dumps(ARGS)),
                     respuesta_texto("Te armé la carga: revisala y tocá «Cargar».")])
    res = await _consultar(con, monkeypatch, llm, mcp)

    assert mcp.llamadas[-1].status == "propuesta", "no salio al MCP"
    assert [ll.status for ll in mcp.llamadas if ll.tool == TOOL] == ["propuesta"]
    assert len(res.propuestas_carga) == 1
    t = res.propuestas_carga[0]
    assert t["titulo"] == "Alta de depósitos (prueba)" and t["total_filas"] == 12
    assert len(t["filas"]) == cargas.MAX_FILAS_MUESTRA, "la tarjeta muestra una muestra"
    devuelto = [m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"][0]["content"]
    assert "No se grabó nada" in devuelto

    await rag.fijar_empresa(con, EMPRESA)
    async with con.cursor() as cur:
        await cur.execute("SELECT estado, usuario, argumentos FROM agente.carga_propuesta WHERE carga_id = %s",
                          (t["carga_id"],))
        fila = await cur.fetchone()
    assert fila["estado"] == "propuesta" and fila["usuario"] == "admin@empresa"
    assert fila["argumentos"] == ARGS


async def test_quirqui_no_ve_la_tool_aunque_el_gateway_la_publique(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_texto("ok")])
    await _consultar(con, monkeypatch, llm, MCPFalso(tools=[_definicion()]), clave="quirqui")
    assert TOOL not in {t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]}


# ============================================================ la confirmacion
async def _proponer(con, empr_id=EMPRESA) -> str:
    await rag.fijar_empresa(con, empr_id)
    p = await cargas.proponer(con, empr_id=empr_id, interaccion_id=None, agente="kuntur",
                              usuario="admin@empresa", tool=TOOL, argumentos=ARGS)
    await con.commit()
    await rag.fijar_empresa(con, empr_id)
    return p.carga_id


def _mcp_de_confirmacion(monkeypatch, salida=None, error=None):
    vistos = []

    class MCP(MCPFalso):
        async def llamar(self, nombre, argumentos):
            if error:
                from agente.mcp_client import MCPError
                raise MCPError(nombre, error)
            return await super().llamar(nombre, argumentos)

    def crear(cfg, autorizacion):
        m = MCP(salidas={TOOL: salida or {"ok": True, "creados": 12}})
        vistos.append((autorizacion, m))
        return m

    monkeypatch.setattr("agente.cargas.ClienteMCP", crear)
    return vistos


async def test_cargar_ejecuta_lo_guardado_con_el_token_del_administrador(con, monkeypatch):
    carga = await _proponer(con)
    vistos = _mcp_de_confirmacion(monkeypatch)
    r = await cargas.confirmar(con, Config(), empr_id=EMPRESA, carga_id=carga,
                               usuario="otro.admin@empresa", autorizacion="Bearer del-admin")
    assert r["estado"] == "ejecutada" and r["respuesta"] == {"ok": True, "creados": 12}
    auth, mcp = vistos[0]
    assert auth == "Bearer del-admin"
    assert [(ll.tool, ll.argumentos) for ll in mcp.llamadas] == [(TOOL, ARGS)]

    with pytest.raises(cargas.CargaInvalida, match="ya está ejecutada"):
        await cargas.confirmar(con, Config(), empr_id=EMPRESA, carga_id=carga,
                               usuario="otro.admin@empresa", autorizacion="Bearer del-admin")
    async with con.cursor() as cur:
        await cur.execute("SELECT confirmado_por FROM agente.carga_propuesta WHERE carga_id = %s", (carga,))
        assert (await cur.fetchone())["confirmado_por"] == "otro.admin@empresa"


async def test_si_falla_queda_como_fallida(con, monkeypatch):
    carga = await _proponer(con)
    _mcp_de_confirmacion(monkeypatch, error="la fila 3 tiene un depósito repetido")
    r = await cargas.confirmar(con, Config(), empr_id=EMPRESA, carga_id=carga,
                               usuario="admin@empresa", autorizacion="Bearer a")
    assert r["estado"] == "fallida" and "repetido" in r["error"]


async def test_si_sacaron_la_tool_de_la_lista_no_se_ejecuta(con, con_admin, monkeypatch):
    carga = await _proponer(con)
    async with con_admin.cursor() as cur:
        await cur.execute("UPDATE agente.agente SET tools_configuracion = '{}' WHERE clave = 'kuntur'")
    await con_admin.commit()
    vistos = _mcp_de_confirmacion(monkeypatch)
    with pytest.raises(cargas.CargaInvalida, match="ya no está habilitada"):
        await cargas.confirmar(con, Config(), empr_id=EMPRESA, carga_id=carga,
                               usuario="admin@empresa", autorizacion="Bearer a")
    assert vistos == []


async def test_una_carga_vencida_no_se_ejecuta(con, con_admin, monkeypatch):
    carga = await _proponer(con)
    async with con_admin.cursor() as cur:
        await cur.execute("UPDATE agente.carga_propuesta SET fec_alta = now() - interval '2 days' "
                          "WHERE carga_id = %s", (carga,))
    await con_admin.commit()
    with pytest.raises(cargas.CargaInvalida, match="venció"):
        await cargas.confirmar(con, Config(), empr_id=EMPRESA, carga_id=carga,
                               usuario="admin@empresa", autorizacion="Bearer a")


async def test_descartar(con):
    carga = await _proponer(con)
    assert (await cargas.descartar(con, empr_id=EMPRESA, carga_id=carga, usuario="admin@empresa"))["estado"] == "descartada"
    with pytest.raises(cargas.CargaInvalida):
        await cargas.descartar(con, empr_id=EMPRESA, carga_id=carga, usuario="admin@empresa")


async def test_otra_empresa_no_confirma_una_carga_ajena(con, monkeypatch):
    carga = await _proponer(con)
    await rag.fijar_empresa(con, OTRA)
    vistos = _mcp_de_confirmacion(monkeypatch)
    with pytest.raises(cargas.CargaInvalida, match="No existe"):
        await cargas.confirmar(con, Config(), empr_id=OTRA, carga_id=carga,
                               usuario="intruso", autorizacion="Bearer otra")
    assert vistos == []


# ==================================================================== la API
def _jwt(**claims) -> str:
    def b64(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")
    return f"Bearer {b64({'alg': 'none'})}.{b64(claims)}.firma"


async def test_un_empleado_no_confirma_cargas(con):
    import agente.api as mod
    carga = await _proponer(con)
    async with AsyncClient(transport=ASGITransport(app=mod.app), base_url="http://t") as api:
        for ruta in ("/kuntur/cargas/confirmar", "/kuntur/cargas/descartar"):
            r = await api.post(ruta, json={"carga_id": carga},
                               headers={"Authorization": _jwt(empr_id=EMPRESA, role="4")})
            assert r.status_code == 404, ruta
