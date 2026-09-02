"""Configuracion compartida de los tests del orquestador.

Regla: NINGUN test toca OpenRouter de verdad. Los que necesitan el modelo usan
el doble de `llm_falso`. El unico que pega contra la API real es el smoke test
de test_smoke_real.py, que esta apagado salvo que se pida explicitamente con
AGENTE_SMOKE_REAL=1.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

# Valores por defecto para que Config no falle en los tests. Se ponen antes de
# importar nada del paquete.
os.environ.setdefault("AGENTE_DB_PASSWORD", "test")
os.environ.setdefault("OPENROUTER_API_KEY", "test-key-no-real")
os.environ.setdefault("AGENTE_PROMPT_PATH", str(RAIZ / "prompts" / "agente-minero.md"))

from agente.config import Config  # noqa: E402
from agente.llm import Respuesta  # noqa: E402


@pytest.fixture
def cfg() -> Config:
    return Config()


@pytest.fixture
def vector():
    """Un embedding cualquiera de la dimension correcta."""
    def _hacer(pos: int = 0, dim: int = 1024) -> list[float]:
        v = [0.0] * dim
        v[pos % dim] = 1.0
        return v
    return _hacer


class LLMFalso:
    """Doble de OpenRouter.

    Se le carga de antemano la secuencia de respuestas que va a devolver, y
    registra con que lo llamaron. No hace ninguna llamada de red.
    """

    def __init__(self, respuestas: list[Respuesta], embedding: list[float] | None = None):
        self._respuestas = list(respuestas)
        self._embedding = embedding or ([0.0] * 1023 + [1.0])
        self.llamadas_chat: list[dict] = []
        self.textos_vectorizados: list[str] = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_):
        return None

    async def chat(self, mensajes, tools=None):
        self.llamadas_chat.append({"mensajes": mensajes, "tools": tools})
        if not self._respuestas:
            raise AssertionError("El LLM falso se quedo sin respuestas cargadas")
        return self._respuestas.pop(0)

    async def embeddings(self, textos):
        self.textos_vectorizados += list(textos)
        return [list(self._embedding) for _ in textos]


@pytest.fixture
def llm_falso():
    return LLMFalso


def respuesta_texto(texto: str, **kw) -> Respuesta:
    return Respuesta(
        texto=texto, tool_calls=[], modelo=kw.get("modelo", "modelo-de-prueba"),
        tokens_prompt=kw.get("tokens_prompt", 10),
        tokens_respuesta=kw.get("tokens_respuesta", 5),
    )


def respuesta_tool(nombre: str, argumentos: str = "{}", *, call_id: str = "c1") -> Respuesta:
    return Respuesta(
        texto="", modelo="modelo-de-prueba", tokens_prompt=10, tokens_respuesta=5,
        tool_calls=[{
            "id": call_id, "type": "function",
            "function": {"name": nombre, "arguments": argumentos},
        }],
    )
