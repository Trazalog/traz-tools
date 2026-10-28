"""Monitoreo operativo: avisos proactivos (AGENTE-AS-03), con MCP simulado.

Siembra destinatarios como administrador (con_admin): el runtime no puede
configurar quien recibe los avisos de otra empresa, y esta bien.
"""
from __future__ import annotations

import uuid
from datetime import date

from agente import monitoreo
from agente.config import Config
from test_orquestador import MCPFalso, _parchar
from test_sugerencias import CERTS, LOTES, STOCK

EMPRESA = 900001
HOY = date(2026, 10, 27)


async def _destinatario(con, tipo: str, usuario: str):
    async with con.cursor() as cur:
        await cur.execute("SET LOCAL agente.empr_id = '900001'")
        await cur.execute("DELETE FROM agente.destinatario_alerta WHERE empr_id = %s", (EMPRESA,))
        await cur.execute("INSERT INTO agente.destinatario_alerta (empr_id, tipo_alerta, usuario, etiqueta) "
                          "VALUES (%s, %s, %s, 'prueba')", (EMPRESA, tipo, usuario))


async def _avisos(con, usuario: str) -> list[dict]:
    async with con.cursor() as cur:
        await cur.execute("SET LOCAL agente.empr_id = '900001'")
        await cur.execute("SELECT tipo, severidad, titulo FROM agente.notificacion "
                          "WHERE usuario = %s ORDER BY notificacion_id", (usuario,))
        return await cur.fetchall()


def _mcp(monkeypatch, llm_falso):
    mcp = MCPFalso(salidas={"alm_get_stock": STOCK, "alm_get_vencimientos": LOTES,
                            "pan_get_certificaciones": CERTS})
    _parchar(monkeypatch, llm_falso([]), mcp)
    monkeypatch.setattr("agente.monitoreo.ClienteMCP", lambda cfg, auth: mcp)
    return mcp


async def test_avisa_a_los_destinatarios_del_tipo(con_admin, monkeypatch, llm_falso):
    usuario = f"jefe-deposito-{uuid.uuid4().hex[:6]}"
    await _destinatario(con_admin, "material_por_vencer", usuario)
    _mcp(monkeypatch, llm_falso)

    r = await monitoreo.monitorear_empresa(con_admin, Config(), EMPRESA, "Bearer maquina", hoy=HOY)

    avisos = await _avisos(con_admin, usuario)
    assert [a["severidad"] for a in avisos] == ["critica", "aviso"], "lote vencido y lote crítico"
    assert {a["tipo"] for a in avisos} == {"material_por_vencer"}
    assert r["sin_destinatario"] > 0, "stock y certificaciones no tienen destinatario: silencio"


async def test_no_repite_el_mismo_aviso_el_mismo_dia(con_admin, monkeypatch, llm_falso):
    usuario = f"jefe-{uuid.uuid4().hex[:6]}"
    await _destinatario(con_admin, "*", usuario)
    _mcp(monkeypatch, llm_falso)

    primero = await monitoreo.monitorear_empresa(con_admin, Config(), EMPRESA, "Bearer m", hoy=HOY)
    segundo = await monitoreo.monitorear_empresa(con_admin, Config(), EMPRESA, "Bearer m", hoy=HOY)

    assert primero["avisos"] > 0 and segundo["avisos"] == 0
    assert len(await _avisos(con_admin, usuario)) == primero["avisos"]


async def test_sin_destinatarios_no_avisa_a_nadie(con_admin, monkeypatch, llm_falso):
    async with con_admin.cursor() as cur:
        await cur.execute("SET LOCAL agente.empr_id = '900001'")
        await cur.execute("DELETE FROM agente.destinatario_alerta WHERE empr_id = %s", (EMPRESA,))
    _mcp(monkeypatch, llm_falso)
    r = await monitoreo.monitorear_empresa(con_admin, Config(), EMPRESA, "Bearer m", hoy=HOY)
    assert r["avisos"] == 0 and r["sin_destinatario"] == r["hallazgos"] > 0


async def test_usa_solo_tools_de_lectura_de_la_lista_blanca(con_admin, monkeypatch, llm_falso):
    mcp = _mcp(monkeypatch, llm_falso)
    await monitoreo.monitorear_empresa(con_admin, Config(), EMPRESA, "Bearer m", hoy=HOY)
    assert {ll.tool for ll in mcp.llamadas} == {"alm_get_stock", "alm_get_vencimientos",
                                                 "pan_get_certificaciones"}


async def test_una_empresa_sin_credencial_no_frena_a_las_demas(con_admin, monkeypatch, llm_falso):
    from agente import credenciales
    _mcp(monkeypatch, llm_falso)

    async def empresas(_con):
        return [900002, EMPRESA]

    async def autorizacion(self, _con, empr_id):
        if empr_id == 900002:
            raise credenciales.CredencialError("La empresa 900002 no tiene credencial de maquina activa")
        return "Bearer maquina"

    monkeypatch.setattr("agente.monitoreo.credenciales.empresas", empresas)
    monkeypatch.setattr("agente.monitoreo.credenciales.TokenMaquina.autorizacion", autorizacion)

    r = await monitoreo.correr(Config())

    assert r[0] == {"empr_id": 900002, "error": "La empresa 900002 no tiene credencial de maquina activa"}
    assert r[1]["empr_id"] == EMPRESA and r[1]["error"] is None
