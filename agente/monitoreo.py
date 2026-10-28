"""Monitoreo operativo: los avisos proactivos de Quirqui (AGENTE-AS-03).

Un job (cron) que recorre las empresas con credencial de maquina y, para cada
una, revisa lo mismo que el siguiente paso del panel (agente/sugerencias.py):
lotes vencidos o criticos, stock bajo el punto de pedido, certificaciones de
herramientas por vencer. Lo que encuentra lo publica en los avisos de Tools
(ADR-015: POST /avisos de toolsNTFAPI, agente/avisos.py).

    python -m agente.monitoreo                 todas las empresas con credencial
    python -m agente.monitoreo --empresa 191   una sola

Reglas:

  * Usa el token de maquina de la empresa (agente/credenciales.py) y pasa por
    la lista blanca de Quirqui, como cualquier consulta.
  * A quien le llega lo decide Tools con las suscripciones del tipo de aviso
    (ntf.suscripcion). Sin suscriptos, el aviso no le llega a nadie (silencio
    en vez de aviso al azar, decision de E1).
  * No repite: la dedupe_key lleva el dia, asi que el mismo hallazgo se avisa
    una vez por dia aunque el cron corra cada hora.
  * Sin AGENTE_AVISOS_URL no se publica nada: los hallazgos quedan en la
    corrida.
  * Cada empresa es una corrida registrada (R8), con disparador
    'evento_operativo' y canal 'scheduler'.

El aviso va firmado por el agente (emisor): el push sale con su nombre en el
titulo y su avatar como icono (Siddhi AvisosPush). Ya no hay cola propia en el
esquema agente.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import time
import uuid
from datetime import date

from . import agentes, avisos, credenciales, rag, sugerencias
from .config import Config, cargar
from .mcp_client import ClienteMCP, MCPError
from .orquestador import AGENTE_POR_DEFECTO, Consulta, Orquestador, Resultado

log = logging.getLogger("agente.monitoreo")

# Tipo de hallazgo (sugerencias.py) -> tipo de aviso de ntf y severidad.
AVISO = {
    "lote_vencido": ("material_por_vencer", "critica"),
    "lote_critico": ("material_por_vencer", "aviso"),
    "stock_bajo": ("stock_critico", "aviso"),
    "certificacion_por_vencer": ("certificacion_por_vencer", "aviso"),
}


async def monitorear_empresa(con, cfg: Config, empr_id: int, autorizacion: str,
                             *, hoy: date | None = None) -> dict:
    """Revisa una empresa y publica los avisos. Devuelve un resumen."""
    hoy = hoy or date.today()
    t0 = time.monotonic()
    agente = await agentes.obtener(con, AGENTE_POR_DEFECTO)
    consulta = Consulta(empr_id=empr_id, pregunta="(monitoreo operativo)",
                        autorizacion=autorizacion, canal="scheduler",
                        disparador="evento_operativo", agente=agente,
                        usuario_nick="agente:monitoreo")
    res = Resultado(interaccion_id=str(uuid.uuid4()), respuesta="")
    resumen = {"empr_id": empr_id, "hallazgos": 0, "avisos": 0, "sin_publicar": 0}
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

        for c in cands:
            if not avisos.habilitado(cfg):
                resumen["sin_publicar"] += 1
                continue
            tipo, severidad = AVISO.get(c.tipo, ("hallazgo", "info"))
            aviso = avisos.Aviso(
                tipo=tipo, titulo=c.titulo, cuerpo=c.detalle, severidad=severidad,
                enlace=c.accion.get("ayuda"), entidad_tipo=c.tipo,
                entidad_id=c.clave.split(":", 1)[-1], emisor=agente.nombre,
                dedupe_key=f"{c.clave}:{hoy.isoformat()}")
            try:
                await avisos.publicar(cfg, autorizacion, aviso)
                resumen["avisos"] += 1
            except avisos.AvisoError as e:
                log.warning("Monitoreo %s: no se publico %s: %s", empr_id, c.clave, e)
                resumen["sin_publicar"] += 1
        res.respuesta = (f"{resumen['hallazgos']} hallazgo(s), {resumen['avisos']} aviso(s) publicado(s), "
                         f"{resumen['sin_publicar']} sin publicar")
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
