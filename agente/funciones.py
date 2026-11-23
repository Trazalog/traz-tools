"""Funciones de Tools que la empresa no usa, recomendadas por Kuntur (AGENTE-CO-08).

Cuando el administrador abre el panel de Kuntur, Kuntur revisa con las tools de
lectura que partes de Tools tiene vacias su empresa y le recomienda hasta tres:
"tenes 12 equipos y ningun plan preventivo", "ninguna meta cargada"...

Igual que el siguiente paso de Quirqui (agente/sugerencias.py), lo deciden
REGLAS sobre lo que devuelven las tools, no el modelo:

  * no gasta tokens y es inmediato;
  * cada cifra sale de contar lo que devolvio una tool, asi que la regla de
    cifras con fuente (R4) se cumple por construccion;
  * Kuntur dice como, no hace (ADR-A8): la recomendacion trae el "como" y el
    link de la ayuda.

Reglas de prudencia:

  * si una tool falla, NO se recomienda lo que dependia de ella (sin evidencia
    no hay recomendacion: "no pude leer" no es "no lo usas");
  * si la empresa ya declaro en la entrevista de Kuntur que modulos usa, solo se
    recomienda dentro de esos modulos (no se insiste con Herramientas a quien
    dijo que no las lleva en Tools). Las metas se recomiendan siempre: son de
    Kuntur;
  * un "no me interesa" vale para toda la empresa por unos dias
    (AGENTE_FUNCIONES_SILENCIO_DIAS, 30 por defecto): la funcion es de la
    empresa, no de un administrador.

Lo que se cuenta es lo que devuelve cada tool tal cual. Las tools de
movimientos pueden traer solo un periodo reciente; por eso el texto dice "no
aparece ningun movimiento", no "nunca hubo".
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

TIPO = "funcion_sin_usar"

AYUDA_ALMACENES = "ayuda/manual_almacenes.html"
AYUDA_HERRAMIENTAS = "ayuda/manual_herramientas.html"
AYUDA_PREVENTIVO = "ayuda/manual_mantenimeinto_preventivo.html"
AYUDA_CONFIGURACION = "ayuda/manual_configuracion_inicial.html"


def filas(data) -> list[dict]:
    """Las filas de una respuesta del gateway, sin importar los nombres.

    El MI envuelve las listas en dos niveles con nombres propios de cada
    servicio ({"materias": {"materia": [...]}}, {"herramientas": {...}}), y
    cuando hay una sola fila la devuelve como objeto suelto en vez de lista.
    Se baja hasta tres niveles por el primer valor que sea lista u objeto.
    Una respuesta que no tiene esa forma (por ejemplo {"ok": true}) cuenta 0.
    """
    x = data
    for nivel in range(4):
        if isinstance(x, list):
            return [e for e in x if isinstance(e, dict)]
        if not isinstance(x, dict) or not x:
            return []
        hijos = [v for v in x.values() if isinstance(v, (dict, list))]
        if not hijos:
            return [x] if nivel >= 2 else []
        x = hijos[0]
    return []


def _numero(v) -> float | None:
    try:
        return float(str(v).replace(",", "."))
    except (TypeError, ValueError):
        return None


@dataclass
class Candidata:
    """Misma forma que sugerencias.Candidata, para guardarla igual."""
    clave: str
    tipo: str
    titulo: str
    detalle: str
    accion: dict = field(default_factory=dict)
    prioridad: int = 9


@dataclass(frozen=True)
class Funcion:
    clave: str
    modulo: str | None          # modulo de la entrevista de Kuntur; None = siempre
    tools: tuple[str, ...]      # todas tienen que haber respondido
    prioridad: int              # menor = se muestra antes
    regla: Callable[[dict], tuple[str, str] | None]   # -> (titulo, detalle) o None
    porque: str
    como: str
    ayuda: str | None


# ------------------------------------------------------------------ reglas
def _metas(d):
    if filas(d["kpi_get_objetivos"]):
        return None
    return ("Ponerle metas a tus indicadores",
            "Tu empresa no tiene ninguna meta cargada.")


def _preventivos(d):
    equipos, planes = len(filas(d["man_get_equipos"])), len(filas(d["man_get_preventivos"]))
    if equipos == 0 or planes > 0:
        return None
    return ("Armar planes de mantenimiento preventivo",
            f"Tenés {equipos} equipos cargados y ningún plan preventivo.")


def _punto_pedido(d):
    articulos = filas(d["alm_get_stock"])
    if not articulos or any((_numero(a.get("punto_pedido")) or 0) > 0 for a in articulos):
        return None
    return ("Usar el punto de pedido para reponer a tiempo",
            f"Tenés {len(articulos)} artículos en stock y ninguno tiene punto de pedido.")


def _certificaciones(d):
    herramientas = len(filas(d["pan_get_herramientas"]))
    if herramientas == 0 or filas(d["pan_get_certificaciones"]):
        return None
    return ("Registrar las certificaciones de las herramientas",
            f"Tenés {herramientas} herramientas cargadas y ninguna certificación registrada.")


def _movimientos(d):
    articulos = len(filas(d["alm_get_stock"]))
    if articulos == 0 or filas(d["alm_get_movimientos"]):
        return None
    return ("Registrar las entradas y salidas de stock",
            f"Tenés {articulos} artículos en stock y no aparece ningún movimiento registrado.")


def _depositos(d):
    if filas(d["alm_get_depositos"]):
        return None
    return ("Cargar tus depósitos", "Tu empresa no tiene ningún depósito cargado.")


def _panol(d):
    if filas(d["pan_get_herramientas"]):
        return None
    return ("Llevar el pañol de herramientas en Tools", "No hay ninguna herramienta cargada.")


CATALOGO: tuple[Funcion, ...] = (
    Funcion("metas", None, ("kpi_get_objetivos",), 0, _metas,
            "Con una meta, Kuntur te avisa cuando un indicador se aleja antes de que sea un problema.",
            "Pedime \"armemos una meta\" y la definimos juntos.", None),
    Funcion("preventivos", "mantenimiento", ("man_get_equipos", "man_get_preventivos"), 1, _preventivos,
            "El preventivo baja las paradas imprevistas, que son las que más cuestan.",
            "Cargá un plan por equipo con su frecuencia en Mantenimiento > Preventivos.", AYUDA_PREVENTIVO),
    Funcion("punto_pedido", "almacenes", ("alm_get_stock",), 2, _punto_pedido,
            "Con punto de pedido, Tools te avisa antes de quedarte sin un repuesto crítico.",
            "Editá el artículo en Almacenes y completá el punto de pedido.", AYUDA_ALMACENES),
    Funcion("certificaciones", "herramientas", ("pan_get_herramientas", "pan_get_certificaciones"), 3,
            _certificaciones,
            "Una herramienta con la certificación vencida puede frenar un trabajo en una auditoría.",
            "Cargá la certificación y su vencimiento en la ficha de cada herramienta.", AYUDA_HERRAMIENTAS),
    Funcion("movimientos", "almacenes", ("alm_get_stock", "alm_get_movimientos"), 4, _movimientos,
            "Sin movimientos, el stock del sistema se desactualiza y deja de servir para decidir.",
            "Registrá las entregas y los ingresos desde Almacenes.", AYUDA_ALMACENES),
    Funcion("depositos", "almacenes", ("alm_get_depositos",), 5, _depositos,
            "Los depósitos son la base del stock: sin ellos no se puede cargar ni mover nada.",
            "Pedime \"cargá un depósito\" o hacelo desde la configuración inicial.", AYUDA_CONFIGURACION),
    Funcion("panol", "herramientas", ("pan_get_herramientas",), 6, _panol,
            "Saber quién tiene cada herramienta evita pérdidas y búsquedas.",
            "Cargá tus herramientas en Pañol, de a una o con la carga masiva.", AYUDA_HERRAMIENTAS),
)


def tools_necesarias(modulos: list[str] | None = None) -> list[str]:
    """Las tools a consultar, sin repetir, para los modulos de la empresa."""
    salida: list[str] = []
    for f in _aplicables(modulos):
        for t in f.tools:
            if t not in salida:
                salida.append(t)
    return salida


def _aplicables(modulos: list[str] | None):
    elegidos = set(modulos or [])
    return [f for f in CATALOGO if f.modulo is None or not elegidos or f.modulo in elegidos]


def candidatas(datos: dict, modulos: list[str] | None = None) -> list[Candidata]:
    """Las funciones sin usar, mas importante primero.

    `datos` tiene la respuesta de cada tool que SI respondio. Una funcion cuya
    tool no esta en `datos` (fallo o no esta permitida) no se evalua.
    """
    salida = []
    for f in _aplicables(modulos):
        if any(t not in datos for t in f.tools):
            continue
        r = f.regla(datos)
        if not r:
            continue
        titulo, detalle = r
        salida.append(Candidata(
            clave=f"funcion:{f.clave}", tipo=TIPO, titulo=titulo, detalle=detalle,
            accion={"texto": f.como, "porque": f.porque, "ayuda": f.ayuda, "funcion": f.clave},
            prioridad=f.prioridad,
        ))
    salida.sort(key=lambda c: c.prioridad)
    return salida
