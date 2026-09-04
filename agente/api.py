"""API HTTP del orquestador (FastAPI).

Endpoints:
    GET  /salud            estado del servicio, config y bloques del prompt sin definir
    POST /consulta         la consulta del usuario -> respuesta del agente
    POST /feedback         calificacion de una respuesta (pulgar arriba/abajo)
    GET  /admin/feedback   feedback negativo agrupado, para el ciclo de mejora

El empr_id NO es un parametro de entrada: se deriva del JWT que manda el
frontend. Aceptarlo por body seria darle a cualquiera la llave de los datos de
cualquier empresa.
"""
from __future__ import annotations

import base64
import binascii
import json
import logging

import psycopg
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from . import entrevistador, rag
from .config import Config, cargar
from .llm import OpenRouter
from .orquestador import Consulta, Orquestador
from .prompt import cargar as cargar_prompt
from .prompt import pendientes as prompt_pendientes

log = logging.getLogger("agente")

cfg: Config = cargar()
app = FastAPI(title="Agente Minero Trazalog", version="0.1.0")
orquestador = Orquestador(cfg)


# ---------------------------------------------------------------- identidad
def _claims(token: str) -> dict:
    """Lee los claims del JWT SIN validar la firma.

    Esto no es un descuido: la validacion la hace el APIM antes de que el
    request llegue hasta acá (ADR-008/ADR-009). El orquestador solo necesita
    saber de que empresa es la consulta para elegir la particion de memoria; el
    acceso a los datos del cliente va por MCP con el mismo token, y ahi si se
    valida de nuevo. Aun asi, este servicio NO debe quedar expuesto sin el
    gateway adelante.
    """
    partes = token.split(".")
    if len(partes) != 3:
        raise HTTPException(401, "El token no tiene formato JWT")
    cuerpo = partes[1] + "=" * (-len(partes[1]) % 4)
    try:
        return json.loads(base64.urlsafe_b64decode(cuerpo))
    except (binascii.Error, json.JSONDecodeError, ValueError) as e:
        raise HTTPException(401, "No se pudieron leer los claims del token") from e


class Identidad(BaseModel):
    empr_id: int
    usr_id: int | None = None
    nick: str | None = None
    autorizacion: str


async def identidad(authorization: str = Header(default="")) -> Identidad:
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Falta el header Authorization: Bearer <token>")
    claims = _claims(authorization[7:].strip())

    crudo = claims.get("empr_id")
    if crudo in (None, ""):
        raise HTTPException(403, "El token no trae empr_id")
    try:
        empr_id = int(crudo)
    except (TypeError, ValueError):
        raise HTTPException(403, f"empr_id invalido en el token: {crudo!r}") from None

    usr = claims.get("usr_id") or claims.get("uid")
    return Identidad(
        empr_id=empr_id,
        usr_id=int(usr) if str(usr or "").isdigit() else None,
        nick=claims.get("preferred_username") or claims.get("sub"),
        autorizacion=authorization,
    )


async def conexion():
    con = await rag.abrir(cfg)
    try:
        yield con
    finally:
        await con.close()


# ------------------------------------------------------------------ modelos
class ConsultaIn(BaseModel):
    pregunta: str = Field(min_length=1, max_length=4000)
    canal: str = "chat_tools"


class ConsultaOut(BaseModel):
    interaccion_id: str
    respuesta: str
    fragmentos: list[dict]
    tools_llamadas: list[dict]
    modelo: str
    latencia_ms: int


class FeedbackIn(BaseModel):
    interaccion_id: str
    util: bool
    comentario: str | None = Field(default=None, max_length=2000)
    motivo: str | None = None


# --- entrevistador -------------------------------------------------------
class IniciarIn(BaseModel):
    experto_id: int
    tema_id: int


class ResponderIn(BaseModel):
    sesion_id: str
    respuesta: str = Field(min_length=1, max_length=8000)


class ValidarIn(BaseModel):
    hecho_id: int
    aprobado: bool
    contenido: str | None = Field(default=None, max_length=4000)


class OpinarIn(BaseModel):
    hecho_id: int
    experto_id: int
    veredicto: str
    comentario: str | None = Field(default=None, max_length=2000)


class ExpertoIn(BaseModel):
    nombre: str = Field(min_length=2, max_length=200)
    especialidad: str | None = Field(default=None, max_length=200)
    usr_id: int | None = None


# ---------------------------------------------------------------- endpoints
@app.get("/salud")
async def salud() -> dict:
    problemas = cfg.validar()
    sin_definir: list[str] = []
    if cfg.prompt_path.exists():
        sin_definir = prompt_pendientes(cargar_prompt(cfg.prompt_path))
    return {
        "estado": "ok" if not problemas else "config_incompleta",
        "modelo": cfg.modelo,
        "modelo_embeddings": cfg.modelo_embeddings,
        "mcp_modo": cfg.mcp_modo,
        "problemas_config": problemas,
        # Que quede visible: salir a produccion con los textos de ejemplo del
        # prompt es un error facil de cometer y dificil de notar.
        "prompt_bloques_sin_definir": sin_definir,
    }


@app.post("/consulta", response_model=ConsultaOut)
async def consulta(
    entrada: ConsultaIn,
    ident: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> ConsultaOut:
    res = await orquestador.responder(con, Consulta(
        empr_id=ident.empr_id, pregunta=entrada.pregunta,
        autorizacion=ident.autorizacion, usr_id=ident.usr_id,
        usuario_nick=ident.nick, canal=entrada.canal,
    ))
    return ConsultaOut(
        interaccion_id=res.interaccion_id, respuesta=res.respuesta,
        fragmentos=res.fragmentos, tools_llamadas=res.tools_llamadas,
        modelo=res.modelo, latencia_ms=res.latencia_ms,
    )


@app.post("/feedback")
async def feedback(
    entrada: FeedbackIn,
    ident: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    await rag.fijar_empresa(con, ident.empr_id)
    # El JOIN contra interaccion filtrando por empr_id evita que alguien
    # califique la interaccion de otra empresa mandando un id ajeno.
    sql = """
        INSERT INTO agente.feedback (interaccion_id, util, comentario, motivo, usr_id)
        SELECT i.interaccion_id, %(util)s, %(comentario)s, %(motivo)s, %(usr_id)s
        FROM agente.interaccion i
        WHERE i.interaccion_id = %(id)s AND i.empr_id = %(empr_id)s
        ON CONFLICT (interaccion_id, usr_id)
        DO UPDATE SET util = EXCLUDED.util,
                      comentario = EXCLUDED.comentario,
                      motivo = EXCLUDED.motivo,
                      fec_alta = now()
        RETURNING feedback_id
    """
    async with con.cursor() as cur:
        await cur.execute(sql, {
            "id": entrada.interaccion_id, "empr_id": ident.empr_id,
            "util": entrada.util, "comentario": entrada.comentario,
            "motivo": entrada.motivo, "usr_id": ident.usr_id,
        })
        fila = await cur.fetchone()
    await con.commit()
    if not fila:
        raise HTTPException(404, "No existe esa interaccion para esta empresa")
    return {"feedback_id": fila["feedback_id"]}


@app.get("/admin/feedback")
async def admin_feedback(
    ident: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
    limite: int = 50,
) -> dict:
    """Feedback negativo sin triar, agrupado por motivo."""
    await rag.fijar_empresa(con, ident.empr_id)
    async with con.cursor() as cur:
        await cur.execute(
            """
            SELECT coalesce(motivo, 'sin_motivo') AS motivo, count(*) AS cantidad
            FROM agente.v_feedback_negativo WHERE empr_id = %s
            GROUP BY 1 ORDER BY 2 DESC
            """,
            (ident.empr_id,),
        )
        resumen = await cur.fetchall()
        await cur.execute(
            "SELECT * FROM agente.v_feedback_negativo WHERE empr_id = %s LIMIT %s",
            (ident.empr_id, min(limite, 200)),
        )
        detalle = await cur.fetchall()
    return {"resumen": resumen, "detalle": detalle}


# =========================================================================
# Entrevistador — la captura de conocimiento experto (E4)
# =========================================================================
# Estos endpoints NO llevan empr_id: el conocimiento que se captura es del
# dominio, no de una empresa. Por eso tampoco se fija el contexto de RLS acá.
# La restricción de quién puede usarlos es de rol, y la aplica Tools.

@app.get("/entrevista/agenda")
async def entrevista_agenda(
    modulo: str | None = None,
    limite: int = 15,
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    """Los temas pendientes, del más al menos prioritario."""
    temas = await entrevistador.agenda(con, limite=min(limite, 50), modulo=modulo)
    return {"temas": [
        {"tema_id": t.tema_id, "nombre": t.nombre, "descripcion": t.descripcion,
         "modulo": t.modulo, "prioridad": t.prioridad,
         "origen_prioridad": t.origen_prioridad}
        for t in temas
    ]}


@app.post("/entrevista/iniciar")
async def entrevista_iniciar(
    entrada: IniciarIn,
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    try:
        async with OpenRouter(cfg) as llm:
            return await entrevistador.iniciar(con, cfg, llm, entrada.experto_id, entrada.tema_id)
    except ValueError as e:
        raise HTTPException(400, str(e)) from e


@app.post("/entrevista/responder")
async def entrevista_responder(
    entrada: ResponderIn,
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    try:
        async with OpenRouter(cfg) as llm:
            return await entrevistador.responder(con, cfg, llm, entrada.sesion_id, entrada.respuesta)
    except ValueError as e:
        raise HTTPException(400, str(e)) from e


@app.post("/entrevista/estructurar")
async def entrevista_estructurar(
    sesion_id: str,
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    """Convierte la conversación en hechos para que el experto los revise."""
    try:
        async with OpenRouter(cfg) as llm:
            hechos = await entrevistador.estructurar(con, cfg, llm, sesion_id)
        return {"sesion_id": sesion_id, "hechos": hechos}
    except ValueError as e:
        raise HTTPException(400, str(e)) from e


@app.post("/entrevista/validar")
async def entrevista_validar(
    entrada: ValidarIn,
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    try:
        return await entrevistador.validar(
            con, entrada.hecho_id, aprobado=entrada.aprobado, contenido=entrada.contenido
        )
    except ValueError as e:
        raise HTTPException(404, str(e)) from e


@app.post("/entrevista/cerrar")
async def entrevista_cerrar(
    sesion_id: str,
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    try:
        return await entrevistador.cerrar_sesion(con, sesion_id)
    except ValueError as e:
        raise HTTPException(404, str(e)) from e


@app.get("/entrevista/para-validar")
async def entrevista_para_validar(
    experto_id: int,
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    """Hechos de OTROS expertos esperando una segunda opinión."""
    return {"hechos": await entrevistador.para_validar(con, experto_id)}


@app.post("/entrevista/opinar")
async def entrevista_opinar(
    entrada: OpinarIn,
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    if entrada.veredicto not in ("coincide", "discrepa", "matiza", "no_opina"):
        raise HTTPException(400, f"Veredicto invalido: {entrada.veredicto}")
    try:
        return await entrevistador.opinar(
            con, entrada.hecho_id, entrada.experto_id, entrada.veredicto, entrada.comentario
        )
    except psycopg.errors.RaiseException as e:
        # El trigger no deja que un experto valide sus propios hechos.
        raise HTTPException(400, str(e).split("CONTEXT")[0].strip()) from e


@app.get("/entrevista/expertos")
async def entrevista_expertos(
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    async with con.cursor() as cur:
        await cur.execute(
            "SELECT experto_id, nombre, especialidad FROM agente.experto "
            "WHERE activo ORDER BY nombre"
        )
        return {"expertos": [dict(f) for f in await cur.fetchall()]}


@app.post("/entrevista/expertos")
async def entrevista_alta_experto(
    entrada: ExpertoIn,
    _: Identidad = Depends(identidad),
    con: psycopg.AsyncConnection = Depends(conexion),
) -> dict:
    """Da de alta un experto, o reactiva uno con el mismo nombre."""
    async with con.cursor() as cur:
        await cur.execute(
            """
            INSERT INTO agente.experto (nombre, especialidad, usr_id)
            VALUES (%s, %s, %s)
            ON CONFLICT (nombre) DO UPDATE
                SET especialidad = EXCLUDED.especialidad,
                    usr_id = EXCLUDED.usr_id,
                    activo = true
            RETURNING experto_id, nombre, especialidad
            """,
            (entrada.nombre.strip(), entrada.especialidad, entrada.usr_id),
        )
        fila = await cur.fetchone()
    await con.commit()
    return dict(fila)
