"""Configuracion de cada agente: Kuntur, Quirqui y Faustino (ADR-A7).

El motor es uno solo. Lo que lo convierte en el Coach, el Asistente o el
Entrevistador es una fila de agente.agente: quien lo puede usar, con que
prompt, que tools tiene permitidas, de que fuentes lee y como se presenta.

La configuracion es global (igual para todos los clientes) y el runtime solo
la lee: se edita desde db/agente/011-agentes.sql. Se consulta en cada uso, sin
cache, para que un cambio aplicado se vea en la proxima consulta sin reiniciar.
"""
from __future__ import annotations

from dataclasses import dataclass
from fnmatch import fnmatchcase
from pathlib import Path

import psycopg

from .prompt import cargar as cargar_prompt

# Dnato pone en el claim "role" el nivel del usuario: 1 = administrador
# (Userlevel::checkLevel de traz-comp-dnato). Es el unico que puede usar al
# Coach (R1). Hoy no es un rol por empresa: deuda conocida, ver ADR-A7.
ROL_ADMIN_DNATO = "1"


class AgenteError(Exception):
    """Base de los errores de configuracion o de acceso a un agente."""


class AgenteDesconocido(AgenteError):
    pass


class AgenteNoDisponible(AgenteError):
    """Existe pero esta inactivo (por ejemplo, Kuntur hasta la Fase 5)."""


class AccesoDenegado(AgenteError):
    pass


@dataclass(frozen=True)
class Agente:
    clave: str
    nombre: str
    rol: str
    personalidad: str
    acceso: str
    prompt: str
    tools_permitidas: tuple[str, ...]
    disparadores: tuple[str, ...]
    fuentes: tuple[str, ...]
    autonomia: str
    avatar: str
    activo: bool

    # ------------------------------------------------------------- acceso
    def puede_usarlo(self, rol_usuario: str | int | None) -> bool:
        """Si un usuario con ese rol de Dnato puede usar este agente.

        'curador' no se resuelve aca: los endpoints del entrevistador los
        restringe Tools por menu (ver api.py). Para /consulta, un agente de
        acceso 'curador' no se ofrece.
        """
        if self.acceso == "usuario":
            return True
        if self.acceso == "admin":
            return str(rol_usuario or "").strip() == ROL_ADMIN_DNATO
        return False

    def tool_permitida(self, nombre: str) -> bool:
        """Si el nombre de tool entra en alguno de los patrones permitidos."""
        return any(fnmatchcase(nombre, patron) for patron in self.tools_permitidas)

    # ------------------------------------------------------------- prompt
    def identidad(self) -> str:
        """Mensaje de sistema con el nombre y la personalidad.

        Va ANTES del prompt del archivo: el nombre sale de la configuracion,
        no del texto del prompt, para poder cambiarlo sin tocar instrucciones.
        """
        return (
            f"Te llamás {self.nombre}. {self.personalidad}\n"
            f"Si te preguntan quién sos, presentate como {self.nombre}."
        )

    def sistema(self, prompts_dir: Path) -> str:
        """Identidad + instrucciones del archivo de prompt, listo para el modelo."""
        return self.identidad() + "\n\n" + cargar_prompt(self.ruta_prompt(prompts_dir))

    def ruta_prompt(self, prompts_dir: Path) -> Path:
        return prompts_dir / self.prompt


_COLUMNAS = (
    "clave, nombre, rol, personalidad, acceso, prompt, tools_permitidas, "
    "disparadores, fuentes, autonomia, avatar, activo"
)


def _desde_fila(f: dict) -> Agente:
    return Agente(
        clave=f["clave"], nombre=f["nombre"], rol=f["rol"],
        personalidad=f["personalidad"], acceso=f["acceso"], prompt=f["prompt"],
        tools_permitidas=tuple(f["tools_permitidas"] or ()),
        disparadores=tuple(f["disparadores"] or ()),
        fuentes=tuple(f["fuentes"] or ()),
        autonomia=f["autonomia"], avatar=f["avatar"], activo=f["activo"],
    )


async def obtener(con: psycopg.AsyncConnection, clave: str, *,
                  solo_activos: bool = True) -> Agente:
    async with con.cursor() as cur:
        await cur.execute(f"SELECT {_COLUMNAS} FROM agente.agente WHERE clave = %s", (clave,))
        fila = await cur.fetchone()
    if not fila:
        raise AgenteDesconocido(f"No existe el agente '{clave}'")
    agente = _desde_fila(fila)
    if solo_activos and not agente.activo:
        raise AgenteNoDisponible(f"{agente.nombre} todavía no está disponible")
    return agente


async def listar(con: psycopg.AsyncConnection) -> list[Agente]:
    async with con.cursor() as cur:
        await cur.execute(f"SELECT {_COLUMNAS} FROM agente.agente ORDER BY clave")
        return [_desde_fila(f) for f in await cur.fetchall()]


async def para_consulta(con: psycopg.AsyncConnection, clave: str,
                        rol_usuario: str | int | None) -> Agente:
    """El agente que va a responder una consulta, verificando que se pueda usar.

    Es la unica puerta de entrada desde /consulta: si el agente no existe, no
    esta activo, no es conversacional o el usuario no tiene el rol, falla
    aca, antes de gastar un token.
    """
    # El acceso se verifica ANTES que si esta activo: si no, un empleado que
    # pide a Kuntur recibiria "todavia no esta disponible" y sabria que existe.
    agente = await obtener(con, clave, solo_activos=False)
    if agente.rol == "entrevistador":
        raise AccesoDenegado(f"{agente.nombre} se usa desde la pantalla de entrevistas")
    if not agente.puede_usarlo(rol_usuario):
        raise AccesoDenegado(f"{agente.nombre} solo está disponible para administradores")
    if not agente.activo:
        raise AgenteNoDisponible(f"{agente.nombre} todavía no está disponible")
    return agente
