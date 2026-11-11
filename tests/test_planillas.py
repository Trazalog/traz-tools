"""La planilla del cliente pasada a la Carga Masiva (agente/planillas.py, 028).

Lo que importa:
  * se lee CSV y Excel .xlsx como los tiene el cliente;
  * al modelo le llegan solo los encabezados y 20 filas (P-8);
  * el modelo da el mapeo; el codigo transforma TODAS las filas y frena con el
    numero de fila si falta algo;
  * en la charla no se carga nada: queda la tarjeta;
  * con "Cargar", el CSV va a la Carga Masiva de Dnato con el token del
    administrador, y si Dnato no grabo, la carga queda fallida.
"""
from __future__ import annotations

import base64
import io
import json
import zipfile

import httpx
import pytest
import respx
from httpx import ASGITransport, AsyncClient

from agente import agentes, cargas, planillas, rag
from agente.config import Config
from agente.orquestador import Consulta, Orquestador
from conftest import respuesta_texto, respuesta_tool
from test_orquestador import MCPFalso, _parchar

EMPRESA = 900401
OTRA = 900402
URL_DNATO = "http://dnato.prueba/bulkload_api/cargar"

CSV = ("﻿Código;Detalle;Unidad;Rubro;Mínimo\n"
       "a-1;Guante de nitrilo;Par;EPP;10\n"
       "A-2;Casco;Unidad;EPP;\n"
       ";;;;\n"
       "A-3;Botín;Par;EPP;4\n").encode("utf-8")
MAPEO = {"codigo": "Código", "descripcion": "Detalle", "unidad_medida": "Unidad",
         "tipo": "Rubro", "punto_pedido": "Mínimo"}


def _xlsx(filas: list[list]) -> bytes:
    """Un .xlsx minimo, con textos compartidos y numeros, como lo guarda Excel."""
    textos: list[str] = []

    def celda(ref, v):
        if isinstance(v, (int, float)):
            return f'<c r="{ref}"><v>{v}</v></c>'
        textos.append(v)
        return f'<c r="{ref}" t="s"><v>{len(textos) - 1}</v></c>'

    xml_filas = "".join(
        f'<row r="{i}">' + "".join(celda(f"{chr(65 + j)}{i}", v) for j, v in enumerate(f) if v != "") + "</row>"
        for i, f in enumerate(filas, start=1))
    ns = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"'
    b = io.BytesIO()
    with zipfile.ZipFile(b, "w") as z:
        z.writestr("xl/worksheets/sheet1.xml", f"<worksheet {ns}><sheetData>{xml_filas}</sheetData></worksheet>")
        z.writestr("xl/sharedStrings.xml",
                   f"<sst {ns}>" + "".join(f"<si><t>{t}</t></si>" for t in textos) + "</sst>")
    return b.getvalue()


# ================================================================ lectura
def test_lee_un_csv_con_punto_y_coma_y_bom():
    enc, filas = planillas.leer("articulos.csv", CSV)
    assert enc == ["Código", "Detalle", "Unidad", "Rubro", "Mínimo"]
    assert len(filas) == 3, "la fila vacia no cuenta"
    assert filas[0] == ["a-1", "Guante de nitrilo", "Par", "EPP", "10"]


def test_lee_un_csv_de_excel_en_windows():
    enc, filas = planillas.leer("x.csv", "Código,Descripción\nA1,Cañería\n".encode("cp1252"))
    assert enc == ["Código", "Descripción"] and filas == [["A1", "Cañería"]]


def test_lee_un_xlsx_y_no_le_agrega_decimales_a_un_codigo():
    contenido = _xlsx([["Código", "Detalle", "Cantidad"], [1001.0, "Pala", 3], ["B-2", "", 2.5]])
    enc, filas = planillas.leer("equipos.xlsx", contenido)
    assert enc == ["Código", "Detalle", "Cantidad"]
    assert filas == [["1001", "Pala", "3"], ["B-2", "", "2.5"]]


@pytest.mark.parametrize("nombre,contenido,mensaje", [
    ("viejo.xls", b"\xd0\xcf\x11\xe0", ".xls"),
    ("roto.xlsx", b"PK\x03\x04basura", "No pude leer el Excel"),
    ("x.pdf", b"%PDF", "Solo se leen"),
    ("x.csv", b"solo,encabezado\n", "no tiene filas"),
    ("x.csv", b"", "vacío"),
    ("x.csv", ("a\n" + "1\n" * (planillas.MAX_FILAS + 1)).encode(), "Más de"),
])
def test_lo_que_no_se_puede_leer_se_dice(nombre, contenido, mensaje):
    with pytest.raises(planillas.PlanillaInvalida, match=mensaje):
        planillas.leer(nombre, contenido)


# ========================================================= transformacion
def _planilla(contenido=CSV, nombre="articulos.csv") -> planillas.Planilla:
    enc, filas = planillas.leer(nombre, contenido)
    return planillas.Planilla("00000000-0000-0000-0000-000000000001", nombre, enc, filas)


def test_transforma_todas_las_filas_en_el_orden_de_la_plantilla():
    filas = planillas.transformar(_planilla(), "Articulos", MAPEO)
    assert [f["codigo"] for f in filas] == ["a-1", "A-2", "A-3"]
    assert filas[1]["punto_pedido"] == "", "un opcional vacio queda vacio"
    texto = planillas.a_csv("Articulos", filas)
    assert texto.splitlines()[0] == "codigo,descripcion,unidad_medida,tipo,punto_pedido", \
        "PostgreSQL toma las columnas por posicion"
    assert texto.splitlines()[1] == "a-1,Guante de nitrilo,Par,EPP,10"


def test_un_valor_fijo_completa_una_columna_que_la_planilla_no_tiene():
    sin_rubro = {k: v for k, v in MAPEO.items() if k != "tipo"}
    with pytest.raises(planillas.PlanillaInvalida, match="obligatorias.*tipo"):
        planillas.transformar(_planilla(), "Articulos", sin_rubro)
    filas = planillas.transformar(_planilla(), "Articulos", sin_rubro, {"tipo": "Insumo"})
    assert {f["tipo"] for f in filas} == {"Insumo"}


@pytest.mark.parametrize("contenido,mensaje", [
    ("Código;Detalle;Unidad;Rubro;Mínimo\nA1;Guante;;EPP;1\nA2;Casco;Unidad;EPP;x\n",
     r"fila 2: falta unidad_medida; fila 3: punto_pedido tiene que ser un número entero"),
    ("Código;Detalle;Unidad;Rubro;Mínimo\nA1;Guante;Par;EPP;1\na1;Otro;Par;EPP;1\n",
     "fila 3: el código a1 ya está en la fila 2"),
])
def test_lo_que_falta_se_informa_con_el_numero_de_fila(contenido, mensaje):
    with pytest.raises(planillas.PlanillaInvalida, match=mensaje):
        planillas.transformar(_planilla(contenido.encode()), "Articulos", MAPEO)


@pytest.mark.parametrize("entidad,mapeo,mensaje", [
    ("Clientes", MAPEO, "No hay plantilla"),
    ("Articulos", {**MAPEO, "empr_id": "Código"}, "no tiene empr_id"),
    ("Articulos", {**MAPEO, "codigo": "SKU"}, "no tiene los encabezados SKU"),
])
def test_un_mapeo_que_no_corresponde_no_pasa(entidad, mapeo, mensaje):
    with pytest.raises(planillas.PlanillaInvalida, match=mensaje):
        planillas.transformar(_planilla(), entidad, mapeo)


def test_al_modelo_le_llegan_solo_veinte_filas():
    filas = "".join(f"C{i};Artículo número {i};Par;EPP;1\n" for i in range(1, 31))
    texto = planillas.contexto(_planilla(("Código;Detalle;Unidad;Rubro;Mínimo\n" + filas).encode()))
    assert "Artículo número 20" in texto and "Artículo número 21" not in texto
    assert "30 filas" in texto and "Mantenimiento Equipos" in texto


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
        for t in ("carga_propuesta", "tool_llamada", "interaccion", "planilla"):
            await cur.execute(f"DELETE FROM agente.{t} WHERE empr_id IN (%s, %s)", (EMPRESA, OTRA))
    await con_admin.commit()
    c = await _conectar_o_saltear()
    try:
        yield c
    finally:
        await c.rollback()
        await c.close()


async def _subir(con, empr_id=EMPRESA, contenido=CSV) -> planillas.Planilla:
    await rag.fijar_empresa(con, empr_id)
    p = await planillas.guardar(con, empr_id=empr_id, usuario="admin@empresa", nombre="articulos.csv",
                                contenido=contenido)
    await con.commit()
    await rag.fijar_empresa(con, empr_id)
    return p


async def test_una_planilla_de_otra_empresa_no_existe(con):
    p = await _subir(con)
    assert (await planillas.obtener(con, p.planilla_id)).total == 3
    await rag.fijar_empresa(con, OTRA)
    with pytest.raises(planillas.PlanillaInvalida, match="No existe"):
        await planillas.obtener(con, p.planilla_id)


async def _consultar(con, monkeypatch, llm, planilla_id=None):
    _parchar(monkeypatch, llm, MCPFalso())
    agente = await agentes.para_consulta(con, "kuntur", "1")
    return await Orquestador(Config()).responder(con, Consulta(
        empr_id=EMPRESA, pregunta="Te subí mis artículos, ¿los cargamos?", autorizacion="Bearer admin",
        usuario_nick="admin@empresa", agente=agente, planilla_id=planilla_id))


async def test_sin_planilla_kuntur_no_ve_la_carga_masiva(con, monkeypatch, llm_falso):
    llm = llm_falso([respuesta_texto("Subime la planilla y la vemos.")])
    await _consultar(con, monkeypatch, llm)
    assert planillas.NOMBRE not in {t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]}


async def test_en_la_charla_kuntur_mapea_y_queda_la_tarjeta(con, monkeypatch, llm_falso):
    p = await _subir(con)
    llm = llm_falso([
        respuesta_tool(planillas.NOMBRE, json.dumps({"planilla_id": p.planilla_id, "entidad": "Articulos",
                                                     "mapeo": MAPEO})),
        respuesta_texto("Te armé la carga de 3 artículos: revisala y tocá «Cargar»."),
    ])
    res = await _consultar(con, monkeypatch, llm, p.planilla_id)

    assert planillas.NOMBRE in {t["function"]["name"] for t in llm.llamadas_chat[0]["tools"]}
    sistema = " ".join(m["content"] for m in llm.llamadas_chat[0]["mensajes"] if m["role"] == "system")
    assert "Guante de nitrilo" in sistema and p.planilla_id in sistema
    t = res.propuestas_carga[0]
    assert t["total_filas"] == 3 and t["filas"][0]["codigo"] == "a-1"
    assert t["datos"]["entidad"] == "Articulos" and t["datos"]["planilla"] == "articulos.csv"
    assert t["datos"]["mapeo"].startswith("codigo ← Código, descripcion ← Detalle") and "planilla_id" not in t["datos"]
    registrada = [ll for ll in res.tools_llamadas if ll["tool"] == planillas.NOMBRE][0]
    assert registrada["status"] == "propuesta" and "filas" not in registrada["argumentos"]
    assert registrada["argumentos"]["total_filas"] == 3


async def test_si_el_mapeo_no_alcanza_vuelve_al_modelo_sin_tarjeta(con, monkeypatch, llm_falso):
    p = await _subir(con)
    llm = llm_falso([
        respuesta_tool(planillas.NOMBRE, json.dumps({"planilla_id": p.planilla_id, "entidad": "Articulos",
                                                     "mapeo": {"codigo": "Código"}})),
        respuesta_texto("Me falta saber la unidad y el tipo."),
    ])
    res = await _consultar(con, monkeypatch, llm, p.planilla_id)
    assert res.propuestas_carga == []
    devuelto = [m for m in llm.llamadas_chat[-1]["mensajes"] if m.get("role") == "tool"][0]["content"]
    assert "Faltan columnas obligatorias" in devuelto


# ============================================================ la confirmacion
async def _propuesta(con) -> str:
    p = await _subir(con)
    args = await planillas.preparar(con, {"planilla_id": p.planilla_id, "entidad": "Articulos", "mapeo": MAPEO})
    prop = await cargas.proponer(con, empr_id=EMPRESA, interaccion_id=None, agente="kuntur",
                                 usuario="admin@empresa", tool=planillas.NOMBRE, argumentos=args)
    await con.commit()
    await rag.fijar_empresa(con, EMPRESA)
    return prop.carga_id


async def _confirmar(con, carga_id):
    return await cargas.confirmar(con, Config(), empr_id=EMPRESA, carga_id=carga_id,
                                  usuario="admin@empresa", autorizacion="Bearer del-admin")


@respx.mock
async def test_cargar_manda_el_csv_a_dnato_con_el_token_del_administrador(con, monkeypatch):
    monkeypatch.setenv("AGENTE_DNATO_BULKLOAD_URL", URL_DNATO)
    ruta = respx.post(URL_DNATO).mock(return_value=httpx.Response(200, json={
        "success": True, "output": "SUCCESS: Carga masiva ejecutada exitosamente | RESULT: Procesados: 3"}))
    r = await _confirmar(con, await _propuesta(con))

    assert r["estado"] == "ejecutada" and r["respuesta"]["filas"] == 3
    pedido = ruta.calls.last.request
    assert pedido.headers["Authorization"] == "Bearer del-admin"
    cuerpo = json.loads(pedido.content)
    assert set(cuerpo) == {"entidad", "csv"}, "la empresa no viaja: sale del token"
    assert cuerpo["entidad"] == "Articulos"
    assert cuerpo["csv"].splitlines() == ["codigo,descripcion,unidad_medida,tipo,punto_pedido",
                                          "a-1,Guante de nitrilo,Par,EPP,10", "A-2,Casco,Unidad,EPP,",
                                          "A-3,Botín,Par,EPP,4"]


@respx.mock
async def test_si_dnato_no_grabo_la_carga_queda_fallida_con_el_motivo(con, monkeypatch):
    monkeypatch.setenv("AGENTE_DNATO_BULKLOAD_URL", URL_DNATO)
    respx.post(URL_DNATO).mock(return_value=httpx.Response(200, json={
        "success": False, "output": "ERROR: El artículo [A-2] tiene una Unidad de Medida no válida "
                                    "o no registrada en el sistema (\"Unidad\"). | LOGS: INFO: ..."}))
    r = await _confirmar(con, await _propuesta(con))
    assert r["estado"] == "fallida"
    assert "No se cargó nada" in r["error"] and "[A-2]" in r["error"] and "LOGS" not in r["error"]


@respx.mock
async def test_si_dnato_rechaza_el_token_la_carga_queda_fallida(con, monkeypatch):
    monkeypatch.setenv("AGENTE_DNATO_BULKLOAD_URL", URL_DNATO)
    respx.post(URL_DNATO).mock(return_value=httpx.Response(403, json={
        "error": "forbidden", "message": "Solo un administrador puede hacer cargas masivas"}))
    r = await _confirmar(con, await _propuesta(con))
    assert r["estado"] == "fallida" and "Solo un administrador" in r["error"]


async def test_sin_la_direccion_de_dnato_no_se_carga(con, monkeypatch):
    monkeypatch.delenv("AGENTE_DNATO_BULKLOAD_URL", raising=False)
    r = await _confirmar(con, await _propuesta(con))
    assert r["estado"] == "fallida" and "no está configurada" in r["error"]


# ==================================================================== la API
def _jwt(**claims) -> str:
    def b64(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")
    return f"Bearer {b64({'alg': 'none'})}.{b64(claims)}.firma"


async def test_subir_la_planilla_solo_un_administrador(con):
    import agente.api as mod
    cuerpo = {"nombre": "articulos.csv", "contenido_base64": base64.b64encode(CSV).decode()}
    async with AsyncClient(transport=ASGITransport(app=mod.app), base_url="http://t") as api:
        r = await api.post("/kuntur/planillas", json=cuerpo,
                           headers={"Authorization": _jwt(empr_id=EMPRESA, role="4")})
        assert r.status_code == 404
        r = await api.post("/kuntur/planillas", json=cuerpo,
                           headers={"Authorization": _jwt(empr_id=EMPRESA, role="1", sub="admin@empresa")})
        assert r.status_code == 200, r.text
        assert r.json()["total_filas"] == 3 and r.json()["encabezados"][0] == "Código"
        r = await api.post("/kuntur/planillas", json={**cuerpo, "contenido_base64": "no-es-base64!"},
                           headers={"Authorization": _jwt(empr_id=EMPRESA, role="1")})
        assert r.status_code == 400
