"""Smoke test contra OpenRouter DE VERDAD. Apagado por defecto.

Gasta tokens (centavos, con un modelo barato), asi que solo corre si se pide:

    AGENTE_SMOKE_REAL=1 OPENROUTER_API_KEY=sk-... pytest tests/test_smoke_real.py -v

Sirve para verificar tres cosas que ningun mock puede: que la API key anda, que
el modelo configurado existe y hace tool-calling, y que el modelo de embeddings
devuelve vectores de la dimension que espera el esquema.
"""
from __future__ import annotations

import os

import pytest

from agente.config import Config
from agente.llm import OpenRouter

pytestmark = pytest.mark.skipif(
    os.environ.get("AGENTE_SMOKE_REAL") != "1",
    reason="Smoke real desactivado. Activar con AGENTE_SMOKE_REAL=1 (gasta tokens).",
)


@pytest.mark.asyncio
async def test_el_modelo_configurado_responde():
    cfg = Config()
    async with OpenRouter(cfg) as llm:
        r = await llm.chat([
            {"role": "system", "content": "Respondé con una sola palabra."},
            {"role": "user", "content": "¿Capital de Argentina?"},
        ])
    assert r.texto.strip(), "El modelo no devolvio texto"
    assert r.tokens_prompt > 0
    print(f"\nmodelo={r.modelo} tokens={r.tokens_prompt}+{r.tokens_respuesta}")


@pytest.mark.asyncio
async def test_el_modelo_soporta_tool_calling():
    """Sin tool-calling el agente no puede consultar datos del cliente."""
    cfg = Config()
    tools = [{
        "type": "function",
        "function": {
            "name": "man_get_equipos",
            "description": "Lista los equipos de la empresa del usuario.",
            "parameters": {"type": "object", "properties": {}},
        },
    }]
    async with OpenRouter(cfg) as llm:
        r = await llm.chat([
            {"role": "system", "content": "Usá las herramientas cuando haga falta."},
            {"role": "user", "content": "¿Qué equipos tengo registrados?"},
        ], tools=tools)
    assert r.pide_tools, (
        f"El modelo {cfg.modelo} no pidio la tool. Sin tool-calling no sirve "
        f"para el agente: revisar la eleccion de modelo."
    )


@pytest.mark.asyncio
async def test_los_embeddings_tienen_la_dimension_del_esquema():
    """Si no coinciden, los INSERT en pgvector fallan mucho despues."""
    cfg = Config()
    async with OpenRouter(cfg) as llm:
        vectores = await llm.embeddings(["cambio de muelas de chancadora"])
    assert len(vectores) == 1
    assert len(vectores[0]) == cfg.dim_embeddings
