"""Lista blanca de tools por agente (ADR-A8, AGENTE-M-02).

Los agentes dicen como, no hacen. Esto verifica las dos barreras:

  1. El modelo solo VE las tools que su agente puede usar: catalogadas, que no
     sean de accion y dentro de sus patrones.
  2. Si igual pide otra, no sale al MCP: queda bloqueada.

Y verifica la fuente: que todo lo que publica el gateway este catalogado, y
que todo lo que no es un GET este marcado como 'accion'. Si manana se publica
una tool de escritura nueva sin catalogarla, este test falla.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from agente import agentes, rag
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool
from test_orquestador import MCPFalso, _parchar

RAIZ = Path(__file__).resolve().parent.parent
CONTRATO = RAIZ / "doc" / "api" / "trazalog-operaciones.yaml"


def _operaciones() -> dict[str, str]:
    """operationId -> metodo HTTP, leidos del contrato del MCP Gateway."""
    ops, metodo = {}, None
    for linea in CONTRATO.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^    (get|post|put|delete|patch):\s*$", linea)
        if m:
            metodo = m.group(1).upper()
        m = re.match(r"^\s+operationId:\s*(\S+)", linea)
        if m:
            ops[m.group(1)] = metodo
    return ops


def _tool(nombre: str) -> dict:
    return {"type": "function",
            "function": {"name": nombre, "description": nombre,
                         "parameters": {"type": "object", "properties": {}}}}


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
    try:
        yield c
    finally:
        await c.rollback()
        await c.close()


async def _catalogo(con) -> dict[str, str]:
    async with con.cursor() as cur:
        await cur.execute("SELECT nombre, clase FROM agente.tool")
        return {f["nombre"]: f["clase"] for f in await cur.fetchall()}


# =================================================== catalogo vs contrato
def test_el_contrato_tiene_operaciones():
    """Que el parser no devuelva vacio y haga pasar todo lo de abajo."""
    ops = _operaciones()
    assert len(ops) >= 25
    assert ops["man_create_ot"] == "POST"


async def test_todo_lo_que_publica_el_gateway_esta_catalogado(con):
    faltan = set(_operaciones()) - set(await _catalogo(con))
    assert not faltan, f"Tools del gateway sin catalogar en 012-tools.sql: {sorted(faltan)}"


async def test_todo_lo_que_no_es_get_es_accion(con):
    """Una tool que escribe no puede quedar como lectura por error de carga."""
    catalogo = await _catalogo(con)
    mal = [n for n, m in _operaciones().items() if m != "GET" and catalogo.get(n) != "accion"]
    assert not mal, f"Tools que escriben y no estan como 'accion': {mal}"


async def test_ningun_agente_puede_usar_una_tool_de_accion(con):
    catalogo = await _catalogo(con)
    for a in await agentes.listar(con):
        for nombre in await agentes.tools_permitidas(con, a.clave):
            assert catalogo[nombre] != "accion", f"{a.clave} alcanza {nombre}"


@pytest.mark.parametrize("patrones", [["man_*"], ["alm_*"], ["*"], ["man_*", "alm_*"]])
async def test_un_patron_demasiado_amplio_no_alcanza_las_de_accion(con, patrones):
    """La defensa para el dia que alguien escriba 'man_*' en una configuracion:
    el filtro de clase sigue dejando afuera crear OTs y pedidos."""
    async with con.cursor() as cur:
        await cur.execute("SELECT agente.tools_por_patrones(%s) AS nombre", (patrones,))
        alcanzadas = {f["nombre"] for f in await cur.fetchall()}
    assert alcanzadas, "el patron tendria que alcanzar al menos las de lectura"
    assert not alcanzadas & {"man_create_ot", "alm_crear_pedido_materiales"}


async def test_un_patron_especifico_alcanza_solo_lo_suyo(con):
    async with con.cursor() as cur:
        await cur.execute("SELECT agente.tools_por_patrones(%s) AS nombre", (["man_get_kpi_*"],))
        alcanzadas = {f["nombre"] for f in await cur.fetchall()}
    assert alcanzadas == {"man_get_kpi_disponibilidad", "man_get_kpi_mttr",
                          "man_get_kpi_mttf", "man_get_kpi_fallas"}


async def test_la_base_y_los_patrones_coinciden(con):
    """El patron en Python y en SQL tienen que decir lo mismo.

    Si divergieran, un test sobre tool_permitida() podria dar verde mientras
    la base deja pasar otra cosa.
    """
    catalogo = await _catalogo(con)
    for a in await agentes.listar(con):
        por_patron = {n for n, clase in catalogo.items()
                      if clase != "accion" and a.tool_permitida(n)}
        assert por_patron == set(await agentes.tools_permitidas(con, a.clave)), a.clave


async def test_quirqui_ve_todas_las_de_lectura(con):
    catalogo = await _catalogo(con)
    lectura = {n for n, c in catalogo.items() if c == "lectura"}
    assert set(await agentes.tools_permitidas(con, "quirqui")) == lectura


# ============================================ las dos barreras, en el loop
TOOLS_DEL_GATEWAY = [
    _tool("man_get_equipos"),
    _tool("man_create_ot"),                # escritura: el gateway la publica
    _tool("alm_crear_pedido_materiales"),  # escritura
    _tool("man_get_algo_nuevo"),           # nueva, sin catalogar
]


async def test_el_modelo_solo_ve_las_tools_permitidas(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_texto("ok")])
    _parchar(monkeypatch, llm, MCPFalso(tools=TOOLS_DEL_GATEWAY))

    await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="¿Qué equipos tengo?", autorizacion="Bearer t",
    ))

    vistas = [t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]]
    assert vistas == ["man_get_equipos"]


async def test_una_tool_nueva_sin_catalogar_no_se_ofrece(con, monkeypatch, llm_falso):
    """Falla cerrado: man_get_algo_nuevo entra en el patron man_get_*, pero no
    esta en el catalogo, asi que nadie decidio todavia si es de lectura."""
    llm = llm_falso([respuesta_texto("ok")])
    _parchar(monkeypatch, llm, MCPFalso(tools=TOOLS_DEL_GATEWAY))

    await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="hola", autorizacion="Bearer t",
    ))

    vistas = {t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]}
    assert "man_get_algo_nuevo" not in vistas


async def test_si_el_modelo_pide_una_de_escritura_no_sale_al_mcp(con, monkeypatch, llm_falso):
    """Segunda barrera: el modelo pide crear una OT aunque no se le ofrecio."""
    llm = llm_falso([
        respuesta_tool("man_create_ot", '{"equi_id": 1}'),
        respuesta_texto("No puedo crear órdenes; te explico cómo hacerlo."),
    ])

    class MCPQueNoDebeEscribir(MCPFalso):
        async def llamar(self, nombre, argumentos):
            raise AssertionError(f"Se llamo al MCP con {nombre}: la lista blanca no freno")

    mcp = MCPQueNoDebeEscribir(tools=TOOLS_DEL_GATEWAY)
    _parchar(monkeypatch, llm, mcp)

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="Creá una OT para el compresor", autorizacion="Bearer t",
    ))

    assert res.error is None
    assert res.respuesta.startswith("No puedo crear órdenes")
    assert res.tools_llamadas == [{
        "tool": "man_create_ot", "argumentos": {"equi_id": 1}, "status": "bloqueada",
        "latencia_ms": 0, "error": "fuera de la lista blanca del agente",
    }]
    # El modelo se entero de que no podia: le volvio un error como contenido.
    devuelto = [m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"]
    assert "no está disponible" in devuelto[0]["content"]


async def test_sin_catalogo_no_responde_con_todas_las_tools(con, monkeypatch, llm_falso):
    """Falla cerrado: si no se puede resolver la lista blanca, el agente no
    responde. Nunca sigue con todas las tools del gateway."""
    llm = llm_falso([respuesta_texto("no deberia llegar aca")])
    mcp = MCPFalso(tools=TOOLS_DEL_GATEWAY)
    _parchar(monkeypatch, llm, mcp)

    async def sin_catalogo(_con, _clave):
        raise RuntimeError("function agente.tools_permitidas(text) does not exist")

    monkeypatch.setattr("agente.orquestador.agentes.tools_permitidas", sin_catalogo)

    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=900001, pregunta="hola", autorizacion="Bearer t",
    ))

    assert res.error and "tools_permitidas" in res.error
    assert llm.llamadas_chat == [], "No tiene que haber llegado al modelo"
    assert mcp.llamadas == []
