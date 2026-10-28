"""Pipeline de ingesta documental: archivos -> fragmentos -> embeddings -> pgvector.

Uso:
    python -m agente.ingesta manual.pdf --modulo man --tipo-equipo chancadora
    python -m agente.ingesta procedimiento-deposito.md --modulo alm
    python -m agente.ingesta norma-seguridad.pdf --modulo general --tipo normativa
    python -m agente.ingesta carpeta/ --dry-run

    # Las ayudas de Tools y el catalogo de casos de uso (AGENTE-M-06). Se
    # reconocen solos por el tipo de archivo, y re-ingestarlos REEMPLAZA:
    python -m agente.ingesta ayuda/ doctest/catalogo/

    # Documentos de UNA empresa: van a su memoria privada, no al conocimiento
    # compartido (R7). Hace falta su particion de memoria creada.
    python -m agente.ingesta procedimientos-internos.pdf --empresa 191

El --modulo dice a que area aplica el material: man (mantenimiento), alm
(almacenes) o general (transversal, como seguridad o normativa). El conocimiento
general se recupera siempre, sin importar el area de la consulta.

Sin --empresa escribe en agente.chunk, que es el conocimiento COMPARTIDO. Por
ADR-A4 eso requiere el rol agente_curador: el usuario del orquestador
(agente_app) tiene solo lectura ahi y este comando va a fallar con "permission
denied" si se corre con sus credenciales. Es a proposito.

Que se reconoce solo:

  .html                 ayuda de Tools: un fragmento por seccion, con su link
  XXX-UC-NNN.yaml       caso de uso de DocTest: un fragmento por caso, solo
                        los 'validado'
  .pdf .md .txt         documento: se trocea por parrafos
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sys
from pathlib import Path

from .config import Config, cargar
from .fuentes import Pieza, es_caso_uso, leer_ayuda, leer_caso_uso
from .llm import OpenRouter
from .rag import _a_vector, abrir, fijar_empresa

EXTENSIONES = {".pdf", ".md", ".txt", ".markdown", ".html", ".yaml", ".yml"}

# Fuentes que se regeneran (las ayudas, el catalogo): re-ingestarlas reemplaza
# lo que habia de ese archivo, en vez de duplicarlo.
TIPOS_QUE_REEMPLAZAN = {"ayuda", "caso_uso"}

# Una seccion de ayuda mas larga que esto se parte: un fragmento enorme se
# recupera mal. Los casos de uso NO se parten: los pasos van juntos.
MAX_SECCION = 1500


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


# --------------------------------------------------------------- piezas
def piezas_de(path: Path, *, tipo: str, modulo: str) -> tuple[str, list[Pieza]]:
    """El tipo de fuente y los fragmentos de un archivo, segun lo que es."""
    if path.suffix.lower() == ".html":
        piezas: list[Pieza] = []
        for p in leer_ayuda(path):
            if len(p.texto) <= MAX_SECCION:
                piezas.append(p)
                continue
            # Cada pedazo conserva el encabezado (manual y seccion) y el link.
            encabezado, _, cuerpo = p.texto.partition("\n\n")
            for parte in trocear(cuerpo):
                piezas.append(Pieza(f"{encabezado}\n\n{parte}", p.modulo, dict(p.metadata)))
        return "ayuda", piezas
    if es_caso_uso(path):
        pieza = leer_caso_uso(path)
        return "caso_uso", [pieza] if pieza else []
    if path.suffix.lower() in (".yaml", ".yml"):
        return tipo, []   # un yaml que no es caso de uso (el schema): nada que ingestar
    return tipo, [Pieza(c, modulo) for c in trocear(leer(path))]


# ---------------------------------------------------------------- ingesta
async def ingestar(
    cfg: Config, archivos: list[Path], *, tipo_fuente: str, tipo_equipo: str | None,
    situacion: str | None, modulo: str, confianza: float, dry_run: bool,
    empresa: int | None = None, reemplazar: bool = False, llm=None,
    vertical: str = "general",
) -> int:
    """Vectoriza y guarda. Con empresa, en su memoria privada; si no, en el
    conocimiento compartido."""
    total = 0
    con = await abrir(cfg)
    try:
        cliente = llm if llm is not None else OpenRouter(cfg)
        async with cliente as llm:
            for archivo in archivos:
                tipo, piezas = piezas_de(archivo, tipo=tipo_fuente, modulo=modulo)
                print(f"{archivo.name}: {tipo}, {len(piezas)} fragmentos")
                if not piezas or dry_run:
                    total += len(piezas)
                    continue
                reemplaza = reemplazar or tipo in TIPOS_QUE_REEMPLAZAN
                if empresa is not None:
                    total += await _a_memoria(con, llm, archivo, piezas, empresa, reemplaza)
                else:
                    # Las ayudas y los casos de uso son del producto: aplican a
                    # todas las industrias, se indique lo que se indique.
                    total += await _a_conocimiento(
                        con, llm, archivo, piezas, tipo=tipo, tipo_equipo=tipo_equipo,
                        situacion=situacion, confianza=confianza, reemplaza=reemplaza,
                        vertical="general" if tipo in TIPOS_QUE_REEMPLAZAN else vertical)
    finally:
        await con.close()
    return total


async def _vectores(llm, piezas: list[Pieza]):
    # De a lotes: una llamada por fragmento seria carisima y lenta.
    for i in range(0, len(piezas), 32):
        lote = piezas[i:i + 32]
        yield lote, await llm.embeddings([p.texto for p in lote])


async def _a_conocimiento(con, llm, archivo: Path, piezas: list[Pieza], *, tipo: str,
                          tipo_equipo, situacion, confianza: float, reemplaza: bool,
                          vertical: str = "general") -> int:
    async with con.cursor() as cur:
        await cur.execute(
            """
            INSERT INTO agente.fuente (tipo, nombre, uri)
            VALUES (%s, %s, %s)
            ON CONFLICT (tipo, nombre) DO UPDATE SET uri = EXCLUDED.uri
            RETURNING fuente_id
            """,
            (tipo, archivo.name, str(archivo)),
        )
        fuente_id = (await cur.fetchone())["fuente_id"]
        if reemplaza:
            # En la misma transaccion que lo nuevo: si algo falla, queda lo viejo.
            await cur.execute("DELETE FROM agente.chunk WHERE fuente_id = %s", (fuente_id,))
    n = 0
    async for lote, vectores in _vectores(llm, piezas):
        async with con.cursor() as cur:
            for p, vector in zip(lote, vectores):
                await cur.execute(
                    """
                    INSERT INTO agente.chunk
                        (fuente_id, contenido, embedding, tipo_equipo, situacion,
                         modulo, confianza, metadata, vertical)
                    VALUES (%s, %s, %s::vector, %s, %s, %s, %s, %s, %s)
                    """,
                    (fuente_id, p.texto, _a_vector(vector), tipo_equipo, situacion,
                     p.modulo, confianza, json.dumps(p.metadata, ensure_ascii=False),
                     vertical),
                )
        n += len(lote)
        print(f"   {n}/{len(piezas)}")
    await con.commit()
    return n


async def _a_memoria(con, llm, archivo: Path, piezas: list[Pieza], empresa: int,
                     reemplaza: bool) -> int:
    """Documentos de UNA empresa: a su memoria, con RLS. Nunca al compartido."""
    await fijar_empresa(con, empresa)
    async with con.cursor() as cur:
        if reemplaza:
            await cur.execute(
                "DELETE FROM agente.memoria WHERE empr_id = %s AND origen = 'ingesta' "
                "AND metadata->>'documento' = %s", (empresa, archivo.name))
    n = 0
    async for lote, vectores in _vectores(llm, piezas):
        async with con.cursor() as cur:
            for p, vector in zip(lote, vectores):
                meta = {**p.metadata, "documento": archivo.name}
                await cur.execute(
                    """
                    INSERT INTO agente.memoria (empr_id, contenido, embedding, origen, metadata)
                    VALUES (%s, %s, %s::vector, 'ingesta', %s)
                    """,
                    (empresa, p.texto, _a_vector(vector), json.dumps(meta, ensure_ascii=False)),
                )
        n += len(lote)
    await con.commit()
    return n


def _dentro_de_un_catalogo(f: Path) -> bool:
    """Si el archivo esta dentro de un catalogo de DocTest.

    Un catalogo se reconoce por su catalogo.schema.json. Ahi conviven los casos
    de uso con documentos INTERNOS -- el esquema y los relevamientos, con
    hallazgos y bugs del sistema -- que no le pueden llegar a un cliente por
    el agente. De un catalogo solo se toman los casos de uso.
    """
    return any((d / "catalogo.schema.json").exists() for d in f.parents)


def juntar_archivos(entradas: list[str]) -> list[Path]:
    archivos: list[Path] = []
    for entrada in entradas:
        p = Path(entrada)
        if p.is_dir():
            archivos += sorted(
                f for f in p.rglob("*")
                if f.suffix.lower() in EXTENSIONES
                and (es_caso_uso(f) or not _dentro_de_un_catalogo(f))
            )
        elif p.suffix.lower() in EXTENSIONES:
            archivos.append(p)
        else:
            print(f"aviso: se saltea {p} (extension no soportada)", file=sys.stderr)
    return archivos


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Ingesta documentos al conocimiento de los agentes de IA de Trazalog."
    )
    ap.add_argument("entradas", nargs="+",
                    help="Archivos o carpetas (.pdf .md .txt, ayudas .html, casos de uso .yaml)")
    ap.add_argument("--tipo", default="documento",
                    choices=["documento", "normativa", "manual"],
                    help="Tipo de fuente (default: documento)")
    ap.add_argument("--modulo", default="general", choices=["man", "alm", "general"],
                    help="Area a la que aplica: man (mantenimiento), alm (almacenes) "
                         "o general (transversal: seguridad, normativa). "
                         "El conocimiento general se recupera siempre, sin importar "
                         "el area de la consulta. Default: general")
    ap.add_argument("--tipo-equipo", default=None,
                    help="Familia de equipo a la que aplica (chancadora, molino...). "
                         "Solo tiene sentido con --modulo man")
    ap.add_argument("--situacion", default=None,
                    help="Situacion operativa (mantenimiento, falla, seguridad...)")
    ap.add_argument("--confianza", type=float, default=0.8,
                    help="Confianza 0..1 del material (default: 0.8)")
    ap.add_argument("--vertical", default="general",
                    choices=["mineria", "oil_gas", "electricidad", "general"],
                    help="Industria a la que aplica el material (ADR-A11). 'general' = a "
                         "todas. Las ayudas y los casos de uso son siempre 'general'")
    ap.add_argument("--empresa", type=int, default=None,
                    help="empr_id: los documentos van a la memoria PRIVADA de esa empresa, "
                         "no al conocimiento compartido")
    ap.add_argument("--reemplazar", action="store_true",
                    help="Borra lo ingestado antes de ese mismo archivo. Las ayudas y los "
                         "casos de uso reemplazan siempre")
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
            tipo, piezas = piezas_de(archivo, tipo=args.tipo, modulo=args.modulo)
            print(f"{archivo.name}: {tipo}, {len(piezas)} fragmentos")
            if piezas:
                print(f"   primero: {piezas[0].texto[:120]}...")
            total += len(piezas)
        print(f"\n[dry-run] {total} fragmentos en {len(archivos)} archivo(s). No se escribio nada.")
        return 0

    total = asyncio.run(ingestar(
        cfg, archivos, tipo_fuente=args.tipo, tipo_equipo=args.tipo_equipo,
        situacion=args.situacion, modulo=args.modulo, confianza=args.confianza,
        dry_run=False, empresa=args.empresa, reemplazar=args.reemplazar,
        vertical=args.vertical,
    ))
    print(f"\nListo: {total} fragmentos ingestados desde {len(archivos)} archivo(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
