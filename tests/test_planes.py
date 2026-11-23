"""Plan de accion de Kuntur, opcion B (agente/planes.py, 031, ADR-A13).

Lo que importa:
  * el codigo valida lo que arma el modelo: topes, nombres, nunca un
    responsable asignado, nunca un proceso (siempre el Proceso Estandar);
  * en la charla no se crea nada en Tareas: queda la propuesta y la tarjeta;
  * "Aceptar" crea pedido -> hitos -> tareas, todo o nada: si un paso falla,
    se deshace lo creado. Hoy SIMULADO hasta que el PM apruebe los recursos MCP;
  * "No lo quiero" exige motivo y Kuntur lo lee para no repetir;
  * una empresa no ve los planes de otra; solo un administrador responde.
"""
from __future__ import annotations

import base64
import json
from datetime import date

import pytest
from httpx import ASGITransport, AsyncClient

from agente import agentes, planes, rag
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool
from test_orquestador import MCPFalso, _parchar

EMPRESA = 900501
OTRA = 900502
HOY = date(2026, 11, 23)


@pytest.fixture(autouse=True)
def _modo_simulado(monkeypatch):
    """Desde el 2026-11-22 el motor crea en Tareas de verdad (SIMULADO = False). Estas
    pruebas corren sin gateway, así que usan el modo simulado; el recorrido real está
    probado con un cliente MCP falso y en el MI aislado (tests/security/mcp-plan-accion.hurl)."""
    monkeypatch.setattr(planes, "SIMULADO", True)


def _plan(**cambios) -> dict:
    p = {
        "porque": "La disponibilidad bajó a 78 % y hay 6 preventivos atrasados en las palas.",
        "objetivo": "Volver a la meta en 4 semanas.",
        "pedido": {"nombre": "Recuperar disponibilidad de palas", "descripcion": "Plan propuesto por Kuntur"},
        "hitos": [
            {"nombre": "Ponerse al día con los preventivos", "semana_desde": 1, "semana_hasta": 2,
             "tareas": [{"nombre": "Hacer los preventivos atrasados", "responsable_sugerido": "jefe de taller"},
                        {"nombre": "Pedir los repuestos que faltan", "responsable_sugerido": "pañolero"}]},
            {"nombre": "Medir", "semana_desde": 4, "semana_hasta": 4,
             "tareas": [{"nombre": "Comparar la disponibilidad antes y después"}]},
        ],
    }
    p.update(cambios)
    return p


# ============================================================ validacion
def test_un_plan_bien_armado_queda_con_el_proceso_estandar_y_sus_totales():
    p = planes.validar(_plan(), hoy=HOY)
    assert p["proceso"] == "PROCESO-STANDAR"
    assert p["semanas"] == 4 and p["total_tareas"] == 3
    assert p["hitos"][0]["tareas"][0]["responsable_sugerido"] == "jefe de taller"


def test_las_semanas_del_plan_no_las_bloquea_el_guardian():
    """Prueba real contra DEV (2026-11-23): "Semana 1" se bloqueaba por cifra sin fuente.

    Las semanas de cada hito las fija el propio plan: el modelo las ve en la
    salida de la tool y puede nombrarlas."""
    from agente import guardian
    prop = planes.Propuesta("p-1", planes.validar(_plan(), hoy=HOY))
    vista = [("kuntur_proponer_plan", json.dumps(prop.para_el_modelo(), ensure_ascii=False))]
    v = guardian.revisar("Semana 1 y 2: preventivos. Semana 4: medir. Son 2 hitos y 3 tareas.", tools=vista)
    assert not v.bloquear, v.sin_fuente


@pytest.mark.parametrize("cambio,mensaje", [
    ({"proc_id": "YUDICA-001"}, "Proceso Estándar"),
    ({"porque": ""}, "porque"),
    ({"objetivo": "  "}, "objetivo"),
    ({"pedido": {"nombre": ""}}, "nombre"),
    ({"hitos": []}, "al menos un hito"),
    ({"hitos": [{"nombre": f"H{i}", "semana_desde": 1, "semana_hasta": 1,
                 "tareas": [{"nombre": "t"}]} for i in range(7)]}, "Máximo 6 hitos"),
    ({"hitos": [{"nombre": "H", "semana_desde": 3, "semana_hasta": 2, "tareas": [{"nombre": "t"}]}]}, "anterior"),
    ({"hitos": [{"nombre": "H", "semana_desde": 1, "semana_hasta": 99, "tareas": [{"nombre": "t"}]}]}, "entre 1 y"),
    ({"hitos": [{"nombre": "H", "semana_desde": 1, "semana_hasta": 1, "tareas": []}]}, "al menos una tarea"),
    ({"hitos": [{"nombre": "H", "semana_desde": 1, "semana_hasta": 1,
                 "tareas": [{"nombre": "t", "user_id": "juan"}]}]}, "nadie se asigna"),
    ({"hitos": [{"nombre": f"H{i}", "semana_desde": 1, "semana_hasta": 1,
                 "tareas": [{"nombre": f"t{j}"} for j in range(8)]} for i in range(4)]}, "Máximo 30 tareas"),
    ({"meta": {"kpi": "inventado", "operador": ">=", "meta": 85, "hasta": "2026-12-31"}}, "Meta del plan"),
])
def test_lo_que_no_sirve_vuelve_al_modelo_con_el_motivo(cambio, mensaje):
    with pytest.raises(planes.PlanInvalido, match=mensaje):
        planes.validar(_plan(**cambio), hoy=HOY)


def test_la_meta_del_plan_se_valida_como_una_meta():
    p = planes.validar(_plan(meta={"kpi": "man_disponibilidad", "operador": ">=", "meta": 85,
                                   "hasta": "2026-12-31"}), hoy=HOY)
    assert p["meta"]["kpi"] == "man_disponibilidad" and p["meta"]["meta"] == "85"


def test_las_fechas_salen_de_las_semanas_y_las_tareas_no_tienen_responsable():
    pedido, hitos = planes.pasos(planes.validar(_plan(), hoy=HOY), hoy=HOY, codigo="K-261123-ABC123")
    assert pedido["fec_inicio"] == "2026-11-23" and pedido["fec_entrega"] == "2026-12-21"
    assert pedido["semanas"] == 4 and pedido["codigo"] == "K-261123-ABC123" and "Objetivo:" in pedido["descripcion"]
    assert planes.codigo_de("abcdef12-0000-0000-0000-000000000000", HOY) == "K-261123-ABCDEF"
    assert hitos[1][0]["fec_inicio"] == "2026-12-14" and hitos[0][0]["semanas"] == 2
    assert all("user_id" not in t and "responsable" not in t for _, ts in hitos for t in ts)
    assert "(sugerido: jefe de taller)" in hitos[0][1][0]["descripcion"]


# ============================================================ todo o nada
class DestinoQueFalla(planes.DestinoSimulado):
    """Falla en la tarea numero `en` y registra lo que se dio de baja."""

    def __init__(self, en: int):
        super().__init__()
        self.en, self.altas, self.bajas = en, 0, []

    async def alta_tarea(self, hito_id, datos):
        self.altas += 1
        if self.altas == self.en:
            raise planes.PasoFallido("Alta de una tarea: el servicio de datos no respondió")
        return await super().alta_tarea(hito_id, datos)

    async def baja_tarea(self, tapl_id):
        self.bajas.append(tapl_id)
        await super().baja_tarea(tapl_id)

    async def baja_pedido(self, petr_id):
        self.bajas.append(petr_id)
        await super().baja_pedido(petr_id)


async def test_si_falla_una_tarea_se_deshace_todo_lo_creado():
    d = DestinoQueFalla(en=3)
    with pytest.raises(planes.PasoFallido, match="todo o nada"):
        await planes.crear(d, planes.validar(_plan(), hoy=HOY), hoy=HOY)
    assert d.bajas == ["SIM-T4", "SIM-T3", "SIM-P1"]   # las tareas al revés y despues el pedido
    assert d.creado["pedido"] is None and d.creado["tareas"] == []


async def test_si_tampoco_se_puede_deshacer_se_dice_que_quedo():
    class SinBaja(DestinoQueFalla):
        async def baja_pedido(self, petr_id):
            raise planes.PasoFallido("no responde")
    with pytest.raises(planes.PasoFallido, match="No se pudo deshacer: pedido SIM-P1"):
        await planes.crear(SinBaja(en=1), planes.validar(_plan(), hoy=HOY), hoy=HOY)


# ============================================================ con la base
async def _conectar_o_saltear():
    cfg = Config()
    try:
        return await rag.abrir(cfg)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"Base del agente no disponible: {e}")


@pytest.fixture
async def con(con_admin):
    async with con_admin.cursor() as cur:
        for t in ("plan_propuesta", "tool_llamada", "interaccion", "simulacion"):
            await cur.execute(f"DELETE FROM agente.{t} WHERE empr_id IN (%s, %s)", (EMPRESA, OTRA))
    await con_admin.commit()
    c = await _conectar_o_saltear()
    try:
        yield c
    finally:
        await c.rollback()
        await c.close()


async def _consultar(con, monkeypatch, llm, rol="1"):
    _parchar(monkeypatch, llm, MCPFalso())
    agente = await agentes.para_consulta(con, "kuntur", rol)
    return await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="La disponibilidad viene mal, ¿qué hacemos?", autorizacion="Bearer admin",
        usuario_nick="admin@empresa", agente=agente))


async def test_en_la_charla_queda_la_propuesta_y_no_se_crea_nada(con, monkeypatch, llm_falso):
    plan = _plan(porque="Hay preventivos atrasados en las palas.")
    llm = llm_falso([
        respuesta_tool(planes.NOMBRE, json.dumps(plan)),
        respuesta_texto("Te dejé el plan en una tarjeta: si te sirve, aceptalo."),
    ])
    res = await _consultar(con, monkeypatch, llm)
    assert planes.NOMBRE in {t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]}
    assert len(res.propuestas_plan) == 1, res.incidentes
    t = res.propuestas_plan[0]
    assert t["proceso"] == "Proceso Estándar" and t["simulado"] is True and t["total_tareas"] == 3
    registrada = [ll for ll in res.tools_llamadas if ll["tool"] == planes.NOMBRE][0]
    assert registrada["status"] == "propuesta"
    devuelto = [m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"][0]["content"]
    assert "No se creó nada" in devuelto and "preventivos" not in devuelto
    async with con.cursor() as cur:
        await cur.execute("SELECT count(*) AS n FROM agente.simulacion")
        assert (await cur.fetchone())["n"] == 0


async def test_quirqui_no_ve_la_herramienta_del_plan(con):
    assert planes.NOMBRE not in await agentes.tools_permitidas(con, "quirqui")
    assert planes.NOMBRE in await agentes.tools_permitidas(con, "kuntur")


async def test_un_plan_con_una_cifra_inventada_no_muestra_tarjeta(con, monkeypatch, llm_falso):
    """El 'porque' lo escribe el modelo: sus cifras pasan por el guardian (R4)."""
    llm = llm_falso([
        respuesta_tool(planes.NOMBRE, json.dumps(_plan(porque="La disponibilidad bajó a 61 % este mes."))),
        respuesta_texto("Te dejé el plan en una tarjeta."),
    ])
    res = await _consultar(con, monkeypatch, llm)
    assert res.propuestas_plan == []


async def _propuesta(con, empr_id=EMPRESA) -> str:
    await rag.fijar_empresa(con, empr_id)
    p = await planes.proponer(con, empr_id=empr_id, interaccion_id=None, usuario="admin@empresa",
                              plan=planes.validar(_plan()))
    await con.commit()
    await rag.fijar_empresa(con, empr_id)
    return p.plan_id


async def test_aceptar_simulado_registra_lo_que_se_crearia(con):
    plan_id = await _propuesta(con)
    r = await planes.aceptar(con, Config(), empr_id=EMPRESA, plan_id=plan_id, usuario="admin@empresa",
                             autorizacion="Bearer del-admin")
    assert r["estado"] == "aceptada" and r["simulado"] is True and r["petr_id"].startswith("SIM-")
    async with con.cursor() as cur:
        await cur.execute("SELECT datos FROM agente.simulacion WHERE entidad = %s AND clave = %s",
                          (planes.ENTIDAD_SIMULACION, plan_id))
        datos = (await cur.fetchone())["datos"]
        await cur.execute("SELECT estado, petr_id, simulado, respondido_por FROM agente.plan_propuesta "
                          "WHERE plan_id = %s", (plan_id,))
        fila = await cur.fetchone()
    assert datos["proceso"] == "PROCESO-STANDAR" and len(datos["hitos"]) == 2 and len(datos["tareas"]) == 3
    assert fila["estado"] == "aceptada" and fila["simulado"] and fila["respondido_por"] == "admin@empresa"
    with pytest.raises(planes.PlanNoDisponible, match="ya está aceptada"):
        await planes.aceptar(con, Config(), empr_id=EMPRESA, plan_id=plan_id, usuario="x", autorizacion="x")


async def test_si_falla_la_creacion_queda_fallida_y_no_se_registra_nada(con):
    plan_id = await _propuesta(con)
    r = await planes.aceptar(con, Config(), empr_id=EMPRESA, plan_id=plan_id, usuario="admin@empresa",
                             autorizacion="Bearer del-admin", destino=DestinoQueFalla(en=2))
    assert r["estado"] == "fallida" and "todo o nada" in r["error"]
    async with con.cursor() as cur:
        await cur.execute("SELECT estado, petr_id FROM agente.plan_propuesta WHERE plan_id = %s", (plan_id,))
        fila = await cur.fetchone()
    assert fila["estado"] == "fallida" and fila["petr_id"] is None


async def test_no_lo_quiero_exige_motivo_y_kuntur_lo_lee(con, monkeypatch, llm_falso):
    plan_id = await _propuesta(con)
    with pytest.raises(planes.PlanNoDisponible, match="motivo"):
        await planes.descartar(con, empr_id=EMPRESA, plan_id=plan_id, usuario="admin@empresa", motivo="porque si")
    r = await planes.descartar(con, empr_id=EMPRESA, plan_id=plan_id, usuario="admin@empresa",
                               motivo="ya_lo_hacemos", texto="Lo arrancamos la semana pasada")
    assert r["estado"] == "descartada"
    llm = llm_falso([respuesta_texto("Entendido.")])
    await _consultar(con, monkeypatch, llm)
    sistema = " ".join(m["content"] for m in llm.llamadas_chat[0]["mensajes"] if m["role"] == "system")
    assert "Recuperar disponibilidad de palas" in sistema and "Ya lo estamos haciendo" in sistema


async def test_el_plan_de_otra_empresa_no_existe(con):
    plan_id = await _propuesta(con, OTRA)
    await rag.fijar_empresa(con, EMPRESA)
    assert await planes.pendientes(con) == []
    with pytest.raises(planes.PlanNoDisponible, match="No existe"):
        await planes.aceptar(con, Config(), empr_id=EMPRESA, plan_id=plan_id, usuario="x", autorizacion="x")


# ==================================================================== la API
def _jwt(**claims) -> str:
    def b64(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")
    return f"Bearer {b64({'alg': 'none'})}.{b64(claims)}.firma"


async def test_solo_un_administrador_ve_y_responde_los_planes(con):
    import agente.api as mod
    plan_id = await _propuesta(con)
    async with AsyncClient(transport=ASGITransport(app=mod.app), base_url="http://t") as api:
        empleado = {"Authorization": _jwt(empr_id=EMPRESA, role="4")}
        admin = {"Authorization": _jwt(empr_id=EMPRESA, role="1", sub="admin@empresa")}
        assert (await api.get("/kuntur/planes", headers=empleado)).status_code == 404
        assert (await api.post("/kuntur/planes/aceptar", json={"plan_id": plan_id},
                               headers=empleado)).status_code == 404
        r = await api.get("/kuntur/planes", headers=admin)
        assert r.status_code == 200 and [p["plan_id"] for p in r.json()["planes"]] == [plan_id]
        r = await api.post("/kuntur/planes/descartar", json={"plan_id": plan_id, "motivo": "cualquiera"},
                           headers=admin)
        assert r.status_code == 422
        r = await api.post("/kuntur/planes/aceptar", json={"plan_id": plan_id}, headers=admin)
        assert r.status_code == 200, r.text
        assert r.json()["estado"] == "aceptada" and r.json()["simulado"] is True


async def test_aceptar_de_verdad_llama_a_las_altas_de_la_fachada_en_orden():
    """El recorrido real (cuando el PM apruebe los recursos MCP): nombres, cuerpos y respuestas."""
    class MCPRegistra:
        def __init__(self):
            self.llamadas, self.n = [], 0

        async def llamar(self, nombre, args):
            self.llamadas.append((nombre, args))
            self.n += 1
            clave = {"tar_alta_pedido": "petr_id", "tar_alta_hito": "hito_id", "tar_alta_tarea": "tapl_id"}[nombre]
            return {"respuesta": {clave: str(self.n)}}

    mcp = MCPRegistra()
    creado = await planes.crear(planes.DestinoMCP(mcp), planes.validar(_plan(), hoy=HOY), hoy=HOY, codigo="K-1")
    nombres = [n for n, _ in mcp.llamadas]
    assert nombres == ["tar_alta_pedido", "tar_alta_hito", "tar_alta_tarea", "tar_alta_tarea",
                       "tar_alta_hito", "tar_alta_tarea"]
    assert mcp.llamadas[0][1]["codigo"] == "K-1" and "proc_id" not in mcp.llamadas[0][1]
    assert mcp.llamadas[1][1]["petr_id"] == "1" and mcp.llamadas[2][1]["hito_id"] == "2"
    assert all("user_id" not in a for _, a in mcp.llamadas)
    assert creado == {"petr_id": "1", "hitos": ["2", "5"], "tareas": ["3", "4", "6"]}


def test_los_textos_largos_se_recortan_sin_cortar_palabras():
    from agente.planes import _texto
    t = _texto("las OTs correctivas cerradas son fugas hidráulicas y rotura de mangueras", 60)
    assert t.endswith("…") and len(t) <= 60
    assert not t[:-1].endswith("mangue")
    assert _texto("corto", 60) == "corto"


def test_una_cantidad_inventada_en_una_tarea_la_ve_el_guardian():
    """Prueba real contra DEV (2026-11-23): "sugerido: 100 u. aceite" llegó a Tareas sin fuente."""
    from agente import guardian
    from agente.orquestador import _textos_del_plan
    p = planes.validar(_plan(hitos=[{"nombre": "Comprar", "semana_desde": 1, "semana_hasta": 1,
                                     "tareas": [{"nombre": "Emitir la orden", "descripcion": "Pedir 130 bidones de aceite"}]}]),
                       hoy=HOY)
    prop = planes.Propuesta("p-2", p)
    vista = [("alm_get_stock", '{"stock": "10", "punto_pedido": "50"}'),
             ("kuntur_proponer_plan", json.dumps(prop.para_el_modelo(), ensure_ascii=False))]
    texto = "\n".join(_textos_del_plan(prop.tarjeta()))
    assert "130" in texto
    v = guardian.revisar(texto, tools=vista)
    assert v.bloquear and "130" in v.sin_fuente


def test_la_meta_que_fija_el_plan_no_la_bloquea_el_guardian():
    """Prueba real contra DEV (2026-11-23): "meta al 13/12" se bloqueaba por cifra sin fuente."""
    from agente import guardian
    p = planes.validar(_plan(meta={"kpi": "man_disponibilidad", "operador": ">=", "meta": 85,
                                   "hasta": "2026-12-13"}), hoy=HOY)
    vista = [("kuntur_proponer_plan", json.dumps(planes.Propuesta("p-3", p).para_el_modelo(), ensure_ascii=False))]
    v = guardian.revisar("La meta: disponibilidad de 85 o más al 13/12.", tools=vista)
    assert not v.bloquear, v.sin_fuente
