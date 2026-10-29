"""Publicar avisos en Tools (ADR-015): POST /avisos de toolsNTFAPI.

Los agentes no tienen cola propia: publican en el mecanismo unico de avisos
de Tools (esquema ntf), con el token de maquina de la empresa. La empresa la
pone el API a partir del token, nunca este codigo. A quien le llega lo
resuelve ntf con las suscripciones del tipo de aviso (ntf.suscripcion), salvo
que se pasen destinatarios. La campanita y el push son los de Tools.

    AGENTE_AVISOS_URL   el recurso POST /avisos de toolsNTFAPI en el gateway
                        (ej. https://<apim>:8243/tools/ntf/1.0/avisos).
                        Vacio = los avisos no se publican (quedan en la corrida).
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

import httpx

from .config import Config

log = logging.getLogger("agente.avisos")


class AvisoError(RuntimeError):
    """El API de avisos no acepto el aviso."""


@dataclass
class Aviso:
    tipo: str
    titulo: str
    cuerpo: str = ""
    severidad: str = "info"
    enlace: str | None = None
    entidad_tipo: str | None = None
    entidad_id: str | None = None
    emisor: str | None = None          # el nombre del agente que firma (Quirqui, Kuntur)
    dedupe_key: str | None = None
    destinatarios: list[str] = field(default_factory=list)   # vacio = suscriptos al tipo

    def a_dict(self) -> dict:
        d = {"origen": "agente", "tipo": self.tipo, "titulo": self.titulo, "cuerpo": self.cuerpo,
             "severidad": self.severidad}
        for k in ("enlace", "entidad_tipo", "entidad_id", "emisor", "dedupe_key"):
            v = getattr(self, k)
            if v:
                d[k] = v
        if self.destinatarios:
            d["destinatarios"] = list(self.destinatarios)
        return d


def habilitado(cfg: Config) -> bool:
    return bool(cfg.avisos_url)


async def publicar(cfg: Config, autorizacion: str, aviso: Aviso,
                   *, cliente: httpx.AsyncClient | None = None) -> int:
    """Publica el aviso y devuelve su aviso_id. Con la misma dedupe_key, ntf
    devuelve el aviso que ya existia (no crea nada ni manda push otra vez)."""
    if not habilitado(cfg):
        raise AvisoError("AGENTE_AVISOS_URL vacia: los avisos no se publican")
    propio = cliente is None
    cliente = cliente or httpx.AsyncClient(timeout=float(cfg.mcp_timeout))
    try:
        r = await cliente.post(cfg.avisos_url, json=aviso.a_dict(),
                               headers={"Authorization": autorizacion, "Accept": "application/json"})
    except httpx.HTTPError as e:
        raise AvisoError(f"API de avisos inalcanzable: {e}") from e
    finally:
        if propio:
            await cliente.aclose()
    if r.status_code != 200:
        raise AvisoError(f"API de avisos respondio {r.status_code}: {r.text[:300]}")
    try:
        return int(r.json()["respuesta"]["aviso_id"])
    except (ValueError, KeyError, TypeError) as e:
        raise AvisoError(f"Respuesta inesperada del API de avisos: {r.text[:300]}") from e
