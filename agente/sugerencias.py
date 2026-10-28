"""El siguiente paso que propone Quirqui sin que se lo pidan (AGENTE-AS-02).

Cuando el usuario abre el panel en una pantalla, Quirqui mira los datos de la
empresa que tienen que ver con esa pantalla y propone hasta tres cosas para
hacer: un articulo bajo el punto de pedido, un lote vencido o por vencer, una
certificacion de herramienta que vence.

Se arma con REGLAS sobre lo que devuelven las tools, no con el modelo:

  * es inmediato y no gasta tokens (se dispara cada vez que se abre el panel);
  * cada cifra viene directo de una tool, asi que R4 se cumple por
    construccion;
  * los agentes dicen como, no hacen (ADR-A8): la propuesta trae el "como" y
    el link de la ayuda, no ejecuta nada.

Los umbrales son valores por defecto configurables (variables
AGENTE_SUGERENCIA_*), marcados asi a proposito: el PM no los definio.

Limitacion de esta version: ninguna tool dice hoy que tarea es de cada
usuario, asi que las propuestas son sobre el estado de la empresa en esa
pantalla. Cuando existan las tools del modulo de tareas (tar_get_tareas, ver
TAR-API), se suma "tus tareas atrasadas".
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime

# Pantalla (primer segmento de la ruta de Tools) -> que se revisa ahi.
REGLAS_POR_MODULO = {
    "traz-comp-almacenes": ("alm_get_vencimientos", "alm_get_stock"),
    "traz-comp-pan": ("pan_get_certificaciones",),
}

# Orden en que se muestran: lo mas urgente primero.
_PRIORIDAD = {"lote_vencido": 0, "lote_critico": 1, "stock_bajo": 2, "certificacion_por_vencer": 3}

AYUDA_ALMACENES = "ayuda/manual_almacenes.html"
AYUDA_HERRAMIENTAS = "ayuda/manual_herramientas.html"


@dataclass
class Candidata:
    clave: str
    tipo: str
    titulo: str
    detalle: str
    accion: dict = field(default_factory=dict)

    @property
    def prioridad(self) -> int:
        return _PRIORIDAD.get(self.tipo, 9)


def modulo_de(pantalla: str | None) -> str | None:
    if not pantalla:
        return None
    return pantalla.strip().lstrip("/").split("/")[0] or None


def _lista(data, *camino) -> list[dict]:
    """Saca la lista de un JSON del gateway: {"materias": {"materia": [...]}}.

    Tolera que el nivel intermedio venga como objeto suelto en vez de lista
    (pasa cuando hay un solo elemento, por la conversion XML -> JSON del MI).
    """
    x = data
    for clave in camino:
        if not isinstance(x, dict):
            return []
        x = x.get(clave)
    if isinstance(x, dict):
        return [x]
    return [e for e in (x or []) if isinstance(e, dict)]


def _numero(v) -> float | None:
    try:
        return float(str(v).replace(",", "."))
    except (TypeError, ValueError):
        return None


# =================================================================== reglas
def stock_bajo(data) -> list[Candidata]:
    """Articulos activos con stock por debajo de su punto de pedido."""
    salida = []
    for a in _lista(data, "materias", "materia"):
        stock, punto = _numero(a.get("stock")), _numero(a.get("punto_pedido"))
        if stock is None or not punto or punto <= 0 or stock >= punto:
            continue
        if str(a.get("estado", "AC")).upper() not in ("AC", ""):
            continue
        nombre = a.get("titulo") or a.get("descripcion") or f"artículo {a.get('id')}"
        unidad = a.get("unidad_medida") or ""
        salida.append(Candidata(
            clave=f"stock_bajo:{a.get('id')}", tipo="stock_bajo",
            titulo=f"Reponer {nombre}",
            detalle=(f"Quedan {a.get('stock')} {unidad}".strip()
                     + f" y el punto de pedido es {a.get('punto_pedido')}."),
            accion={"texto": "Generá un pedido de materiales para reponerlo antes de que frene un trabajo.",
                    "ayuda": AYUDA_ALMACENES},
        ))
    return salida


def lotes(data) -> list[Candidata]:
    """Lotes vencidos o en estado critico (el gateway lo calcula: <10 dias)."""
    salida = []
    for l in _lista(data, "vencimientos", "lote"):
        estado = str(l.get("estado_vencimiento", "")).lower()
        if estado not in ("vencido", "critico", "crítico"):
            continue
        vencido = estado == "vencido"
        articulo = l.get("articulo") or f"artículo {l.get('arti_id')}"
        lote = l.get("lote") or l.get("lote_id")
        donde = f" en {l.get('deposito')}" if l.get("deposito") else ""
        cuando = (f"venció el {l.get('fec_vencimiento')}" if vencido
                  else f"vence el {l.get('fec_vencimiento')}")
        salida.append(Candidata(
            clave=f"lote:{l.get('lote_id')}", tipo="lote_vencido" if vencido else "lote_critico",
            titulo=f"{'Lote vencido' if vencido else 'Lote por vencer'}: {articulo}",
            detalle=f"El lote {lote}{donde} {cuando} ({l.get('cantidad')} {l.get('unidad_medida') or ''}).".replace(" )", ")"),
            accion={"texto": ("Separalo para que no se entregue y registrá la baja."
                              if vencido else "Priorizá su uso o su entrega antes de que venza."),
                    "ayuda": AYUDA_ALMACENES},
        ))
    return salida


def certificaciones(data, *, hoy: date, dias: int) -> list[Candidata]:
    """Certificaciones de herramientas vencidas o que vencen en `dias` o menos."""
    salida = []
    for c in _lista(data, "certificaciones", "certificacion"):
        try:
            vence = datetime.strptime(str(c.get("fec_vencimiento"))[:10], "%Y-%m-%d").date()
        except ValueError:
            continue
        faltan = (vence - hoy).days
        if faltan > dias:
            continue
        herr = c.get("herr_codigo") or c.get("herr_descripcion") or f"herramienta {c.get('herr_id')}"
        salida.append(Candidata(
            clave=f"certificacion:{c.get('cert_id')}", tipo="certificacion_por_vencer",
            titulo=f"Renovar la certificación de {herr}",
            detalle=(f"La certificación venció el {vence.isoformat()}." if faltan < 0
                     else f"La certificación vence el {vence.isoformat()}."),
            accion={"texto": "Coordiná la recertificación y, mientras tanto, no la entregues para trabajos que la exigen.",
                    "ayuda": AYUDA_HERRAMIENTAS},
        ))
    return salida


def candidatas(tool: str, data, *, hoy: date, dias_certificacion: int) -> list[Candidata]:
    if tool == "alm_get_stock":
        return stock_bajo(data)
    if tool == "alm_get_vencimientos":
        return lotes(data)
    if tool == "pan_get_certificaciones":
        return certificaciones(data, hoy=hoy, dias=dias_certificacion)
    return []
