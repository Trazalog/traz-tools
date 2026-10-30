"""Seguimiento de metas: los avisos de Kuntur al administrador (AGENTE-CO-07).

Un trabajo programado (cron, una vez por dia) que recorre las empresas con
credencial de maquina y, para cada una, mira sus metas vigentes. Si una no se
cumple, se lo avisa a quien la cargo, firmado por Kuntur.

    python -m agente.coach                 todas las empresas con credencial
    python -m agente.coach --empresa 191   una sola

Reglas:

  * Usa el token de maquina de la empresa y la lista blanca de Kuntur: solo
    lee (kpi_get_objetivos y, para la meta de Mantenimiento,
    man_get_kpi_disponibilidad). No usa el modelo: es una regla sobre los
    datos, y cada cifra del aviso sale de una tool (R4).
  * La meta de Mantenimiento se evalua aca, con la disponibilidad de los
    ultimos 30 dias (agente/metas.py), porque el valor vive en AssetPlanner.
  * El aviso va a quien confirmo la meta (usuario_alta de kpi.objetivos): es
    el administrador que la cargo. Asi no hace falta saber quien es
    administrador desde ntf (D-85 sigue abierta para otros usos).
  * No insiste: la dedupe_key lleva la semana, asi que una meta que sigue sin
    cumplirse se avisa una vez por semana aunque el cron corra todos los dias.
  * Sin AGENTE_AVISOS_URL no se publica nada: los desvios quedan en la corrida.
  * Cada empresa es una corrida registrada (R8), con disparador 'desvio_kpi'
    y canal 'scheduler'.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import time
import uuid
from datetime import date
from decimal import Decimal

from . import agentes, avisos, credenciales, metas, rag
from .config import Config, cargar
from .mcp_client import ClienteMCP, MCPError
from .orquestador import Consulta, Orquestador, Resultado

log = logging.getLogger("agente.coach")

AGENTE = "kuntur"
TOOL_OBJETIVOS = "kpi_get_objetivos"
TOOL_DISPONIBILIDAD = "man_get_kpi_disponibilidad"
TIPO_AVISO = "kpi_desvio"
ENLACE_METAS = "Dash/dashboard"   # el Tablero del Administrador, donde esta la tarjeta Metas


def _numero(d: Decimal) -> str:
    """Como se ve el numero en el aviso: sin ceros de mas, con coma decimal."""
    return format(d.normalize(), "f").replace(".", ",")


def aviso_de(d: metas.Desvio, *, hoy: date, emisor: str) -> avisos.Aviso:
    signo = "≥" if d.operador == ">=" else "≤"
    semana = hoy.isocalendar()
    fecha = f"{d.hasta[8:10]}/{d.hasta[5:7]}/{d.hasta[0:4]}" if len(d.hasta) == 10 else d.hasta
    cuerpo = (f"Hoy está en {_numero(d.valor)} y la meta es {signo} {_numero(d.meta)} para el {fecha}."
              + (f" Responsable: {d.responsable}." if d.responsable else ""))
    return avisos.Aviso(
        tipo=TIPO_AVISO, titulo=f"No se cumple la meta: {d.titulo}", cuerpo=cuerpo,
        severidad="aviso", enlace=ENLACE_METAS, entidad_tipo="kpi_objetivo",
        entidad_id=str(d.objetivo_id), emisor=emisor,
        dedupe_key=f"{TIPO_AVISO}:{d.objetivo_id}:{semana[0]}-W{semana[1]:02d}",
        destinatarios=[d.usuario_alta] if d.usuario_alta else [],
    )


async def revisar_empresa(con, cfg: Config, empr_id: int, autorizacion: str,
                          *, hoy: date | None = None) -> dict:
    """Revisa las metas de una empresa y publica los avisos. Devuelve un resumen."""
    hoy = hoy or date.today()
    t0 = time.monotonic()
    agente = await agentes.obtener(con, AGENTE, solo_activos=False)
    consulta = Consulta(empr_id=empr_id, pregunta="(seguimiento de metas)",
                        autorizacion=autorizacion, canal="scheduler",
                        disparador="desvio_kpi", agente=agente,
                        usuario_nick="agente:coach")
    res = Resultado(interaccion_id=str(uuid.uuid4()), respuesta="")
    resumen = {"empr_id": empr_id, "metas": 0, "desvios": 0, "avisos": 0, "sin_publicar": 0}
    await rag.fijar_empresa(con, empr_id)

    try:
        if not agente.activo:
            raise RuntimeError("Kuntur no esta activo")
        permitidas = await agentes.tools_permitidas(con, agente.clave)
        if TOOL_OBJETIVOS not in permitidas:
            raise RuntimeError(f"{TOOL_OBJETIVOS} no esta en la lista blanca de Kuntur")
        async with ClienteMCP(cfg, autorizacion) as mcp:
            data = await mcp.llamar(TOOL_OBJETIVOS, {})
            res.contenidos_tools.append(json.dumps(data, ensure_ascii=False)[:8000])
            filas = metas.objetivos(data)

            valores_man: dict[str, Decimal | None] = {}
            if any(f.get("fuente") == "man" and f.get("kpi") == "man_disponibilidad" for f in filas):
                if TOOL_DISPONIBILIDAD in permitidas:
                    try:
                        disp = await mcp.llamar(TOOL_DISPONIBILIDAD, metas.periodo_disponibilidad(hoy))
                        res.contenidos_tools.append(json.dumps(disp, ensure_ascii=False)[:8000])
                        valores_man["man_disponibilidad"] = metas.valor_disponibilidad(disp)
                    except MCPError as e:
                        # Sin el dato de Mantenimiento, se siguen revisando las demas.
                        log.warning("Coach %s: %s fallo: %s", empr_id, TOOL_DISPONIBILIDAD, e)
            res.tools_llamadas = [ll.a_dict() for ll in mcp.llamadas]

        desvios = metas.evaluar(filas, hoy=hoy, valores_man=valores_man)
        resumen["metas"], resumen["desvios"] = len(filas), len(desvios)

        for d in desvios:
            if not avisos.habilitado(cfg) or not d.usuario_alta:
                resumen["sin_publicar"] += 1
                continue
            try:
                await avisos.publicar(cfg, autorizacion, aviso_de(d, hoy=hoy, emisor=agente.nombre))
                resumen["avisos"] += 1
            except avisos.AvisoError as e:
                log.warning("Coach %s: no se publico el desvio de %s: %s", empr_id, d.objetivo_id, e)
                resumen["sin_publicar"] += 1
        res.respuesta = (f"{resumen['metas']} meta(s), {resumen['desvios']} sin cumplirse, "
                         f"{resumen['avisos']} aviso(s) publicado(s), {resumen['sin_publicar']} sin publicar")
        res.controles.append({"control": "seguimiento_metas", **resumen,
                              "objetivos_en_desvio": [d.objetivo_id for d in desvios]})
    except Exception as e:  # noqa: BLE001 - se registra y se sigue con la proxima empresa
        res.error = f"{type(e).__name__}: {e}"
        res.respuesta = "(seguimiento de metas con error)"
        await con.rollback()
        await rag.fijar_empresa(con, empr_id)

    res.latencia_ms = int((time.monotonic() - t0) * 1000)
    await Orquestador(cfg)._registrar(con, consulta, res)
    resumen["error"] = res.error
    return resumen


async def correr(cfg: Config, *, empresa: int | None = None) -> list[dict]:
    tokens = credenciales.TokenMaquina(cfg)
    con = await rag.abrir(cfg)
    salida = []
    try:
        lista = [empresa] if empresa else await credenciales.empresas(con)
        for empr_id in lista:
            try:
                autorizacion = await tokens.autorizacion(con, empr_id)
                await con.commit()
            except credenciales.CredencialError as e:
                await con.rollback()
                salida.append({"empr_id": empr_id, "error": str(e)})
                continue
            salida.append(await revisar_empresa(con, cfg, empr_id, autorizacion))
    finally:
        await con.close()
    return salida


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Seguimiento de metas: avisos de Kuntur al administrador.")
    ap.add_argument("--empresa", type=int, default=None, help="Solo esta empresa")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO)
    for r in asyncio.run(correr(cargar(), empresa=args.empresa)):
        print(json.dumps(r, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
