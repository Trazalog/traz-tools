"""Servicios simulados de la puesta en marcha (agente/simulados.py, 026).

Mantenimiento con la interfaz de MANDataService de develop-v3 y Dnato v3 en
diseno. Lo que importa:
  * respetan la interfaz (campos, requeridos, opciones);
  * las altas pasan por la carga propuesta y la confirmacion (ADR-A12);
  * cada empresa ve solo lo suyo, y un equipo no apunta a un sector ajeno.
"""
from __future__ import annotations

import json

import pytest

from agente import agentes, cargas, rag, simulados
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool
from test_orquestador import MCPFalso, _parchar

EMPRESA = 900301
OTRA = 900302


# ================================================================ la interfaz
def test_los_abm_de_mantenimiento_tienen_la_interfaz_de_develop_v3():
    assert simulados.SERVICIOS["man_alta_sector"].contrato.startswith("MANDataService POST /equipos/sector")
    assert simulados.SERVICIOS["man_alta_marca"].requeridos == ("marcadescrip",)
    assert simulados.validar("man_alta_sector", {"descripcion": " Planta  "}) == {"descripcion": "Planta"}
    assert len(simulados.validar("man_alta_sector", {"descripcion": "x" * 80})["descripcion"]) == 50


@pytest.mark.parametrize("nombre,args,mensaje", [
    ("man_alta_sector", {}, "Faltan datos"),
    ("man_alta_sector", {"descripcion": "A", "id_empresa": 5}, "no tiene el campo"),
    ("man_alta_equipo", {"descripcion": "Pala", "codigo": "P1", "id_sector": "3"}, "número entero"),
    ("dnato_asignar_menu_rol", {"rol": "Administrador", "opciones": []}, "no es una opción"),
    ("dnato_asignar_menu_rol", {"rol": "Planificador", "opciones": ["alm.inventada"]}, "no existen"),
    ("dnato_activar_funcionalidad", {"funcionalidad": "ALM", "activa": "si"}, "verdadero o falso"),
])
def test_lo_que_no_respeta_la_interfaz_no_pasa(nombre, args, mensaje):
    with pytest.raises(simulados.SimulacionInvalida, match=mensaje):
        simulados.validar(nombre, args)


def test_la_empresa_no_es_un_parametro():
    """id_empresa sale del token en los reales; en la interfaz para el modelo no existe."""
    for s in simulados.SERVICIOS.values():
        assert "id_empresa" not in s.propiedades and "empr_id" not in s.propiedades, s.nombre


def test_solo_se_ofrecen_las_permitidas():
    nombres = {d["function"]["name"] for d in simulados.definiciones(frozenset({"man_alta_sector"}))}
    assert nombres == {"man_alta_sector"}
    assert "SIMULADO" in simulados.definiciones(frozenset({"man_alta_sector"}))[0]["function"]["description"]


# ============================================================ con la base
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
    async with con_admin.cursor() as cur:
        await cur.execute("DELETE FROM agente.simulacion WHERE empr_id IN (%s, %s)", (EMPRESA, OTRA))
        await cur.execute("DELETE FROM agente.carga_propuesta WHERE empr_id IN (%s, %s)", (EMPRESA, OTRA))
        await cur.execute("DELETE FROM agente.tool_llamada WHERE empr_id IN (%s, %s)", (EMPRESA, OTRA))
        await cur.execute("DELETE FROM agente.interaccion WHERE empr_id IN (%s, %s)", (EMPRESA, OTRA))
    await con_admin.commit()
    c = await _conectar_o_saltear()
    try:
        yield c
    finally:
        await c.rollback()
        await c.close()


async def test_kuntur_las_tiene_y_quirqui_no(con):
    de_config = await cargas.de_configuracion(con, "kuntur")
    assert {"man_alta_sector", "man_alta_equipo", "dnato_asignar_menu_rol"} <= de_config
    assert "dnato_get_funcionalidades" in await agentes.tools_permitidas(con, "kuntur")
    quirqui = await agentes.tools_permitidas(con, "quirqui")
    assert not any(t.startswith(("man_alta_", "dnato_")) for t in quirqui)


async def _cargar(con, tool, args, empr_id=EMPRESA) -> dict:
    await rag.fijar_empresa(con, empr_id)
    p = await cargas.proponer(con, empr_id=empr_id, interaccion_id=None, agente="kuntur",
                              usuario="admin@empresa", tool=tool, argumentos=args)
    await con.commit()
    await rag.fijar_empresa(con, empr_id)
    r = await cargas.confirmar(con, Config(), empr_id=empr_id, carga_id=p.carga_id,
                               usuario="admin@empresa", autorizacion="Bearer admin")
    await rag.fijar_empresa(con, empr_id)
    return r


async def test_alta_de_sector_y_equipo_con_confirmacion(con):
    r = await _cargar(con, "man_alta_sector", {"descripcion": "Planta de chancado"})
    assert r["estado"] == "ejecutada" and r["respuesta"]["simulado"] is True
    sector = r["respuesta"]["respuesta"]["id"]
    r = await _cargar(con, "man_alta_equipo", {"descripcion": "Chancadora primaria", "codigo": "CH-01",
                                               "id_sector": sector})
    assert r["estado"] == "ejecutada"
    conf = await simulados.leer(con, EMPRESA, "man_get_configuracion")
    assert [s["descripcion"] for s in conf["configuracion"]["sector"]] == ["Planta de chancado"]
    assert conf["configuracion"]["equipo"][0]["id_sector"] == sector


async def test_un_equipo_no_apunta_a_un_sector_de_otra_empresa(con):
    ajeno = (await _cargar(con, "man_alta_sector", {"descripcion": "De la otra"}, empr_id=OTRA))
    r = await _cargar(con, "man_alta_equipo", {"descripcion": "Pala", "codigo": "P1",
                                               "id_sector": ajeno["respuesta"]["respuesta"]["id"]})
    assert r["estado"] == "fallida" and "No existe id_sector" in r["error"]
    assert await simulados.leer(con, EMPRESA, "man_get_configuracion") == {"configuracion": {}, "simulado": True}


async def test_roles_menus_y_administradores_de_dnato(con):
    await _cargar(con, "dnato_asignar_rol_usuario", {"usuario": "ana@empresa", "rol": "Administrador"})
    await _cargar(con, "dnato_asignar_rol_usuario", {"usuario": "beto@empresa", "rol": "Administrador"})
    await _cargar(con, "dnato_asignar_rol_usuario", {"usuario": "BETO@empresa", "rol": "Planificador"})
    assert (await simulados.leer(con, EMPRESA, "dnato_get_administradores"))["administradores"] == ["ana@empresa"]

    await _cargar(con, "dnato_asignar_menu_rol", {"rol": "Planificador", "opciones": ["tar.planificacion", "man.ordenes"]})
    f = await simulados.leer(con, EMPRESA, "dnato_get_funcionalidades")
    assert f["menu_por_rol"]["Planificador"] == ["man.ordenes", "tar.planificacion"]
    assert f["menu_por_rol"]["Administrador"] == "todas"
    assert {x["clave"]: x["activa"] for x in f["funcionalidades"]} == {"ALM": True, "MAN": True, "PAN": True, "TAR": False}

    r = await _cargar(con, "dnato_activar_funcionalidad", {"funcionalidad": "TAR", "activa": True})
    assert r["estado"] == "fallida" and "no está en el plan" in r["error"]


async def test_cada_empresa_ve_solo_su_simulacion(con):
    await _cargar(con, "man_alta_area", {"descripcion": "Área de A"})
    await rag.fijar_empresa(con, OTRA)
    async with con.cursor() as cur:
        await cur.execute("SELECT count(*) AS n FROM agente.simulacion")
        assert (await cur.fetchone())["n"] == 0


# ============================================================ en la charla
async def test_en_la_charla_kuntur_lee_y_propone_sin_grabar(con, monkeypatch, llm_falso):
    llm = llm_falso([
        respuesta_tool("man_get_configuracion", "{}", call_id="c1"),
        respuesta_tool("man_alta_sector", json.dumps({"descripcion": "Mina a cielo abierto"}), call_id="c2"),
        respuesta_texto("Te propongo cargar el sector: tocá «Cargar» si está bien."),
    ])
    mcp = MCPFalso()
    _parchar(monkeypatch, llm, mcp)
    agente = await agentes.para_consulta(con, "kuntur", "1")
    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="Armemos los sectores", autorizacion="Bearer admin",
        usuario_nick="admin@empresa", agente=agente))

    vistas = {t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]}
    assert {"man_get_configuracion", "man_alta_sector", "dnato_asignar_menu_rol"} <= vistas
    assert [(ll.tool, ll.status) for ll in mcp.llamadas] == [("man_get_configuracion", "ok"),
                                                             ("man_alta_sector", "propuesta")]
    assert res.propuestas_carga[0]["simulado"] is True
    await rag.fijar_empresa(con, EMPRESA)
    assert (await simulados.leer(con, EMPRESA, "man_get_configuracion"))["configuracion"] == {}


async def test_una_propuesta_que_no_respeta_la_interfaz_vuelve_al_modelo(con, monkeypatch, llm_falso):
    llm = llm_falso([
        respuesta_tool("dnato_asignar_menu_rol", json.dumps({"rol": "Administrador", "opciones": []})),
        respuesta_texto("El rol Administrador no se puede editar."),
    ])
    _parchar(monkeypatch, llm, MCPFalso())
    agente = await agentes.para_consulta(con, "kuntur", "1")
    res = await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="Sacale opciones al administrador", autorizacion="Bearer admin",
        usuario_nick="admin@empresa", agente=agente))
    assert res.propuestas_carga == []
    devuelto = [m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"][0]["content"]
    assert "No se puede proponer" in devuelto
