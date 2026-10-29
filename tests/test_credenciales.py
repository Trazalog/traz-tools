"""Token de maquina por empresa (ADR-A10, AGENTE-AS-03), contra un Dnato simulado.

La emision real en Dnato espera la aprobacion del analisis de impacto; este
lado (credencial cifrada -> token -> cache) se prueba con respx.
"""
from __future__ import annotations

from dataclasses import replace
from urllib.parse import parse_qs

import httpx
import pytest
import respx

from agente import credenciales, rag
from agente.config import Config

DNATO = "http://dnato.prueba/oauth/token"
CLAVE = "clave-de-prueba"
EMPRESA = 900001
OTRA = 900002


def _cfg(**kw) -> Config:
    return replace(Config(), dnato_token_url=kw.get("url", DNATO),
                   clave_credenciales=kw.get("clave", CLAVE))


async def _sembrar(con, empr_id=EMPRESA, client_id="agente-900001", secreto="s3creto"):
    async with con.cursor() as cur:
        await cur.execute(f"SET LOCAL agente.empr_id = '{empr_id}'")
        await cur.execute(
            "INSERT INTO agente.credencial_empresa (empr_id, client_id, secreto_cifrado) "
            "VALUES (%s, %s, pgp_sym_encrypt(%s, %s)) ON CONFLICT (empr_id) DO UPDATE SET "
            "client_id = EXCLUDED.client_id, secreto_cifrado = EXCLUDED.secreto_cifrado, activo = true",
            (empr_id, client_id, secreto, CLAVE))


class Reloj:
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t


@respx.mock
async def test_pide_el_token_con_client_credentials_y_el_secreto_descifrado(con_admin):
    await _sembrar(con_admin)
    ruta = respx.post(DNATO).respond(json={"access_token": "jwt-1", "expires_in": 900})

    auth = await credenciales.TokenMaquina(_cfg()).autorizacion(con_admin, EMPRESA)

    assert auth == "Bearer jwt-1"
    enviado = parse_qs(ruta.calls[0].request.content.decode())
    assert enviado == {"grant_type": ["client_credentials"], "client_id": ["agente-900001"],
                       "client_secret": ["s3creto"]}


@respx.mock
async def test_el_pedido_no_lleva_empr_id(con_admin):
    """El empr_id lo pone Dnato a partir del cliente: no es un parametro."""
    await _sembrar(con_admin)
    ruta = respx.post(DNATO).respond(json={"access_token": "jwt", "expires_in": 900})
    await credenciales.TokenMaquina(_cfg()).autorizacion(con_admin, EMPRESA)
    assert "empr_id" not in ruta.calls[0].request.content.decode()


@respx.mock
async def test_usa_la_cache_hasta_un_minuto_antes_de_vencer(con_admin):
    await _sembrar(con_admin)
    ruta = respx.post(DNATO).mock(side_effect=[
        httpx.Response(200, json={"access_token": "jwt-1", "expires_in": 900}),
        httpx.Response(200, json={"access_token": "jwt-2", "expires_in": 900}),
    ])
    reloj = Reloj()
    tm = credenciales.TokenMaquina(_cfg(), reloj=reloj)

    assert await tm.autorizacion(con_admin, EMPRESA) == "Bearer jwt-1"
    reloj.t += 900 - credenciales.MARGEN_SEGUNDOS - 1
    assert await tm.autorizacion(con_admin, EMPRESA) == "Bearer jwt-1"
    reloj.t += 2
    assert await tm.autorizacion(con_admin, EMPRESA) == "Bearer jwt-2"
    assert ruta.call_count == 2


async def test_con_otra_clave_no_se_puede_descifrar(con_admin):
    import psycopg
    await _sembrar(con_admin)
    with pytest.raises(psycopg.Error):
        await credenciales.TokenMaquina(_cfg(clave="otra-clave")).autorizacion(con_admin, EMPRESA)


async def test_una_empresa_sin_credencial_no_obtiene_token(con_admin):
    async with con_admin.cursor() as cur:
        await cur.execute("SET LOCAL agente.empr_id = '900002'")
        await cur.execute("DELETE FROM agente.credencial_empresa WHERE empr_id = %s", (OTRA,))
    with pytest.raises(credenciales.CredencialError, match="no tiene credencial"):
        await credenciales.TokenMaquina(_cfg()).autorizacion(con_admin, OTRA)


@respx.mock
async def test_un_rechazo_de_dnato_es_un_error_claro(con_admin):
    await _sembrar(con_admin)
    respx.post(DNATO).respond(400, json={"error": "invalid_client"})
    with pytest.raises(credenciales.CredencialError, match="400"):
        await credenciales.TokenMaquina(_cfg()).autorizacion(con_admin, EMPRESA)


def test_sin_url_o_sin_clave_no_esta_disponible():
    assert not credenciales.TokenMaquina(_cfg(url="")).disponible()
    assert not credenciales.TokenMaquina(_cfg(clave="")).disponible()


# ------------------------------------------- con el usuario del orquestador
async def _conectar_o_saltear():
    cfg = Config()
    if not cfg.db_password:
        pytest.skip("Sin AGENTE_DB_PASSWORD")
    try:
        c = await rag.abrir(cfg)
    except Exception as e:  # noqa: BLE001
        pytest.skip(f"Base no disponible: {e}")
    async with c.cursor() as cur:
        await cur.execute("SELECT to_regclass('agente.credencial_empresa') AS t")
        if not (await cur.fetchone())["t"]:
            await c.close()
            pytest.skip("Falta aplicar 018-avisos.sql")
    return c


async def test_el_runtime_no_puede_escribir_credenciales():
    import psycopg
    con = await _conectar_o_saltear()
    try:
        await rag.fijar_empresa(con, EMPRESA)
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            async with con.cursor() as cur:
                await cur.execute("INSERT INTO agente.credencial_empresa (empr_id, client_id, secreto_cifrado) "
                                  "VALUES (%s, 'x-robado', 'x')", (EMPRESA,))
    finally:
        await con.rollback()
        await con.close()


async def test_la_lista_de_empresas_no_expone_secretos():
    con = await _conectar_o_saltear()
    try:
        async with con.cursor() as cur:
            await cur.execute("SELECT * FROM agente.empresas_con_credencial() LIMIT 1")
            assert [d.name for d in cur.description] == ["empresas_con_credencial"]
    finally:
        await con.close()
