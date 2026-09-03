"""Agente entrevistador: le saca conocimiento a un experto y lo estructura.

El circuito, en criollo:

    agenda      qué preguntar primero, priorizado por datos reales
    sesion      pregunta amplia -> repreguntas -> el experto habla
    estructura  la conversación se convierte en hechos discretos
    valida      el experto revisa y corrige lo que quedó escrito
    cruzada     otro experto opina (coincide / discrepa / matiza)
    promueve    los aprobados pasan a agente.chunk, con embedding

Dos reglas que atraviesan todo el módulo:

  * NADA llega al conocimiento compartido sin que un humano lo apruebe
    (ADR-A4). Este módulo escribe hechos, no chunks; la promoción es un paso
    aparte y explícito.
  * El agente no completa lo que el experto no dijo. Si un hecho queda a
    medias, queda a medias -- inventar un procedimiento en una base de
    conocimiento minera puede terminar lastimando a alguien.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

import psycopg

from .config import Config
from .llm import LLMError, OpenRouter
from .prompt import cargar as cargar_prompt
from .rag import _a_vector

# Cuántos intercambios antes de sugerir cerrar. No es un tope duro: el agente
# puede cerrar antes si ya tiene lo que necesita.
INTERCAMBIOS_SUGERIDOS = 6


def _prompt_path(cfg: Config) -> Path:
    return cfg.prompt_path.parent / "entrevistador.md"


@dataclass
class Tema:
    tema_id: int
    nombre: str
    descripcion: str | None
    modulo: str
    tipo_equipo: str | None
    situacion: str | None
    prioridad: float
    origen_prioridad: dict = field(default_factory=dict)


# ---------------------------------------------------------------- la agenda
async def agenda(con: psycopg.AsyncConnection, *, limite: int = 15,
                 modulo: str | None = None) -> list[Tema]:
    """Los temas pendientes, del más al menos prioritario."""
    sql = """
        SELECT tema_id, nombre, descripcion, modulo, tipo_equipo, situacion,
               prioridad, origen_prioridad
        FROM agente.tema
        WHERE estado = 'pendiente'
          AND prioridad > 0
          AND (%(modulo)s::text IS NULL OR modulo IN (%(modulo)s, 'general'))
        ORDER BY prioridad DESC, nombre
        LIMIT %(limite)s
    """
    async with con.cursor() as cur:
        await cur.execute(sql, {"modulo": modulo, "limite": limite})
        filas = await cur.fetchall()
    return [
        Tema(f["tema_id"], f["nombre"], f["descripcion"], f["modulo"],
             f["tipo_equipo"], f["situacion"], float(f["prioridad"]),
             f["origen_prioridad"] or {})
        for f in filas
    ]


async def recalcular_prioridades(
    con: psycopg.AsyncConnection, conteo_por_equipo: dict[str, int],
    huecos_por_tema: dict[int, int] | None = None,
) -> int:
    """Recalcula la agenda cruzando el peso base con los datos reales.

    `conteo_por_equipo` sale de las tools MCP: cuántas OTs generó cada familia
    de equipo. Es la fuente más potente de las cuatro -- si las chancadoras
    generan el 40% de las OTs de los clientes, ese conocimiento va primero.

    `huecos_por_tema` son las consultas que el agente no pudo responder: si a un
    tema le faltó conocimiento en el uso real, sube.

    La prioridad final es la suma de los aportes, y cada uno queda registrado en
    origen_prioridad para que la agenda sea auditable: se puede saber POR QUÉ un
    tema está donde está.
    """
    huecos_por_tema = huecos_por_tema or {}
    total_ots = sum(conteo_por_equipo.values()) or 1
    actualizados = 0

    async with con.cursor() as cur:
        await cur.execute(
            "SELECT tema_id, tipo_equipo, origen_prioridad FROM agente.tema"
        )
        temas = await cur.fetchall()

        for t in temas:
            origen = dict(t["origen_prioridad"] or {})
            seed = float(origen.get("seed", 0))

            # Hasta 50 puntos segun la porcion de OTs de esa familia de equipo.
            ots = conteo_por_equipo.get(t["tipo_equipo"] or "", 0)
            por_ots = round(50.0 * ots / total_ots, 2) if ots else 0.0

            # Hasta 30 puntos por huecos detectados en el uso.
            por_huecos = min(30.0, 3.0 * huecos_por_tema.get(t["tema_id"], 0))

            origen.update({"ots": por_ots, "huecos": por_huecos,
                           "ots_contadas": ots})
            nueva = round(seed + por_ots + por_huecos, 2)

            await cur.execute(
                "UPDATE agente.tema SET prioridad = %s, origen_prioridad = %s "
                "WHERE tema_id = %s",
                (nueva, json.dumps(origen), t["tema_id"]),
            )
            actualizados += 1
    await con.commit()
    return actualizados


# ------------------------------------------------------------- la entrevista
async def iniciar(con: psycopg.AsyncConnection, cfg: Config, llm: OpenRouter,
                  experto_id: int, tema_id: int) -> dict:
    """Abre una sesión y devuelve la primera pregunta, que es amplia."""
    async with con.cursor() as cur:
        await cur.execute(
            "SELECT nombre, descripcion, modulo, tipo_equipo, situacion "
            "FROM agente.tema WHERE tema_id = %s", (tema_id,)
        )
        tema = await cur.fetchone()
        if not tema:
            raise ValueError(f"No existe el tema {tema_id}")

        await cur.execute("SELECT nombre, especialidad FROM agente.experto WHERE experto_id = %s",
                          (experto_id,))
        experto = await cur.fetchone()
        if not experto:
            raise ValueError(f"No existe el experto {experto_id}")

    pregunta = await _generar(cfg, llm, [
        {"role": "user", "content":
            f"Vas a entrevistar a {experto['nombre']}"
            + (f", especialista en {experto['especialidad']}" if experto.get("especialidad") else "")
            + f", sobre el tema: **{tema['nombre']}**.\n"
            + (f"Alcance del tema: {tema['descripcion']}\n" if tema["descripcion"] else "")
            + "\nEscribí SOLO la primera pregunta, que tiene que ser amplia y abierta. "
              "Sin saludo largo ni preámbulo."},
    ])

    async with con.cursor() as cur:
        await cur.execute(
            """
            INSERT INTO agente.sesion_entrevista (experto_id, tema_id, modelo, transcripcion)
            VALUES (%s, %s, %s, %s::jsonb)
            RETURNING sesion_id
            """,
            (experto_id, tema_id, cfg.modelo,
             json.dumps([{"rol": "agente", "texto": pregunta}])),
        )
        sesion_id = (await cur.fetchone())["sesion_id"]
    await con.commit()

    return {"sesion_id": str(sesion_id), "tema": tema["nombre"], "pregunta": pregunta}


async def responder(con: psycopg.AsyncConnection, cfg: Config, llm: OpenRouter,
                    sesion_id: str, respuesta: str) -> dict:
    """Registra lo que dijo el experto y devuelve la repregunta."""
    sesion = await _sesion(con, sesion_id)
    if sesion["estado"] != "abierta":
        raise ValueError(f"La sesión está {sesion['estado']}, no admite respuestas")

    transcripcion = list(sesion["transcripcion"] or [])
    transcripcion.append({"rol": "experto", "texto": respuesta})

    intercambios = sum(1 for m in transcripcion if m["rol"] == "experto")
    cierre = (
        "\n\nYa llevás varios intercambios: si el tema está cubierto, en vez de "
        "otra pregunta respondé exactamente CERRAR."
        if intercambios >= INTERCAMBIOS_SUGERIDOS else ""
    )

    siguiente = await _generar(cfg, llm, [
        {"role": "user", "content":
            f"Tema de la entrevista: {sesion['tema_nombre']}.\n\n"
            "Conversación hasta ahora:\n\n" + _formatear(transcripcion)
            + "\n\nEscribí SOLO tu próxima pregunta." + cierre},
    ])

    if siguiente.strip().upper().startswith("CERRAR"):
        transcripcion.append({"rol": "sistema", "texto": "El agente considera cubierto el tema."})
        await _guardar_transcripcion(con, sesion_id, transcripcion, estado="estructurando")
        return {"sesion_id": sesion_id, "cerrar": True,
                "mensaje": "Creo que ya tenemos lo importante de este tema. "
                           "Voy a ordenar lo que me contaste."}

    transcripcion.append({"rol": "agente", "texto": siguiente})
    await _guardar_transcripcion(con, sesion_id, transcripcion)
    return {"sesion_id": sesion_id, "cerrar": False, "pregunta": siguiente,
            "intercambios": intercambios}


async def estructurar(con: psycopg.AsyncConnection, cfg: Config, llm: OpenRouter,
                      sesion_id: str) -> list[dict]:
    """Convierte la conversación en hechos, para que el experto los valide.

    Los hechos quedan en estado 'borrador': todavía no son conocimiento, son una
    propuesta de redacción de lo que el experto dijo.
    """
    sesion = await _sesion(con, sesion_id)
    transcripcion = list(sesion["transcripcion"] or [])
    if not any(m["rol"] == "experto" for m in transcripcion):
        raise ValueError("La sesión no tiene ninguna respuesta del experto")

    crudo = await _generar(cfg, llm, [
        {"role": "user", "content":
            f"Tema: {sesion['tema_nombre']}.\n\n"
            "Esta es la entrevista completa:\n\n" + _formatear(transcripcion)
            + "\n\nConvertila en hechos, siguiendo las reglas de tu prompt.\n"
              "Respondé SOLO un array JSON, sin texto alrededor y sin ```. "
              "Cada elemento: {\"contenido\": str, \"tipo_equipo\": str|null, "
              "\"situacion\": str|null, \"confianza\": float}"},
    ])

    hechos = _parsear_hechos(crudo)
    if not hechos:
        raise ValueError("No se pudo estructurar ningún hecho de esta entrevista")

    creados = []
    async with con.cursor() as cur:
        for h in hechos:
            await cur.execute(
                """
                INSERT INTO agente.hecho
                    (sesion_id, contenido, tipo_equipo, situacion, modulo, confianza)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING hecho_id, contenido, tipo_equipo, situacion, confianza
                """,
                (sesion_id, h["contenido"], h.get("tipo_equipo"), h.get("situacion"),
                 sesion["tema_modulo"], h.get("confianza", 0.7)),
            )
            f = await cur.fetchone()
            creados.append({
                "hecho_id": f["hecho_id"], "contenido": f["contenido"],
                "tipo_equipo": f["tipo_equipo"], "situacion": f["situacion"],
                "confianza": float(f["confianza"]),
            })
        await cur.execute(
            "UPDATE agente.sesion_entrevista SET estado = 'en_validacion' WHERE sesion_id = %s",
            (sesion_id,),
        )
    await con.commit()
    return creados


async def validar(con: psycopg.AsyncConnection, hecho_id: int, *,
                  aprobado: bool, contenido: str | None = None) -> dict:
    """El experto confirma, corrige o descarta un hecho.

    Si edita el texto, se guarda el suyo: es su conocimiento, no la redacción
    del modelo.
    """
    estado = "validado_experto" if aprobado else "rechazado"
    async with con.cursor() as cur:
        if contenido:
            await cur.execute(
                "UPDATE agente.hecho SET contenido = %s, estado_validacion = %s, "
                "fec_validacion = now() WHERE hecho_id = %s RETURNING hecho_id, contenido, estado_validacion",
                (contenido, estado, hecho_id),
            )
        else:
            await cur.execute(
                "UPDATE agente.hecho SET estado_validacion = %s, fec_validacion = now() "
                "WHERE hecho_id = %s RETURNING hecho_id, contenido, estado_validacion",
                (estado, hecho_id),
            )
        fila = await cur.fetchone()
    await con.commit()
    if not fila:
        raise ValueError(f"No existe el hecho {hecho_id}")
    return dict(fila)


async def cerrar_sesion(con: psycopg.AsyncConnection, sesion_id: str) -> dict:
    """Cierra la sesión y marca el tema como cubierto si quedó algo validado."""
    async with con.cursor() as cur:
        await cur.execute(
            "UPDATE agente.sesion_entrevista SET estado = 'cerrada', fec_cierre = now() "
            "WHERE sesion_id = %s RETURNING tema_id", (sesion_id,)
        )
        fila = await cur.fetchone()
        if not fila:
            raise ValueError(f"No existe la sesión {sesion_id}")

        await cur.execute(
            """
            SELECT count(*) AS validados FROM agente.hecho
            WHERE sesion_id = %s AND estado_validacion <> 'rechazado'
            """, (sesion_id,)
        )
        validados = (await cur.fetchone())["validados"]

        # El tema se marca cubierto solo si de verdad quedó conocimiento. Una
        # entrevista que no dio nada deja el tema pendiente, para volver.
        if validados and fila["tema_id"]:
            await cur.execute(
                "UPDATE agente.tema SET estado = 'cubierto' WHERE tema_id = %s",
                (fila["tema_id"],),
            )
    await con.commit()
    return {"sesion_id": sesion_id, "hechos_validados": validados}


# ------------------------------------------------------- validación cruzada
async def para_validar(con: psycopg.AsyncConnection, experto_id: int) -> list[dict]:
    """Hechos de OTROS expertos esperando una segunda opinión.

    El filtro por autor no es cosmético: si alguien valida lo suyo, la
    validación cruzada deja de significar nada.
    """
    async with con.cursor() as cur:
        await cur.execute(
            """
            SELECT h.hecho_id, h.contenido, h.tipo_equipo, h.situacion, h.modulo,
                   e.nombre AS autor, t.nombre AS tema
            FROM agente.hecho h
            JOIN agente.sesion_entrevista s USING (sesion_id)
            JOIN agente.experto e ON e.experto_id = s.experto_id
            LEFT JOIN agente.tema t ON t.tema_id = s.tema_id
            WHERE h.estado_validacion IN ('validado_experto', 'en_validacion_cruzada')
              AND s.experto_id <> %(experto)s
              AND NOT EXISTS (
                  SELECT 1 FROM agente.validacion_cruzada v
                  WHERE v.hecho_id = h.hecho_id AND v.experto_id = %(experto)s
              )
            ORDER BY h.fec_alta
            """, {"experto": experto_id},
        )
        return [dict(f) for f in await cur.fetchall()]


async def opinar(con: psycopg.AsyncConnection, hecho_id: int, experto_id: int,
                 veredicto: str, comentario: str | None = None) -> dict:
    """Registra la opinión de otro experto y ajusta el estado del hecho.

    Si discrepan, el hecho NO se descarta: queda como zona gris. Un desacuerdo
    entre dos expertos es información, y perderla sería tirar justo lo que más
    conviene revisar.
    """
    async with con.cursor() as cur:
        await cur.execute(
            """
            INSERT INTO agente.validacion_cruzada (hecho_id, experto_id, veredicto, comentario)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (hecho_id, experto_id)
            DO UPDATE SET veredicto = EXCLUDED.veredicto, comentario = EXCLUDED.comentario
            """, (hecho_id, experto_id, veredicto, comentario),
        )
        await cur.execute(
            """
            SELECT count(*) FILTER (WHERE veredicto = 'coincide') AS coinciden,
                   count(*) FILTER (WHERE veredicto = 'discrepa') AS discrepan
            FROM agente.validacion_cruzada WHERE hecho_id = %s
            """, (hecho_id,),
        )
        v = await cur.fetchone()

        if v["discrepan"]:
            estado = "zona_gris"
        elif v["coinciden"] >= 1:
            estado = "en_validacion_cruzada"
        else:
            estado = "validado_experto"

        await cur.execute(
            "UPDATE agente.hecho SET estado_validacion = %s WHERE hecho_id = %s "
            "AND estado_validacion <> 'aprobado'", (estado, hecho_id),
        )
    await con.commit()
    return {"hecho_id": hecho_id, "estado": estado,
            "coinciden": v["coinciden"], "discrepan": v["discrepan"]}


# ------------------------------------------------------------ la promoción
async def promover(con: psycopg.AsyncConnection, cfg: Config, llm: OpenRouter,
                   hecho_id: int, *, curador: str) -> dict:
    """Pasa un hecho aprobado al conocimiento compartido.

    Es el ÚNICO punto donde algo entra a agente.chunk desde una entrevista, y
    requiere el rol agente_curador: con las credenciales del orquestador esto
    falla con permission denied, y está bien (ADR-A4).
    """
    async with con.cursor() as cur:
        await cur.execute(
            """
            SELECT h.contenido, h.tipo_equipo, h.situacion, h.modulo, h.confianza,
                   h.estado_validacion, e.nombre AS experto
            FROM agente.hecho h
            JOIN agente.sesion_entrevista s USING (sesion_id)
            JOIN agente.experto e ON e.experto_id = s.experto_id
            WHERE h.hecho_id = %s
            """, (hecho_id,),
        )
        h = await cur.fetchone()

    if not h:
        raise ValueError(f"No existe el hecho {hecho_id}")
    if h["estado_validacion"] not in ("validado_experto", "en_validacion_cruzada", "zona_gris"):
        raise ValueError(
            f"El hecho está en estado '{h['estado_validacion']}': solo se promueve "
            "lo que el experto validó"
        )

    vector = (await llm.embeddings([h["contenido"]]))[0]

    # La zona gris se promueve con la confianza bajada: hay conocimiento, pero
    # los expertos no coincidieron, y el agente tiene que poder decirlo.
    confianza = float(h["confianza"])
    if h["estado_validacion"] == "zona_gris":
        confianza = min(confianza, 0.5)

    async with con.cursor() as cur:
        await cur.execute(
            """
            INSERT INTO agente.fuente (tipo, nombre)
            VALUES ('experto', %s)
            ON CONFLICT (tipo, nombre) DO UPDATE SET nombre = EXCLUDED.nombre
            RETURNING fuente_id
            """, (h["experto"],),
        )
        fuente_id = (await cur.fetchone())["fuente_id"]

        await cur.execute(
            """
            INSERT INTO agente.chunk
                (fuente_id, contenido, embedding, tipo_equipo, situacion, modulo,
                 confianza, metadata)
            VALUES (%s, %s, %s::vector, %s, %s, %s, %s, %s::jsonb)
            RETURNING chunk_id
            """,
            (fuente_id, h["contenido"], _a_vector(vector), h["tipo_equipo"],
             h["situacion"], h["modulo"], confianza,
             json.dumps({"hecho_id": hecho_id, "curador": curador,
                         "estado_validacion": h["estado_validacion"]})),
        )
        chunk_id = (await cur.fetchone())["chunk_id"]

        await cur.execute(
            "UPDATE agente.hecho SET estado_validacion = 'aprobado', chunk_id = %s "
            "WHERE hecho_id = %s", (chunk_id, hecho_id),
        )
    await con.commit()
    return {"hecho_id": hecho_id, "chunk_id": chunk_id, "confianza": confianza}


# ---------------------------------------------------------------- internos
async def _sesion(con: psycopg.AsyncConnection, sesion_id: str) -> dict:
    async with con.cursor() as cur:
        await cur.execute(
            """
            SELECT s.sesion_id, s.estado, s.transcripcion, s.experto_id,
                   t.nombre AS tema_nombre, t.modulo AS tema_modulo
            FROM agente.sesion_entrevista s
            LEFT JOIN agente.tema t ON t.tema_id = s.tema_id
            WHERE s.sesion_id = %s
            """, (sesion_id,),
        )
        fila = await cur.fetchone()
    if not fila:
        raise ValueError(f"No existe la sesión {sesion_id}")
    return dict(fila)


async def _guardar_transcripcion(con, sesion_id, transcripcion, estado=None) -> None:
    async with con.cursor() as cur:
        if estado:
            await cur.execute(
                "UPDATE agente.sesion_entrevista SET transcripcion = %s::jsonb, estado = %s "
                "WHERE sesion_id = %s",
                (json.dumps(transcripcion, ensure_ascii=False), estado, sesion_id),
            )
        else:
            await cur.execute(
                "UPDATE agente.sesion_entrevista SET transcripcion = %s::jsonb "
                "WHERE sesion_id = %s",
                (json.dumps(transcripcion, ensure_ascii=False), sesion_id),
            )
    await con.commit()


async def _generar(cfg: Config, llm: OpenRouter, mensajes: list[dict]) -> str:
    sistema = cargar_prompt(_prompt_path(cfg))
    rsp = await llm.chat([{"role": "system", "content": sistema}] + mensajes)
    if not rsp.texto.strip():
        raise LLMError("El entrevistador no devolvió texto")
    return rsp.texto.strip()


def _formatear(transcripcion: list[dict]) -> str:
    etiquetas = {"agente": "VOS", "experto": "EXPERTO", "sistema": "(sistema)"}
    return "\n\n".join(
        f"{etiquetas.get(m['rol'], m['rol'].upper())}: {m['texto']}"
        for m in transcripcion
    )


def _parsear_hechos(crudo: str) -> list[dict]:
    """Saca el array JSON de la respuesta del modelo.

    Los modelos suelen envolver el JSON en ``` aunque se les pida que no, así
    que se limpia antes de parsear en vez de fallar por eso.
    """
    texto = crudo.strip()
    if texto.startswith("```"):
        texto = texto.split("```")[1]
        if texto.startswith("json"):
            texto = texto[4:]
    inicio, fin = texto.find("["), texto.rfind("]")
    if inicio == -1 or fin == -1:
        return []
    try:
        datos = json.loads(texto[inicio:fin + 1])
    except (json.JSONDecodeError, ValueError):
        return []

    hechos = []
    for d in datos:
        if not isinstance(d, dict):
            continue
        contenido = str(d.get("contenido", "")).strip()
        # Un hecho de una línea suelta no se sostiene solo: se descarta.
        if len(contenido) < 20:
            continue
        try:
            confianza = float(d.get("confianza", 0.7))
        except (TypeError, ValueError):
            confianza = 0.7
        # Por debajo de 0.5 el prompt dice que no se registre.
        if confianza < 0.5:
            continue
        hechos.append({
            "contenido": contenido,
            "tipo_equipo": d.get("tipo_equipo") or None,
            "situacion": d.get("situacion") or None,
            "confianza": max(0.0, min(1.0, confianza)),
        })
    return hechos
