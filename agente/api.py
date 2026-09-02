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

from . import rag
from .config import Config, cargar
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
