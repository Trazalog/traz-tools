"""Configuracion del orquestador, toda por variables de entorno.

Nada de esto se hardcodea: el modelo de LLM, el de embeddings y las URLs
cambian por ambiente. Ver .env.example para la lista completa con explicaciones.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent


def _env(nombre: str, defecto: str | None = None, *, requerida: bool = False) -> str:
    valor = os.environ.get(nombre, defecto)
    if requerida and not valor:
        raise RuntimeError(
            f"Falta la variable de entorno {nombre}. Ver .env.example."
        )
    return valor or ""


def _env_int(nombre: str, defecto: int) -> int:
    try:
        return int(os.environ.get(nombre, defecto))
    except ValueError:
        return defecto


def _env_float(nombre: str, defecto: float) -> float:
    try:
        return float(os.environ.get(nombre, defecto))
    except ValueError:
        return defecto


@dataclass(frozen=True)
class Config:
    # --- Base de datos del agente (la vectorial, NO la productiva) ----------
    db_host: str = field(default_factory=lambda: _env("AGENTE_DB_HOST", "127.0.0.1"))
    db_port: int = field(default_factory=lambda: _env_int("AGENTE_DB_PORT", 5432))
    db_name: str = field(default_factory=lambda: _env("AGENTE_DB_NAME", "agente_minero"))
    db_user: str = field(default_factory=lambda: _env("AGENTE_DB_USER", "agente_orq"))
    db_password: str = field(default_factory=lambda: _env("AGENTE_DB_PASSWORD"))

    # --- OpenRouter (ADR-A1: unico proveedor de LLM) ------------------------
    openrouter_base_url: str = field(
        default_factory=lambda: _env("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    )
    openrouter_api_key: str = field(default_factory=lambda: _env("OPENROUTER_API_KEY"))
    # Modelo configurable, nunca hardcodeado. DeepSeek por defecto: barato para
    # desarrollo y con tool-calling. Se cambia sin tocar codigo.
    modelo: str = field(default_factory=lambda: _env("AGENTE_MODELO", "deepseek/deepseek-chat"))
    modelo_embeddings: str = field(
        default_factory=lambda: _env("AGENTE_MODELO_EMBEDDINGS", "cohere/embed-multilingual-v3.0")
    )
    # Tiene que coincidir con la dimension del DDL (vector(1024) en db/agente).
    dim_embeddings: int = field(default_factory=lambda: _env_int("AGENTE_DIM_EMBEDDINGS", 1024))
    temperatura: float = field(default_factory=lambda: _env_float("AGENTE_TEMPERATURA", 0.2))
    max_tokens: int = field(default_factory=lambda: _env_int("AGENTE_MAX_TOKENS", 1500))

    # --- MCP ----------------------------------------------------------------
    # "apim" = camino real: JSON-RPC MCP contra el gateway, con el Bearer del
    #          usuario tal cual llega (el APIM ya lo valido).
    # "mi"   = camino de desarrollo: REST directo al MI con X-JWT-Assertion,
    #          para poder trabajar sin un APIM levantado.
    mcp_modo: str = field(default_factory=lambda: _env("AGENTE_MCP_MODO", "apim"))
    mcp_url: str = field(
        default_factory=lambda: _env("AGENTE_MCP_URL", "http://localhost:8290/tools/mcp/mcp")
    )
    mcp_timeout: int = field(default_factory=lambda: _env_int("AGENTE_MCP_TIMEOUT", 60))

    # --- RAG ----------------------------------------------------------------
    rag_top_k: int = field(default_factory=lambda: _env_int("AGENTE_RAG_TOP_K", 6))
    rag_top_k_memoria: int = field(default_factory=lambda: _env_int("AGENTE_RAG_TOP_K_MEMORIA", 4))
    # Distancia coseno maxima para considerar util un fragmento. 0 = identico,
    # 1 = ortogonal. Por encima de esto, el fragmento se descarta: es preferible
    # responder "no lo tengo" a traer algo que no viene al caso.
    rag_distancia_max: float = field(
        default_factory=lambda: _env_float("AGENTE_RAG_DISTANCIA_MAX", 0.55)
    )

    # --- Loop del agente ----------------------------------------------------
    max_iteraciones: int = field(default_factory=lambda: _env_int("AGENTE_MAX_ITERACIONES", 4))

    # --- Prompt -------------------------------------------------------------
    prompt_path: Path = field(
        default_factory=lambda: Path(
            _env("AGENTE_PROMPT_PATH", str(RAIZ / "prompts" / "agente-minero.md"))
        )
    )

    @property
    def dsn(self) -> str:
        return (
            f"host={self.db_host} port={self.db_port} dbname={self.db_name} "
            f"user={self.db_user} password={self.db_password}"
        )

    def validar(self) -> list[str]:
        """Devuelve la lista de problemas de configuracion. Vacia = todo bien."""
        problemas = []
        if not self.db_password:
            problemas.append("AGENTE_DB_PASSWORD no esta seteada")
        if not self.openrouter_api_key:
            problemas.append("OPENROUTER_API_KEY no esta seteada")
        if self.mcp_modo not in ("apim", "mi"):
            problemas.append(f"AGENTE_MCP_MODO invalido: {self.mcp_modo} (apim | mi)")
        if not self.prompt_path.exists():
            problemas.append(f"No existe el prompt de sistema en {self.prompt_path}")
        return problemas


def cargar() -> Config:
    return Config()
