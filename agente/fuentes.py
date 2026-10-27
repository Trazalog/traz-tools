"""Lectores de las fuentes de conocimiento del producto (AGENTE-M-06).

Dos fuentes que no son "un documento para trocear", sino material con
estructura propia que conviene conservar:

  * Las AYUDAS de Tools (ayuda/*.html, el sitio que ve el usuario). Se parten
    por seccion (<section id="s03">), asi cada fragmento lleva su link exacto
    y el agente puede decir "esta en ayuda/manual_almacenes.html#s03".

  * El CATALOGO DE CASOS DE USO de DocTest (doctest/catalogo/**/*.yaml). Un
    fragmento por caso, sin partir: pantalla, perfil, pasos y validaciones
    juntos. En la metadata van las pantallas y los controladores que lo
    implementan: es lo que va a usar el Asistente para saber que se hace en
    la pantalla donde esta parado el usuario (AGENTE-AS-01), por ruta exacta y
    no solo por parecido.

Solo se ingestan los casos 'validado': un borrador tiene dudas abiertas por
definicion, y un obsoleto describe algo que ya no es asi.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path

import yaml

# El sitio de ayudas se sirve en ayuda/ (constante URL_AYUDA de Tools).
PREFIJO_AYUDA = "ayuda/"

# Modulo de DocTest -> area del conocimiento (CHECK de agente.chunk.modulo).
_MODULOS = {"MAN": "man", "ALM": "alm"}


@dataclass
class Pieza:
    """Un fragmento listo para vectorizar, con de donde salio."""

    texto: str
    modulo: str = "general"
    metadata: dict = field(default_factory=dict)


# ================================================================== ayudas
class _LectorAyuda(HTMLParser):
    """Junta el texto de cada <section id=...>, sin scripts, estilos ni nav."""

    _IGNORAR = {"script", "style", "nav", "button", "svg"}
    _BLOQUE = {"p", "li", "h1", "h2", "h3", "h4", "tr", "br", "div", "section"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.secciones: list[dict] = []
        self._actual: dict | None = None
        self._ignorando = 0
        self._en_titulo = False
        self.titulo_doc = ""
        self._en_title = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in self._IGNORAR:
            self._ignorando += 1
            return
        if tag == "title":
            self._en_title = True
        if tag == "section" and attrs.get("id") and attrs["id"] != "cover":
            self._actual = {"id": attrs["id"], "titulo": "", "texto": []}
            self.secciones.append(self._actual)
        if tag in ("h1", "h2") and self._actual is not None and not self._actual["titulo"]:
            self._en_titulo = True
        if tag in self._BLOQUE and self._actual is not None:
            self._actual["texto"].append("\n")

    def handle_endtag(self, tag):
        if tag in self._IGNORAR and self._ignorando:
            self._ignorando -= 1
        if tag in ("h1", "h2"):
            self._en_titulo = False
        if tag == "title":
            self._en_title = False

    def handle_data(self, data):
        if self._ignorando:
            return
        if self._en_title:
            self.titulo_doc += data.strip()
        if self._actual is None:
            return
        if self._en_titulo:
            self._actual["titulo"] += data.strip() + " "
        self._actual["texto"].append(data)


def _limpiar(texto: str) -> str:
    texto = re.sub(r"[ \t\r\f\v]+", " ", texto)
    texto = re.sub(r"\n\s*\n+", "\n\n", texto)
    return "\n".join(l.strip() for l in texto.splitlines()).strip()


def leer_ayuda(path: Path) -> list[Pieza]:
    lector = _LectorAyuda()
    lector.feed(path.read_text(encoding="utf-8", errors="replace"))
    piezas = []
    for s in lector.secciones:
        texto = _limpiar("".join(s["texto"]))
        if len(texto) < 40:
            continue
        titulo = re.sub(r"\s+", " ", s["titulo"]).strip()
        link = f"{PREFIJO_AYUDA}{path.name}#{s['id']}"
        encabezado = f"Ayuda de Trazalog — {lector.titulo_doc or path.stem}"
        if titulo:
            encabezado += f" — {titulo}"
        piezas.append(Pieza(
            texto=f"{encabezado}\n\n{texto}",
            modulo=_modulo_de_ayuda(path.name),
            metadata={"ayuda": link, "titulo": titulo, "documento": path.name},
        ))
    return piezas


def _modulo_de_ayuda(nombre: str) -> str:
    n = nombre.lower()
    if "almacen" in n and "mantenimiento" not in n:
        return "alm"
    if "mantenim" in n or "equipos" in n:
        return "man"
    return "general"


# ========================================================== casos de uso
def leer_caso_uso(path: Path) -> Pieza | None:
    """Un caso de uso validado del catalogo, como un fragmento entero.

    Devuelve None si no es un caso de uso (por ejemplo el schema) o si no esta
    validado.
    """
    try:
        uc = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        return None
    if not isinstance(uc, dict) or "id" not in uc or "flujo_principal" not in uc:
        return None
    if uc.get("estado") != "validado":
        return None

    pantallas = [str(p) for p in uc.get("pantallas") or []]
    lineas = [f"Caso de uso {uc['id']} — {uc.get('titulo', '')}"]
    if pantallas:
        lineas.append("Pantalla: " + "; ".join(pantallas))
    if uc.get("perfil"):
        lineas.append(f"Quién lo hace: {uc['perfil']}")
    if uc.get("precondiciones"):
        lineas.append("Antes de empezar: " + "; ".join(map(str, uc["precondiciones"])))
    lineas.append("Pasos:")
    for n, paso in enumerate(uc.get("flujo_principal") or [], start=1):
        if isinstance(paso, dict):
            lineas.append(f"{n}. {paso.get('paso', '')} → {paso.get('resultado', '')}")
    for alt in uc.get("flujos_alternativos") or []:
        if isinstance(alt, dict) and alt.get("nombre"):
            lineas.append(f"Si {alt['nombre'][0].lower()}{alt['nombre'][1:]}:")
            for paso in alt.get("pasos") or []:
                if isinstance(paso, dict):
                    lineas.append(f"  - {paso.get('paso', '')} → {paso.get('resultado', '')}")
    if uc.get("validaciones"):
        lineas.append("Reglas: " + "; ".join(map(str, uc["validaciones"])))

    ayuda = (uc.get("derivados") or {}).get("ayuda")
    metadata = {
        "caso_uso": uc["id"],
        "pantallas": pantallas,
        "perfil": uc.get("perfil"),
        # repo/path de los controladores: la clave para ubicar la pantalla
        # desde la ruta de Tools (AGENTE-AS-01).
        "controladores": [
            f"{r.get('repo', '')}/{r.get('path', '')}"
            for r in uc.get("referencias_codigo") or []
            if isinstance(r, dict) and "controllers/" in str(r.get("path", ""))
        ],
        "documento": path.name,
    }
    if ayuda:
        # El catalogo apunta al fuente (ayudas/src/alm/x.html#s03); el usuario
        # ve el sitio armado en ayuda/x.html#s03.
        archivo, _, ancla = str(ayuda).partition("#")
        metadata["ayuda"] = f"{PREFIJO_AYUDA}{Path(archivo).name}" + (f"#{ancla}" if ancla else "")

    return Pieza(
        texto="\n".join(lineas),
        modulo=_MODULOS.get(str(uc.get("modulo", "")).upper(), "general"),
        metadata=metadata,
    )


def es_caso_uso(path: Path) -> bool:
    return path.suffix.lower() in (".yaml", ".yml") and re.match(r"^[A-Z]+-UC-\d+", path.name) is not None
