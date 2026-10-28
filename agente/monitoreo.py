"""Monitoreo operativo: los avisos proactivos de Quirqui (AGENTE-AS-03).

Un job (cron) que recorre las empresas con credencial de maquina y, para cada
una, revisa lo mismo que el siguiente paso del panel (agente/sugerencias.py):
lotes vencidos o criticos, stock bajo el punto de pedido, certificaciones de
herramientas por vencer. Lo que encuentra lo encola en agente.notificacion
para los destinatarios configurados de ese tipo de aviso.

    python -m agente.monitoreo                 todas las empresas con credencial
    python -m agente.monitoreo --empresa 191   una sola

Reglas:

  * Usa el token de maquina de la empresa (agente/credenciales.py) y pasa por
    la lista blanca de Quirqui, como cualquier consulta.
  * Sin destinatarios configurados para un tipo de aviso, NO se avisa (silencio
    en vez de aviso al azar, decision de E1). Queda en la corrida.
  * No repite: la dedupe_key lleva el dia, asi que el mismo hallazgo se avisa
    una vez por dia y por destinatario aunque el cron corra cada hora.
  * Cada empresa es una corrida registrada (R8), con disparador
    'evento_operativo' y canal 'scheduler'.

Por cada aviso nuevo se encola un envio push (agente.envio) por dispositivo
activo del destinatario, firmado por el agente y con su avatar como icono. El
envio real lo hace la app Siddhi (cola -> FirebaseConnectorAPI), que todavia
no esta.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import time
import uuid
from datetime import date

from . import agentes, credenciales, rag, sugerencias
from .config import Config, cargar
from .mcp_client import ClienteMCP, MCPError
from .orquestador import AGENTE_POR_DEFECTO, Consulta, Orquestador, Resultado

log = logging.getLogger("agente.monitoreo")

# Tipo de hallazgo (sugerencias.py) -> tipo de aviso y severidad (007/018).
AVISO = {
    "lote_vencido": ("material_por_vencer", "critica"),
    "lote_critico": ("material_por_vencer", "aviso"),
    "stock_bajo": ("stock_critico", "aviso"),
    "certificacion_por_vencer": ("certificacion_por_vencer", "aviso"),
}


async def monitorear_empresa(con, cfg: Config, empr_id: int, autorizacion: str,
                             *, hoy: date | None = None) -> dict:
    """Revisa una empresa y encola los avisos. Devuelve un resumen."""
    hoy = hoy or date.today()
    t0 = time.monotonic()
    agente = await agentes.obtener(con, AGENTE_POR_DEFECTO)
    consulta = Consulta(empr_id=empr_id, pregunta="(monitoreo operativo)",
                        autorizacion=autorizacion, canal="scheduler",
                        disparador="evento_operativo", agente=agente,
                        usuario_nick="agente:monitoreo")
    res = Resultado(interaccion_id=str(uuid.uuid4()), respuesta="")
    resumen = {"empr_id": empr_id, "hallazgos": 0, "avisos": 0, "sin_destinatario": 0, "envios": 0}
    await rag.fijar_empresa(con, empr_id)

    try:
        permitidas = await agentes.tools_permitidas(con, agente.clave)
        tools = sorted({t for ts in sugerencias.REGLAS_POR_MODULO.values() for t in ts} & permitidas)
        cands: list[sugerencias.Candidata] = []
        async with ClienteMCP(cfg, autorizacion) as mcp:
            for tool in tools:
                try:
                    data = await mcp.llamar(tool, {})
                except MCPError as e:
                    log.warning("Monitoreo %s: %s fallo: %s", empr_id, tool, e)
                    continue
                res.contenidos_tools.append(json.dumps(data, ensure_ascii=False)[:8000])
                cands += sugerencias.candidatas(tool, data, hoy=hoy,
                                                dias_certificacion=cfg.sugerencia_dias_certificacion)
            res.tools_llamadas = [ll.a_dict() for ll in mcp.llamadas]
        resumen["hallazgos"] = len(cands)

        async with con.cursor() as cur:
            for c in cands:
                tipo, severidad = AVISO.get(c.tipo, ("hallazgo", "info"))
                await cur.execute("SELECT usr_id, usuario FROM agente.destinatarios(%s, %s)",
                                  (empr_id, tipo))
                destinos = await cur.fetchall()
                if not destinos:
                    resumen["sin_destinatario"] += 1
                    continue
                for d in destinos:
                    quien = d["usuario"] or str(d["usr_id"])
                    await cur.execute(
                        """
                        INSERT INTO agente.notificacion
                            (empr_id, usr_id, usuario, tipo, titulo, cuerpo, severidad,
                             entidad_tipo, entidad_id, enlace, dedupe_key)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (empr_id, dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING
                        RETURNING notificacion_id
                        """,
                        (empr_id, d["usr_id"], d["usuario"], tipo, c.titulo, c.detalle, severidad,
                         c.tipo, c.clave.split(":", 1)[-1], c.accion.get("ayuda"),
                         f"{c.clave}:{quien}:{hoy.isoformat()}"))
                    nueva = await cur.fetchone()
                    if not nueva:
                        continue   # ya se aviso hoy
                    resumen["avisos"] += 1
                    resumen["envios"] += await _encolar_push(
                        cur, nueva["notificacion_id"], empr_id, d, c, agente, cfg)
        res.respuesta = (f"{resumen['hallazgos']} hallazgo(s), {resumen['avisos']} aviso(s) nuevo(s), "
                         f"{resumen['sin_destinatario']} sin destinatario")
        res.controles.append({"control": "monitoreo", **resumen})
    except Exception as e:  # noqa: BLE001 - se registra y se sigue con la proxima empresa
        res.error = f"{type(e).__name__}: {e}"
        res.respuesta = "(monitoreo con error)"
        await con.rollback()
        await rag.fijar_empresa(con, empr_id)

    res.latencia_ms = int((time.monotonic() - t0) * 1000)
    await Orquestador(cfg)._registrar(con, consulta, res)
    resumen["error"] = res.error
    return resumen


async def _encolar_push(cur, notificacion_id: int, empr_id: int, destino: dict,
                        c: "sugerencias.Candidata", agente, cfg: Config) -> int:
    """Una fila en agente.envio por cada dispositivo activo del destinatario.

    El envio real lo hace la app Siddhi (cola -> FirebaseConnectorAPI). El
    push va firmado por el agente: su nombre en el titulo y su avatar como
    icono (AGENTE-ID-06). Sin dispositivos registrados, el aviso queda solo en
    la campanita.
    """
    await cur.execute(
        """
        SELECT dispositivo_id, token FROM agente.dispositivo
        WHERE empr_id = %s AND activo
          AND (usuario = %s OR (usr_id IS NOT NULL AND usr_id = %s))
        """, (empr_id, destino["usuario"], destino["usr_id"]))
    dispositivos = await cur.fetchall()
    for disp in dispositivos:
        payload = {
            "notification": {
                "title": f"{agente.nombre}: {c.titulo}",
                "body": c.detalle,
                "icon": f"assets/agentes/{agente.avatar}/icono.png",
            },
            "data": {"notificacion_id": str(notificacion_id), "tipo": c.tipo,
                     "enlace": c.accion.get("ayuda") or ""},
        }
        await cur.execute(
            "INSERT INTO agente.envio (notificacion_id, dispositivo_id, token, payload) "
            "VALUES (%s, %s, %s, %s)",
            (notificacion_id, disp["dispositivo_id"], disp["token"],
             json.dumps(payload, ensure_ascii=False)))
    return len(dispositivos)


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
            salida.append(await monitorear_empresa(con, cfg, empr_id, autorizacion))
    finally:
        await con.close()
    return salida


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Monitoreo operativo: avisos proactivos de Quirqui.")
    ap.add_argument("--empresa", type=int, default=None, help="Solo esta empresa")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO)
    for r in asyncio.run(correr(cargar(), empresa=args.empresa)):
        print(json.dumps(r, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
