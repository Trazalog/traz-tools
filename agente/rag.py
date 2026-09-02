"""Acceso a la base vectorial: conocimiento compartido y memoria del cliente.

ADR-A2: el conocimiento se consulta por query directa a pgvector, sin pasar por
MCP. MCP en el medio solo agregaria latencia y costo para leer una tabla propia.

Regla que atraviesa todo este modulo: ANTES de tocar la memoria o cualquier
tabla con empr_id, hay que setear el contexto de empresa en la sesion de base.
Sin eso, las policies de RLS no dejan ver nada -- que es el comportamiento
buscado: fallar cerrado en vez de mostrar de mas.
"""
from __future__ import annotations

from dataclasses import dataclass

import psycopg
from psycopg.rows import dict_row

from .config import Config


@dataclass
class Fragmento:
    """Un pedazo de contexto recuperado, con de donde salio."""

    origen: str          # "conocimiento" | "memoria"
    id: int
    contenido: str
    distancia: float
    metadata: dict

    @property
    def cita(self) -> str:
        return f"{self.origen}:{self.id}"


def _a_vector(v: list[float]) -> str:
    """pgvector acepta el literal '[1,2,3]'."""
    return "[" + ",".join(f"{x:.6f}" for x in v) + "]"


async def abrir(cfg: Config) -> psycopg.AsyncConnection:
    return await psycopg.AsyncConnection.connect(cfg.dsn, row_factory=dict_row)


async def fijar_empresa(con: psycopg.AsyncConnection, empr_id: int) -> None:
    """Setea el contexto de empresa para las policies de RLS.

    Se usa SET LOCAL, asi el contexto muere con la transaccion y no queda
    pegado en una conexion reutilizada del pool -- que seria la forma mas
    facil de filtrar datos entre clientes.
    """
    async with con.cursor() as cur:
        await cur.execute("SELECT set_config('agente.empr_id', %s, true)", (str(empr_id),))


async def buscar_conocimiento(
    con: psycopg.AsyncConnection, cfg: Config, embedding: list[float],
    *, tipo_equipo: str | None = None, situacion: str | None = None,
    modulo: str | None = None,
) -> list[Fragmento]:
    """Conocimiento minero compartido, comun a todos los clientes.

    Cubre las dos areas del agente: mantenimiento y almacenes. Por defecto NO
    filtra por modulo -- la similitud vectorial ya separa bien, y muchas
    consultas cruzan las dos ("¿tengo el filtro para el preventivo de la
    chancadora?"). El filtro esta disponible para cuando se sabe el area de
    antemano, por ejemplo desde un job de monitoreo.

    Cuando se filtra, el conocimiento 'general' (seguridad, normativa
    transversal) se recupera igual: aplica a las dos areas.
    """
    sql = """
        SELECT c.chunk_id, c.contenido, c.tipo_equipo, c.situacion, c.confianza,
               c.modulo, f.tipo AS fuente_tipo, f.nombre AS fuente_nombre,
               c.embedding <=> %(emb)s::vector AS distancia
        FROM agente.chunk c
        JOIN agente.fuente f USING (fuente_id)
        WHERE c.vigente
          AND c.embedding IS NOT NULL
          AND (%(tipo_equipo)s::text IS NULL OR c.tipo_equipo = %(tipo_equipo)s)
          AND (%(situacion)s::text  IS NULL OR c.situacion  = %(situacion)s)
          AND (%(modulo)s::text     IS NULL OR c.modulo IN (%(modulo)s, 'general'))
        ORDER BY c.embedding <=> %(emb)s::vector
        LIMIT %(k)s
    """
    async with con.cursor() as cur:
        await cur.execute(sql, {
            "emb": _a_vector(embedding), "tipo_equipo": tipo_equipo,
            "situacion": situacion, "modulo": modulo, "k": cfg.rag_top_k,
        })
        filas = await cur.fetchall()

    return [
        Fragmento(
            origen="conocimiento", id=f["chunk_id"], contenido=f["contenido"],
            distancia=float(f["distancia"]),
            metadata={
                "tipo_equipo": f["tipo_equipo"], "situacion": f["situacion"],
                "modulo": f["modulo"], "confianza": float(f["confianza"]),
                "fuente": f"{f['fuente_tipo']}: {f['fuente_nombre']}",
            },
        )
        for f in filas
        if float(f["distancia"]) <= cfg.rag_distancia_max
    ]


async def buscar_memoria(
    con: psycopg.AsyncConnection, cfg: Config, empr_id: int, embedding: list[float],
) -> list[Fragmento]:
    """Memoria privada de ESTA empresa.

    El WHERE por empr_id es redundante con RLS a proposito: si alguien
    desactivara la policy, el filtro explicito sigue estando. Dos barreras.
    """
    sql = """
        SELECT memoria_id, contenido, origen, entidad_tipo, entidad_id, fec_alta,
               embedding <=> %(emb)s::vector AS distancia
        FROM agente.memoria
        WHERE empr_id = %(empr_id)s
          AND embedding IS NOT NULL
        ORDER BY embedding <=> %(emb)s::vector
        LIMIT %(k)s
    """
    async with con.cursor() as cur:
        await cur.execute(sql, {
            "emb": _a_vector(embedding), "empr_id": empr_id,
            "k": cfg.rag_top_k_memoria,
        })
        filas = await cur.fetchall()

    return [
        Fragmento(
            origen="memoria", id=f["memoria_id"], contenido=f["contenido"],
            distancia=float(f["distancia"]),
            metadata={
                "origen_memoria": f["origen"], "entidad_tipo": f["entidad_tipo"],
                "entidad_id": f["entidad_id"], "fecha": str(f["fec_alta"]),
            },
        )
        for f in filas
        if float(f["distancia"]) <= cfg.rag_distancia_max
    ]


async def guardar_memoria(
    con: psycopg.AsyncConnection, empr_id: int, contenido: str,
    embedding: list[float] | None = None, *, origen: str = "consulta",
    entidad_tipo: str | None = None, entidad_id: str | None = None,
) -> int:
    """Registra algo en la memoria de esta empresa. Devuelve el id."""
    sql = """
        INSERT INTO agente.memoria
            (empr_id, contenido, embedding, origen, entidad_tipo, entidad_id)
        VALUES (%(empr_id)s, %(contenido)s, %(emb)s::vector, %(origen)s,
                %(entidad_tipo)s, %(entidad_id)s)
        RETURNING memoria_id
    """
    async with con.cursor() as cur:
        await cur.execute(sql, {
            "empr_id": empr_id, "contenido": contenido,
            "emb": _a_vector(embedding) if embedding else None,
            "origen": origen, "entidad_tipo": entidad_tipo, "entidad_id": entidad_id,
        })
        fila = await cur.fetchone()
    return fila["memoria_id"]


def armar_contexto(fragmentos: list[Fragmento]) -> str:
    """Convierte los fragmentos en el bloque de texto que ve el modelo.

    Cada fragmento va etiquetado con su origen para que el prompt pueda pedirle
    al agente que distinga "lo que dice la norma" de "lo que pasa en esta
    empresa". Sin la etiqueta, esa distincion es imposible de sostener.
    """
    if not fragmentos:
        return (
            "No hay conocimiento ni memoria registrada que aplique a esta consulta. "
            "Respondé según las reglas de 'Cuando no sabés'."
        )

    conocimiento = [f for f in fragmentos if f.origen == "conocimiento"]
    memoria = [f for f in fragmentos if f.origen == "memoria"]
    partes: list[str] = []

    if conocimiento:
        partes.append("## Conocimiento minero — mantenimiento y almacenes (general, no de esta empresa)\n")
        for f in conocimiento:
            conf = f.metadata.get("confianza")
            etiquetas = [f"fuente: {f.metadata.get('fuente')}"]
            modulo = f.metadata.get("modulo")
            if modulo and modulo != "general":
                etiquetas.append(
                    {"man": "área: mantenimiento", "alm": "área: almacenes"}.get(modulo, modulo)
                )
            if conf is not None:
                etiquetas.append(f"confianza: {conf:.2f}")
            if f.metadata.get("tipo_equipo"):
                etiquetas.append(f"equipo: {f.metadata['tipo_equipo']}")
            partes.append(f"[{f.cita}] ({'; '.join(etiquetas)})\n{f.contenido}\n")

    if memoria:
        partes.append("## Memoria de esta empresa (privada, de consultas anteriores)\n")
        for f in memoria:
            etiquetas = [f"registrado: {f.metadata.get('fecha', '')[:10]}"]
            if f.metadata.get("entidad_tipo"):
                etiquetas.append(
                    f"sobre: {f.metadata['entidad_tipo']} {f.metadata.get('entidad_id', '')}"
                )
            partes.append(f"[{f.cita}] ({'; '.join(etiquetas)})\n{f.contenido}\n")

    return "\n".join(partes)
