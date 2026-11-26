"""El comando del curador (AGENTE-PRUEBAS-01).

Hasta ahora no había forma de pasar lo que contó un experto al conocimiento
compartido: promover() existía pero nadie lo llamaba. El comando lista lo que
los expertos revisaron y lo aprueba.
"""
from __future__ import annotations

import json

import pytest

from agente import curar
from agente import entrevistador as ent
from agente.config import Config
from test_entrevistador import LLMFalso, con, expertos  # noqa: F401  (fixtures)


async def _hecho(con, experto_id, texto):
    temas = await ent.agenda(con, limite=1)
    llm = LLMFalso(["¿Cómo?", "¿Y después?", json.dumps([{"contenido": texto, "confianza": 0.8}])])
    r = await ent.iniciar(con, Config(), llm, experto_id, temas[0].tema_id)
    await ent.responder(con, Config(), llm, r["sesion_id"], "Lo hacemos así en la planta.")
    return (await ent.estructurar(con, Config(), llm, r["sesion_id"]))[0]["hecho_id"]


@pytest.mark.asyncio
async def test_lista_solo_lo_que_el_experto_ya_reviso(con, expertos):  # noqa: F811
    revisado = await _hecho(con, expertos[0], "TEST Los mantos se cambian a los 45 milímetros de desgaste.")
    borrador = await _hecho(con, expertos[0], "TEST Un hecho que el experto todavía no miró nunca.")
    await ent.validar(con, revisado, aprobado=True)

    ids = [f["hecho_id"] for f in await curar.pendientes(con)]
    assert revisado in ids
    assert borrador not in ids


@pytest.mark.asyncio
async def test_aprobar_lo_no_revisado_avisa_y_sigue_con_el_resto(con, expertos, monkeypatch, capsys):  # noqa: F811
    borrador = await _hecho(con, expertos[0], "TEST Otro hecho en borrador que no se puede aprobar.")
    await con.commit()

    async def abrir_la_misma(_cfg):
        class Igual:
            async def __aenter__(self):
                return con

            async def __aexit__(self, *a):
                return False
        return Igual()

    class SinLLM:
        def __init__(self, *_a, **_k): ...
        async def __aenter__(self): return self
        async def __aexit__(self, *a): return False

    monkeypatch.setattr(curar, "abrir", abrir_la_misma)
    monkeypatch.setattr(curar, "OpenRouter", SinLLM)
    assert await curar._aprobar(Config(), [borrador], "test") == 1
    assert "solo se promueve" in capsys.readouterr().err


def test_aprobar_exige_decir_quien_aprueba():
    with pytest.raises(SystemExit):
        curar.main(["aprobar", "12"])
