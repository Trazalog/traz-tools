"""Aprobar lo que contaron los expertos para que lo usen Quirqui y Kuntur.

Lo que un experto le cuenta a Faustino y después revisa queda como "hecho
validado", pero todavía no es conocimiento: hace falta que un curador lo
apruebe (ADR-A4). Este comando es esa aprobación, mientras no haya pantalla.

DÓNDE SE CORRE: terminal local, desde la raíz del repo, con el usuario de base
CURADOR (el del motor no puede escribir el conocimiento compartido, y está bien):

    AGENTE_DB_USER=<curador> AGENTE_DB_PASSWORD=<clave> \\
      .venv-agente/bin/python -m agente.curar listar

    AGENTE_DB_USER=<curador> AGENTE_DB_PASSWORD=<clave> \\
      .venv-agente/bin/python -m agente.curar aprobar 12 13 --curador "Rodolfo"

Aprobar gasta un vector por hecho (OpenRouter, centavos).
"""
from __future__ import annotations

import argparse
import asyncio
import sys

from .config import cargar
from .entrevistador import promover
from .llm import OpenRouter
from .rag import abrir

# Los mismos estados que acepta promover(): lo que el experto ya revisó.
PARA_APROBAR = ("validado_experto", "en_validacion_cruzada", "zona_gris")


async def pendientes(con) -> list[dict]:
    async with con.cursor() as cur:
        await cur.execute(
            """
            SELECT h.hecho_id, h.contenido, h.estado_validacion, h.confianza,
                   e.nombre AS experto, t.nombre AS tema, coalesce(t.vertical, 'general') AS vertical
            FROM agente.hecho h
            JOIN agente.sesion_entrevista s USING (sesion_id)
            JOIN agente.experto e ON e.experto_id = s.experto_id
            LEFT JOIN agente.tema t ON t.tema_id = s.tema_id
            WHERE h.estado_validacion = ANY(%s) AND h.chunk_id IS NULL
            ORDER BY h.hecho_id
            """, (list(PARA_APROBAR),))
        return await cur.fetchall()


async def _listar(cfg) -> int:
    async with await abrir(cfg) as con:
        filas = await pendientes(con)
    if not filas:
        print("No hay hechos para aprobar: los expertos todavía no revisaron ninguno.")
        return 0
    for f in filas:
        gris = "  ⚠️ los expertos no coincidieron" if f["estado_validacion"] == "zona_gris" else ""
        print(f"#{f['hecho_id']}  {f['experto']} · {f['tema'] or 'sin tema'} · {f['vertical']}"
              f" · confianza {float(f['confianza']):.2f}{gris}\n    {f['contenido']}\n")
    print(f"{len(filas)} para aprobar. Ej.: python -m agente.curar aprobar "
          f"{' '.join(str(f['hecho_id']) for f in filas[:3])} --curador \"Tu nombre\"")
    return 0


async def _aprobar(cfg, ids: list[int], curador: str) -> int:
    errores = 0
    async with OpenRouter(cfg) as llm, await abrir(cfg) as con:
        for i in ids:
            try:
                r = await promover(con, cfg, llm, i, curador=curador)
                print(f"✅ #{i} aprobado: ya lo usan Quirqui y Kuntur (confianza {r['confianza']:.2f})")
            except ValueError as e:
                await con.rollback()
                errores += 1
                print(f"❌ #{i}: {e}", file=sys.stderr)
    return 1 if errores else 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Aprobar lo que contaron los expertos (curador).")
    sub = ap.add_subparsers(dest="accion", required=True)
    sub.add_parser("listar", help="lo que los expertos revisaron y falta aprobar")
    a = sub.add_parser("aprobar", help="pasa hechos al conocimiento compartido")
    a.add_argument("hechos", nargs="+", type=int, help="números de hecho (los de 'listar')")
    a.add_argument("--curador", required=True, help="quién aprueba: queda registrado")
    args = ap.parse_args(argv)
    cfg = cargar()
    if args.accion == "listar":
        return asyncio.run(_listar(cfg))
    return asyncio.run(_aprobar(cfg, args.hechos, args.curador))


if __name__ == "__main__":
    sys.exit(main())
