"""Tool web_buscar: busqueda en internet sobre SearXNG autoalojado (AGENTE-M-05).

Para lo que el conocimiento de la industria no cubre: una norma, un dato de
mercado, una ficha de fabricante. La busca SearXNG -- un metabuscador libre que
corre en nuestra infraestructura, sin API key ni costo (ADR-005) -- y el
agente recibe titulo, URL y extracto de los primeros resultados.

Dos reglas que la acompañan:

  * Toda cifra que salga de aca tiene que ir con su URL en la respuesta, o el
    guardian de cifras la bloquea (R4, agente/guardian.py).
  * La consulta sale de nuestra infraestructura hacia buscadores externos: no
    puede llevar datos de la empresa. Lo dice el prompt y se refuerza en la
    descripcion de la tool, que es lo que el modelo lee al decidir usarla.

No pasa por el MCP Gateway porque no son datos del cliente (ADR-A3 no aplica),
pero si por la misma lista blanca que cualquier tool: esta catalogada en
agente.tool (script 014) y cada agente la tiene o no en su configuracion.
"""
from __future__ import annotations

import httpx

from .config import Config

NOMBRE = "web_buscar"

DEFINICION = {
    "type": "function",
    "function": {
        "name": NOMBRE,
        "description": (
            "Busca en internet y devuelve título, URL y extracto de los primeros "
            "resultados. Usala solo para lo que no está en el conocimiento ni en los "
            "datos de la empresa: normas, fichas de fabricante, información pública. "
            "La consulta NO puede incluir datos de la empresa (nombres, códigos de "
            "equipo, clientes, cifras propias): sale a buscadores externos. "
            "Si usás una cifra de un resultado, citá su URL en la respuesta."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "consulta": {"type": "string",
                             "description": "Qué buscar, en pocas palabras y sin datos de la empresa."},
            },
            "required": ["consulta"],
        },
    },
}


class WebError(RuntimeError):
    pass


def habilitada(cfg: Config) -> bool:
    """Sin URL de SearXNG la busqueda queda apagada: no se ofrece la tool."""
    return bool(cfg.web_url)


async def buscar(cfg: Config, consulta: str, *,
                 cliente: httpx.AsyncClient | None = None) -> dict:
    consulta = (consulta or "").strip()
    if not consulta:
        raise WebError("consulta vacía")
    propio = cliente is None
    cliente = cliente or httpx.AsyncClient(timeout=float(cfg.web_timeout))
    try:
        r = await cliente.get(
            cfg.web_url.rstrip("/") + "/search",
            params={"q": consulta, "format": "json", "language": "es"},
        )
    except httpx.HTTPError as e:
        raise WebError(f"no se pudo llegar al buscador: {e}") from e
    finally:
        if propio:
            await cliente.aclose()
    if r.status_code >= 400:
        raise WebError(f"el buscador respondió HTTP {r.status_code}")
    try:
        data = r.json()
    except ValueError as e:
        raise WebError("el buscador no devolvió JSON (¿falta 'json' en search.formats?)") from e

    resultados = [
        {"titulo": (x.get("title") or "").strip(),
         "url": x.get("url"),
         "extracto": (x.get("content") or "").strip()[:500]}
        for x in data.get("results", [])
        if x.get("url")
    ][: cfg.web_resultados]
    return {"consulta": consulta, "resultados": resultados}
