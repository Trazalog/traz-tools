"""Cliente de OpenRouter (ADR-A1: unico proveedor de LLM).

La API es compatible con la de OpenAI, asi que esto sirve para chat con
tool-calling y para embeddings, cambiando solo el modelo por variable de
entorno. Nada de nombres de modelo hardcodeados.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

import httpx

from .config import Config


class LLMError(RuntimeError):
    """Fallo hablando con OpenRouter. Incluye el cuerpo para poder diagnosticar."""

    def __init__(self, mensaje: str, status: int | None = None, cuerpo: Any = None):
        self.status = status
        self.cuerpo = cuerpo
        super().__init__(mensaje)


@dataclass
class Respuesta:
    """Una respuesta del modelo: texto, tools que pidio llamar, y consumo."""

    texto: str
    tool_calls: list[dict]
    modelo: str
    tokens_prompt: int
    tokens_respuesta: int

    @property
    def pide_tools(self) -> bool:
        return bool(self.tool_calls)


class OpenRouter:
    def __init__(self, cfg: Config, cliente: httpx.AsyncClient | None = None):
        self.cfg = cfg
        self._cliente = cliente
        self._propio = cliente is None

    async def __aenter__(self) -> "OpenRouter":
        if self._cliente is None:
            self._cliente = httpx.AsyncClient(timeout=120.0)
        return self

    async def __aexit__(self, *_) -> None:
        if self._propio and self._cliente is not None:
            await self._cliente.aclose()
            self._cliente = None

    @property
    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.cfg.openrouter_api_key}",
            "Content-Type": "application/json",
            # OpenRouter los usa para atribuir el trafico; no son obligatorios.
            "HTTP-Referer": "https://cloudtrazalog.com",
            "X-Title": "Trazalog Agente Minero",
        }

    async def _post(self, ruta: str, cuerpo: dict) -> dict:
        if self._cliente is None:
            raise LLMError("El cliente HTTP no esta abierto; usar 'async with'.")
        url = f"{self.cfg.openrouter_base_url.rstrip('/')}{ruta}"
        try:
            r = await self._cliente.post(url, headers=self._headers, json=cuerpo)
        except httpx.HTTPError as e:
            raise LLMError(f"No se pudo llegar a OpenRouter: {e}") from e
        if r.status_code >= 400:
            try:
                detalle = r.json()
            except (json.JSONDecodeError, ValueError):
                detalle = r.text[:500]
            raise LLMError(
                f"OpenRouter respondio {r.status_code}", r.status_code, detalle
            )
        return r.json()

    async def chat(
        self,
        mensajes: list[dict],
        tools: list[dict] | None = None,
    ) -> Respuesta:
        cuerpo: dict[str, Any] = {
            "model": self.cfg.modelo,
            "messages": mensajes,
            "temperature": self.cfg.temperatura,
            "max_tokens": self.cfg.max_tokens,
        }
        if tools:
            cuerpo["tools"] = tools
            cuerpo["tool_choice"] = "auto"

        data = await self._post("/chat/completions", cuerpo)

        try:
            mensaje = data["choices"][0]["message"]
        except (KeyError, IndexError) as e:
            raise LLMError("Respuesta de OpenRouter sin choices", cuerpo=data) from e

        uso = data.get("usage") or {}
        return Respuesta(
            texto=mensaje.get("content") or "",
            tool_calls=mensaje.get("tool_calls") or [],
            modelo=data.get("model", self.cfg.modelo),
            tokens_prompt=uso.get("prompt_tokens", 0),
            tokens_respuesta=uso.get("completion_tokens", 0),
        )

    async def embeddings(self, textos: list[str]) -> list[list[float]]:
        """Vectoriza una lista de textos. Devuelve un vector por texto, en orden."""
        if not textos:
            return []
        data = await self._post(
            "/embeddings", {"model": self.cfg.modelo_embeddings, "input": textos}
        )
        try:
            filas = sorted(data["data"], key=lambda d: d.get("index", 0))
            vectores = [f["embedding"] for f in filas]
        except (KeyError, TypeError) as e:
            raise LLMError("Respuesta de embeddings con formato inesperado", cuerpo=data) from e

        # Si la dimension no coincide con la del DDL, los INSERT van a fallar
        # despues con un error mucho menos claro que este.
        for v in vectores:
            if len(v) != self.cfg.dim_embeddings:
                raise LLMError(
                    f"El modelo {self.cfg.modelo_embeddings} devolvio vectores de "
                    f"{len(v)} dimensiones, pero el esquema espera "
                    f"{self.cfg.dim_embeddings}. Revisar AGENTE_MODELO_EMBEDDINGS "
                    f"y AGENTE_DIM_EMBEDDINGS, y ver db/agente/README.md."
                )
        return vectores
