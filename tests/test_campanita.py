"""La campanita: los avisos de cada usuario (AGENTE-AS-03)."""
from __future__ import annotations

import base64
import json
import uuid

import pytest
from httpx import ASGITransport, AsyncClient

EMPRESA = 900001


def _jwt(**claims) -> str:
    def b64(d):
        return base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip("=")
    return f"Bearer {b64({'alg': 'none'})}.{b64(claims)}.firma"


async def _aviso(con, empr_id, **kw):
    async with con.cursor() as cur:
        await cur.execute(f"SET LOCAL agente.empr_id = '{empr_id}'")
        await cur.execute(
            "INSERT INTO agente.notificacion (empr_id, usuario, rol_destino, tipo, titulo, cuerpo) "
            "VALUES (%s, %s, %s, 'stock_critico', %s, 'detalle') RETURNING notificacion_id",
            (empr_id, kw.get("usuario"), kw.get("rol"), kw["titulo"]))
        return (await cur.fetchone())["notificacion_id"]


@pytest.fixture
def api():
    import agente.api as mod
    return AsyncClient(transport=ASGITransport(app=mod.app), base_url="http://t")


async def test_cada_uno_ve_solo_los_suyos(con_admin, api):
    ana, beto = f"ana-{uuid.uuid4().hex[:6]}", f"beto-{uuid.uuid4().hex[:6]}"
    await _aviso(con_admin, EMPRESA, usuario=ana, titulo="para ana")
    await _aviso(con_admin, EMPRESA, usuario=beto, titulo="para beto")
    await _aviso(con_admin, 900002, usuario=ana, titulo="otra empresa")
    await con_admin.commit()

    r = await api.get("/notificaciones", headers={"Authorization": _jwt(empr_id=EMPRESA, sub=ana, role="4")})
    titulos = [n["titulo"] for n in r.json()["notificaciones"]]
    assert titulos == ["para ana"] and r.json()["sin_leer"] == 1


async def test_los_dirigidos_a_admin_solo_los_ve_un_administrador(con_admin, api):
    marca = f"para admins {uuid.uuid4().hex[:6]}"
    await _aviso(con_admin, EMPRESA, rol="admin", titulo=marca)
    await con_admin.commit()
    admin = await api.get("/notificaciones", headers={"Authorization": _jwt(empr_id=EMPRESA, sub="x", role="1")})
    comun = await api.get("/notificaciones", headers={"Authorization": _jwt(empr_id=EMPRESA, sub="x", role="4")})
    assert marca in [n["titulo"] for n in admin.json()["notificaciones"]]
    assert marca not in [n["titulo"] for n in comun.json()["notificaciones"]]


async def test_marcar_leido_solo_el_propio(con_admin, api):
    ana = f"ana-{uuid.uuid4().hex[:6]}"
    nid = await _aviso(con_admin, EMPRESA, usuario=ana, titulo="leer")
    await con_admin.commit()
    ajeno = await api.post("/notificaciones/leida", json={"notificacion_id": nid},
                           headers={"Authorization": _jwt(empr_id=EMPRESA, sub="beto", role="4")})
    assert ajeno.status_code == 404
    ok = await api.post("/notificaciones/leida", json={"notificacion_id": nid},
                        headers={"Authorization": _jwt(empr_id=EMPRESA, sub=ana, role="4")})
    assert ok.status_code == 200
    r = await api.get("/notificaciones", headers={"Authorization": _jwt(empr_id=EMPRESA, sub=ana, role="4")})
    assert r.json()["sin_leer"] == 0
