"""Monitoreo operativo: avisos proactivos (AGENTE-AS-03), con MCP simulado.

Desde ADR-015 el monitoreo no escribe avisos en la base del agente: los
publica en Tools (POST /avisos de toolsNTFAPI). Aca el API de avisos se
simula; que ntf no duplique ni cruce empresas lo prueban tests/test_ntf.py.
"""
from __future__ import annotations

import dataclasses
from datetime import date

import httpx
import pytest

from agente import avisos, monitoreo
from agente.config import Config
from test_orquestador import MCPFalso, _parchar
from test_sugerencias import CERTS, LOTES, STOCK

EMPRESA = 900001
HOY = date(2026, 10, 27)
URL = "https://apim.prueba/tools/ntf/1.0/avisos"


class APIAvisosFalso:
    """Hace de toolsNTFAPI: guarda lo publicado y, como ntf, devuelve el mismo
    aviso_id para la misma dedupe_key."""

    def __init__(self, status: int = 200):
        self.status = status
        self.pedidos: list[tuple[str, dict]] = []
        self.por_clave: dict[str, int] = {}

    def transporte(self) -> httpx.MockTransport:
        def manejar(req: httpx.Request) -> httpx.Response:
            import json
            cuerpo = json.loads(req.content)
            self.pedidos.append((req.headers.get("Authorization"), cuerpo))
            if self.status != 200:
                return httpx.Response(self.status, json={"error": "x"})
            clave = cuerpo.get("dedupe_key") or str(len(self.pedidos))
            aviso_id = self.por_clave.setdefault(clave, len(self.por_clave) + 1)
            return httpx.Response(200, json={"respuesta": {"aviso_id": str(aviso_id)}})
        return httpx.MockTransport(manejar)


def _mcp(monkeypatch, llm_falso):
    mcp = MCPFalso(salidas={"alm_get_stock": STOCK, "alm_get_vencimientos": LOTES,
                            "pan_get_certificaciones": CERTS})
    _parchar(monkeypatch, llm_falso([]), mcp)
    monkeypatch.setattr("agente.monitoreo.ClienteMCP", lambda cfg, auth: mcp)
    return mcp


def _api(monkeypatch, status: int = 200) -> APIAvisosFalso:
    api = APIAvisosFalso(status)
    original = avisos.publicar

    async def publicar(cfg, autorizacion, aviso, *, cliente=None):
        async with httpx.AsyncClient(transport=api.transporte()) as c:
            return await original(cfg, autorizacion, aviso, cliente=c)

    monkeypatch.setattr("agente.monitoreo.avisos.publicar", publicar)
    return api


def _cfg() -> Config:
    return dataclasses.replace(Config(), avisos_url=URL)


async def test_publica_los_hallazgos_firmados_por_el_agente(con_admin, monkeypatch, llm_falso):
    _mcp(monkeypatch, llm_falso)
    api = _api(monkeypatch)

    r = await monitoreo.monitorear_empresa(con_admin, _cfg(), EMPRESA, "Bearer maquina", hoy=HOY)

    assert r["avisos"] == r["hallazgos"] == len(api.pedidos) > 0
    auth, primero = api.pedidos[0]
    assert auth == "Bearer maquina", "con el token de maquina de la empresa"
    assert "empr_id" not in primero, "la empresa la pone el API a partir del token"
    assert primero["origen"] == "agente" and primero["emisor"] == "Quirqui"
    assert "destinatarios" not in primero, "a quien le llega lo deciden las suscripciones de ntf"
    severidades = {p["tipo"]: p["severidad"] for _, p in api.pedidos if p["entidad_tipo"] == "lote_vencido"}
    assert severidades == {"material_por_vencer": "critica"}


async def test_la_clave_lleva_el_dia_para_no_repetir(con_admin, monkeypatch, llm_falso):
    _mcp(monkeypatch, llm_falso)
    api = _api(monkeypatch)

    await monitoreo.monitorear_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=HOY)
    await monitoreo.monitorear_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=HOY)

    claves = [p["dedupe_key"] for _, p in api.pedidos]
    assert all(c.endswith(":2026-10-27") for c in claves)
    assert len(set(claves)) == len(claves) // 2, "la segunda corrida repite las mismas claves: ntf no duplica"


async def test_sin_url_de_avisos_no_publica_y_queda_en_la_corrida(con_admin, monkeypatch, llm_falso):
    _mcp(monkeypatch, llm_falso)
    api = _api(monkeypatch)
    r = await monitoreo.monitorear_empresa(con_admin, Config(), EMPRESA, "Bearer m", hoy=HOY)
    assert api.pedidos == []
    assert r["avisos"] == 0 and r["sin_publicar"] == r["hallazgos"] > 0


async def test_si_el_api_rechaza_se_cuenta_y_sigue(con_admin, monkeypatch, llm_falso):
    _mcp(monkeypatch, llm_falso)
    _api(monkeypatch, status=503)
    r = await monitoreo.monitorear_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=HOY)
    assert r["error"] is None, "un aviso rechazado no corta el monitoreo"
    assert r["avisos"] == 0 and r["sin_publicar"] == r["hallazgos"] > 0


async def test_usa_solo_tools_de_lectura_de_la_lista_blanca(con_admin, monkeypatch, llm_falso):
    mcp = _mcp(monkeypatch, llm_falso)
    _api(monkeypatch)
    await monitoreo.monitorear_empresa(con_admin, _cfg(), EMPRESA, "Bearer m", hoy=HOY)
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


# ---------------------------------------------------------------- agente/avisos.py
async def test_publicar_sin_url_falla_claro():
    with pytest.raises(avisos.AvisoError, match="AGENTE_AVISOS_URL"):
        await avisos.publicar(Config(), "Bearer m", avisos.Aviso(tipo="x1", titulo="t"))


async def test_publicar_respuesta_rara_es_error():
    def manejar(_req):
        return httpx.Response(200, json={"otra": "cosa"})
    async with httpx.AsyncClient(transport=httpx.MockTransport(manejar)) as c:
        with pytest.raises(avisos.AvisoError, match="inesperada"):
            await avisos.publicar(_cfg(), "Bearer m", avisos.Aviso(tipo="x1", titulo="t"), cliente=c)
