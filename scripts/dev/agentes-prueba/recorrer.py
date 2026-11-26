"""Recorre el guion de la prueba manual por la API del motor, con la IA real.

Sirve para dos cosas (lección de portal_t4):
  - sacar de una corrida REAL lo que tiene que aparecer en cada función del
    guion, en vez de inventarlo;
  - encontrar errores antes de que el PM se siente a probar.

DÓNDE SE CORRE: terminal local, desde la raíz del repo, con
scripts/dev/agentes-prueba/levantar.sh corriendo y después de
preparar_prueba.py --borrar. Gasta tokens (modelo gratuito: centavos o nada).

    .venv-agente/bin/python scripts/dev/agentes-prueba/recorrer.py <carpeta-salida> [bloques]

Escribe <carpeta-salida>/recorrido.json y recorrido.md. Al terminar hay que
volver a sembrar con --borrar: el recorrido cambia el punto de partida.

Los tokens que arma NO tienen firma válida: el motor solo lee los claims
(la firma la valida el gateway, ADR-009). No sirven contra el gateway real.
"""
from __future__ import annotations

import base64
import json
import pathlib
import sys
import time

import httpx

MOTOR = "http://127.0.0.1:8099"

# nick: (empr_id, rol Dnato, usr_id de seg.users en DEV)
USUARIOS = {
    "agenteminero": (191, "1", 328),
    "expertominero": (191, "4", 687),
    "expertaminera": (191, "4", 688),
    "operariominero": (191, "4", 689),
    "adminelectrica": (230, "1", 690),
}


def jwt(nick: str) -> str:
    empr, rol, usr = USUARIOS[nick]

    def b64(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")
    return "Bearer " + ".".join([b64({"alg": "RS256"}), b64(
        {"sub": nick, "preferred_username": nick, "empr_id": str(empr), "role": rol, "usr_id": str(usr),
         # Como el token de Dnato: el id de la empresa en AssetPlanner (preparar_prueba lo deja igual).
         "empr_id_mysql": empr}),
        "sin-firma"])


class Recorrido:
    def __init__(self, salida: pathlib.Path):
        self.salida, self.pasos = salida, []
        self.http = httpx.Client(base_url=MOTOR, timeout=240)

    def llamar(self, f: str, nick: str, metodo: str, ruta: str, cuerpo: dict | None = None,
               nota: str = "") -> dict:
        t = time.time()
        r = self.http.request(metodo, ruta, json=cuerpo, headers={"Authorization": jwt(nick)})
        try:
            datos = r.json()
        except ValueError:
            datos = {"texto": r.text[:2000]}
        paso = {"f": f, "usuario": nick, "pedido": f"{metodo} {ruta}", "cuerpo": cuerpo, "nota": nota,
                "status": r.status_code, "segundos": round(time.time() - t, 1), "respuesta": datos}
        self.pasos.append(paso)
        resumen = datos.get("respuesta") if isinstance(datos, dict) else None
        print(f"{f} {nick:15} {metodo} {ruta} → {r.status_code} ({paso['segundos']} s) "
              f"{(resumen or json.dumps(datos, ensure_ascii=False))[:160]!r}", flush=True)
        self.guardar()
        return datos if isinstance(datos, dict) else {"lista": datos}

    def consulta(self, f, nick, pregunta, pantalla=None, agente="quirqui", nota=""):
        c = {"pregunta": pregunta, "agente": agente}
        if pantalla:
            c["pantalla"] = pantalla
        return self.llamar(f, nick, "POST", "/consulta", c, nota)

    def guardar(self):
        self.salida.mkdir(parents=True, exist_ok=True)
        (self.salida / "recorrido.json").write_text(json.dumps(self.pasos, ensure_ascii=False, indent=1))
        md = ["# Recorrido automático\n"]
        for p in self.pasos:
            d = p["respuesta"]
            md.append(f"## {p['f']} · {p['usuario']} · `{p['pedido']}` → {p['status']} ({p['segundos']} s)\n")
            if p["nota"]:
                md.append(f"_{p['nota']}_\n")
            if p["cuerpo"]:
                md.append("```json\n" + json.dumps(p["cuerpo"], ensure_ascii=False)[:600] + "\n```\n")
            if isinstance(d, dict) and "respuesta" in d:
                md.append(d["respuesta"] + "\n")
                extra = {k: v for k, v in d.items() if k not in ("respuesta", "fragmentos") and v}
                md.append("```json\n" + json.dumps(extra, ensure_ascii=False, indent=1)[:3000] + "\n```\n")
            else:
                md.append("```json\n" + json.dumps(d, ensure_ascii=False, indent=1)[:3000] + "\n```\n")
        (self.salida / "recorrido.md").write_text("\n".join(md))


# ------------------------------------------------------------------ bloques
def bloque_a(r: Recorrido):
    """Quirqui con los datos del día a día (operario de la 191)."""
    op = "operariominero"
    r.llamar("A-agentes", op, "GET", "/agentes", nota="un usuario común solo tiene a Quirqui")
    r.llamar("A-sugerencias", op, "POST", "/sugerencias", {"pantalla": "traz-comp-almacenes/Articulo"},
             nota="al abrir el panel en Almacenes: hasta 3 próximos pasos")
    r.consulta("A-pantalla", op, "¿Qué hago en esta pantalla?", "traz-comp-almacenes/Articulo")
    r.consulta("A-lotes", op, "¿Qué lotes están por vencer o ya vencieron?", "traz-comp-almacenes/Lote/indexStock")
    r.consulta("A-stock", op, "¿Qué artículos están por debajo del punto de pedido?",
               "traz-comp-almacenes/Lote/puntoPedList")
    r.consulta("A-ots", op, "¿Cuántas órdenes de trabajo abiertas hay y cuál es la más vieja?", "Dash")
    r.consulta("A-tablero", op, "¿Qué hago en esta pantalla?", "Dash/dashboard",
               nota="sin caso de uso del Tablero: no tiene que inventar botones")
    res = r.consulta("A-alta", op, "Dame de alta un artículo nuevo: guantes de nitrilo talle L",
                     "traz-comp-almacenes/Articulo", nota="explica cómo; no lo crea")
    if res.get("interaccion_id"):
        r.llamar("A-pulgar", op, "POST", "/feedback", {"interaccion_id": res["interaccion_id"], "util": False,
                                                        "motivo": "incompleta", "comentario": "Quería que lo cargue"})
    r.consulta("A-saber-mineria", op, "¿Cada cuánto hay que revisar los mantos de la chancadora primaria?",
               nota="conocimiento de minería: 250 horas y 45 mm")
    r.consulta("A-saber-otra-industria", op,
               "¿Cada cuánto se analiza el aceite dieléctrico de un transformador de 13,2 kV?",
               nota="el dato de electricidad NO tiene que aparecer en una minera")
    r.consulta("A-web", op, "¿Qué dice la ley de seguridad minera argentina sobre espacios confinados?")


def bloque_c(r: Recorrido):
    """Kuntur entrevista a la empresa nueva (ELECTRICA DEL SUR TEST)."""
    ad = "adminelectrica"
    r.llamar("C-agentes", ad, "GET", "/agentes", nota="el administrador tiene a Quirqui y a Kuntur")
    estado = r.llamar("C-config", ad, "GET", "/kuntur/configuracion")
    p = r.llamar("C-iniciar", ad, "POST", "/kuntur/configuracion/iniciar")
    respuestas = {"industria": ["electricidad"], "modulos": ["mantenimiento", "almacenes"],
                  "operadora": ["no"]}
    for i in range(10):
        preg = p.get("pregunta")
        if not preg:
            break
        opciones = [o["valor"] for o in preg.get("opciones") or []]
        vals = respuestas.get(preg["id"]) or opciones[:1]
        p = r.llamar(f"C-responder-{preg['id']}", ad, "POST", "/kuntur/configuracion/responder",
                     {"pregunta": preg["id"], "valores": vals})
    r.llamar("C-confirmar", ad, "POST", "/kuntur/configuracion/confirmar")
    r.llamar("C-agenda-faustino", ad, "GET", "/entrevista/agenda?vertical=electricidad",
             nota="Faustino propone la industria que declaró la empresa")
    r.consulta("C-saber-electricidad", ad,
               "¿Cada cuánto se analiza el aceite dieléctrico de un transformador de 13,2 kV?",
               nota="ahora sí: 6 meses y 30 kV")
    r.llamar("C-funciones", ad, "GET", "/kuntur/funciones", nota="funciones de Tools que la empresa no usa")
    del estado


def bloque_d(r: Recorrido):
    """Faustino entrevista al experto de la 191 y él revisa lo que entendió."""
    ex = "expertominero"
    ag = r.llamar("D-agenda", ex, "GET", "/entrevista/agenda?vertical=mineria",
                  nota="la pantalla pide la agenda con la industria de la empresa")
    exs = r.llamar("D-expertos", ex, "GET", "/entrevista/expertos")
    temas = ag.get("temas") or []
    tema = next((t for t in temas if "chancad" in t["nombre"].lower()), temas[0] if temas else None)
    experto = next(e for e in exs["expertos"] if e["nombre"].startswith("Juan"))
    s = r.llamar("D-iniciar", ex, "POST", "/entrevista/iniciar",
                 {"experto_id": experto["experto_id"], "tema_id": tema["tema_id"]})
    for i, txt in enumerate([
        "En nuestra planta los mantos de la chancadora primaria los medimos cada 200 horas con galga, en 4 puntos.",
        "Cuando el desgaste pasa los 40 milímetros programamos el cambio en la parada siguiente; nunca esperamos a 50.",
        "Lo que más falla antes que el manto es el anillo de ajuste: si hay ruido metálico, se para y se revisa ese día.",
    ]):
        s = r.llamar(f"D-responder-{i + 1}", ex, "POST", "/entrevista/responder",
                     {"sesion_id": s["sesion_id"], "respuesta": txt})
    hechos = r.llamar("D-estructurar", ex, "POST", f"/entrevista/estructurar?sesion_id={s['sesion_id']}")
    lista = hechos.get("hechos") or []
    for i, h in enumerate(lista):
        r.llamar(f"D-validar-{i + 1}", ex, "POST", "/entrevista/validar",
                 {"hecho_id": h["hecho_id"], "aprobado": i < 2})
    r.llamar("D-cerrar", ex, "POST", f"/entrevista/cerrar?sesion_id={s['sesion_id']}")


def bloque_e(r: Recorrido):
    """Quirqui y Kuntur usan lo que contó el experto (después de que el curador lo aprueba)."""
    r.consulta("E-quirqui", "operariominero", "¿Cada cuántas horas se miden los mantos de la chancadora primaria?",
               nota="el experto dijo 200 h; el ejemplo cargado dice 250 h: ¿cómo lo resuelve?")
    r.consulta("E-rechazado", "operariominero", "¿Qué falla antes que el manto en la chancadora?",
               nota="lo del anillo de ajuste lo rechazó el experto: no tiene que aparecer como conocimiento")
    r.consulta("E-kuntur", "agenteminero", "¿Cuándo conviene programar el cambio de mantos?", agente="kuntur")


def bloque_f(r: Recorrido):
    """Kuntur con el administrador de la 191: metas, plan, cargas."""
    ad = "agenteminero"
    r.consulta("F-ots", "operariominero", "¿Qué órdenes de trabajo están abiertas y de qué equipos?", "Dash")
    r.consulta("F-meta", ad, "Tengo muchos artículos bajo el punto de pedido. Proponeme una meta para fin de mes.",
               agente="kuntur")
    r.llamar("F-avisos", ad, "GET", "/kuntur/avisos")
    r.consulta("G-plan", ad, "Las chancadoras paran mucho por fallas. Armame un plan de acción para bajarlas.",
               agente="kuntur")
    r.llamar("G-planes", ad, "GET", "/kuntur/planes")
    r.consulta("H-carga", ad, "Quiero dar de alta un depósito nuevo llamado Depósito Rampa Norte", agente="kuntur")
    r.consulta("H-carga-sim", ad, "Cargame el sector Planta de Chancado en mantenimiento", agente="kuntur")
    r.llamar("H-funciones", ad, "GET", "/kuntur/funciones")
    r.llamar("H-mediciones", ad, "GET", "/kuntur/mediciones")


def bloque_i(r: Recorrido):
    """Permisos: lo que un usuario común no tiene que poder hacer."""
    op = "operariominero"
    r.consulta("I-kuntur", op, "Proponeme una meta", agente="kuntur", nota="404 como si no existiera")
    r.llamar("I-config", op, "GET", "/kuntur/configuracion", nota="404")
    r.llamar("I-feedback-admin", op, "GET", "/admin/feedback", nota="¿lo ve un usuario común?")
    r.llamar("I-faustino", op, "GET", "/entrevista/agenda", nota="el motor no controla el rol (ya sabido)")


BLOQUES = {"a": bloque_a, "c": bloque_c, "d": bloque_d, "e": bloque_e, "f": bloque_f, "i": bloque_i}


def main() -> int:
    salida = pathlib.Path(sys.argv[1])
    elegidos = sys.argv[2] if len(sys.argv) > 2 else "".join(BLOQUES)
    r = Recorrido(salida)
    for b in elegidos:
        print(f"\n=== bloque {b.upper()}: {BLOQUES[b].__doc__}")
        try:
            BLOQUES[b](r)
        except Exception as e:  # noqa: BLE001 - se anota y se sigue con el próximo bloque
            print(f"!!! el bloque {b} se cortó: {e!r}")
            r.pasos.append({"f": f"{b.upper()}-cortado", "usuario": "-", "pedido": "-", "cuerpo": None,
                            "nota": repr(e), "status": 0, "segundos": 0, "respuesta": {}})
            r.guardar()
    return 0


if __name__ == "__main__":
    sys.exit(main())
