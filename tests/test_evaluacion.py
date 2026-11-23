"""Medicion del plan y practicas (AGENTE-CO-05).

Las reglas (hacia donde mejora, funciono / no funciono / sin datos, el texto del
aviso, la practica sin cifras) corren sin base. Las que guardan necesitan la
base de prueba (AGENTE_DB_* y AGENTE_TEST_DB_ADMIN_DSN).
"""
from __future__ import annotations

import re
from datetime import date, timedelta
from decimal import Decimal

import pytest

from agente import evaluacion as ev
from agente import mediciones as m
from agente import rag
from agente.config import Config
from test_orquestador import MCPFalso, _conectar_o_saltear, _parchar

EMPRESA = 900411
OTRA = 900412
HOY = date(2026, 11, 22)


def _med(indicador="tar_get_atrasadas", parametros=None, petr_id=77, mid=1):
    return {"medicion_id": mid, "empr_id": EMPRESA, "petr_id": petr_id,
            "indicador": indicador, "parametros": parametros or {}}


def _res(*valores, tool="tar_get_atrasadas"):
    return [{"fecha": HOY - timedelta(days=30 - 7 * i), "valor": None if v is None else Decimal(str(v)), "tool": tool}
            for i, v in enumerate(valores)]


# ================================================================ sin base
@pytest.mark.parametrize("indicador,parametros,esperado", [
    ("tar_get_atrasadas", {}, "bajar"),
    ("man_get_kpi_disponibilidad", {}, "subir"),
    ("man_get_kpi_fallas", {}, "bajar"),
    ("kpi_get_valor", {"kpi": "alm_reorder"}, "subir"),            # sin sentido conocido: subir
    ("tar_get_atrasadas", {"mejor": "subir"}, "subir"),            # lo que dijo Kuntur manda
    ("kpi_get_valor", {"mejor": "bajar"}, "bajar"),
    ("kpi_get_valor", {"mejor": "cualquiera"}, "subir"),
])
def test_hacia_donde_mejora_el_indicador(indicador, parametros, esperado):
    assert ev.mejor_de(indicador, parametros) == esperado


@pytest.mark.parametrize("indicador,parametros,valores,resultado", [
    ("tar_get_atrasadas", {}, (12, 9, 4), ev.FUNCIONO),              # bajaron las atrasadas
    ("tar_get_atrasadas", {}, (4, 6, 9), ev.NO_FUNCIONO),
    ("tar_get_atrasadas", {}, (5, 5), ev.NO_FUNCIONO),               # igual = no funciono
    ("man_get_kpi_disponibilidad", {}, (78, 80, 86), ev.FUNCIONO),
    ("man_get_kpi_disponibilidad", {}, (86, 80), ev.NO_FUNCIONO),
    ("tar_get_atrasadas", {}, (7,), ev.SIN_DATOS),                   # una sola medicion
    ("tar_get_atrasadas", {}, (None, 7, None), ev.SIN_DATOS),        # los sin valor no cuentan
    ("tar_get_atrasadas", {}, (), ev.SIN_DATOS),
])
def test_funciono_no_funciono_o_sin_datos(indicador, parametros, valores, resultado):
    e = ev.evaluar(_med(indicador, parametros), _res(*valores, tool=indicador))
    assert e.resultado == resultado


def test_compara_el_primer_valor_con_el_ultimo_e_ignora_los_vacios():
    e = ev.evaluar(_med(), _res(None, 12, 15, 4, None))
    assert (e.valor_inicial, e.valor_final, e.mediciones) == (Decimal("12"), Decimal("4"), 3)
    assert e.fecha_inicial < e.fecha_final and e.tool == "tar_get_atrasadas"


def test_el_aviso_lleva_los_dos_numeros_sus_fechas_y_la_tool():
    e = ev.evaluar(_med(), _res(12, 4))
    a = ev.aviso_de(e, emisor="Kuntur")
    assert a.tipo == ev.TIPO_AVISO and a.emisor == "Kuntur"
    assert a.titulo == "El plan del pedido 77 funcionó"
    assert "pasó de 12 el " in a.cuerpo and " a 4 el " in a.cuerpo and "según tar_get_atrasadas" in a.cuerpo
    assert a.dedupe_key == "plan_accion_resultado:1"          # uno por medicion
    assert a.entidad_tipo == "pedido_trabajo" and a.entidad_id == "77"

    no = ev.aviso_de(ev.evaluar(_med(), _res(4, 12)), emisor="Kuntur")
    assert "no movió" in no.titulo and "revisar la causa" in no.cuerpo and no.severidad == "aviso"

    sd = ev.aviso_de(ev.evaluar(_med(), _res(4)), emisor="Kuntur")
    assert "No pude saber" in sd.titulo and "tengo 1 valor(es)" in sd.cuerpo


def test_la_practica_no_lleva_cifras_ni_datos_de_la_empresa():
    e = ev.evaluar(_med("man_get_kpi_disponibilidad"), _res(78, 86, tool="man_get_kpi_disponibilidad"))
    hitos, tareas = ev.nombres_del_pedido({"pedido": {"petr_id": "77", "cliente": "Minera X"}, "hitos": [
        {"hito_id": "1", "descripcion": "Ponerse al día con 6 preventivos", "tareas": [
            {"tapl_id": "10", "nombre": "Hacer los 6 preventivos de la pala P-01"},
            {"tapl_id": "11", "nombre": "Pedir repuestos al 50%"}]},
        {"hito_id": "2", "descripcion": "Medir", "tareas": []}]})
    contenido, evidencia = ev.candidato_de(e, hitos=hitos, tareas=tareas, vertical="mineria")
    assert not re.search(r"\d", contenido), contenido
    assert "Minera X" not in contenido and "77" not in contenido
    assert "Ponerse al día con preventivos" in contenido and "la disponibilidad de los equipos" in contenido
    assert "de mineria" in contenido
    assert evidencia == {"origen": "plan_accion", "indicador": "man_get_kpi_disponibilidad",
                         "mejor": "subir", "resultado": "funciono", "vertical": "mineria"}
    assert not any(re.search(r"\d", str(v)) for v in evidencia.values())


def test_sin_detalle_del_pedido_la_practica_lo_dice_para_el_curador():
    e = ev.evaluar(_med(), _res(9, 3))
    contenido, _ = ev.candidato_de(e, hitos=[], tareas=[], vertical=None)
    assert "completarlo al curar" in contenido and not re.search(r"\d", contenido)


def test_kuntur_puede_decir_hacia_donde_mejora_y_no_viaja_a_la_tool():
    f = m.validar({"indicador": "kpi_get_valor", "parametros": {"kpi": "alm_reorder", "mejor": "bajar"},
                   "frecuencia": "semanal", "hasta": (HOY + timedelta(days=30)).isoformat(), "petr_id": 77},
                  hoy=HOY, medibles=frozenset({"kpi_get_valor"}))
    assert f["parametros"] == {"kpi": "alm_reorder", "mejor": "bajar"}
    assert m.argumentos_de("kpi_get_valor", f["parametros"], HOY) == {"kpi": "alm_reorder"}
    with pytest.raises(m.MedicionInvalida, match="mejor"):
        m.validar({"indicador": "kpi_get_valor", "parametros": {"mejor": "al costado"},
                   "frecuencia": "semanal", "hasta": (HOY + timedelta(days=30)).isoformat()},
                  hoy=HOY, medibles=frozenset({"kpi_get_valor"}))


# ================================================================ con base
@pytest.fixture
async def con(con_admin):
    async with con_admin.cursor() as cur:
        for t in ("avance_plan", "medicion_resultado", "medicion_pedida"):
            await cur.execute(f"DELETE FROM agente.{t} WHERE empr_id IN (%s, %s)", (EMPRESA, OTRA))
        await cur.execute("DELETE FROM agente.candidato WHERE origen = 'plan_accion' AND situacion = 'plan_accion_que_funciono' "
                          "AND evidencia->>'indicador' = 'tar_get_atrasadas' AND contenido LIKE '%%prueba-co05%%'")
    await con_admin.commit()
    co = await _conectar_o_saltear()
    try:
        yield co
    finally:
        await co.rollback()
        await co.close()


async def _medicion_vencida(con, empr, valores, *, petr_id=77):
    await rag.fijar_empresa(con, empr)
    async with con.cursor() as cur:
        await cur.execute(
            """INSERT INTO agente.medicion_pedida (empr_id, indicador, parametros, alcance, frecuencia, desde, hasta, petr_id)
               VALUES (%s, 'tar_get_atrasadas', '{}'::jsonb, 'actividad', 'semanal', %s, %s, %s) RETURNING medicion_id""",
            (empr, HOY - timedelta(days=40), HOY - timedelta(days=1), petr_id))
        mid = (await cur.fetchone())["medicion_id"]
        for i, v in enumerate(valores):
            await cur.execute("""INSERT INTO agente.medicion_resultado (medicion_id, empr_id, fecha, valor, tool)
                                 VALUES (%s, %s, %s, %s, 'tar_get_atrasadas')""",
                              (mid, empr, HOY - timedelta(days=35 - 7 * i), v))
    await con.commit()
    return mid


def _pedido_prueba():
    return {"pedido": {"petr_id": "77"}, "hitos": [
        {"hito_id": "1", "descripcion": "Ordenar el taller prueba-co05",
         "tareas": [{"tapl_id": "10", "nombre": "Terminar 5 tareas viejas"}]}]}


async def test_el_trabajo_diario_evalua_una_vez_avisa_y_propone_practica(con, monkeypatch, llm_falso):
    mid = await _medicion_vencida(con, EMPRESA, [12, 8, 3])
    publicados = []

    async def publicar(cfg, auth, aviso, **kw):
        publicados.append(aviso)
        return 555

    monkeypatch.setattr(ev.avisos, "habilitado", lambda cfg: True)
    monkeypatch.setattr(ev.avisos, "publicar", publicar)
    mcp = MCPFalso(salidas={"tar_get_pedido": _pedido_prueba()})
    _parchar(monkeypatch, llm_falso([]), mcp)
    monkeypatch.setattr("agente.mediciones.ClienteMCP", lambda cfg, auth: mcp)

    r = await m.medir_empresa(con, Config(), EMPRESA, "Bearer maquina", hoy=HOY)
    assert r["error"] is None and r["planes_evaluados"] == 1
    assert [a.titulo for a in publicados] == ["El plan del pedido 77 funcionó"]
    assert [ll.tool for ll in mcp.llamadas] == ["tar_get_pedido"]

    await rag.fijar_empresa(con, EMPRESA)
    async with con.cursor() as cur:
        await cur.execute("SELECT resultado, aviso_id, candidato_id, valor_inicial, valor_final "
                          "FROM agente.evaluacion_plan WHERE medicion_id = %s", (mid,))
        e = await cur.fetchone()
        assert e["resultado"] == "funciono" and e["aviso_id"] == 555 and e["candidato_id"]
        assert (e["valor_inicial"], e["valor_final"]) == (Decimal("12"), Decimal("3"))
        await cur.execute("SELECT contenido, estado, origen FROM agente.candidato WHERE candidato_id = %s",
                          (e["candidato_id"],))
        c = await cur.fetchone()
        assert c["estado"] == "pendiente" and c["origen"] == "plan_accion"
        assert not re.search(r"\d", c["contenido"]) and "Terminar tareas viejas" in c["contenido"]

    # El panel lo muestra en "Planes que terminaron".
    lista = {x["medicion_id"]: x for x in await m.listar(con)}
    assert lista[mid]["evaluacion"]["resultado"] == "funciono"
    assert lista[mid]["evaluacion"]["valor_final"] == 3.0

    # Corre de nuevo: no evalua ni avisa otra vez.
    publicados.clear()
    mcp.llamadas.clear()
    r = await m.medir_empresa(con, Config(), EMPRESA, "Bearer maquina", hoy=HOY)
    assert r.get("planes_evaluados") is None and publicados == [] and mcp.llamadas == []


async def test_si_el_aviso_no_sale_se_reintenta_sin_reevaluar(con, monkeypatch, llm_falso):
    mid = await _medicion_vencida(con, EMPRESA, [3, 9])            # no funciono: no lee el pedido
    mcp = MCPFalso()
    _parchar(monkeypatch, llm_falso([]), mcp)
    monkeypatch.setattr("agente.mediciones.ClienteMCP", lambda cfg, auth: mcp)
    monkeypatch.setattr(ev.avisos, "habilitado", lambda cfg: True)

    async def falla(cfg, auth, aviso, **kw):
        raise ev.avisos.AvisoError("caido")

    monkeypatch.setattr(ev.avisos, "publicar", falla)
    r = await m.medir_empresa(con, Config(), EMPRESA, "Bearer m", hoy=HOY)
    assert r["planes_evaluados"] == 1 and mcp.llamadas == []

    publicados = []

    async def ok(cfg, auth, aviso, **kw):
        publicados.append(aviso)
        return 7

    monkeypatch.setattr(ev.avisos, "publicar", ok)
    await m.medir_empresa(con, Config(), EMPRESA, "Bearer m", hoy=HOY + timedelta(days=1))
    assert [a.dedupe_key for a in publicados] == [f"plan_accion_resultado:{mid}"]
    assert "no movió" in publicados[0].titulo
    await rag.fijar_empresa(con, EMPRESA)
    async with con.cursor() as cur:
        await cur.execute("SELECT aviso_id, candidato_id FROM agente.evaluacion_plan WHERE medicion_id = %s", (mid,))
        assert await cur.fetchone() == {"aviso_id": 7, "candidato_id": None}


async def test_una_medicion_sin_plan_o_cancelada_no_se_evalua(con, monkeypatch, llm_falso):
    sin_plan = await _medicion_vencida(con, EMPRESA, [12, 3], petr_id=None)
    cancelada = await _medicion_vencida(con, EMPRESA, [12, 3])
    await rag.fijar_empresa(con, EMPRESA)
    async with con.cursor() as cur:
        await cur.execute("UPDATE agente.medicion_pedida SET estado = 'cancelada' WHERE medicion_id = %s", (cancelada,))
    await con.commit()
    mcp = MCPFalso()
    _parchar(monkeypatch, llm_falso([]), mcp)
    monkeypatch.setattr("agente.mediciones.ClienteMCP", lambda cfg, auth: mcp)
    r = await m.medir_empresa(con, Config(), EMPRESA, "Bearer m", hoy=HOY)
    assert r.get("planes_evaluados") is None
    await rag.fijar_empresa(con, EMPRESA)
    assert await ev.por_evaluar(con) == []
    assert sin_plan and cancelada


async def test_una_empresa_no_ve_las_evaluaciones_de_otra(con, monkeypatch, llm_falso):
    mid = await _medicion_vencida(con, EMPRESA, [12, 3])
    mcp = MCPFalso(salidas={"tar_get_pedido": _pedido_prueba()})
    _parchar(monkeypatch, llm_falso([]), mcp)
    monkeypatch.setattr("agente.mediciones.ClienteMCP", lambda cfg, auth: mcp)
    await m.medir_empresa(con, Config(), EMPRESA, "Bearer m", hoy=HOY)

    await rag.fijar_empresa(con, OTRA)
    async with con.cursor() as cur:
        await cur.execute("SELECT count(*) AS n FROM agente.evaluacion_plan WHERE medicion_id = %s", (mid,))
        assert (await cur.fetchone())["n"] == 0
        await cur.execute("SELECT count(*) AS n FROM agente.evaluacion_plan")
        assert (await cur.fetchone())["n"] == 0
    assert await ev.por_evaluar(con) == []
