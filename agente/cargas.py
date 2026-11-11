"""Cargas de configuracion que propone Kuntur (ADR-A12).

Las tools de clase 'configuracion' graban: depositos, unidades, tipos, ABM de
Mantenimiento, menus y roles. Kuntur puede usarlas, pero el motor NUNCA las
ejecuta en la charla:

  1. Kuntur "llama" la tool. El motor guarda una carga PROPUESTA
     (agente.carga_propuesta) y le devuelve al modelo que quedo para
     confirmar, sin decir que se grabo.
  2. El panel la muestra como tarjeta con lo que se va a grabar.
  3. El administrador toca "Cargar". Recien ahi se ejecuta la tool, con SU
     token (nunca el de maquina), y queda quien confirmo y que devolvio.

Lo que se ejecuta es exactamente lo que se guardo: la tarjeta solo manda el id
de la carga, no los datos. Una carga vence a las VIGENCIA_HORAS.

Las cinco condiciones de ADR-A12: confirmacion, token del administrador, lista
cerrada (agente.tools_de_configuracion), registro y todo o nada (las cargas de
varias filas van por una sola tool que lo garantiza).
"""
from __future__ import annotations

import json
import time
import uuid
from dataclasses import dataclass

import psycopg

from . import rag
from .config import Config
from .mcp_client import ClienteMCP, MCPError

VIGENCIA_HORAS = 24
MAX_FILAS_MUESTRA = 10


class CargaInvalida(ValueError):
    """La carga no se puede confirmar: no existe, ya se respondio o vencio."""


async def de_configuracion(con: psycopg.AsyncConnection, clave_agente: str) -> frozenset[str]:
    """Las tools que este agente solo puede PROPONER (agente.tools_de_configuracion)."""
    async with con.cursor() as cur:
        await cur.execute("SELECT agente.tools_de_configuracion(%s) AS nombre", (clave_agente,))
        return frozenset(f["nombre"] for f in await cur.fetchall())


async def descripcion(con: psycopg.AsyncConnection, tool: str) -> str:
    async with con.cursor() as cur:
        await cur.execute("SELECT descripcion FROM agente.tool WHERE nombre = %s", (tool,))
        f = await cur.fetchone()
    return f["descripcion"] if f else tool


def _filas(argumentos: dict) -> list | None:
    """Si la carga es de varias filas, la lista. Por convencion, el argumento 'filas'."""
    filas = argumentos.get("filas")
    return filas if isinstance(filas, list) else None


@dataclass
class Propuesta:
    carga_id: str
    tool: str
    titulo: str
    argumentos: dict

    def tarjeta(self) -> dict:
        """Lo que ve el administrador: que se va a grabar. Con muchas filas, una muestra."""
        filas = _filas(self.argumentos)
        datos = {k: v for k, v in self.argumentos.items() if k != "filas"}
        return {"carga_id": self.carga_id, "tool": self.tool, "titulo": self.titulo,
                "datos": datos, "filas": (filas or [])[:MAX_FILAS_MUESTRA],
                "total_filas": len(filas) if filas is not None else None}

    def para_el_modelo(self) -> dict:
        """Lo que vuelve al modelo. Sin 'ya esta': todavia no se grabo nada."""
        filas = _filas(self.argumentos)
        return {"carga_propuesta": self.carga_id, "total_filas": len(filas) if filas is not None else 1,
                "nota": "No se grabó nada. Se le muestra al administrador como tarjeta y se graba "
                        "solo si toca «Cargar». Decíselo así; no digas que ya está cargado."}


async def proponer(con: psycopg.AsyncConnection, *, empr_id: int, interaccion_id: str, agente: str,
                   usuario: str, tool: str, argumentos: dict) -> Propuesta:
    carga_id = str(uuid.uuid4())
    async with con.cursor() as cur:
        await cur.execute(
            """
            INSERT INTO agente.carga_propuesta (carga_id, empr_id, interaccion_id, agente, tool,
                                                argumentos, usuario)
            VALUES (%s, %s, %s, %s, %s, %s::jsonb, %s)
            """, (carga_id, empr_id, interaccion_id, agente, tool,
                  json.dumps(argumentos, ensure_ascii=False), usuario))
    return Propuesta(carga_id, tool, await descripcion(con, tool), argumentos)


async def _pendiente(con: psycopg.AsyncConnection, carga_id: str) -> dict:
    try:
        uuid.UUID(carga_id)
    except ValueError:
        raise CargaInvalida("No existe esa carga") from None
    async with con.cursor() as cur:
        await cur.execute(
            """
            SELECT carga_id, agente, tool, argumentos, estado,
                   fec_alta < now() - make_interval(hours => %s) AS vencida
            FROM agente.carga_propuesta WHERE carga_id = %s FOR UPDATE
            """, (VIGENCIA_HORAS, carga_id))
        f = await cur.fetchone()
    if not f:
        raise CargaInvalida("No existe esa carga")
    if f["estado"] != "propuesta":
        raise CargaInvalida(f"Esa carga ya está {f['estado']}")
    if f["vencida"]:
        async with con.cursor() as cur:
            await cur.execute("UPDATE agente.carga_propuesta SET estado = 'vencida', fec_respuesta = now() "
                              "WHERE carga_id = %s", (carga_id,))
        await con.commit()
        raise CargaInvalida(f"La propuesta venció (dura {VIGENCIA_HORAS} horas). Pedile a Kuntur que la arme de nuevo.")
    return dict(f)


async def confirmar(con: psycopg.AsyncConnection, cfg: Config, *, empr_id: int, carga_id: str,
                    usuario: str, autorizacion: str) -> dict:
    """El administrador toco "Cargar": se ejecuta la tool con SU token.

    Antes se verifica que la tool siga en la lista de configuracion del agente:
    si la sacaron despues de proponerla, no se ejecuta.
    """
    c = await _pendiente(con, carga_id)
    if c["tool"] not in await de_configuracion(con, c["agente"]):
        raise CargaInvalida(f"{c['tool']} ya no está habilitada para {c['agente']}")
    t0 = time.monotonic()
    try:
        async with ClienteMCP(cfg, autorizacion) as mcp:
            salida = await mcp.llamar(c["tool"], c["argumentos"])
        estado, resultado = "ejecutada", {"respuesta": salida}
    except MCPError as e:
        estado, resultado = "fallida", {"error": str(e)[:1000]}
    resultado["ms"] = int((time.monotonic() - t0) * 1000)
    async with con.cursor() as cur:
        await cur.execute(
            "UPDATE agente.carga_propuesta SET estado = %s, confirmado_por = %s, resultado = %s::jsonb, "
            "fec_respuesta = now() WHERE carga_id = %s",
            (estado, usuario, json.dumps(resultado, ensure_ascii=False, default=str), carga_id))
    await con.commit()
    await rag.fijar_empresa(con, empr_id)
    return {"carga_id": carga_id, "estado": estado, **resultado}


async def descartar(con: psycopg.AsyncConnection, *, empr_id: int, carga_id: str, usuario: str) -> dict:
    await _pendiente(con, carga_id)
    async with con.cursor() as cur:
        await cur.execute("UPDATE agente.carga_propuesta SET estado = 'descartada', confirmado_por = %s, "
                          "fec_respuesta = now() WHERE carga_id = %s", (usuario, carga_id))
    await con.commit()
    await rag.fijar_empresa(con, empr_id)
    return {"carga_id": carga_id, "estado": "descartada"}
