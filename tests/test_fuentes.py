"""Base de conocimiento ampliada (AGENTE-M-06): ayudas, casos de uso y
documentos de empresa.

Los lectores se prueban contra el material REAL del repo (ayuda/ y
doctest/catalogo/): si alguien cambia el formato de las ayudas o del catalogo,
estos tests lo avisan antes de que el agente empiece a recuperar basura.
"""
from __future__ import annotations

from dataclasses import replace
from pathlib import Path

import psycopg
import pytest

from agente import ingesta, rag
from agente.config import Config
from agente.fuentes import es_caso_uso, leer_ayuda, leer_caso_uso

RAIZ = Path(__file__).resolve().parent.parent
AYUDA = RAIZ / "ayuda"
CATALOGO = RAIZ / "doctest" / "catalogo"


# ================================================================ ayudas
def test_una_ayuda_se_parte_por_seccion_con_su_link():
    piezas = leer_ayuda(AYUDA / "manual_almacenes.html")
    assert len(piezas) >= 5
    links = [p.metadata["ayuda"] for p in piezas]
    assert all(l.startswith("ayuda/manual_almacenes.html#s") for l in links)
    assert len(set(links)) == len(links), "cada seccion tiene su propio link"


def test_la_ayuda_no_trae_codigo_ni_estilos():
    for p in leer_ayuda(AYUDA / "manual_almacenes.html"):
        assert "function(" not in p.texto and "{" not in p.texto, p.metadata["ayuda"]


def test_cada_pieza_dice_de_que_manual_y_seccion_es():
    """Un fragmento suelto tiene que entenderse sin el resto del manual."""
    p = leer_ayuda(AYUDA / "manual_almacenes.html")[0]
    assert p.texto.startswith("Ayuda de Trazalog — ")


def test_las_secciones_largas_se_parten_conservando_link_y_encabezado():
    _, piezas = ingesta.piezas_de(AYUDA / "manual_almacenes.html", tipo="documento", modulo="general")
    assert all(len(p.texto) <= ingesta.MAX_SECCION + 400 for p in piezas)
    assert all(p.texto.startswith("Ayuda de Trazalog — ") for p in piezas)
    assert all(p.metadata.get("ayuda") for p in piezas)


def test_todas_las_ayudas_del_sitio_se_leen():
    con_contenido = [f.name for f in AYUDA.glob("manual*.html") if leer_ayuda(f)]
    assert len(con_contenido) >= 8


# ============================================================ casos de uso
def test_un_caso_validado_es_un_fragmento_con_pantalla_controlador_y_ayuda():
    p = leer_caso_uso(CATALOGO / "alm" / "ALM-UC-001.yaml")
    assert p is not None and p.modulo == "alm"
    assert p.metadata["caso_uso"] == "ALM-UC-001"
    assert p.metadata["pantallas"] == ["Almacenes → Articulos"]
    assert p.metadata["controladores"] == ["traz-comp-almacenes/controllers/Articulo.php"]
    # El catalogo apunta al fuente de la ayuda; el usuario ve el sitio armado.
    assert p.metadata["ayuda"] == "ayuda/manual_almacenes.html#s03"
    assert "Pasos:" in p.texto and "1. " in p.texto


@pytest.mark.parametrize("archivo", ["alm/ALM-UC-019.yaml",   # borrador
                                     "alm/ALM-UC-008.yaml"])  # obsoleto
def test_borradores_y_obsoletos_no_se_ingestan(archivo):
    """Un borrador tiene dudas abiertas; un obsoleto describe algo que ya no es asi."""
    assert leer_caso_uso(CATALOGO / archivo) is None


def test_hay_casos_validados_de_las_areas_principales():
    modulos = {p.modulo for p in (leer_caso_uso(f) for f in CATALOGO.rglob("*.yaml") if es_caso_uso(f)) if p}
    assert {"man", "alm"} <= modulos


# ======================================== documentos internos: nunca entran
def test_de_un_catalogo_solo_se_toman_los_casos_de_uso():
    """En el catalogo conviven los relevamientos internos (con hallazgos y
    bugs del sistema). No le pueden llegar a un cliente por el agente."""
    archivos = ingesta.juntar_archivos([str(CATALOGO)])
    assert archivos, "tendria que encontrar los casos de uso"
    assert all(es_caso_uso(f) for f in archivos), [f.name for f in archivos if not es_caso_uso(f)]
    assert not any("RELEVAMIENTO" in f.name or f.name == "SCHEMA.md" for f in archivos)


def test_fuera_de_un_catalogo_los_md_si_se_toman(tmp_path):
    (tmp_path / "procedimiento.md").write_text("# Procedimiento\n\n" + "texto " * 20)
    assert [f.name for f in ingesta.juntar_archivos([str(tmp_path)])] == ["procedimiento.md"]


# ====================================================== con base
class LLMFalso:
    async def __aenter__(self):
        return self

    async def __aexit__(self, *_):
        return None

    async def embeddings(self, textos):
        return [[0.0] * 1023 + [1.0] for _ in textos]


def _cfg_o_saltear() -> Config:
    cfg = Config()
    if not cfg.db_password:
        pytest.skip("Sin AGENTE_DB_PASSWORD: se saltean los tests con base")
    return cfg


async def _hay_base(cfg):
    try:
        c = await rag.abrir(cfg)
        await c.close()
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"Base del agente no disponible: {e}")


async def test_el_runtime_no_puede_escribir_el_conocimiento_compartido():
    """ADR-A4: ingestar al compartido requiere el rol curador. Con el usuario
    del orquestador falla, a proposito."""
    cfg = _cfg_o_saltear()
    await _hay_base(cfg)
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        await ingesta.ingestar(cfg, [AYUDA / "manual_almacenes.html"], tipo_fuente="documento",
                               tipo_equipo=None, situacion=None, modulo="general",
                               confianza=0.8, dry_run=False, llm=LLMFalso())


async def test_un_documento_de_empresa_va_a_su_memoria_y_reemplaza(tmp_path):
    cfg = _cfg_o_saltear()
    await _hay_base(cfg)
    doc = tmp_path / "procedimiento-interno-prueba.md"
    doc.write_text("# Interno\n\nEl compresor se purga todos los lunes antes del arranque del turno.")

    for _ in range(2):
        await ingesta.ingestar(cfg, [doc], tipo_fuente="documento", tipo_equipo=None,
                               situacion=None, modulo="general", confianza=0.8,
                               dry_run=False, empresa=900001, reemplazar=True, llm=LLMFalso())

    con = await rag.abrir(cfg)
    try:
        async def contar(empr):
            await rag.fijar_empresa(con, empr)
            async with con.cursor() as cur:
                await cur.execute("SELECT count(*) AS n FROM agente.memoria WHERE origen = 'ingesta' "
                                  "AND metadata->>'documento' = %s", (doc.name,))
                n = (await cur.fetchone())["n"]
            await con.rollback()
            return n
        assert await contar(900001) == 1, "re-ingestar con --reemplazar no duplica"
        assert await contar(900002) == 0, "el documento de una empresa no lo ve otra"
    finally:
        await con.close()
