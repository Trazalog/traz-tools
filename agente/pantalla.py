"""Donde esta parado el usuario (AGENTE-AS-01).

El panel de Quirqui manda la ruta de la pantalla actual de Tools (la variable
`site` de lib/props/navegacion.js, por ejemplo "traz-comp-almacenes/Articulo").
Con eso se buscan los casos de uso de esa pantalla en el conocimiento del
producto -- por el CONTROLADOR que la implementa, no por parecido --, y el
agente puede explicar que se hace ahi y cual es el siguiente paso.

La correspondencia sale del catalogo de DocTest (referencias_codigo de cada
caso, ingestadas en chunk.metadata->'controladores' por AGENTE-M-06):

    ruta de Tools                        controlador del catalogo
    traz-comp-almacenes/Articulo     ->  traz-comp-almacenes/controllers/Articulo.php
    traz-comp-pan/herramienta/index  ->  traz-comp-pan/controllers/Herramienta.php

Las pantallas de la raiz de Tools (application/controllers, por ejemplo
"Empresa/editar" o "Dash/dashboard") se buscan como
"traz-tools/application/controllers/Empresa.php", que es como las cita el
catalogo.

Limitacion conocida: los casos de Mantenimiento estan relevados sobre
AssetPlanner y los de Dnato sobre su propia app, que no son pantallas de
Tools. Se cubren cuando Mantenimiento migre a traz-tools-man.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

import psycopg

# Lo que puede venir como ruta: segmentos de URL de CodeIgniter. Nada de
# esquemas, dominios ni "..".
_RUTA_VALIDA = re.compile(r"^[A-Za-z0-9_\-]+(?:/[A-Za-z0-9_\-.%=]*)*(?:\?[A-Za-z0-9_\-.%=&]*)?$")
MAX_CASOS = 3


@dataclass
class CasoDePantalla:
    caso_uso: str
    contenido: str
    ayuda: str | None


def ruta_valida(ruta: str | None) -> bool:
    """Si la ruta tiene forma de URL de CodeIgniter y nada mas.

    Importa porque la ruta viene del navegador y termina DENTRO de un mensaje
    de sistema: sin esto, alguien podria mandar instrucciones al modelo
    disfrazadas de pantalla.
    """
    return bool(ruta) and len(ruta) <= 300 and ".." not in ruta and bool(_RUTA_VALIDA.match(ruta.strip().lstrip("/")))


def controlador(ruta: str | None) -> str | None:
    """"traz-comp-almacenes/articulo/index?x=1" -> "traz-comp-almacenes/controllers/Articulo.php".

    None si la ruta no tiene la forma modulo/controlador o trae algo raro.
    """
    if not ruta_valida(ruta):
        return None
    ruta = ruta.strip().lstrip("/")
    segmentos = [s for s in ruta.split("?")[0].split("/") if s]
    if len(segmentos) < 2:
        return None
    modulo, ctrl = segmentos[0], segmentos[1]
    if not re.match(r"^[A-Za-z0-9_\-]+$", ctrl):
        return None
    return f"{modulo}/controllers/{ctrl[:1].upper()}{ctrl[1:]}.php"


def controladores(ruta: str | None) -> list[str]:
    """Los controladores que pueden implementar la ruta, en minusculas.

    "traz-comp-almacenes/Articulo" puede ser el controlador Articulo del modulo
    traz-comp-almacenes; "Empresa/editar" o "Dash", un controlador de la raiz de
    Tools. Se prueban las dos lecturas: el catalogo dice cual existe.
    """
    if not ruta_valida(ruta):
        return []
    segmentos = [s for s in ruta.strip().lstrip("/").split("?")[0].split("/") if s]
    if not segmentos or not all(re.match(r"^[A-Za-z0-9_\-]+$", s) for s in segmentos[:2]):
        return []
    candidatos = []
    modulo = controlador(ruta)
    if modulo:
        candidatos.append(modulo)
    raiz = segmentos[0]
    candidatos.append(f"traz-tools/application/controllers/{raiz[:1].upper()}{raiz[1:]}.php")
    return [c.lower() for c in candidatos]


async def casos_de(con: psycopg.AsyncConnection, ruta: str | None) -> list[CasoDePantalla]:
    """Los casos de uso validados de la pantalla, del conocimiento del producto."""
    claves = controladores(ruta)
    if not claves:
        return []
    async with con.cursor() as cur:
        await cur.execute(
            """
            SELECT c.metadata->>'caso_uso' AS caso_uso, c.contenido,
                   c.metadata->>'ayuda' AS ayuda
            FROM agente.chunk c
            JOIN agente.fuente f USING (fuente_id)
            WHERE f.tipo = 'caso_uso' AND c.vigente
              AND EXISTS (
                  SELECT 1 FROM jsonb_array_elements_text(c.metadata->'controladores') x
                  WHERE lower(x) = ANY(%s))
            ORDER BY c.metadata->>'caso_uso'
            LIMIT %s
            """,
            (claves, MAX_CASOS),
        )
        return [CasoDePantalla(f["caso_uso"], f["contenido"], f["ayuda"]) for f in await cur.fetchall()]


def contexto(ruta: str, casos: list[CasoDePantalla]) -> str:
    """El mensaje de sistema que le cuenta al modelo donde esta el usuario."""
    if not casos:
        # Sin esto el modelo describia botones y menus que no existen ("un icono
        # de engranaje", "Personalizar") con total seguridad: lo vio el PM en el
        # Tablero de inicio, que no tiene caso de uso (2026-11-25).
        return (f"El usuario está en la pantalla '{ruta}' de Tools. No tenés registrado qué se "
                "hace en esa pantalla: si te pregunta por ella, decilo y ofrecé lo que sí sabés. "
                "No describas botones, menús, íconos, pestañas ni pasos de esa pantalla: no los "
                "conocés y el usuario los va a buscar. Si sirve, sugerile mirar la ayuda del sistema "
                "o preguntarle al administrador de su empresa.")
    partes = [f"El usuario está en la pantalla '{ruta}' de Tools. Esto es lo que se hace ahí "
              "(si te pregunta qué hacer, explicalo con esto y proponé el siguiente paso; "
              "si corresponde, citá la ayuda):"]
    for c in casos:
        partes.append(c.contenido + (f"\n(ayuda: {c.ayuda})" if c.ayuda else ""))
    return "\n\n".join(partes)
