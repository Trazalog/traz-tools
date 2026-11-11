"""Metas de indicadores para Kuntur (AGENTE-CO-03 y CO-07).

Dos cosas, las dos sin escribir nada en Tools (ADR-A8):

  * La tool kpi_proponer_meta. Kuntur charla con el administrador y, cuando
    llegan a una meta, la PROPONE con esta tool. No la graba: el motor la
    valida y la devuelve en la respuesta, y el panel la muestra como una
    tarjeta con el boton "Cargar meta". La graba el administrador, con su
    sesion, en Objetivos/guardar (la misma validacion que la tarjeta Metas).

  * evaluar(): que metas vigentes hoy no se cumplen. Las de fuente 'tools' ya
    vienen evaluadas por kpi_get_objetivos; la de Mantenimiento (fuente
    'man') la evalua este modulo con man_get_kpi_disponibilidad, porque el
    valor vive en AssetPlanner (analisis de impacto aprobado, seccion 7). Lo
    usa el trabajo programado de Kuntur (agente/coach.py).

Los indicadores sobre los que se puede fijar una meta son los del Tablero
(application/config/dashboard.php). INDICADORES repite esa lista: un test
(tests/test_metas.py) falla si dejan de coincidir.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation

NOMBRE = "kpi_proponer_meta"

# nombre -> (titulo, fuente). Igual que config/dashboard.php (dashboard_kpis):
# los de fuente 'tools' por kpi_nombre, el de Mantenimiento por id.
INDICADORES: dict[str, tuple[str, str]] = {
    "alm_reorder": ("Artículos bajo punto de pedido", "tools"),
    "alm_mov_sin_entregar": ("Movimientos internos sin entregar", "tools"),
    "her_transito": ("Herramientas en tránsito vs total", "tools"),
    "man_disponibilidad": ("Disponibilidad de equipos", "man"),
}

# Ventana con la que se mide la disponibilidad para compararla con su meta.
DIAS_DISPONIBILIDAD = 30

DEFINICION = {
    "type": "function",
    "function": {
        "name": NOMBRE,
        "description": (
            "Propone al administrador una meta sobre un indicador. NO la guarda: el "
            "administrador la ve como una tarjeta y decide si la carga. Usala solo cuando "
            "ya acordaron en la charla el indicador, el valor y la fecha. Una meta por "
            "indicador: si ya hay una vigente (kpi_get_objetivos), decilo antes de proponer otra."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "kpi": {"type": "string", "enum": sorted(INDICADORES),
                        "description": "El indicador."},
                "operador": {"type": "string", "enum": [">=", "<="],
                             "description": "'>=' si tiene que quedar igual o por encima; '<=' si por debajo."},
                "meta": {"type": "number", "description": "El valor a alcanzar."},
                "hasta": {"type": "string", "description": "Fecha límite, YYYY-MM-DD, hoy o más adelante."},
                "responsable": {"type": "string", "description": "Quién se ocupa (opcional)."},
                "motivo": {"type": "string",
                           "description": "Por qué esta meta, en una o dos frases, con los datos que la justifican."},
            },
            "required": ["kpi", "operador", "meta", "hasta", "motivo"],
        },
    },
}

_FECHA = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class PropuestaInvalida(ValueError):
    """La propuesta no se puede mostrar: el modelo la armo mal."""


def proponer(argumentos: dict, *, hoy: date | None = None) -> dict:
    """Valida lo que pidio el modelo y devuelve la propuesta lista para la tarjeta.

    Las mismas reglas que Objetivos::guardar(), para que una tarjeta que se
    muestra se pueda cargar. Si no cumple, PropuestaInvalida con un texto que
    vuelve al modelo para que la corrija.
    """
    hoy = hoy or date.today()
    kpi = str(argumentos.get("kpi") or "")
    if kpi not in INDICADORES:
        raise PropuestaInvalida(f"El indicador '{kpi}' no admite metas. Opciones: {', '.join(sorted(INDICADORES))}.")
    operador = str(argumentos.get("operador") or "")
    if operador not in (">=", "<="):
        raise PropuestaInvalida("El operador tiene que ser '>=' o '<='.")
    try:
        meta = Decimal(str(argumentos.get("meta")).replace(",", "."))
    except (InvalidOperation, ValueError):
        raise PropuestaInvalida("La meta tiene que ser un número.") from None
    if not meta.is_finite():
        raise PropuestaInvalida("La meta tiene que ser un número.")
    hasta = str(argumentos.get("hasta") or "")
    try:
        if not _FECHA.match(hasta) or date.fromisoformat(hasta) < hoy:
            raise ValueError
    except ValueError:
        raise PropuestaInvalida(f"La fecha límite tiene que ser YYYY-MM-DD, desde {hoy.isoformat()}.") from None
    responsable = str(argumentos.get("responsable") or "").strip()[:255]
    motivo = str(argumentos.get("motivo") or "").strip()[:500]
    if not motivo:
        raise PropuestaInvalida("Falta el motivo: por qué esta meta.")
    titulo, fuente = INDICADORES[kpi]
    return {
        "kpi": kpi, "titulo": titulo, "fuente": fuente, "operador": operador,
        "meta": format(meta.normalize(), "f"), "hasta": hasta,
        "responsable": responsable, "motivo": motivo,
    }


# --------------------------------------------------------------- evaluacion
@dataclass
class Desvio:
    objetivo_id: int
    kpi: str
    titulo: str
    operador: str
    meta: Decimal
    valor: Decimal
    hasta: str
    usuario_alta: str
    responsable: str = ""


def _decimal(v) -> Decimal | None:
    if v is None or v == "":
        return None
    try:
        d = Decimal(str(v))
    except (InvalidOperation, ValueError):
        return None
    return d if d.is_finite() else None


def _filas(data, *camino) -> list[dict]:
    """El DataService envuelve las filas ({"objetivos":{"objetivo":[...]}}) y,
    con una sola, a veces devuelve el objeto en lugar de la lista."""
    for clave in camino:
        if not isinstance(data, dict):
            return []
        data = data.get(clave)
    if isinstance(data, dict):
        return [data]
    return [f for f in data or [] if isinstance(f, dict)]


def cumple(operador: str, valor: Decimal, meta: Decimal) -> bool:
    return valor >= meta if operador == ">=" else valor <= meta


def objetivos(data) -> list[dict]:
    """Las metas de kpi_get_objetivos."""
    return _filas(data, "objetivos", "objetivo")


def periodo_disponibilidad(hoy: date) -> dict:
    """Los argumentos de man_get_kpi_disponibilidad para la ventana de la meta."""
    return {"fec_inicio": (hoy - timedelta(days=DIAS_DISPONIBILIDAD)).isoformat(),
            "fec_fin": hoy.isoformat()}


def valor_disponibilidad(data) -> Decimal | None:
    """El valor de man_get_kpi_disponibilidad ({"respuesta":{"disponibilidad":"99.74"}})."""
    if isinstance(data, dict):
        data = data.get("respuesta", data)
    return _decimal(data.get("disponibilidad")) if isinstance(data, dict) else None


def evaluar(filas: list[dict], *, hoy: date, valores_man: dict[str, Decimal | None]) -> list[Desvio]:
    """Las metas vigentes que hoy no se cumplen.

    filas: lo que devolvio kpi_get_objetivos (solo vigentes).
    valores_man: el valor de hoy de cada indicador de Mantenimiento.
    Una meta sin valor no es un desvio: no hay con que compararla.
    """
    desvios = []
    for f in filas:
        if f.get("estado") not in (None, "", "vigente"):
            continue
        hasta = str(f.get("hasta") or "")
        if hasta and hasta < hoy.isoformat():
            continue
        kpi = str(f.get("kpi") or "")
        meta = _decimal(f.get("meta"))
        valor = valores_man.get(kpi) if f.get("fuente") == "man" else _decimal(f.get("valor_actual"))
        operador = str(f.get("operador") or "")
        if meta is None or valor is None or operador not in (">=", "<="):
            continue
        if cumple(operador, valor, meta):
            continue
        try:
            objetivo_id = int(f.get("objetivo_id"))
        except (TypeError, ValueError):
            continue
        desvios.append(Desvio(
            objetivo_id=objetivo_id, kpi=kpi,
            titulo=INDICADORES.get(kpi, (f.get("descripcion") or kpi, ""))[0],
            operador=operador, meta=meta, valor=valor, hasta=hasta,
            usuario_alta=str(f.get("usuario_alta") or ""), responsable=str(f.get("responsable") or ""),
        ))
    return desvios
