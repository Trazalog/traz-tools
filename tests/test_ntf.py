"""Esquema ntf: el mecanismo unico de avisos de Tools (ADR-015).

Corre contra una base PostgreSQL con ntf_avisos.sql aplicado, idealmente la
version de produccion (11). Se saltea si no esta NTF_TEST_DSN, por ejemplo:

    NTF_TEST_DSN="host=127.0.0.1 port=55411 dbname=trazalog_tools user=postgres password=..."

Cada test usa una empresa propia (ids altos, aleatorios) para no pisarse.
"""
from __future__ import annotations

import asyncio
import os
import random

import psycopg
import pytest
from psycopg.rows import dict_row

DSN = os.environ.get("NTF_TEST_DSN")
pytestmark = pytest.mark.skipif(not DSN, reason="Sin NTF_TEST_DSN: se saltean los tests de ntf")


@pytest.fixture
async def db():
    c = await psycopg.AsyncConnection.connect(DSN, row_factory=dict_row, autocommit=True)
    try:
        yield c
    finally:
        await c.close()


@pytest.fixture
def empresa():
    return random.randint(800_000, 899_999)


async def _uno(db, sql, *args):
    async with db.cursor() as cur:
        await cur.execute(sql, args)
        return await cur.fetchone()


async def _exec(db, sql, *args):
    async with db.cursor() as cur:
        await cur.execute(sql, args)


async def _todos(db, sql, *args):
    async with db.cursor() as cur:
        await cur.execute(sql, args)
        return await cur.fetchall()


async def _dispositivo(db, empresa, usuario, token):
    await _uno(db, "INSERT INTO ntf.dispositivo (empr_id, usuario, token) VALUES (%s, %s, %s) "
                   "RETURNING dispositivo_id", empresa, usuario, token)


async def _publicar(db, empresa, **kw):
    f = await _uno(db, """
        SELECT ntf.publicar(p_empr_id => %s, p_origen => %s, p_tipo => %s, p_titulo => %s,
                            p_cuerpo => %s, p_destinatarios => %s, p_dedupe_key => %s,
                            p_token_directo => %s, p_emisor => %s) AS id""",
        empresa, kw.get("origen", "alm"), kw.get("tipo", "stock_critico"), kw.get("titulo", "Reponer filtro"),
        kw.get("cuerpo", "Quedan 4"), kw.get("destinatarios"), kw.get("dedupe"), kw.get("token_directo"),
        kw.get("emisor", "quirqui"))
    return f["id"]


# ================================================================ version
async def test_corre_en_la_version_de_produccion(db):
    """Produccion es PostgreSQL 11.7: el esquema tiene que andar ahi."""
    v = (await _uno(db, "SHOW server_version_num"))["server_version_num"]
    if int(v) >= 120000:
        pytest.skip(f"La base de prueba es {v}; la verificacion de compatibilidad corre contra PG 11")
    assert int(v) < 120000


# ================================================================ publicar
async def test_publicar_crea_aviso_destinos_y_un_envio_por_dispositivo(db, empresa):
    await _dispositivo(db, empresa, "ana", f"tok-ana-cel-{empresa}")
    await _dispositivo(db, empresa, "ana", f"tok-ana-pc-{empresa}")
    await _dispositivo(db, empresa, "beto", f"tok-beto-{empresa}")

    aviso = await _publicar(db, empresa, destinatarios=["ana", "beto"])

    destinos = await _todos(db, "SELECT usuario FROM ntf.destino WHERE aviso_id = %s ORDER BY 1", aviso)
    envios = await _todos(db, "SELECT estado FROM ntf.envio WHERE aviso_id = %s", aviso)
    assert [d["usuario"] for d in destinos] == ["ana", "beto"]
    assert len(envios) == 3 and {e["estado"] for e in envios} == {"pendiente"}


async def test_sin_destinatarios_usa_los_suscriptos_al_tipo(db, empresa):
    await _uno(db, "INSERT INTO ntf.suscripcion (empr_id, tipo, usuario) VALUES (%s, 'stock_critico', 'deposito'), "
                   "(%s, '*', 'jefe'), (%s, 'lote_vencido', 'otro') RETURNING 1", empresa, empresa, empresa)
    aviso = await _publicar(db, empresa)
    destinos = {d["usuario"] for d in await _todos(db, "SELECT usuario FROM ntf.destino WHERE aviso_id = %s", aviso)}
    assert destinos == {"deposito", "jefe"}


async def test_la_misma_dedupe_key_no_duplica_nada(db, empresa):
    await _dispositivo(db, empresa, "ana", f"tok-dup-{empresa}")
    a = await _publicar(db, empresa, destinatarios=["ana"], dedupe="lote:1:2026-10-28")
    b = await _publicar(db, empresa, destinatarios=["ana"], dedupe="lote:1:2026-10-28")
    assert a == b
    assert (await _uno(db, "SELECT count(*) n FROM ntf.envio WHERE aviso_id = %s", a))["n"] == 1


async def test_el_dispositivo_de_otra_empresa_no_recibe(db, empresa):
    """El mismo nick en otra empresa es otra persona."""
    await _dispositivo(db, empresa + 1, "ana", f"tok-otra-{empresa}")
    aviso = await _publicar(db, empresa, destinatarios=["ana"])
    assert (await _uno(db, "SELECT count(*) n FROM ntf.envio WHERE aviso_id = %s", aviso))["n"] == 0


async def test_un_aviso_de_asset_lleva_su_token_directo(db, empresa):
    aviso = await _publicar(db, empresa, origen="asset", destinatarios=["asset:17"],
                            token_directo="tok-del-data-json")
    e = await _uno(db, "SELECT token_directo, dispositivo_id FROM ntf.envio WHERE aviso_id = %s", aviso)
    assert e["token_directo"] == "tok-del-data-json" and e["dispositivo_id"] is None


# ================================================================ tomar
async def _pendientes(db, empresa, n):
    await _dispositivo(db, empresa, "ana", f"tok-lote-{empresa}")
    for i in range(n):
        await _publicar(db, empresa, destinatarios=["ana"], dedupe=f"lote:{i}")


async def _tomar_de(db, empresa, lote=500):
    filas = await _todos(db, "SELECT t.envio_id, t.token, t.titulo, t.emisor FROM ntf.tomar_envios(%s) t "
                             "JOIN ntf.aviso a USING (aviso_id) WHERE a.empr_id = %s", lote, empresa)
    return filas


async def test_tomar_marca_enviando_y_trae_lo_necesario_para_mandar(db, empresa):
    await _pendientes(db, empresa, 2)
    tomados = await _tomar_de(db, empresa)
    assert len(tomados) == 2
    assert tomados[0]["token"] == f"tok-lote-{empresa}" and tomados[0]["emisor"] == "quirqui"
    estados = {e["estado"] for e in await _todos(
        db, "SELECT e.estado FROM ntf.envio e JOIN ntf.aviso a USING (aviso_id) WHERE a.empr_id = %s", empresa)}
    assert estados == {"enviando"}
    assert await _tomar_de(db, empresa) == [], "lo tomado no se vuelve a tomar"


async def test_dos_transportes_a_la_vez_nunca_toman_el_mismo_envio(empresa):
    """El problema de los duplicados, con dos conexiones concurrentes reales."""
    preparar = await psycopg.AsyncConnection.connect(DSN, row_factory=dict_row, autocommit=True)
    await _pendientes(preparar, empresa, 40)
    await preparar.close()

    async def transporte():
        c = await psycopg.AsyncConnection.connect(DSN, row_factory=dict_row)
        try:
            ids = []
            for _ in range(10):
                async with c.cursor() as cur:
                    await cur.execute("SELECT t.envio_id FROM ntf.tomar_envios(3) t JOIN ntf.aviso a "
                                      "USING (aviso_id) WHERE a.empr_id = %s", (empresa,))
                    ids += [f["envio_id"] for f in await cur.fetchall()]
                await c.commit()
            return ids
        finally:
            await c.close()

    a, b = await asyncio.gather(transporte(), transporte())
    assert not set(a) & set(b), "un envio fue tomado por los dos transportes"
    assert len(a) == len(set(a)) and len(b) == len(set(b))


async def test_lo_que_quedo_enviando_mas_de_10_minutos_vuelve_a_la_cola(db, empresa):
    await _pendientes(db, empresa, 1)
    (t,) = await _tomar_de(db, empresa)
    await _uno(db, "UPDATE ntf.envio SET fec_tomado = now() - interval '11 minutes' WHERE envio_id = %s "
                   "RETURNING 1", t["envio_id"])
    assert [x["envio_id"] for x in await _tomar_de(db, empresa)] == [t["envio_id"]]


# ================================================================ marcar
async def test_enviado_queda_con_fecha(db, empresa):
    await _pendientes(db, empresa, 1)
    (t,) = await _tomar_de(db, empresa)
    assert (await _uno(db, "SELECT ntf.marcar_envio(%s, 'enviado') r", t["envio_id"]))["r"] == "enviado"
    e = await _uno(db, "SELECT estado, fec_envio FROM ntf.envio WHERE envio_id = %s", t["envio_id"])
    assert e["estado"] == "enviado" and e["fec_envio"] is not None


async def test_una_respuesta_repetida_no_pisa_nada(db, empresa):
    await _pendientes(db, empresa, 1)
    (t,) = await _tomar_de(db, empresa)
    await _uno(db, "SELECT ntf.marcar_envio(%s, 'enviado')", t["envio_id"])
    assert (await _uno(db, "SELECT ntf.marcar_envio(%s, 'fallido', 'tarde') r", t["envio_id"]))["r"] == "ignorado"


async def test_fallido_reintenta_y_al_cuarto_queda_fallido(db, empresa):
    await _pendientes(db, empresa, 1)
    resultados = []
    for _ in range(4):
        await _uno(db, "UPDATE ntf.envio e SET proximo_intento = now() FROM ntf.aviso a "
                       "WHERE a.aviso_id = e.aviso_id AND a.empr_id = %s RETURNING 1", empresa)
        (t,) = await _tomar_de(db, empresa)
        resultados.append((await _uno(db, "SELECT ntf.marcar_envio(%s, 'fallido', 'HTTP 503') r",
                                      t["envio_id"]))["r"])
    assert resultados == ["reintenta", "reintenta", "reintenta", "fallido"]


async def test_reintentar_espera_antes_de_volver_a_tomar(db, empresa):
    await _pendientes(db, empresa, 1)
    (t,) = await _tomar_de(db, empresa)
    await _uno(db, "SELECT ntf.marcar_envio(%s, 'fallido', 'HTTP 503')", t["envio_id"])
    assert await _tomar_de(db, empresa) == [], "no se reintenta en el acto"


async def test_un_token_que_ya_no_existe_desactiva_el_dispositivo(db, empresa):
    await _pendientes(db, empresa, 1)
    (t,) = await _tomar_de(db, empresa)
    await _uno(db, "SELECT ntf.marcar_envio(%s, 'descartado', 'UNREGISTERED')", t["envio_id"])
    d = await _uno(db, "SELECT activo FROM ntf.dispositivo WHERE token = %s", f"tok-lote-{empresa}")
    assert d["activo"] is False


# ================================================================ depurar
async def test_depurar_borra_lo_viejo_y_deja_lo_pendiente(db, empresa):
    await _pendientes(db, empresa, 3)
    tomados = await _tomar_de(db, empresa)
    await _uno(db, "SELECT ntf.marcar_envio(%s, 'enviado')", tomados[0]["envio_id"])
    await _uno(db, "UPDATE ntf.destino d SET leido = true, fec_lectura = now() FROM ntf.aviso a "
                   "WHERE a.aviso_id = d.aviso_id AND a.empr_id = %s RETURNING 1", empresa)
    await _uno(db, "UPDATE ntf.aviso SET fec_alta = now() - interval '100 days' WHERE empr_id = %s RETURNING 1", empresa)
    await _uno(db, "UPDATE ntf.envio e SET fec_alta = now() - interval '100 days' FROM ntf.aviso a "
                   "WHERE a.aviso_id = e.aviso_id AND a.empr_id = %s RETURNING 1", empresa)
    # Los otros dos siguen 'enviando': su aviso no se puede borrar.
    await _uno(db, "SELECT ntf.depurar()")
    quedan = await _todos(db, "SELECT e.estado FROM ntf.envio e JOIN ntf.aviso a USING (aviso_id) "
                              "WHERE a.empr_id = %s", empresa)
    assert sorted(x["estado"] for x in quedan) == ["enviando", "enviando"]
    avisos = (await _uno(db, "SELECT count(*) n FROM ntf.aviso WHERE empr_id = %s", empresa))["n"]
    assert avisos == 2, "el aviso ya enviado y leido se fue; los que tienen envios en curso quedan"


# ================================================================ permisos
async def test_el_rol_del_transporte_no_ve_las_tablas(db):
    for tabla in ("aviso", "destino", "dispositivo", "envio", "suscripcion"):
        r = await _uno(db, "SELECT has_table_privilege('ntf_transporte', %s, 'SELECT') v", f"ntf.{tabla}")
        assert r["v"] is False, tabla
    r = await _uno(db, "SELECT has_function_privilege('ntf_transporte', 'ntf.tomar_envios(integer)', 'EXECUTE') v")
    assert r["v"] is True
    r = await _uno(db, "SELECT has_function_privilege('ntf_transporte', "
                       "'ntf.publicar(integer,text,text,text,text,text[],text,text,text,text,text,text,timestamptz,text)', "
                       "'EXECUTE') v")
    assert r["v"] is False, "el transporte no publica avisos"
    r = await _uno(db, "SELECT has_function_privilege('ntf_transporte', "
                       "'ntf.publicar_asset(bigint,integer,integer,text)', 'EXECUTE') v")
    assert r["v"] is True, "el puente de AssetPlanner publica solo por publicar_asset"
    for f in ("ntf.mis_avisos(integer,text,integer)", "ntf.marcar_leido(integer,text,bigint)",
              "ntf.registrar_dispositivo(integer,text,text,text)"):
        r = await _uno(db, "SELECT has_function_privilege('ntf_transporte', %s, 'EXECUTE') v", f)
        assert r["v"] is False, f


# ================================================================ campanita (API)
async def test_mis_avisos_trae_solo_los_propios_y_los_no_leidos_primero(db, empresa):
    viejo = await _publicar(db, empresa, destinatarios=["ana"], titulo="Viejo")
    await _uno(db, "SELECT ntf.marcar_leido(%s, 'ana', %s)", empresa, viejo)
    nuevo = await _publicar(db, empresa, destinatarios=["ana"], titulo="Nuevo")
    await _publicar(db, empresa, destinatarios=["beto"], titulo="De beto")
    await _publicar(db, empresa + 1, destinatarios=["ana"], titulo="Otra empresa")

    avisos = await _todos(db, "SELECT * FROM ntf.mis_avisos(%s, 'ana')", empresa)
    assert [a["aviso_id"] for a in avisos] == [nuevo, viejo]
    assert [a["leido"] for a in avisos] == [False, True]
    assert (await _uno(db, "SELECT ntf.no_leidos(%s, 'ana') n", empresa))["n"] == 1


async def test_marcar_leido_no_toca_avisos_ajenos(db, empresa):
    de_beto = await _publicar(db, empresa, destinatarios=["beto"])
    n = (await _uno(db, "SELECT ntf.marcar_leido(%s, 'ana', %s) n", empresa, de_beto))["n"]
    assert n == 0
    n = (await _uno(db, "SELECT ntf.marcar_leido(%s + 1, 'beto', %s) n", empresa, de_beto))["n"]
    assert n == 0, "con el usuario correcto pero otra empresa tampoco"
    assert (await _uno(db, "SELECT ntf.no_leidos(%s, 'beto') n", empresa))["n"] == 1


async def test_marcar_leido_sin_id_marca_todos_los_propios(db, empresa):
    for _ in range(3):
        await _publicar(db, empresa, destinatarios=["ana", "beto"])
    n = (await _uno(db, "SELECT ntf.marcar_leido(%s, 'ana') n", empresa))["n"]
    assert n == 3
    assert (await _uno(db, "SELECT ntf.no_leidos(%s, 'beto') n", empresa))["n"] == 3


async def test_un_aviso_vencido_no_aparece(db, empresa):
    await _uno(db, "SELECT ntf.publicar(p_empr_id => %s, p_origen => 'alm', p_tipo => 'oferta', p_titulo => 'Ya fue', "
                   "p_destinatarios => ARRAY['ana'], p_vence_en => now() - interval '1 minute')", empresa)
    assert await _todos(db, "SELECT * FROM ntf.mis_avisos(%s, 'ana')", empresa) == []


# ================================================================ dispositivos (API)
async def test_registrar_dispositivo_y_recibir_el_proximo_aviso(db, empresa):
    token = f"fcm-token-largo-de-prueba-{empresa}"
    d1 = (await _uno(db, "SELECT ntf.registrar_dispositivo(%s, 'ana', %s) id", empresa, token))["id"]
    d2 = (await _uno(db, "SELECT ntf.registrar_dispositivo(%s, 'ana', %s) id", empresa, token))["id"]
    assert d1 == d2, "registrar dos veces el mismo navegador no duplica"
    aviso = await _publicar(db, empresa, destinatarios=["ana"])
    envios = await _todos(db, "SELECT dispositivo_id FROM ntf.envio WHERE aviso_id = %s", aviso)
    assert [e["dispositivo_id"] for e in envios] == [d1]


async def test_el_mismo_navegador_con_otro_usuario_pasa_al_nuevo(db, empresa):
    token = f"fcm-token-compartido-{empresa}"
    await _uno(db, "SELECT ntf.registrar_dispositivo(%s, 'ana', %s)", empresa, token)
    await _uno(db, "SELECT ntf.registrar_dispositivo(%s, 'beto', %s)", empresa, token)
    aviso = await _publicar(db, empresa, destinatarios=["ana"])
    assert await _todos(db, "SELECT 1 FROM ntf.envio WHERE aviso_id = %s", aviso) == [], \
        "a ana ya no le llega al navegador que ahora usa beto"


async def test_baja_dispositivo_solo_el_propio(db, empresa):
    token = f"fcm-token-para-baja-{empresa}"
    await _uno(db, "SELECT ntf.registrar_dispositivo(%s, 'ana', %s)", empresa, token)
    assert (await _uno(db, "SELECT ntf.baja_dispositivo(%s, 'beto', %s) n", empresa, token))["n"] == 0
    assert (await _uno(db, "SELECT ntf.baja_dispositivo(%s, 'ana', %s) n", empresa, token))["n"] == 1
    aviso = await _publicar(db, empresa, destinatarios=["ana"])
    assert await _todos(db, "SELECT 1 FROM ntf.envio WHERE aviso_id = %s", aviso) == []


async def test_registrar_rechaza_un_token_vacio(db, empresa):
    with pytest.raises(psycopg.errors.RaiseException):
        await _uno(db, "SELECT ntf.registrar_dispositivo(%s, 'ana', '  ')", empresa)


# ================================================================ puente de AssetPlanner
_DATA_JSON_ASSET = ('{"registrationToken":"tok-asset-%s","notificationTitle":"Nueva Orden de Trabajo asignada",'
                    '"webPushNotificationBody":"Por favor revise su bandeja.","webPushNotificationIcon":"x.png"}')


async def test_publicar_asset_traduce_la_fila_de_la_cola(db, empresa):
    queue_id = empresa * 10
    aviso = (await _uno(db, "SELECT ntf.publicar_asset(%s, 7, 42, %s) id",
                        queue_id, _DATA_JSON_ASSET % empresa))["id"]
    a = await _uno(db, "SELECT origen, titulo, cuerpo, emisor, dedupe_key FROM ntf.aviso WHERE aviso_id = %s", aviso)
    assert a == {"origen": "asset", "titulo": "Nueva Orden de Trabajo asignada",
                 "cuerpo": "Por favor revise su bandeja.", "emisor": "AssetPlanner",
                 "dedupe_key": f"asset:{queue_id}"}
    envios = await _todos(db, "SELECT token_directo FROM ntf.envio WHERE aviso_id = %s", aviso)
    assert [e["token_directo"] for e in envios] == [f"tok-asset-{empresa}"]
    destinos = await _todos(db, "SELECT usuario FROM ntf.destino WHERE aviso_id = %s", aviso)
    assert [d["usuario"] for d in destinos] == ["asset:42"]


async def test_publicar_asset_dos_veces_la_misma_fila_no_duplica(db, empresa):
    queue_id = empresa * 10 + 1
    a1 = (await _uno(db, "SELECT ntf.publicar_asset(%s, 7, 42, %s) id", queue_id, _DATA_JSON_ASSET % empresa))["id"]
    a2 = (await _uno(db, "SELECT ntf.publicar_asset(%s, 7, 42, %s) id", queue_id, _DATA_JSON_ASSET % empresa))["id"]
    assert a1 == a2
    assert len(await _todos(db, "SELECT 1 FROM ntf.envio WHERE aviso_id = %s", a1)) == 1


async def test_publicar_asset_aguanta_un_json_roto_y_sin_token(db, empresa):
    aviso = (await _uno(db, "SELECT ntf.publicar_asset(%s, 7, 42, 'esto no es json') id", empresa * 10 + 2))["id"]
    a = await _uno(db, "SELECT titulo FROM ntf.aviso WHERE aviso_id = %s", aviso)
    assert a["titulo"] == "Aviso de AssetPlanner"
    assert await _todos(db, "SELECT 1 FROM ntf.envio WHERE aviso_id = %s", aviso) == [], "sin token no hay push"


async def test_publicar_asset_traduce_la_empresa_de_assetplanner(db, empresa):
    """empr_id de AssetPlanner = core.empresas.empr_id_mysql (en la base de prueba se crea la tabla minima)."""
    await _exec(db, "CREATE SCHEMA IF NOT EXISTS core")
    await _exec(db, "CREATE TABLE IF NOT EXISTS core.empresas (empr_id integer, empr_id_mysql integer)")
    mysql = empresa + 5_000_000
    await _exec(db, "INSERT INTO core.empresas (empr_id, empr_id_mysql) VALUES (%s, %s)", empresa, mysql)
    aviso = (await _uno(db, "SELECT ntf.publicar_asset(%s, %s, 42, %s) id",
                        empresa * 10 + 3, mysql, _DATA_JSON_ASSET % empresa))["id"]
    a = await _uno(db, "SELECT empr_id FROM ntf.aviso WHERE aviso_id = %s", aviso)
    assert a["empr_id"] == empresa
