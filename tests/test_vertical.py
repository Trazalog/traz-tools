"""Conocimiento multi-vertical (ADR-A11, AGENTE-M-08).

Una empresa de oil & gas no recibe lo que es solo de mineria; recibe lo de su
industria y lo general. Sin industria declarada, recibe todo (etiquetado).

Los tests de recuperacion siembran fragmentos como administrador, dentro de
una transaccion que se deshace (fixture con_admin): el runtime no puede
escribir el conocimiento compartido, y esta bien que no pueda.
"""
from __future__ import annotations

from dataclasses import replace

import pytest

from agente import rag
from agente.config import Config
from agente.ingesta import main as ingesta_main

EMPRESA_OIL = 900001
EMPRESA_SIN = 900002
VECTOR = [0.0] * 1023 + [1.0]


async def _sembrar(con):
    async with con.cursor() as cur:
        await cur.execute(
            "INSERT INTO agente.fuente (tipo, nombre) VALUES ('documento', 'prueba-vertical') "
            "RETURNING fuente_id")
        fuente = (await cur.fetchone())["fuente_id"]
        for vertical, texto in [("mineria", "SOLO MINERIA: muelas de la chancadora"),
                                ("oil_gas", "SOLO OIL: sellos de la bomba de transferencia"),
                                ("electricidad", "SOLO ELECTRICIDAD: termografia del tablero"),
                                ("general", "GENERAL: bloqueo y etiquetado de energias")]:
            await cur.execute(
                "INSERT INTO agente.chunk (fuente_id, contenido, embedding, vertical) "
                "VALUES (%s, %s, %s::vector, %s)", (fuente, texto, rag._a_vector(VECTOR), vertical))
        await cur.execute("SET LOCAL agente.empr_id = '900001'")
        await cur.execute("INSERT INTO agente.perfil_empresa (empr_id, vertical) VALUES (%s, 'oil_gas') "
                          "ON CONFLICT (empr_id) DO UPDATE SET vertical = 'oil_gas'", (EMPRESA_OIL,))


def _cfg() -> Config:
    return replace(Config(), rag_top_k=20, rag_distancia_max=1.0)


async def test_una_empresa_de_oil_and_gas_no_recibe_lo_de_mineria(con_admin):
    await _sembrar(con_admin)
    vertical = await rag.vertical_de(con_admin, EMPRESA_OIL)
    assert vertical == "oil_gas"

    textos = {f.contenido for f in await rag.buscar_conocimiento(con_admin, _cfg(), VECTOR, vertical=vertical)}
    assert "SOLO OIL: sellos de la bomba de transferencia" in textos
    assert "GENERAL: bloqueo y etiquetado de energias" in textos
    assert not any(t.startswith(("SOLO MINERIA", "SOLO ELECTRICIDAD")) for t in textos)


async def test_sin_industria_declarada_recibe_todo(con_admin):
    await _sembrar(con_admin)
    await con_admin.execute("SET LOCAL agente.empr_id = '900002'")
    assert await rag.vertical_de(con_admin, EMPRESA_SIN) is None
    textos = {f.contenido for f in await rag.buscar_conocimiento(con_admin, _cfg(), VECTOR, vertical=None)}
    assert {t.split(":")[0] for t in textos if "prueba" not in t} >= {
        "SOLO MINERIA", "SOLO OIL", "SOLO ELECTRICIDAD", "GENERAL"}


async def test_el_modelo_ve_de_que_industria_es_cada_fragmento(con_admin):
    await _sembrar(con_admin)
    frags = await rag.buscar_conocimiento(con_admin, _cfg(), VECTOR, vertical=None)
    contexto = rag.armar_contexto(frags)
    assert "industria: minería" in contexto and "industria: oil & gas" in contexto
    # Lo general no lleva etiqueta: aplica a todas.
    assert "industria: general" not in contexto


def test_la_ingesta_acepta_las_industrias():
    for v in ("mineria", "oil_gas", "electricidad", "general"):
        assert ingesta_main(["ayuda/manual_almacenes.html", "--dry-run", "--vertical", v]) == 0


def test_la_ingesta_rechaza_una_industria_inventada():
    with pytest.raises(SystemExit):
        ingesta_main(["ayuda/manual_almacenes.html", "--dry-run", "--vertical", "petroquimica"])


def test_las_verticales_del_codigo_son_las_de_la_base():
    """Si se agrega una industria, va en los dos lados (CHECK de 016 y rag.VERTICALES)."""
    sql = open("db/agente/016-vertical.sql", encoding="utf-8").read()
    for v in rag.VERTICALES:
        assert f"'{v}'" in sql
