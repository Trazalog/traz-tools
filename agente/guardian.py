"""Guardian de cifras (R4, AGENTE-M-04).

Toda cifra que diga un agente tiene que tener origen. Si la respuesta trae un
numero que no aparece en nada de lo que el modelo leyo en esa corrida, la
respuesta se bloquea: el usuario recibe "no tengo datos para responder eso" y
la corrida queda con un incidente para revisar.

El problema que resuelve: un modelo de lenguaje inventa numeros con la misma
soltura con la que redacta. "Tenes 7 ordenes vencidas" suena igual de seguro
sea 7 o no.

QUE CUENTA COMO ORIGEN (en orden de peso):

  1. Lo que devolvieron las tools en la corrida -- exactamente el texto que se
     le paso al modelo (agente.tool_llamada.contenido).
  2. El contexto de conocimiento y memoria que vio el modelo.
  3. La pregunta del usuario: repetir un numero que dijo el mismo no es
     inventarlo.
  4. Lo que vino de la web (tool web_buscar), SOLO si la respuesta cita una de
     las URLs que devolvio la busqueda.

Ademas, un numero vale si es la CANTIDAD de elementos de una lista que
devolvio una tool: "tenes 3 equipos" cuando la tool devolvio tres. Contar no
es inventar.

QUE NO SE CONTROLA (para no bloquear de mas):

  * Fechas y horas (2026-10-27, 27/10/2026, 14:30).
  * Codigos de letras seguidas de numeros (COMP-001, OT-1234). Un codigo es un
    identificador, no una cifra.
  * Marcadores de lista al principio de una linea ("1.", "2)", "Paso 3:").
  * Numeros chicos de discurso: "en 3 pasos", "2 opciones". La lista de
    palabras es configurable (PALABRAS_DE_DISCURSO).

Una norma como "ISO 55000" SI se controla: inventar una referencia normativa
es tan grave como inventar un torque (prompts/quirqui.md, "Cuando no sabes").

Las decisiones de criterio de este modulo estan en
doc/agente/decisiones-para-revisar.md (D-15 a D-19).
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation

# Tool cuyo contenido solo vale como fuente si la respuesta cita su URL.
TOOL_WEB = "web_buscar"

# Numeros chicos que se usan para ordenar el discurso, no como dato.
# Configurable: si aparece un falso positivo recurrente en los incidentes,
# se agrega la palabra aca.
PALABRAS_DE_DISCURSO = frozenset({
    "paso", "pasos", "opcion", "opciones", "opción", "cosa", "cosas", "punto",
    "puntos", "alternativa", "alternativas", "pregunta", "preguntas", "forma",
    "formas", "manera", "maneras", "motivo", "motivos", "razon", "razones",
    "razón", "consejo", "consejos", "recomendacion", "recomendaciones",
    "recomendación", "ejemplo", "ejemplos", "fuente", "fuentes", "herramienta",
    "herramientas", "caso", "casos", "etapa", "etapas",
})
MAX_DISCURSO = 10

MENSAJE_BLOQUEO = (
    "No tengo datos para responder eso con certeza. Puedo consultar los datos de "
    "tu empresa o buscar una fuente si me decís qué necesitás exactamente."
)

_FECHA = re.compile(
    r"\b\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2})?)?\b"   # 2026-10-27, con hora
    r"|\b\d{1,2}/\d{1,2}/\d{2,4}\b"                          # 27/10/2026
    r"|\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:hs?\b|horas?\b)?"     # 14:30, 14:30 hs
)
# Codigo: letras seguidas de digitos, pegados o con guion (COMP-001, OT1234,
# H-086). "ISO 55000" NO es codigo (hay un espacio): el 55000 se controla.
_CODIGO = re.compile(r"\b[A-Za-z]+[-_]?\d[\w-]*")
_MARCADOR_LISTA = re.compile(r"(?m)^\s*(?:[-*]\s*)?(?:paso\s+)?\d{1,2}\s*[.)\-:]\s", re.IGNORECASE)
_URL = re.compile(r"https?://[^\s)\]\"'<>]+")
# Un numero: 1.500 / 1,5 / 72 / 0.72 / 12.345,67, con % opcional. Sin signo: en
# "10-20" el guion es un rango, no un menos. Puede ir pegado a una unidad
# ("250hs"): la unidad no lo salva de tener que tener origen.
_NUMERO = re.compile(r"(?<![\w.,])\d+(?:[.,]\d+)*(?:\s?%)?(?!\d)")


@dataclass
class Veredicto:
    cifras: list[str] = field(default_factory=list)       # las controladas
    sin_fuente: list[str] = field(default_factory=list)   # las que no tienen origen
    web_sin_cita: list[str] = field(default_factory=list) # solo en la web, sin URL citada

    @property
    def bloquear(self) -> bool:
        return bool(self.sin_fuente or self.web_sin_cita)

    def control(self) -> dict:
        return {"control": "R4_cifras", "cifras": len(self.cifras),
                "sin_fuente": len(self.sin_fuente) + len(self.web_sin_cita)}

    def incidente(self, respuesta_original: str) -> dict:
        return {"tipo": "cifra_sin_fuente", "cifras": self.sin_fuente,
                "web_sin_cita": self.web_sin_cita,
                "respuesta_bloqueada": respuesta_original}


# ---------------------------------------------------------------- numeros
def _interpretaciones(token: str) -> set[Decimal]:
    """Los valores que puede significar un numero escrito.

    "1.500" puede ser mil quinientos (estilo argentino) o uno coma cinco
    (estilo ingles); "1,5" es uno coma cinco. Se aceptan las dos lecturas: el
    guardian busca si el numero tiene origen, no corrige su formato.
    """
    t = token.replace(" ", "").rstrip("%")
    candidatos = {t}
    if "," in t and "." in t:
        # El ultimo separador es el decimal.
        if t.rfind(",") > t.rfind("."):
            candidatos = {t.replace(".", "").replace(",", ".")}
        else:
            candidatos = {t.replace(",", "")}
    elif "," in t:
        candidatos = {t.replace(",", "."), t.replace(",", "")}
    elif t.count(".") > 1:
        candidatos = {t.replace(".", "")}
    elif "." in t:
        candidatos = {t, t.replace(".", "")}
    valores = set()
    for c in candidatos:
        try:
            valores.add(Decimal(c))
        except InvalidOperation:
            continue
    return valores


def _decimales(token: str) -> int:
    m = re.search(r"[.,](\d+)\s?%?$", token)
    return len(m.group(1)) if m else 0


def _numeros_en(texto: str) -> set[Decimal]:
    valores: set[Decimal] = set()
    for m in _NUMERO.finditer(texto):
        valores |= _interpretaciones(m.group(0))
    return valores


def _largos_de_listas(texto: str) -> set[Decimal]:
    """Cantidad de elementos de cada lista de un JSON (para aceptar conteos)."""
    try:
        data = json.loads(texto)
    except (json.JSONDecodeError, ValueError, TypeError):
        return set()
    largos: set[Decimal] = set()

    def recorrer(x):
        if isinstance(x, list):
            largos.add(Decimal(len(x)))
            for e in x:
                recorrer(e)
        elif isinstance(x, dict):
            for v in x.values():
                recorrer(v)

    recorrer(data)
    return largos


def _tiene_origen(token: str, fuentes: set[Decimal]) -> bool:
    """Si alguna lectura del numero coincide con una fuente.

    Admite redondeo a los decimales que se escribieron (72 contra 71,83) y,
    si es un porcentaje, la fuente expresada como fraccion (72 % contra 0,72).
    """
    es_porcentaje = token.rstrip().endswith("%")
    dec = _decimales(token)
    cuanto = Decimal(1).scaleb(-dec)
    for valor in _interpretaciones(token):
        for f in fuentes:
            candidatos = [f]
            if es_porcentaje and abs(f) <= 1:
                candidatos.append(f * 100)
            for c in candidatos:
                if c == valor:
                    return True
                try:
                    if c.quantize(cuanto) == valor.quantize(cuanto):
                        return True
                except InvalidOperation:
                    continue
    return False


def _sin_lo_que_no_se_controla(texto: str) -> str:
    texto = _URL.sub(" ", texto)
    texto = _FECHA.sub(" ", texto)
    texto = _MARCADOR_LISTA.sub(" ", texto)
    texto = _CODIGO.sub(" ", texto)
    return texto


def _es_de_discurso(texto: str, m: re.Match) -> bool:
    try:
        n = Decimal(m.group(0).rstrip("%").replace(",", "."))
    except InvalidOperation:
        return False
    if n != n.to_integral_value() or not (0 <= n <= MAX_DISCURSO) or "%" in m.group(0):
        return False
    siguiente = re.match(r"\s+([A-Za-zÁÉÍÓÚáéíóúñÑ]+)", texto[m.end():])
    return bool(siguiente and siguiente.group(1).lower() in PALABRAS_DE_DISCURSO)


# --------------------------------------------------------------- veredicto
def revisar(respuesta: str, *, tools: list[tuple[str, str]], contexto: str = "",
            pregunta: str = "") -> Veredicto:
    """Revisa las cifras de una respuesta contra lo que leyo el modelo.

    tools: [(nombre_de_tool, contenido_que_vio_el_modelo), ...]
    """
    fuentes = _numeros_en(contexto) | _numeros_en(pregunta)
    web_textos: list[str] = []
    for nombre, contenido in tools:
        if not contenido:
            continue
        if nombre == TOOL_WEB:
            web_textos.append(contenido)
            continue
        fuentes |= _numeros_en(contenido) | _largos_de_listas(contenido)

    fuentes_web: set[Decimal] = set()
    urls_web: set[str] = set()
    for w in web_textos:
        fuentes_web |= _numeros_en(w)
        urls_web |= {u.rstrip(".,;") for u in _URL.findall(w)}
    urls_citadas = {u.rstrip(".,;") for u in _URL.findall(respuesta)}
    cita_web = bool(urls_web & urls_citadas)

    v = Veredicto()
    limpio = _sin_lo_que_no_se_controla(respuesta)
    for m in _NUMERO.finditer(limpio):
        token = m.group(0).strip()
        if _es_de_discurso(limpio, m):
            continue
        v.cifras.append(token)
        if _tiene_origen(token, fuentes):
            continue
        if _tiene_origen(token, fuentes_web):
            if not cita_web:
                v.web_sin_cita.append(token)
            continue
        v.sin_fuente.append(token)
    return v
