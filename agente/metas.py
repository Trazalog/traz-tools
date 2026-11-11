"""Metas de indicadores para Kuntur (AGENTE-CO-03 y CO-07).

Dos cosas, las dos sin escribir nada en Tools (ADR-A8):

  * La tool kpi_proponer_meta. Kuntur charla con el administrador y, cuando
    llegan a una meta, la PROPONE con esta tool. No la graba: el motor la
    valida y la devuelve en la respuesta, y el panel la muestra como una
    tarjeta con el boton "Cargar meta". La graba el administrador, con su
    sesion, en Objetivos/guardar (la misma validacion que la tarjeta Metas).

  * evaluar() y seguir(): que metas vigentes hoy no se cumplen y cuales, aunque
    hoy se cumplan, a este ritmo no llegan a la fecha (en riesgo). Las de fuente 'tools' ya
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

# Tendencia (AGENTE-CO-07): con la historia de los ultimos DIAS_TENDENCIA dias
# y al menos MIN_PUNTOS valores, se proyecta en linea recta hasta la fecha de
# la meta. Si hoy se cumple pero la proyeccion no, la meta esta "en riesgo".
DIAS_TENDENCIA = 30
MIN_PUNTOS = 7

# Los estados de una meta, del mejor al peor.
OK, EN_RIESGO, NO_CUMPLE = "ok", "en_riesgo", "no_cumple"

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
    # ok | en_riesgo | no_cumple. evaluar() solo devuelve los no_cumple;
    # seguir() devuelve todas las metas con su estado.
    estado: str = NO_CUMPLE


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


def serie_historico(data) -> list[tuple[date, Decimal]]:
    """Los puntos de kpi_get_historico ({"historico":{"punto":[{fecha, valor}]}}), en orden."""
    puntos = []
    for f in _filas(data, "historico", "punto"):
        v = _decimal(f.get("valor"))
        try:
            d = date.fromisoformat(str(f.get("fecha") or "")[:10])
        except ValueError:
            continue
        if v is not None:
            puntos.append((d, v))
    return sorted(puntos)


def periodo_tendencia(hoy: date) -> dict:
    """Los argumentos de kpi_get_historico para la tendencia (sin el nombre)."""
    return {"desde": (hoy - timedelta(days=DIAS_TENDENCIA)).isoformat(), "hasta": hoy.isoformat()}


def pendiente(serie: list[tuple[date, Decimal]]) -> Decimal | None:
    """Cuanto cambia por dia, por minimos cuadrados. None si no alcanzan los puntos."""
    if len(serie) < MIN_PUNTOS:
        return None
    x0 = serie[0][0]
    xs = [Decimal((d - x0).days) for d, _ in serie]
    ys = [v for _, v in serie]
    n = Decimal(len(serie))
    mx, my = sum(xs) / n, sum(ys) / n
    den = sum((x - mx) ** 2 for x in xs)
    if den == 0:
        return None
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / den


def estado_meta(operador: str, valor: Decimal, meta: Decimal, hasta: str, hoy: date,
                serie: list[tuple[date, Decimal]] | None = None) -> str:
    """ok, en_riesgo (hoy se cumple pero a este ritmo no llega) o no_cumple."""
    if not cumple(operador, valor, meta):
        return NO_CUMPLE
    try:
        dias = (date.fromisoformat(hasta) - hoy).days if hasta else 0
    except ValueError:
        dias = 0
    p = pendiente(serie or [])
    if p is None or dias <= 0:
        return OK
    proyectado = valor + p * Decimal(dias)
    return OK if cumple(operador, proyectado, meta) else EN_RIESGO


def seguir(filas: list[dict], *, hoy: date, valores_man: dict[str, Decimal | None],
           series: dict[str, list[tuple[date, Decimal]]] | None = None) -> list[Desvio]:
    """Todas las metas vigentes con valor, cada una con su estado (ok, en riesgo, no se cumple).

    series: la historia de cada indicador (kpi -> puntos), para la tendencia.
    Sin historia, una meta que hoy se cumple queda ok: no se adivina.
    """
    series = series or {}
    salida = []
    for d in _vigentes(filas, hoy=hoy, valores_man=valores_man):
        d.estado = estado_meta(d.operador, d.valor, d.meta, d.hasta, hoy, series.get(d.kpi))
        salida.append(d)
    return salida


def evaluar(filas: list[dict], *, hoy: date, valores_man: dict[str, Decimal | None]) -> list[Desvio]:
    """Las metas vigentes que hoy no se cumplen.

    filas: lo que devolvio kpi_get_objetivos (solo vigentes).
    valores_man: el valor de hoy de cada indicador de Mantenimiento.
    Una meta sin valor no es un desvio: no hay con que compararla.
    """
    return [d for d in _vigentes(filas, hoy=hoy, valores_man=valores_man)
            if not cumple(d.operador, d.valor, d.meta)]


def _vigentes(filas: list[dict], *, hoy: date, valores_man: dict[str, Decimal | None]) -> list[Desvio]:
    """Las metas vigentes con meta, valor y operador validos."""
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
