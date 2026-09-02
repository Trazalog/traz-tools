"""Pipeline de ingesta documental: PDF/MD/TXT -> chunks -> embeddings -> pgvector.

Uso:
    python -m agente.ingesta archivo.pdf --tipo-equipo chancadora --situacion mantenimiento
    python -m agente.ingesta carpeta/ --tipo documento --dry-run

Escribe en agente.chunk, que es el conocimiento COMPARTIDO. Por ADR-A4 eso
requiere el rol agente_curador: el usuario del orquestador (agente_app) tiene
solo lectura ahi y este comando va a fallar con "permission denied" si se corre
con sus credenciales. Es a proposito.
"""
from __future__ import annotations

import argparse
import asyncio
import os
import re
import sys
from pathlib import Path

from .config import Config, cargar
from .llm import OpenRouter
from .rag import _a_vector, abrir

EXTENSIONES = {".pdf", ".md", ".txt", ".markdown"}


# ----------------------------------------------------------------- lectura
def leer(path: Path) -> str:
    if path.suffix.lower() == ".pdf":
        try:
            from pypdf import PdfReader
        except ImportError:
            raise SystemExit(
                "Para ingestar PDFs hace falta pypdf: pip install pypdf"
            ) from None
        lector = PdfReader(str(path))
        return "\n\n".join((p.extract_text() or "") for p in lector.pages)
    return path.read_text(encoding="utf-8", errors="replace")


# ---------------------------------------------------------------- troceado
def trocear(texto: str, *, objetivo: int = 900, solape: int = 150) -> list[str]:
    """Parte el texto en fragmentos, cortando por parrafo.

    Cortar por parrafo y no por cantidad fija de caracteres importa: un
    procedimiento partido a la mitad de un paso se recupera incompleto, y el
    agente termina dando media instruccion.
    """
    texto = re.sub(r"[ \t]+", " ", texto)
    parrafos = [p.strip() for p in re.split(r"\n\s*\n", texto) if p.strip()]

    chunks: list[str] = []
    actual = ""
    for p in parrafos:
        if len(actual) + len(p) + 2 <= objetivo:
            actual = f"{actual}\n\n{p}" if actual else p
            continue
        if actual:
            chunks.append(actual)
            # El solape mantiene contexto entre fragmentos contiguos.
            cola = actual[-solape:] if solape else ""
            actual = f"{cola}\n\n{p}" if cola else p
        else:
            # Un parrafo mas largo que el objetivo: se parte por oraciones.
            for i in range(0, len(p), objetivo):
                chunks.append(p[i:i + objetivo])
            actual = ""
    if actual:
        chunks.append(actual)
    return [c.strip() for c in chunks if len(c.strip()) > 40]


# ---------------------------------------------------------------- ingesta
async def ingestar(
    cfg: Config, archivos: list[Path], *, tipo_fuente: str, tipo_equipo: str | None,
    situacion: str | None, confianza: float, dry_run: bool,
) -> int:
    total = 0
    con = await abrir(cfg)
    try:
        async with OpenRouter(cfg) as llm:
            for archivo in archivos:
                texto = leer(archivo)
                chunks = trocear(texto)
                print(f"{archivo.name}: {len(texto)} caracteres -> {len(chunks)} fragmentos")
                if dry_run:
                    if chunks:
                        print(f"   primer fragmento: {chunks[0][:120]}...")
                    total += len(chunks)
                    continue

                async with con.cursor() as cur:
                    await cur.execute(
                        """
                        INSERT INTO agente.fuente (tipo, nombre, uri)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (tipo, nombre) DO UPDATE SET uri = EXCLUDED.uri
                        RETURNING fuente_id
                        """,
                        (tipo_fuente, archivo.name, str(archivo.resolve())),
                    )
                    fuente_id = (await cur.fetchone())["fuente_id"]

                # De a lotes: una llamada por fragmento seria carisima y lenta.
                for i in range(0, len(chunks), 32):
                    lote = chunks[i:i + 32]
                    vectores = await llm.embeddings(lote)
                    async with con.cursor() as cur:
                        for contenido, vector in zip(lote, vectores):
                            await cur.execute(
                                """
                                INSERT INTO agente.chunk
                                    (fuente_id, contenido, embedding, tipo_equipo,
                                     situacion, confianza)
                                VALUES (%s, %s, %s::vector, %s, %s, %s)
                                """,
                                (fuente_id, contenido, _a_vector(vector),
                                 tipo_equipo, situacion, confianza),
                            )
                    await con.commit()
                    total += len(lote)
                    print(f"   {min(i + 32, len(chunks))}/{len(chunks)} ingestados")
    finally:
        await con.close()
    return total


def juntar_archivos(entradas: list[str]) -> list[Path]:
    archivos: list[Path] = []
    for entrada in entradas:
        p = Path(entrada)
        if p.is_dir():
            archivos += sorted(
                f for f in p.rglob("*") if f.suffix.lower() in EXTENSIONES
            )
        elif p.suffix.lower() in EXTENSIONES:
            archivos.append(p)
        else:
            print(f"aviso: se saltea {p} (extension no soportada)", file=sys.stderr)
    return archivos


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Ingesta documentos al conocimiento compartido del Agente Minero."
    )
    ap.add_argument("entradas", nargs="+", help="Archivos o carpetas (.pdf .md .txt)")
    ap.add_argument("--tipo", default="documento",
                    choices=["documento", "normativa", "manual"],
                    help="Tipo de fuente (default: documento)")
    ap.add_argument("--tipo-equipo", default=None,
                    help="Familia de equipo a la que aplica (chancadora, molino...)")
    ap.add_argument("--situacion", default=None,
                    help="Situacion operativa (mantenimiento, falla, seguridad...)")
    ap.add_argument("--confianza", type=float, default=0.8,
                    help="Confianza 0..1 del material (default: 0.8)")
    ap.add_argument("--dry-run", action="store_true",
                    help="Solo mostrar como quedaria troceado, sin escribir ni gastar tokens")
    args = ap.parse_args(argv)

    cfg = cargar()
    problemas = [p for p in cfg.validar() if args.dry_run is False or "DB" in p]
    if problemas and not args.dry_run:
        for p in problemas:
            print(f"error de configuracion: {p}", file=sys.stderr)
        return 2

    archivos = juntar_archivos(args.entradas)
    if not archivos:
        print("No se encontro ningun archivo para ingestar.", file=sys.stderr)
        return 1

    if args.dry_run:
        # Sin credenciales ni llamadas: solo trocea y muestra.
        total = 0
        for archivo in archivos:
            chunks = trocear(leer(archivo))
            print(f"{archivo.name}: {len(chunks)} fragmentos")
            if chunks:
                print(f"   primero: {chunks[0][:120]}...")
            total += len(chunks)
        print(f"\n[dry-run] {total} fragmentos en {len(archivos)} archivo(s). No se escribio nada.")
        return 0

    total = asyncio.run(ingestar(
        cfg, archivos, tipo_fuente=args.tipo, tipo_equipo=args.tipo_equipo,
        situacion=args.situacion, confianza=args.confianza, dry_run=False,
    ))
    print(f"\nListo: {total} fragmentos ingestados desde {len(archivos)} archivo(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
