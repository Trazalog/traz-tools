"""Kuntur y las metas (AGENTE-CO-03, CO-07): proponer y seguir, sin escribir en Tools.

  * agente/metas.py: validar una propuesta y evaluar que metas no se cumplen.
  * La tool kpi_proponer_meta en el loop: solo Kuntur la ve, la propuesta llega
    en la respuesta, y si el guardian bloquea la respuesta, la tarjeta se cae.
  * agente/coach.py: el trabajo programado avisa a quien cargo la meta.

El MCP, el modelo y el API de avisos se simulan.
"""
from __future__ import annotations

import dataclasses
import re
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path

import pytest

from agente import agentes, coach, metas
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool
from test_monitoreo import URL, APIAvisosFalso
from test_orquestador import MCPFalso, _parchar

RAIZ = Path(__file__).resolve().parent.parent
EMPRESA = 900001
HOY = date(2026, 10, 29)


# ============================================================ la propuesta
def _args(**kw) -> dict:
    a = {"kpi": "alm_reorder", "operador": "<=", "meta": 5, "hasta": "2026-12-31",
         "motivo": "Hoy hay 37 artículos bajo punto de pedido."}
    a.update(kw)
    return a


def test_una_propuesta_valida_trae_lo_que_necesita_la_tarjeta():
    p = metas.proponer(_args(meta="5,50", responsable="Pañolero"), hoy=HOY)
    assert p == {"kpi": "alm_reorder", "titulo": "Artículos bajo punto de pedido", "fuente": "tools",
                 "operador": "<=", "meta": "5.5", "hasta": "2026-12-31", "responsable": "Pañolero",
                 "motivo": "Hoy hay 37 artículos bajo punto de pedido."}


@pytest.mark.parametrize("cambio, error", [
    ({"kpi": "inventado"}, "no admite metas"),
    ({"operador": ">"}, "operador"),
    ({"meta": "mucho"}, "número"),
    ({"meta": "NaN"}, "número"),
    ({"hasta": "2026-10-28"}, "fecha"),
    ({"hasta": "31/12/2026"}, "fecha"),
    ({"motivo": "  "}, "motivo"),
])
def test_una_propuesta_mal_armada_vuelve_al_modelo_con_el_error(cambio, error):
    with pytest.raises(metas.PropuestaInvalida, match=error):
        metas.proponer(_args(**cambio), hoy=HOY)


def test_los_indicadores_son_los_del_tablero():
    """metas.INDICADORES repite config/dashboard.php: si alguien agrega un
    indicador al Tablero, tiene que agregarlo aca (y al reves)."""
    php = (RAIZ / "application" / "config" / "dashboard.php").read_text(encoding="utf-8")
    bloque = php[php.index("$config['dashboard_kpis']"):]
    del_tablero = {}
    for caja in re.findall(r"array\((.*?)\),\n", bloque, flags=re.S):
        campos = dict(re.findall(r"'(\w+)'\s*=>\s*'([^']*)'", caja))
        if "fuente" in campos:
            nombre = campos["id"] if campos["fuente"] == "man" else campos["kpi_nombre"]
            del_tablero[nombre] = (campos["titulo"], campos["fuente"])
    assert del_tablero == metas.INDICADORES


# ============================================================ la evaluacion
def _fila(**kw) -> dict:
    f = {"objetivo_id": "7", "kpi": "alm_reorder", "fuente": "tools", "operador": "<=", "meta": "5",
         "hasta": "2026-12-31", "estado": "vigente", "usuario_alta": "admin@empresa",
         "responsable": "", "valor_actual": "12", "cumple": "false"}
    f.update(kw)
    return f


def test_evaluar_encuentra_las_que_no_se_cumplen():
    filas = [_fila(), _fila(objetivo_id="8", kpi="her_transito", valor_actual="3", meta="5")]
    d = metas.evaluar(filas, hoy=HOY, valores_man={})
    assert [(x.objetivo_id, x.valor, x.meta) for x in d] == [(7, Decimal("12"), Decimal("5"))]


def test_sin_valor_no_hay_desvio():
    assert metas.evaluar([_fila(valor_actual="")], hoy=HOY, valores_man={}) == []


def test_una_meta_vencida_no_es_un_desvio():
    assert metas.evaluar([_fila(hasta="2026-10-01")], hoy=HOY, valores_man={}) == []


def test_la_de_mantenimiento_se_evalua_con_el_valor_de_asset():
    fila = _fila(objetivo_id="9", kpi="man_disponibilidad", fuente="man", operador=">=",
                 meta="95", valor_actual="")
    assert metas.evaluar([fila], hoy=HOY, valores_man={"man_disponibilidad": Decimal("97.1")}) == []
    d = metas.evaluar([fila], hoy=HOY, valores_man={"man_disponibilidad": Decimal("91.4")})
    assert d[0].titulo == "Disponibilidad de equipos" and d[0].valor == Decimal("91.4")


def test_lee_una_sola_fila_aunque_el_dataservice_no_la_envuelva_en_lista():
    assert len(metas.objetivos({"objetivos": {"objetivo": _fila()}})) == 1
    assert metas.objetivos({"objetivos": {}}) == []


def test_periodo_y_valor_de_disponibilidad():
    assert metas.periodo_disponibilidad(HOY) == {"fec_inicio": "2026-09-29", "fec_fin": "2026-10-29"}
    assert metas.valor_disponibilidad({"respuesta": {"disponibilidad": "99.74"}}) == Decimal("99.74")
    assert metas.valor_disponibilidad({"respuesta": {}}) is None


# ======================================================= la tool en el loop
async def _conectar_o_saltear():
    from agente import rag
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


async def _consultar(con, monkeypatch, llm, clave: str, salidas=None):
    _parchar(monkeypatch, llm, MCPFalso(salidas=salidas))
    agente = await agentes.para_consulta(con, clave, "1")
    return await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="Quiero bajar los artículos bajo punto de pedido",
        autorizacion="Bearer t", agente=agente))


async def test_solo_kuntur_ve_la_tool_de_proponer(con, monkeypatch, llm_falso):
    for clave, la_ve in (("kuntur", True), ("quirqui", False)):
        llm = llm_falso([respuesta_texto("ok")])
        await _consultar(con, monkeypatch, llm, clave)
        vistas = {t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]}
        assert (metas.NOMBRE in vistas) is la_ve, clave


async def test_la_propuesta_llega_en_la_respuesta_y_no_se_graba(con, monkeypatch, llm_falso):
    import json
    llm = llm_falso([
        respuesta_tool("kpi_get_valor", "{}"),
        respuesta_tool(metas.NOMBRE, json.dumps(_args(hasta="2027-03-31"))),
        respuesta_texto("Te propongo dejar los artículos bajo punto de pedido en 5 o menos para fin de marzo."),
    ])
    res = await _consultar(con, monkeypatch, llm, "kuntur",
                           salidas={"kpi_get_valor": {"kpi": {"nombre": "alm_reorder", "valor": "37"}}})
    assert res.error is None and not res.incidentes
    assert res.respuesta.startswith("Te propongo"), "el 5 sale de la propuesta: el guardian no la bloquea"
    assert [p["kpi"] for p in res.propuestas_meta] == ["alm_reorder"]
    assert [t["tool"] for t in res.tools_llamadas] == ["kpi_get_valor", metas.NOMBRE]
    assert res.tools_llamadas[1]["status"] == "ok"


async def test_al_modelo_no_le_vuelve_el_motivo(con, monkeypatch, llm_falso):
    """Si volviera, una cifra inventada en el motivo pasaria despues por "leida"."""
    import json
    llm = llm_falso([respuesta_tool(metas.NOMBRE, json.dumps(_args())), respuesta_texto("Listo.")])
    await _consultar(con, monkeypatch, llm, "kuntur")
    devuelto = [m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"][0]["content"]
    assert "motivo" not in devuelto and "37" not in devuelto


async def test_una_cifra_inventada_en_el_motivo_bloquea(con, monkeypatch, llm_falso):
    """R4 tambien en la tarjeta: el 37 del motivo no salio de ninguna tool."""
    import json
    llm = llm_falso([respuesta_tool(metas.NOMBRE, json.dumps(_args())), respuesta_texto("Te propongo esta meta.")])
    res = await _consultar(con, monkeypatch, llm, "kuntur")
    assert res.incidentes and res.propuestas_meta == []
    assert res.respuesta.startswith("No tengo datos")


async def test_una_propuesta_invalida_no_llega_al_panel(con, monkeypatch, llm_falso):
    import json
    llm = llm_falso([
        respuesta_tool(metas.NOMBRE, json.dumps(_args(kpi="inventado"))),
        respuesta_texto("No pude armar la propuesta."),
    ])
    res = await _consultar(con, monkeypatch, llm, "kuntur")
    assert res.propuestas_meta == []
    devuelto = [m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"]
    assert "no admite metas" in devuelto[0]["content"]


async def test_si_el_guardian_bloquea_la_tarjeta_se_cae(con, monkeypatch, llm_falso):
    import json
    llm = llm_falso([
        respuesta_tool(metas.NOMBRE, json.dumps(_args())),
        respuesta_texto("Con esto vas a ahorrar 4.300.000 pesos."),
    ])
    res = await _consultar(con, monkeypatch, llm, "kuntur")
    assert res.incidentes and res.propuestas_meta == []


# ================================================= el trabajo programado
OBJETIVOS = {"objetivos": {"objetivo": [
    _fila(),                                                     # no se cumple
    _fila(objetivo_id="8", kpi="her_transito", valor_actual="3"),  # se cumple
    _fila(objetivo_id="9", kpi="man_disponibilidad", fuente="man", operador=">=", meta="95",
          valor_actual="", usuario_alta="otro@empresa", responsable="Jefe de mantenimiento"),
]}}


def _mcp(monkeypatch, llm_falso, disponibilidad="91.4", objetivos=None, historico=None):
    salidas = {"kpi_get_objetivos": objetivos or OBJETIVOS,
               "man_get_kpi_disponibilidad": {"respuesta": {"disponibilidad": disponibilidad}}}
    if historico is not None:
        salidas["kpi_get_historico"] = historico
    mcp = MCPFalso(salidas=salidas)
    _parchar(monkeypatch, llm_falso([]), mcp)
    monkeypatch.setattr("agente.coach.ClienteMCP", lambda cfg, auth: mcp)
    return mcp


async def _sin_avisos_previos(con):
    """El seguimiento guarda lo que aviso, y la corrida hace commit: se arranca limpio."""
    async with con.cursor() as cur:
        await cur.execute("DELETE FROM agente.aviso_meta WHERE empr_id = %s", (EMPRESA,))
    await con.commit()


async def _avisados(con) -> dict:
    async with con.cursor() as cur:
        await cur.execute("SELECT objetivo_id, estado, silenciado FROM agente.aviso_meta "
                          "WHERE empr_id = %s", (EMPRESA,))
        return {f["objetivo_id"]: (f["estado"], f["silenciado"]) for f in await cur.fetchall()}


def _api(monkeypatch) -> APIAvisosFalso:
    import httpx
    from agente import avisos
    api = APIAvisosFalso()
    original = avisos.publicar

    async def publicar(cfg, autorizacion, aviso, *, cliente=None):
        async with httpx.AsyncClient(transport=api.transporte()) as c:
            return await original(cfg, autorizacion, aviso, cliente=c)

    monkeypatch.setattr("agente.coach.avisos.publicar", publicar)
    return api


def _cfg() -> Config:
    return dataclasses.replace(Config(), avisos_url=URL)


async def test_avisa_a_quien_cargo_la_meta_firmado_por_kuntur(con_admin, monkeypatch, llm_falso):
    await _sin_avisos_previos(con_admin)
    mcp = _mcp(monkeypatch, llm_falso)
    api = _api(monkeypatch)

    r = await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer maquina", hoy=HOY)

    assert r == {"empr_id": EMPRESA, "metas": 3, "desvios": 2, "en_riesgo": 0, "silenciados": 0,
                 "avisos": 2, "sin_publicar": 0, "error": None}
    por_objetivo = {p["entidad_id"]: (auth, p) for auth, p in api.pedidos}
    auth, alm = por_objetivo["7"]
    assert auth == "Bearer maquina"
    assert alm["emisor"] == "Kuntur" and alm["tipo"] == "kpi_desvio"
    assert alm["destinatarios"] == ["admin@empresa"], "a quien la cargo, no a los suscriptos"
    assert alm["titulo"] == "No se cumple la meta: Artículos bajo punto de pedido"
    assert alm["cuerpo"] == ("Hoy está en 12 y la meta es ≤ 5 para el 31/12/2026. "
                             "Si no querés que insista, tocá «No insistas» en la pestaña Kuntur.")
    assert alm["enlace"] == "Dash/dashboard"
    assert alm["dedupe_key"] == "kpi_desvio:7:no_cumple:2026-10-29"
    _, man = por_objetivo["9"]
    assert man["destinatarios"] == ["otro@empresa"]
    assert man["cuerpo"].startswith("Hoy está en 91,4 y la meta es ≥ 95")
    assert "Responsable: Jefe de mantenimiento." in man["cuerpo"]
    assert {ll.tool for ll in mcp.llamadas} == {"kpi_get_objetivos", "man_get_kpi_disponibilidad",
                                                 "kpi_get_historico"}
    disp = [ll for ll in mcp.llamadas if ll.tool == "man_get_kpi_disponibilidad"][0]
    assert disp.argumentos == {"fec_inicio": "2026-09-29", "fec_fin": "2026-10-29"}
    hist = sorted(ll.argumentos["nombre"] for ll in mcp.llamadas if ll.tool == "kpi_get_historico")
    assert hist == ["alm_reorder", "her_transito"], "la historia solo de las metas de Tools"
    assert await _avisados(con_admin) == {7: ("no_cumple", False), 9: ("no_cumple", False)}


async def test_avisa_cuando_cambia_el_estado_no_todos_los_dias(con_admin, monkeypatch, llm_falso):
    await _sin_avisos_previos(con_admin)
    _mcp(monkeypatch, llm_falso)
    api = _api(monkeypatch)
    for dia in (HOY, date(2026, 10, 30), date(2026, 11, 2)):
        await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=dia)
    assert len(api.pedidos) == 2, "la misma situacion se avisa una sola vez"

    # Se recupera (12 -> 4) y vuelve a caer (4 -> 9): se avisa de nuevo.
    _mcp(monkeypatch, llm_falso, objetivos={"objetivos": {"objetivo": [_fila(valor_actual="4")]}})
    await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=date(2026, 11, 3))
    assert (await _avisados(con_admin))[7] == ("ok", False)
    _mcp(monkeypatch, llm_falso, objetivos={"objetivos": {"objetivo": [_fila(valor_actual="9")]}})
    await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=date(2026, 11, 4))
    claves = [p["dedupe_key"] for _, p in api.pedidos]
    assert claves[-1] == "kpi_desvio:7:no_cumple:2026-11-04" and len(claves) == 3


def _historia(valores, hasta=HOY) -> dict:
    """Un punto por dia, terminando hoy."""
    n = len(valores)
    return {"historico": {"punto": [
        {"fecha": (hasta - timedelta(days=n - 1 - i)).isoformat(), "valor": str(v)}
        for i, v in enumerate(valores)]}}


async def test_en_riesgo_si_la_tendencia_no_llega(con_admin, monkeypatch, llm_falso):
    """Hoy 4 con meta <= 5, pero sube 1 por semana: al 31/12 no llega."""
    await _sin_avisos_previos(con_admin)
    fila = _fila(valor_actual="4", cumple="true")
    subiendo = [Decimal(1) + Decimal(i) / 7 for i in range(22)]   # termina en 4
    _mcp(monkeypatch, llm_falso, objetivos={"objetivos": {"objetivo": [fila]}},
         historico=_historia(subiendo))
    api = _api(monkeypatch)
    r = await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=HOY)
    assert r["en_riesgo"] == 1 and r["avisos"] == 1
    aviso = api.pedidos[0][1]
    assert aviso["titulo"] == "Una meta está en riesgo: Artículos bajo punto de pedido"
    assert aviso["cuerpo"].startswith("Hoy está en 4 y la meta es ≤ 5 para el 31/12/2026: "
                                      "con la tendencia del último mes, no llega.")


async def test_no_insistas_hasta_que_vuelva_a_cumplirse(con_admin, monkeypatch, llm_falso):
    await _sin_avisos_previos(con_admin)
    fila = _fila(valor_actual="4", cumple="true")
    subiendo = [Decimal(1) + Decimal(i) / 7 for i in range(22)]
    _mcp(monkeypatch, llm_falso, objetivos={"objetivos": {"objetivo": [fila]}},
         historico=_historia(subiendo))
    api = _api(monkeypatch)
    await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=HOY)
    assert len(api.pedidos) == 1

    # El administrador toca "No insistas".
    from agente import configuracion
    await configuracion.silenciar(con_admin, EMPRESA, 7, "admin@empresa", silenciado=True)

    # Empeora (en riesgo -> no se cumple): no se avisa, pero queda anotado.
    _mcp(monkeypatch, llm_falso)
    r = await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=date(2026, 10, 30))
    assert len([p for _, p in api.pedidos if p["entidad_id"] == "7"]) == 1
    assert r["silenciados"] == 1
    assert (await _avisados(con_admin))[7] == ("no_cumple", True)

    # Se cumple de nuevo: se limpia el "no insistas", y una caida nueva se avisa.
    _mcp(monkeypatch, llm_falso, objetivos={"objetivos": {"objetivo": [_fila(valor_actual="3")]}})
    await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=date(2026, 10, 31))
    assert (await _avisados(con_admin))[7] == ("ok", False)


async def test_si_mantenimiento_no_responde_sigue_con_las_demas(con_admin, monkeypatch, llm_falso):
    from agente.mcp_client import MCPError
    await _sin_avisos_previos(con_admin)
    mcp = _mcp(monkeypatch, llm_falso)
    original = mcp.llamar

    async def llamar(nombre, argumentos):
        if nombre == "man_get_kpi_disponibilidad":
            raise MCPError(nombre, "timeout")
        return await original(nombre, argumentos)

    mcp.llamar = llamar
    _api(monkeypatch)
    r = await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=HOY)
    assert r["error"] is None and r["desvios"] == 1


async def test_sin_url_de_avisos_queda_en_la_corrida(con_admin, monkeypatch, llm_falso):
    await _sin_avisos_previos(con_admin)
    _mcp(monkeypatch, llm_falso)
    api = _api(monkeypatch)
    r = await coach.revisar_empresa(con_admin, Config(), EMPRESA, "Bearer m", hoy=HOY)
    assert api.pedidos == [] and r["sin_publicar"] == r["desvios"] == 2
    assert await _avisados(con_admin) == {}, "sin publicar no se da por avisado: se reintenta"


async def test_con_kuntur_apagado_no_lee_nada(con_admin, monkeypatch, llm_falso):
    mcp = _mcp(monkeypatch, llm_falso)
    async with con_admin.cursor() as cur:
        await cur.execute("UPDATE agente.agente SET activo = false WHERE clave = 'kuntur'")
    r = await coach.revisar_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=HOY)
    assert "no esta activo" in r["error"] and mcp.llamadas == []


# ======================================================= tendencia (puras)
def _serie(valores):
    return metas.serie_historico(_historia(valores))


def test_la_tendencia_necesita_puntos_suficientes():
    assert metas.pendiente(_serie([1, 2, 3])) is None
    assert metas.estado_meta("<=", Decimal(4), Decimal(5), "2026-12-31", HOY, _serie([1, 2, 3])) == metas.OK


def test_bajando_hacia_la_meta_esta_ok():
    bajando = [10 - i * 0.2 for i in range(20)]
    assert metas.pendiente(_serie(bajando)) < 0
    assert metas.estado_meta("<=", Decimal(4), Decimal(5), "2026-12-31", HOY, _serie(bajando)) == metas.OK


def test_meta_de_minimo_que_viene_cayendo_esta_en_riesgo():
    """Disponibilidad >= 90: hoy 93, pero cae medio punto por dia."""
    cayendo = [103 - i * 0.5 for i in range(21)]                  # termina en 93
    assert metas.estado_meta(">=", Decimal(93), Decimal(90), "2026-11-30", HOY, _serie(cayendo)) == metas.EN_RIESGO


def test_sin_dias_por_delante_no_hay_riesgo_sino_el_valor_de_hoy():
    subiendo = [1 + i / 7 for i in range(22)]
    assert metas.estado_meta("<=", Decimal(4), Decimal(5), HOY.isoformat(), HOY, _serie(subiendo)) == metas.OK
    assert metas.estado_meta("<=", Decimal(6), Decimal(5), HOY.isoformat(), HOY, _serie(subiendo)) == metas.NO_CUMPLE


def test_la_historia_ignora_puntos_rotos_y_ordena():
    data = {"historico": {"punto": [{"fecha": "2026-10-02", "valor": "2"}, {"fecha": "x", "valor": "1"},
                                    {"fecha": "2026-10-01", "valor": ""}, {"fecha": "2026-10-01", "valor": "1"}]}}
    assert metas.serie_historico(data) == [(date(2026, 10, 1), Decimal(1)), (date(2026, 10, 2), Decimal(2))]
    assert metas.serie_historico({"historico": {"punto": {"fecha": "2026-10-01", "valor": "3"}}}) == [
        (date(2026, 10, 1), Decimal(3))]
