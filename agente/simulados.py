"""Servicios simulados para la puesta en marcha con Kuntur (ADR-A12, deuda tecnica).

Decision del PM (2026-11-11): mientras no existan los servicios reales, Kuntur
trabaja contra simulaciones con la MISMA interfaz:

  * Mantenimiento: los ABM de configuracion (sector, area, proceso,
    criticidad, grupo, marca) y el equipo, con los parametros de
    MANDataService de develop-v3 ("ya esta probado, no va a cambiar mucho").
    Los equipos van en la tabla de MariaDB (AssetPlanner); la de PostgreSQL
    (core.equipos) esta deprecada.
  * Dnato v3 (en diseno): funcionalidades por empresa, menu por rol, rol por
    usuario y administradores de la empresa (traz-tools/doc/v3/dnato,
    RF-50 a 53, CU-31, CU-38, CU-40; los cinco roles fijos de D-09).

Lo que "graban" queda en agente.simulacion, con aislamiento por empresa. La
tarjeta de Kuntur avisa que es una simulacion. DEUDA TECNICA: cuando existan
los servicios reales, se saca la entrada de SERVICIOS, se publica la tool en
el gateway con el mismo nombre y argumentos, y nada mas cambia: el motor y el
panel no distinguen.

Las de clase 'configuracion' pasan por la carga propuesta (agente/cargas.py):
se ejecutan solo con "Cargar". Las de 'lectura' las responde el motor.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field

import psycopg

LECTURA, CONFIGURACION = "lectura", "configuracion"

# Dnato v3: los cinco roles base de cada empresa (D-09: no se crean roles nuevos).
ROLES = ("Administrador", "Solicitante", "Supervisor", "Planificador", "Mantenedor")

# Dnato v3: funcionalidades y opciones de menu. SUPUESTO PROPIO para la
# simulacion: el catalogo real (seg.menues) es de Dnato y no esta disenado
# todavia por modulo. Plan Freemium = MAN, ALM, PAN (D-15 de Dnato).
FUNCIONALIDADES = {
    "ALM": ("Almacenes", ("alm.articulos", "alm.depositos", "alm.stock", "alm.pedidos", "alm.entregas")),
    "MAN": ("Mantenimiento", ("man.equipos", "man.ordenes", "man.preventivos", "man.solicitudes",
                              "man.configuracion")),
    "PAN": ("Herramientas", ("pan.herramientas", "pan.movimientos", "pan.certificaciones")),
    "TAR": ("Tareas", ("tar.pedidos", "tar.planificacion", "tar.bandeja")),
}
PLAN_FREEMIUM = ("ALM", "MAN", "PAN")
OPCIONES = {o for _, ops in FUNCIONALIDADES.values() for o in ops}


class SimulacionInvalida(ValueError):
    """Los argumentos no respetan la interfaz del servicio real."""


def _texto(descripcion: str, maximo: int | None = None) -> dict:
    d = {"type": "string", "description": descripcion}
    if maximo:
        d["maxLength"] = maximo
    return d


@dataclass(frozen=True)
class Servicio:
    nombre: str
    modulo: str                 # 'man' | 'dnato'
    clase: str                  # lectura | configuracion
    descripcion: str
    contrato: str               # el servicio real que simula
    propiedades: dict = field(default_factory=dict)
    requeridos: tuple[str, ...] = ()
    entidad: str = ""           # donde se guarda en la simulacion

    def definicion(self) -> dict:
        return {"type": "function", "function": {
            "name": self.nombre,
            "description": self.descripcion + " (SIMULADO: todavía no graba en el sistema real.)",
            "parameters": {"type": "object", "properties": self.propiedades,
                           "required": list(self.requeridos)}}}


def _abm_man(entidad: str, titulo: str, recurso: str, query: str, campo: str = "descripcion",
             maximo: int = 50) -> Servicio:
    return Servicio(
        nombre=f"man_alta_{entidad}", modulo="man", clase=CONFIGURACION,
        descripcion=f"Da de alta {titulo} de Mantenimiento.",
        contrato=f"MANDataService POST {recurso} ({query}), develop-v3",
        propiedades={campo: _texto(f"Nombre de {titulo}", maximo)},
        requeridos=(campo,), entidad=f"man.{entidad}")


SERVICIOS: dict[str, Servicio] = {s.nombre: s for s in (
    # --- Mantenimiento (MariaDB de AssetPlanner), interfaz de develop-v3 -----
    _abm_man("sector", "un sector", "/equipos/sector", "setSectorEqMan"),
    _abm_man("area", "un área", "/area", "setAreaMan", maximo=None),
    _abm_man("proceso", "un proceso", "/proceso", "setProcesoMan", maximo=None),
    _abm_man("criticidad", "una criticidad", "/equipos/criticidad", "setCriticidadEqMan"),
    _abm_man("grupo", "un grupo de equipos", "/equipos/grupo", "setGrupoEqMan"),
    _abm_man("marca", "una marca de equipos", "/equipos/marca", "setMarcaEqMan",
             campo="marcadescrip", maximo=255),
    Servicio(
        nombre="man_alta_equipo", modulo="man", clase=CONFIGURACION,
        descripcion="Da de alta un equipo en Mantenimiento. Los id de sector, grupo, criticidad, área y "
                    "proceso salen de man_get_configuracion.",
        contrato="MANDataService POST /equipo (setEquipoMan), develop-v3",
        propiedades={
            "descripcion": _texto("Descripción del equipo"), "codigo": _texto("Código interno"),
            "marca": _texto("Marca"), "numero_serie": _texto("Número de serie"),
            "descrip_tecnica": _texto("Descripción técnica"),
            "fecha_ingreso": _texto("Fecha de ingreso, YYYY-MM-DD"),
            "fecha_garantia": _texto("Fin de la garantía, YYYY-MM-DD"),
            "id_sector": {"type": "integer"}, "id_grupo": {"type": "integer"},
            "id_criticidad": {"type": "integer"}, "id_area": {"type": "integer"},
            "id_proceso": {"type": "integer"},
        },
        requeridos=("descripcion", "codigo"), entidad="man.equipo"),
    Servicio(
        nombre="man_get_configuracion", modulo="man", clase=LECTURA,
        descripcion="Lo que ya está cargado en la configuración de Mantenimiento: sectores, áreas, "
                    "procesos, criticidades, grupos, marcas y equipos, con su id.",
        contrato="MANDataService GET de cada ABM, develop-v3", entidad="man."),
    # --- Dnato v3 (en diseño) -------------------------------------------------
    Servicio(
        nombre="dnato_get_funcionalidades", modulo="dnato", clase=LECTURA,
        descripcion="Funcionalidades del plan de la empresa, cuáles están activas, y qué opciones del "
                    "menú ve cada uno de los cinco roles.",
        contrato="Dnato v3: Funcionalidades (RF-50 a 53) y Roles y accesos (CU-40)", entidad="dnato."),
    Servicio(
        nombre="dnato_activar_funcionalidad", modulo="dnato", clase=CONFIGURACION,
        descripcion="Activa o desactiva una funcionalidad del plan de la empresa.",
        contrato="Dnato v3: Funcionalidades (CU-31)",
        propiedades={"funcionalidad": {"type": "string", "enum": sorted(FUNCIONALIDADES)},
                     "activa": {"type": "boolean"}},
        requeridos=("funcionalidad", "activa"), entidad="dnato.funcionalidad"),
    Servicio(
        nombre="dnato_asignar_menu_rol", modulo="dnato", clase=CONFIGURACION,
        descripcion="Define qué opciones del menú ve un rol. El rol Administrador no se edita.",
        contrato="Dnato v3: seg.memberships_menues (CU-40, RF-77)",
        propiedades={"rol": {"type": "string", "enum": list(ROLES[1:])},
                     "opciones": {"type": "array", "items": {"type": "string", "enum": sorted(OPCIONES)}}},
        requeridos=("rol", "opciones"), entidad="dnato.menu_rol"),
    Servicio(
        nombre="dnato_asignar_rol_usuario", modulo="dnato", clase=CONFIGURACION,
        descripcion="Le da a un usuario de la empresa uno de los cinco roles.",
        contrato="Dnato v3: cambiar el rol de un miembro (CU-38, RF-75)",
        propiedades={"usuario": _texto("Usuario (correo o nick)", 255),
                     "rol": {"type": "string", "enum": list(ROLES)}},
        requeridos=("usuario", "rol"), entidad="dnato.rol_usuario"),
    Servicio(
        nombre="dnato_get_administradores", modulo="dnato", clase=LECTURA,
        descripcion="Los administradores de la empresa.",
        contrato="No existe en el diseño de Dnato v3: se le pide a ese frente", entidad="dnato.rol_usuario"),
)}


def definiciones(permitidas: frozenset[str]) -> list[dict]:
    """Las que el motor le ofrece al modelo: las simuladas que el agente puede usar."""
    return [s.definicion() for n, s in sorted(SERVICIOS.items()) if n in permitidas]


def validar(nombre: str, argumentos: dict) -> dict:
    """Respeta la interfaz del servicio real: campos conocidos, requeridos, tipos y opciones."""
    s = SERVICIOS.get(nombre)
    if s is None:
        raise SimulacionInvalida(f"{nombre} no es un servicio simulado")
    if not isinstance(argumentos, dict):
        raise SimulacionInvalida("Los argumentos tienen que ser un objeto")
    limpio = {}
    for campo, valor in argumentos.items():
        regla = s.propiedades.get(campo)
        if regla is None:
            raise SimulacionInvalida(f"{nombre} no tiene el campo '{campo}'")
        tipo = regla.get("type")
        if tipo == "string":
            if not isinstance(valor, str) or not valor.strip():
                raise SimulacionInvalida(f"'{campo}' tiene que ser un texto")
            valor = valor.strip()[: regla.get("maxLength") or 1000]
            if "enum" in regla and valor not in regla["enum"]:
                raise SimulacionInvalida(f"'{valor}' no es una opción de '{campo}'")
        elif tipo == "integer":
            if isinstance(valor, bool) or not isinstance(valor, int):
                raise SimulacionInvalida(f"'{campo}' tiene que ser un número entero")
        elif tipo == "boolean":
            if not isinstance(valor, bool):
                raise SimulacionInvalida(f"'{campo}' tiene que ser verdadero o falso")
        elif tipo == "array":
            if not isinstance(valor, list) or any(v not in regla["items"]["enum"] for v in valor):
                raise SimulacionInvalida(f"'{campo}' tiene opciones que no existen")
            valor = sorted(set(valor))
        limpio[campo] = valor
    faltan = [c for c in s.requeridos if c not in limpio]
    if faltan:
        raise SimulacionInvalida(f"Faltan datos: {', '.join(faltan)}")
    return limpio


# ------------------------------------------------------------------ la base
async def _filas(con: psycopg.AsyncConnection, empr_id: int, prefijo: str) -> list[dict]:
    async with con.cursor() as cur:
        await cur.execute("SELECT sim_id, entidad, datos FROM agente.simulacion "
                          "WHERE empr_id = %s AND entidad LIKE %s ORDER BY sim_id",
                          (empr_id, prefijo.replace("_", "\\_") + "%"))
        return [dict(f) for f in await cur.fetchall()]


async def _referencias_validas(con, empr_id: int, datos: dict) -> None:
    """Un equipo solo puede apuntar a sector, grupo... de SU empresa (en la simulacion)."""
    for campo in ("id_sector", "id_grupo", "id_criticidad", "id_area", "id_proceso"):
        if campo in datos:
            entidad = "man." + campo[3:]
            async with con.cursor() as cur:
                await cur.execute("SELECT 1 FROM agente.simulacion WHERE empr_id = %s AND sim_id = %s "
                                  "AND entidad = %s", (empr_id, datos[campo], entidad))
                if await cur.fetchone() is None:
                    raise SimulacionInvalida(f"No existe {campo}={datos[campo]} en esta empresa")


async def ejecutar(con: psycopg.AsyncConnection, empr_id: int, nombre: str, argumentos: dict) -> dict:
    """Una de configuracion, ya confirmada por el administrador. Necesita el RLS fijado."""
    s = SERVICIOS[nombre]
    if s.clase != CONFIGURACION:
        raise SimulacionInvalida(f"{nombre} no graba")
    datos = validar(nombre, argumentos)
    if nombre == "dnato_activar_funcionalidad" and datos["activa"] and datos["funcionalidad"] not in PLAN_FREEMIUM:
        raise SimulacionInvalida(f"{datos['funcionalidad']} no está en el plan de la empresa")
    if nombre == "man_alta_equipo":
        await _referencias_validas(con, empr_id, datos)
    clave = None
    if s.entidad == "dnato.menu_rol":
        clave = datos["rol"]
    elif s.entidad == "dnato.rol_usuario":
        clave = datos["usuario"].lower()
    elif s.entidad == "dnato.funcionalidad":
        clave = datos["funcionalidad"]
    async with con.cursor() as cur:
        if clave is not None:
            # Las de Dnato reemplazan (un rol por usuario, un menu por rol...).
            await cur.execute("DELETE FROM agente.simulacion WHERE empr_id = %s AND entidad = %s "
                              "AND clave = %s", (empr_id, s.entidad, clave))
        await cur.execute(
            "INSERT INTO agente.simulacion (empr_id, servicio, entidad, clave, datos) "
            "VALUES (%s, %s, %s, %s, %s::jsonb) RETURNING sim_id",
            (empr_id, nombre, s.entidad, clave, json.dumps(datos, ensure_ascii=False)))
        sim_id = (await cur.fetchone())["sim_id"]
    return {"respuesta": {"id": sim_id}, "simulado": True}


async def leer(con: psycopg.AsyncConnection, empr_id: int, nombre: str) -> dict:
    """Las de lectura. Necesita el RLS fijado."""
    if nombre == "man_get_configuracion":
        salida: dict[str, list] = {}
        for f in await _filas(con, empr_id, "man."):
            salida.setdefault(f["entidad"][4:], []).append({"id": f["sim_id"], **f["datos"]})
        return {"configuracion": salida, "simulado": True}
    filas = await _filas(con, empr_id, "dnato.")
    roles = {f["datos"]["usuario"]: f["datos"]["rol"] for f in filas if f["entidad"] == "dnato.rol_usuario"}
    if nombre == "dnato_get_administradores":
        return {"administradores": sorted(u for u, r in roles.items() if r == "Administrador"), "simulado": True}
    if nombre == "dnato_get_funcionalidades":
        estado = {f["datos"]["funcionalidad"]: f["datos"]["activa"]
                  for f in filas if f["entidad"] == "dnato.funcionalidad"}
        menus = {f["datos"]["rol"]: f["datos"]["opciones"] for f in filas if f["entidad"] == "dnato.menu_rol"}
        return {"simulado": True, "funcionalidades": [
            {"clave": k, "nombre": n, "en_el_plan": k in PLAN_FREEMIUM,
             "activa": estado.get(k, k in PLAN_FREEMIUM), "opciones": list(ops)}
            for k, (n, ops) in FUNCIONALIDADES.items()],
            "menu_por_rol": {r: ("todas" if r == "Administrador" else menus.get(r, [])) for r in ROLES},
            "roles_por_usuario": roles}
    raise SimulacionInvalida(f"{nombre} no es de lectura")
