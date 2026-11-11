"""Seguimiento de metas: los avisos de Kuntur al administrador (AGENTE-CO-07).

Un trabajo programado (cron, una vez por dia) que recorre las empresas con
credencial de maquina y, para cada una, mira sus metas vigentes. Si una no se
cumple, se lo avisa a quien la cargo, firmado por Kuntur.

    python -m agente.coach                 todas las empresas con credencial
    python -m agente.coach --empresa 191   una sola

Reglas:

  * Usa el token de maquina de la empresa y la lista blanca de Kuntur: solo
    lee (kpi_get_objetivos, kpi_get_historico y, para la meta de
    Mantenimiento, man_get_kpi_disponibilidad). No usa el modelo: es una regla
    sobre los datos, y cada cifra del aviso sale de una tool (R4).
  * Cada meta queda en un estado: ok, en riesgo (hoy se cumple, pero con la
    tendencia de los ultimos 30 dias no llega a la fecha) o no se cumple
    (agente/metas.py). La de Mantenimiento se evalua aca, con la
    disponibilidad de los ultimos 30 dias, porque el valor vive en AssetPlanner;
    no tiene historia, asi que no pasa por "en riesgo".
  * Avisa cuando el estado CAMBIA a en riesgo o a no se cumple, no por
    calendario (pedido del PM, 2026-11-11): lo que vio la ultima vez queda en
    agente.aviso_meta. Si el administrador pidio "no insistas", no avisa mas
    de esa meta hasta que vuelva a cumplirse.
  * El aviso va a quien confirmo la meta (usuario_alta de kpi.objetivos): es
    el administrador que la cargo. Nunca a un empleado.
  * Sin AGENTE_AVISOS_URL no se publica nada y el estado no se guarda: se
    vuelve a intentar en la proxima corrida.
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
TOOL_HISTORICO = "kpi_get_historico"
TIPO_AVISO = "kpi_desvio"
ENLACE_METAS = "Dash/dashboard"   # el Tablero del Administrador, donde esta la tarjeta Metas


def _numero(d: Decimal) -> str:
    """Como se ve el numero en el aviso: sin ceros de mas, con coma decimal."""
    return format(d.normalize(), "f").replace(".", ",")


def aviso_de(d: metas.Desvio, *, hoy: date, emisor: str) -> avisos.Aviso:
    signo = "≥" if d.operador == ">=" else "≤"
    fecha = f"{d.hasta[8:10]}/{d.hasta[5:7]}/{d.hasta[0:4]}" if len(d.hasta) == 10 else d.hasta
    base = f"Hoy está en {_numero(d.valor)} y la meta es {signo} {_numero(d.meta)} para el {fecha}"
    if d.estado == metas.EN_RIESGO:
        titulo = f"Una meta está en riesgo: {d.titulo}"
        cuerpo = base + ": con la tendencia del último mes, no llega."
    else:
        titulo = f"No se cumple la meta: {d.titulo}"
        cuerpo = base + "."
    cuerpo += (f" Responsable: {d.responsable}." if d.responsable else "")
    cuerpo += " Si no querés que insista, tocá «No insistas» en la pestaña Kuntur."
    return avisos.Aviso(
        tipo=TIPO_AVISO, titulo=titulo, cuerpo=cuerpo,
        severidad="aviso", enlace=ENLACE_METAS, entidad_tipo="kpi_objetivo",
        entidad_id=str(d.objetivo_id), emisor=emisor,
        dedupe_key=f"{TIPO_AVISO}:{d.objetivo_id}:{d.estado}:{hoy.isoformat()}",
        destinatarios=[d.usuario_alta] if d.usuario_alta else [],
    )


async def _avisados(con, empr_id: int) -> dict[int, dict]:
    async with con.cursor() as cur:
        await cur.execute("SELECT objetivo_id, estado, silenciado FROM agente.aviso_meta "
                          "WHERE empr_id = %s", (empr_id,))
        return {f["objetivo_id"]: dict(f) for f in await cur.fetchall()}


async def _guardar_estado(con, empr_id: int, d: metas.Desvio, *, aviso: avisos.Aviso | None) -> None:
    """Lo que vio el seguimiento. Volver a 'ok' limpia el "no insistas"."""
    async with con.cursor() as cur:
        await cur.execute(
            """
            INSERT INTO agente.aviso_meta (empr_id, objetivo_id, estado, titulo, cuerpo, fec_aviso)
            VALUES (%(e)s, %(o)s, %(s)s, %(t)s, %(c)s, CASE WHEN %(avisado)s THEN now() END)
            ON CONFLICT (empr_id, objetivo_id) DO UPDATE SET
                estado = EXCLUDED.estado,
                titulo = COALESCE(EXCLUDED.titulo, agente.aviso_meta.titulo),
                cuerpo = COALESCE(EXCLUDED.cuerpo, agente.aviso_meta.cuerpo),
                fec_aviso = COALESCE(EXCLUDED.fec_aviso, agente.aviso_meta.fec_aviso),
                silenciado = CASE WHEN EXCLUDED.estado = 'ok' THEN false ELSE agente.aviso_meta.silenciado END,
                silenciado_por = CASE WHEN EXCLUDED.estado = 'ok' THEN NULL ELSE agente.aviso_meta.silenciado_por END,
                fec_silencio = CASE WHEN EXCLUDED.estado = 'ok' THEN NULL ELSE agente.aviso_meta.fec_silencio END,
                fec_mod = now()
            """,
            {"e": empr_id, "o": d.objetivo_id, "s": d.estado,
             "t": aviso.titulo if aviso else None, "c": aviso.cuerpo if aviso else None,
             "avisado": aviso is not None})


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
            # La historia de cada indicador con meta, para la tendencia.
            series = {}
            if TOOL_HISTORICO in permitidas:
                for kpi in sorted({str(f.get("kpi")) for f in filas if f.get("fuente") == "tools"}):
                    try:
                        hist = await mcp.llamar(TOOL_HISTORICO, {"nombre": kpi, **metas.periodo_tendencia(hoy)})
                        res.contenidos_tools.append(json.dumps(hist, ensure_ascii=False)[:8000])
                        series[kpi] = metas.serie_historico(hist)
                    except MCPError as e:
                        # Sin historia, la meta se evalua solo con el valor de hoy.
                        log.warning("Coach %s: %s de %s fallo: %s", empr_id, TOOL_HISTORICO, kpi, e)
            res.tools_llamadas = [ll.a_dict() for ll in mcp.llamadas]

        seguidas = metas.seguir(filas, hoy=hoy, valores_man=valores_man, series=series)
        desvios = [d for d in seguidas if d.estado != metas.OK]
        resumen["metas"], resumen["desvios"] = len(filas), len(desvios)
        resumen["en_riesgo"] = sum(1 for d in desvios if d.estado == metas.EN_RIESGO)
        resumen["silenciados"] = 0
        avisados = await _avisados(con, empr_id)

        for d in seguidas:
            previo = avisados.get(d.objetivo_id) or {"estado": metas.OK, "silenciado": False}
            if d.estado == metas.OK:
                if previo["estado"] != metas.OK:
                    await _guardar_estado(con, empr_id, d, aviso=None)
                continue
            if d.estado == previo["estado"]:
                continue                      # ya se aviso de esto
            if previo["silenciado"]:
                resumen["silenciados"] += 1   # "no insistas": se anota sin avisar
                await _guardar_estado(con, empr_id, d, aviso=None)
                continue
            if not avisos.habilitado(cfg) or not d.usuario_alta:
                resumen["sin_publicar"] += 1
                continue
            aviso = aviso_de(d, hoy=hoy, emisor=agente.nombre)
            try:
                await avisos.publicar(cfg, autorizacion, aviso)
            except avisos.AvisoError as e:
                log.warning("Coach %s: no se publico el aviso de %s: %s", empr_id, d.objetivo_id, e)
                resumen["sin_publicar"] += 1
                continue
            resumen["avisos"] += 1
            await _guardar_estado(con, empr_id, d, aviso=aviso)
        res.respuesta = (f"{resumen['metas']} meta(s), {resumen['desvios']} en riesgo o sin cumplirse, "
                         f"{resumen['avisos']} aviso(s) publicado(s), {resumen['sin_publicar']} sin publicar")
        res.controles.append({"control": "seguimiento_metas", **resumen,
                              "objetivos_en_desvio": {d.objetivo_id: d.estado for d in desvios}})
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
