"""La planilla del cliente, pasada a la Carga Masiva (ADR-A12, lote 2).

El administrador sube su planilla como la tiene. Kuntur no la reescribe:

  1. El codigo la lee (CSV o Excel .xlsx, sin dependencias nuevas) y la guarda
     en agente.planilla.
  2. Al modelo le llegan SOLO los encabezados y unas 20 filas (P-8 del PM) y
     las plantillas de la Carga Masiva. El modelo dice que columna del cliente
     va en cada columna de la plantilla, y que valor fijo usar si falta alguna.
  3. El codigo transforma TODAS las filas con ese mapeo. El modelo no toca los
     datos, asi que no puede inventarlos. Lo que falta o esta mal se informa
     con el numero de fila y no se propone nada.
  4. La carga propuesta guarda las filas ya transformadas; la tarjeta muestra
     10 y el total. Con "Cargar" se ejecuta, todo o nada. HOY SIMULADA (ver
     "la carga" abajo): Dnato se reemplaza por Dnato v3.

Las plantillas copian lo que espera la Carga Masiva en DEV (2026-11-11):
PostgreSQL toma las columnas POR POSICION (COPY ... WITH CSV HEADER), asi que
el orden importa; MariaDB las toma POR NOMBRE de la tabla intermedia.
"""
from __future__ import annotations

import csv
import io
import json
import re
import uuid
import zipfile
from dataclasses import dataclass
from xml.etree import ElementTree as ET

import psycopg


NOMBRE = "kuntur_carga_masiva"
MAX_BYTES = 5 * 1024 * 1024
MAX_FILAS = 5000          # el mismo limite que la entrada de Dnato
MAX_COLUMNAS = 80
FILAS_PARA_EL_MODELO = 20


class PlanillaInvalida(ValueError):
    """No se puede leer la planilla, o el mapeo no alcanza para cargarla."""


class CargaFallida(RuntimeError):
    """La Carga Masiva corrio y no grabo nada (todo o nada)."""


@dataclass(frozen=True)
class Plantilla:
    entidad: str                 # nombre en sta.entidades_negocio
    para_que: str
    columnas: tuple[str, ...]    # en el orden del archivo
    requeridas: tuple[str, ...]
    enteras: tuple[str, ...] = ()
    nota: str = ""


PLANTILLAS: dict[str, Plantilla] = {p.entidad: p for p in (
    Plantilla("Articulos", "Artículos de Almacenes",
              ("codigo", "descripcion", "unidad_medida", "tipo", "punto_pedido"),
              ("codigo", "descripcion", "unidad_medida", "tipo"), ("punto_pedido",),
              "La unidad de medida y el tipo tienen que existir en las listas de la empresa. "
              "Un código que ya está cargado hace fallar toda la carga."),
    Plantilla("Herramientas", "Herramientas de Pañol",
              ("codigo", "marca", "modelo", "tipo", "descripcion", "panol"),
              ("codigo", "descripcion", "marca", "panol"), (),
              "La marca y el pañol tienen que existir: se buscan por su código."),
    Plantilla("Mantenimiento Equipos", "Equipos de Mantenimiento",
              ("codigo", "descripcion", "marca", "numero_serie", "sector", "area", "proceso", "grupo",
               "criticidad", "estado", "descrip_tecnica", "fecha_ingreso", "fecha_garantia",
               "fecha_ultimalectura", "ultima_lectura", "meta_disponibilidad"),
              ("codigo", "descripcion", "marca", "sector", "area", "proceso", "grupo", "criticidad",
               "estado"), (),
              "Sector, área, proceso, grupo, criticidad y marca tienen que existir en Mantenimiento."),
    Plantilla("Mantenimiento Articulos", "Artículos de Mantenimiento",
              ("codigo", "u_medida", "descripcion"), ("codigo", "u_medida", "descripcion")),
)}


# ============================================================== lectura
def leer(nombre: str, contenido: bytes) -> tuple[list[str], list[list[str]]]:
    """Encabezados y filas, como texto. La primera fila no vacia es el encabezado."""
    if not contenido:
        raise PlanillaInvalida("El archivo está vacío")
    if len(contenido) > MAX_BYTES:
        raise PlanillaInvalida(f"El archivo pasa de {MAX_BYTES // (1024 * 1024)} MB")
    ext = nombre.lower().rsplit(".", 1)[-1] if "." in nombre else ""
    if ext == "xlsx" or contenido[:2] == b"PK":
        filas = _leer_xlsx(contenido)
    elif ext in ("csv", "txt", ""):
        filas = _leer_csv(contenido)
    elif ext == "xls":
        raise PlanillaInvalida("El formato .xls (Excel 97-2003) no se puede leer: guardala como .xlsx o .csv")
    else:
        raise PlanillaInvalida("Solo se leen planillas .xlsx o .csv")
    filas = [[c.strip() for c in f] for f in filas]
    filas = [f for f in filas if any(f)]
    if len(filas) < 2:
        raise PlanillaInvalida("La planilla no tiene filas de datos, solo encabezado o nada")
    encabezados = filas[0]
    while encabezados and not encabezados[-1]:
        encabezados.pop()
    if not encabezados:
        raise PlanillaInvalida("La primera fila tiene que tener los nombres de las columnas")
    if len(encabezados) > MAX_COLUMNAS:
        raise PlanillaInvalida(f"Más de {MAX_COLUMNAS} columnas")
    vistos: set[str] = set()
    for i, e in enumerate(encabezados):
        e = e or f"Columna {i + 1}"
        while e in vistos:
            e += " (2)"
        encabezados[i] = e
        vistos.add(e)
    datos = [(f + [""] * len(encabezados))[:len(encabezados)] for f in filas[1:]]
    if len(datos) > MAX_FILAS:
        raise PlanillaInvalida(f"Más de {MAX_FILAS} filas: para una migración grande, usá la pantalla de Carga Masiva")
    return encabezados, datos


def _leer_csv(contenido: bytes) -> list[list[str]]:
    for cod in ("utf-8-sig", "cp1252"):
        try:
            texto = contenido.decode(cod)
            break
        except UnicodeDecodeError:
            continue
    primera = texto.splitlines()[0] if texto else ""
    delim = max((";", ",", "\t"), key=primera.count)
    return list(csv.reader(io.StringIO(texto), delimiter=delim))


_NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
_REL = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"


def _leer_xlsx(contenido: bytes) -> list[list[str]]:
    """La primera hoja de un .xlsx, con lo que trae Python (zip + XML)."""
    try:
        z = zipfile.ZipFile(io.BytesIO(contenido))
        nombres = set(z.namelist())
        if sum(i.file_size for i in z.infolist()) > 20 * MAX_BYTES:
            raise PlanillaInvalida("El Excel descomprimido es demasiado grande")
        compartidos = []
        if "xl/sharedStrings.xml" in nombres:
            for si in ET.fromstring(z.read("xl/sharedStrings.xml")).iter(_NS + "si"):
                compartidos.append("".join(t.text or "" for t in si.iter(_NS + "t")))
        hoja = _primera_hoja(z, nombres)
        filas: list[list[str]] = []
        for fila in ET.fromstring(z.read(hoja)).iter(_NS + "row"):
            valores: dict[int, str] = {}
            for c in fila.iter(_NS + "c"):
                col = _columna(c.get("r", "")) if c.get("r") else len(valores)
                t, v = c.get("t"), c.find(_NS + "v")
                if t == "s" and v is not None:
                    valores[col] = compartidos[int(v.text)]
                elif t == "inlineStr":
                    valores[col] = "".join(x.text or "" for x in c.iter(_NS + "t"))
                else:
                    valores[col] = _numero(v.text) if v is not None and v.text else ""
            if valores:
                filas.append([valores.get(i, "") for i in range(max(valores) + 1)])
        return filas
    except PlanillaInvalida:
        raise
    except (zipfile.BadZipFile, KeyError, ET.ParseError, IndexError, ValueError):
        raise PlanillaInvalida("No pude leer el Excel: guardalo de nuevo como .xlsx o como .csv") from None


def _primera_hoja(z: zipfile.ZipFile, nombres: set[str]) -> str:
    """La hoja que Excel muestra primero, no la de nombre mas chico."""
    try:
        libro = ET.fromstring(z.read("xl/workbook.xml"))
        rid = next(libro.iter(_NS + "sheet")).get(_REL + "id")
        rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
        for r in rels:
            if r.get("Id") == rid:
                destino = r.get("Target", "").lstrip("/")
                return destino if destino.startswith("xl/") else "xl/" + destino
    except (KeyError, StopIteration, ET.ParseError):
        pass
    hojas = sorted(n for n in nombres if re.fullmatch(r"xl/worksheets/sheet\d+\.xml", n))
    if not hojas:
        raise PlanillaInvalida("El Excel no tiene hojas")
    return hojas[0]


def _columna(ref: str) -> int:
    n = 0
    for ch in re.match(r"[A-Z]+", ref).group(0):
        n = n * 26 + ord(ch) - 64
    return n - 1


def _numero(texto: str) -> str:
    """Excel guarda 10 como '10' y a veces como '10.0': un codigo no lleva decimales."""
    if re.fullmatch(r"-?\d+\.0+", texto):
        return texto.split(".")[0]
    return texto


# ============================================================ la base
@dataclass
class Planilla:
    planilla_id: str
    nombre: str
    encabezados: list[str]
    filas: list[list[str]]

    @property
    def total(self) -> int:
        return len(self.filas)

    def resumen(self) -> dict:
        return {"planilla_id": self.planilla_id, "nombre": self.nombre,
                "encabezados": self.encabezados, "total_filas": self.total}


async def guardar(con: psycopg.AsyncConnection, *, empr_id: int, usuario: str, nombre: str,
                  contenido: bytes) -> Planilla:
    encabezados, filas = leer(nombre, contenido)
    p = Planilla(str(uuid.uuid4()), nombre[:200], encabezados, filas)
    async with con.cursor() as cur:
        await cur.execute(
            "INSERT INTO agente.planilla (planilla_id, empr_id, usuario, nombre, encabezados, filas, total_filas) "
            "VALUES (%s, %s, %s, %s, %s::jsonb, %s::jsonb, %s)",
            (p.planilla_id, empr_id, usuario, p.nombre, json.dumps(encabezados, ensure_ascii=False),
             json.dumps(filas, ensure_ascii=False), p.total))
    return p


async def obtener(con: psycopg.AsyncConnection, planilla_id: str) -> Planilla:
    """Con la empresa fijada (RLS): una planilla de otra empresa no existe."""
    try:
        uuid.UUID(str(planilla_id))
    except ValueError:
        raise PlanillaInvalida("No existe esa planilla") from None
    async with con.cursor() as cur:
        await cur.execute("SELECT planilla_id, nombre, encabezados, filas FROM agente.planilla "
                          "WHERE planilla_id = %s", (planilla_id,))
        f = await cur.fetchone()
    if not f:
        raise PlanillaInvalida("No existe esa planilla")
    return Planilla(str(f["planilla_id"]), f["nombre"], f["encabezados"], f["filas"])


# ===================================================== para el modelo
def contexto(p: Planilla) -> str:
    """Encabezados y unas 20 filas (P-8), y las plantillas. Nada mas de la planilla."""
    muestra = [dict(zip(p.encabezados, f)) for f in p.filas[:FILAS_PARA_EL_MODELO]]
    plantillas = "\n".join(
        f"- «{t.entidad}» ({t.para_que}): columnas {', '.join(t.columnas)}; obligatorias "
        f"{', '.join(t.requeridas)}." + (f" {t.nota}" if t.nota else "")
        for t in PLANTILLAS.values())
    return (
        f"El administrador subió la planilla «{p.nombre}» (planilla_id {p.planilla_id}), con "
        f"{p.total} filas. Estos son sus encabezados y las primeras {len(muestra)} filas; el resto "
        "no lo ves y no hace falta:\n"
        f"Encabezados: {json.dumps(p.encabezados, ensure_ascii=False)}\n"
        f"Filas: {json.dumps(muestra, ensure_ascii=False)}\n\n"
        "Plantillas de la Carga Masiva:\n" + plantillas + "\n\n"
        f"Para cargarla, usá {NOMBRE}: elegí la plantilla, decí qué encabezado de la planilla va en "
        "cada columna (mapeo) y, si a la planilla le falta una columna obligatoria que tiene el mismo "
        "valor para todas las filas, poné ese valor en valores_fijos. No copies ni corrijas datos: "
        "la transformación la hace el sistema con todas las filas."
    )


DEFINICION = {
    "type": "function",
    "function": {
        "name": NOMBRE,
        "description": (
            "Propone la carga masiva de la planilla que subió el administrador, pasada a una "
            "plantilla de la Carga Masiva. NO graba: se le muestra una tarjeta con una muestra y "
            "el total, y se carga solo si el administrador toca «Cargar». Es todo o nada."),
        "parameters": {
            "type": "object",
            "properties": {
                "planilla_id": {"type": "string", "description": "El planilla_id que se te informó."},
                "entidad": {"type": "string", "enum": list(PLANTILLAS)},
                "mapeo": {"type": "object", "additionalProperties": {"type": "string"},
                          "description": "Columna de la plantilla -> encabezado de la planilla."},
                "valores_fijos": {"type": "object", "additionalProperties": {"type": "string"},
                                  "description": "Columna de la plantilla -> valor para todas las filas."},
            },
            "required": ["planilla_id", "entidad", "mapeo"],
        },
    },
}


# ===================================================== transformacion
def transformar(p: Planilla, entidad: str, mapeo: dict, fijos: dict | None = None) -> list[dict]:
    """TODAS las filas en la plantilla, o PlanillaInvalida con lo que falta."""
    t = PLANTILLAS.get(entidad)
    if not t:
        raise PlanillaInvalida(f"No hay plantilla «{entidad}». Las que hay: {', '.join(PLANTILLAS)}")
    if not isinstance(mapeo, dict) or not all(isinstance(v, str) for v in mapeo.values()):
        raise PlanillaInvalida("mapeo tiene que ser columna de la plantilla -> encabezado de la planilla")
    fijos = fijos or {}
    if not isinstance(fijos, dict):
        raise PlanillaInvalida("valores_fijos tiene que ser columna -> valor")
    ajenas = sorted((set(mapeo) | set(fijos)) - set(t.columnas))
    if ajenas:
        raise PlanillaInvalida(f"La plantilla «{entidad}» no tiene {', '.join(ajenas)}. Tiene: {', '.join(t.columnas)}")
    inexistentes = sorted(set(mapeo.values()) - set(p.encabezados))
    if inexistentes:
        raise PlanillaInvalida(f"La planilla no tiene los encabezados {', '.join(inexistentes)}")
    faltan = [c for c in t.requeridas if c not in mapeo and not str(fijos.get(c, "")).strip()]
    if faltan:
        raise PlanillaInvalida(f"Faltan columnas obligatorias de «{entidad}»: {', '.join(faltan)}")

    pos = {e: i for i, e in enumerate(p.encabezados)}
    filas, problemas, codigos = [], [], {}
    for n, origen in enumerate(p.filas, start=2):  # fila 1 = encabezado, como la ve el cliente
        fila = {}
        for c in t.columnas:
            if c in mapeo:
                fila[c] = (origen[pos[mapeo[c]]] if pos[mapeo[c]] < len(origen) else "").strip()
            else:
                fila[c] = str(fijos.get(c, "")).strip()
        if not any(fila[c] for c in mapeo):
            continue  # fila vacia en lo que importa
        vacias = [c for c in t.requeridas if not fila[c]]
        if vacias:
            problemas.append(f"fila {n}: falta {', '.join(vacias)}")
        for c in t.enteras:
            if fila[c] and not re.fullmatch(r"-?\d+", fila[c]):
                problemas.append(f"fila {n}: {c} tiene que ser un número entero («{fila[c]}»)")
        cod = fila.get("codigo", "").upper()
        if cod:
            if cod in codigos:
                problemas.append(f"fila {n}: el código {fila['codigo']} ya está en la fila {codigos[cod]}")
            codigos.setdefault(cod, n)
        filas.append(fila)
    if problemas:
        extra = f" (y {len(problemas) - 5} más)" if len(problemas) > 5 else ""
        raise PlanillaInvalida("La planilla tiene problemas: " + "; ".join(problemas[:5]) + extra)
    if not filas:
        raise PlanillaInvalida("Con ese mapeo no queda ninguna fila con datos")
    return filas


async def preparar(con: psycopg.AsyncConnection, argumentos: dict) -> dict:
    """Los argumentos que se guardan en la carga propuesta: las filas ya transformadas.

    Lo que se ejecuta despues es exactamente esto (cargas.py)."""
    p = await obtener(con, str(argumentos.get("planilla_id", "")))
    entidad = str(argumentos.get("entidad", ""))
    filas = transformar(p, entidad, argumentos.get("mapeo") or {}, argumentos.get("valores_fijos"))
    return {"entidad": entidad, "planilla": p.nombre, "planilla_id": p.planilla_id,
            "mapeo": argumentos.get("mapeo"), "valores_fijos": argumentos.get("valores_fijos") or {},
            "filas": filas}


def a_csv(entidad: str, filas: list[dict]) -> str:
    t = PLANTILLAS[entidad]
    out = io.StringIO()
    w = csv.writer(out, lineterminator="\n")
    w.writerow(t.columnas)
    for f in filas:
        w.writerow([f.get(c, "") for c in t.columnas])
    return out.getvalue()


# ============================================================ la carga
# SIMULADA (decision del PM, 2026-11-11). La Carga Masiva de hoy vive en Dnato,
# que se reemplaza por Dnato v3 (en construccion). No se le abre una entrada a
# algo que va a desaparecer: hasta que Dnato v3 tenga su API de carga masiva
# (publicada en WSO2), la carga queda registrada en agente.simulacion con el
# MISMO archivo que recibiria la Carga Masiva. Deuda tecnica en STATE.md.
SIMULADO = True
ENTIDAD_SIMULACION = "carga_masiva"


async def ejecutar(con: psycopg.AsyncConnection, empr_id: int, argumentos: dict) -> dict:
    """Simula la Carga Masiva: todo o nada, como la real.

    Controla lo que la real controla sin otra base: que un codigo no se haya
    cargado antes para esa entidad en esta empresa."""
    entidad = argumentos["entidad"]
    filas = argumentos["filas"]
    codigos = {str(f.get("codigo", "")).upper() for f in filas if f.get("codigo")}
    async with con.cursor() as cur:
        await cur.execute(
            "SELECT datos->'codigos' AS codigos FROM agente.simulacion "
            "WHERE empr_id = %s AND entidad = %s AND datos->>'entidad' = %s",
            (empr_id, ENTIDAD_SIMULACION, entidad))
        previos = {c for f in await cur.fetchall() for c in (f["codigos"] or [])}
        repetidos = sorted(codigos & previos)
        if repetidos:
            raise CargaFallida("No se cargó nada (es todo o nada). Ya están cargados: "
                               + ", ".join(repetidos[:5]) + (" y otros" if len(repetidos) > 5 else ""))
        await cur.execute(
            "INSERT INTO agente.simulacion (empr_id, servicio, entidad, datos) VALUES (%s, %s, %s, %s::jsonb)",
            (empr_id, NOMBRE, ENTIDAD_SIMULACION, json.dumps({
                "entidad": entidad, "planilla": argumentos.get("planilla"), "total_filas": len(filas),
                "codigos": sorted(codigos), "csv": a_csv(entidad, filas)}, ensure_ascii=False)))
    return {"simulado": True, "entidad": entidad, "filas": len(filas),
            "resultado": f"Simulación: {len(filas)} filas de {entidad} quedaron registradas, todavía no en el sistema real."}
