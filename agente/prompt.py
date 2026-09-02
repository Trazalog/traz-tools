"""Carga del system prompt desde prompts/agente-minero.md.

El archivo se relee en cada consulta si cambio en disco, asi se puede ajustar
el prompt sin reiniciar el servicio. Los comentarios HTML se descartan: estan
ahi para explicarle cosas a quien edita el archivo, no para el modelo.
"""
from __future__ import annotations

import re
import threading
from pathlib import Path

_COMENTARIO_HTML = re.compile(r"<!--.*?-->", re.DOTALL)
# Los bloques que todavia esperan una definicion del PM quedan marcados asi.
_MARCADOR_PENDIENTE = re.compile(r">>>\s*COMPLETAR\s*\(([A-Z])\)\s*—?\s*(.*?)\s*<<<")

_lock = threading.Lock()
_cache: dict[str, tuple[float, str]] = {}


def limpiar(texto: str) -> str:
    """Saca los comentarios HTML y normaliza espacios sobrantes."""
    sin_comentarios = _COMENTARIO_HTML.sub("", texto)
    # Colapsa las corridas de mas de dos saltos que quedan al sacar comentarios.
    return re.sub(r"\n{3,}", "\n\n", sin_comentarios).strip()


def pendientes(texto: str) -> list[str]:
    """Bloques del prompt que todavia esperan una definicion.

    No es un error: el agente funciona igual, con los textos de ejemplo. Pero
    conviene que quede visible en el arranque y en /salud, para que nadie salga
    a produccion con los ejemplos puestos.
    """
    return [f"({letra}) {titulo}" for letra, titulo in _MARCADOR_PENDIENTE.findall(texto)]


def cargar(path: Path) -> str:
    """Devuelve el prompt listo para mandarle al modelo, releyendo si cambio."""
    clave = str(path)
    mtime = path.stat().st_mtime
    with _lock:
        cacheado = _cache.get(clave)
        if cacheado and cacheado[0] == mtime:
            return cacheado[1]
        contenido = limpiar(path.read_text(encoding="utf-8"))
        _cache[clave] = (mtime, contenido)
        return contenido
