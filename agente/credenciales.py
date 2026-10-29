"""Token de maquina por empresa (ADR-A10, AGENTE-AS-03).

Los jobs de los agentes (avisos proactivos, mediciones) corren sin nadie
conectado, asi que no tienen el JWT de un usuario. Piden uno propio a Dnato por
client_credentials, con el client_id y el secreto de cada empresa.

    Credencial (agente.credencial_empresa, secreto cifrado)
        -> se descifra con AGENTE_CLAVE_CREDENCIALES (variable de entorno)
        -> POST a Dnato /oauth/token  grant_type=client_credentials
        -> JWT de 15 min con el empr_id de la empresa y token_tipo=maquina
        -> se guarda en memoria hasta un minuto antes de vencer

El empr_id del token lo pone Dnato a partir del cliente, nunca este codigo:
aca solo se elige QUE credencial usar. Y el token sigue pasando por la lista
blanca y el guardian, como el de un usuario.

ESTADO: la emision del lado de Dnato espera la aprobacion de
doc/agente/analisis-impacto-token-maquina.md. Este lado esta listo y probado
contra un Dnato simulado; cuando Dnato emita, alcanza con configurar
AGENTE_DNATO_TOKEN_URL y dar de alta las credenciales.

Alta de una credencial (terminal local o del servidor, con el usuario
curador de la base del agente; el secreto se pide por teclado, no va en la
linea de comandos para que no quede en el historial):

    python -m agente.credenciales alta --empresa 191 --client-id agente-191
    python -m agente.credenciales listar
    python -m agente.credenciales baja --empresa 191
"""
from __future__ import annotations

import argparse
import asyncio
import getpass
import sys
import time
from dataclasses import dataclass

import httpx
import psycopg

from . import rag
from .config import Config, cargar

# Se renueva un poco antes de que venza, para no usar un token en su ultimo segundo.
MARGEN_SEGUNDOS = 60


class CredencialError(RuntimeError):
    pass


@dataclass
class _EnCache:
    autorizacion: str
    vence: float


class TokenMaquina:
    """Pide y guarda el token de maquina de cada empresa."""

    def __init__(self, cfg: Config, *, cliente: httpx.AsyncClient | None = None,
                 reloj=time.monotonic):
        self.cfg = cfg
        self._cliente = cliente
        self._reloj = reloj
        self._cache: dict[int, _EnCache] = {}

    def disponible(self) -> bool:
        return bool(self.cfg.dnato_token_url and self.cfg.clave_credenciales)

    async def autorizacion(self, con: psycopg.AsyncConnection, empr_id: int) -> str:
        """El header Authorization ("Bearer ...") de la empresa."""
        en_cache = self._cache.get(empr_id)
        if en_cache and en_cache.vence > self._reloj():
            return en_cache.autorizacion
        if not self.disponible():
            raise CredencialError("Faltan AGENTE_DNATO_TOKEN_URL o AGENTE_CLAVE_CREDENCIALES")

        client_id, secreto = await _leer(con, empr_id, self.cfg.clave_credenciales)
        datos = await self._pedir(client_id, secreto)
        token = datos.get("access_token")
        if not token:
            raise CredencialError("Dnato no devolvio access_token")
        vida = int(datos.get("expires_in") or 900)
        self._cache[empr_id] = _EnCache(f"Bearer {token}",
                                        self._reloj() + max(vida - MARGEN_SEGUNDOS, 30))
        await _marcar_uso(con, empr_id)
        return self._cache[empr_id].autorizacion

    async def _pedir(self, client_id: str, secreto: str) -> dict:
        propio = self._cliente is None
        cliente = self._cliente or httpx.AsyncClient(timeout=15.0)
        try:
            r = await cliente.post(self.cfg.dnato_token_url, data={
                "grant_type": "client_credentials",
                "client_id": client_id,
                "client_secret": secreto,
            })
        except httpx.HTTPError as e:
            raise CredencialError(f"No se pudo llegar a Dnato: {e}") from e
        finally:
            if propio:
                await cliente.aclose()
        if r.status_code >= 400:
            # El cuerpo de error de OAuth no trae secretos; igual se recorta.
            raise CredencialError(f"Dnato respondio {r.status_code}: {r.text[:200]}")
        try:
            return r.json()
        except ValueError as e:
            raise CredencialError("Dnato no devolvio JSON") from e


async def _leer(con: psycopg.AsyncConnection, empr_id: int, clave: str) -> tuple[str, str]:
    await rag.fijar_empresa(con, empr_id)
    async with con.cursor() as cur:
        await cur.execute(
            """
            SELECT client_id, pgp_sym_decrypt(secreto_cifrado, %s) AS secreto
            FROM agente.credencial_empresa WHERE empr_id = %s AND activo
            """, (clave, empr_id))
        fila = await cur.fetchone()
    if not fila:
        raise CredencialError(f"La empresa {empr_id} no tiene credencial de maquina activa")
    return fila["client_id"], fila["secreto"]


async def _marcar_uso(con: psycopg.AsyncConnection, empr_id: int) -> None:
    async with con.cursor() as cur:
        await cur.execute("UPDATE agente.credencial_empresa SET fec_ultimo_uso = now() "
                          "WHERE empr_id = %s", (empr_id,))


async def empresas(con: psycopg.AsyncConnection) -> list[int]:
    """Las empresas con credencial activa, sin leer ningun secreto."""
    async with con.cursor() as cur:
        await cur.execute("SELECT agente.empresas_con_credencial() AS empr_id")
        return [f["empr_id"] for f in await cur.fetchall()]


# ===================================================================== CLI
async def _alta(cfg: Config, empr_id: int, client_id: str, secreto: str) -> None:
    con = await rag.abrir(cfg)
    try:
        await rag.fijar_empresa(con, empr_id)
        async with con.cursor() as cur:
            await cur.execute(
                """
                INSERT INTO agente.credencial_empresa (empr_id, client_id, secreto_cifrado)
                VALUES (%s, %s, pgp_sym_encrypt(%s, %s))
                ON CONFLICT (empr_id) DO UPDATE SET
                    client_id = EXCLUDED.client_id, secreto_cifrado = EXCLUDED.secreto_cifrado,
                    activo = true, fec_mod = now()
                """, (empr_id, client_id, secreto, cfg.clave_credenciales))
        await con.commit()
    finally:
        await con.close()


async def _baja(cfg: Config, empr_id: int) -> int:
    con = await rag.abrir(cfg)
    try:
        await rag.fijar_empresa(con, empr_id)
        async with con.cursor() as cur:
            await cur.execute("UPDATE agente.credencial_empresa SET activo = false, fec_mod = now() "
                              "WHERE empr_id = %s", (empr_id,))
            n = cur.rowcount
        await con.commit()
        return n
    finally:
        await con.close()


async def _listar(cfg: Config) -> list[int]:
    con = await rag.abrir(cfg)
    try:
        return await empresas(con)
    finally:
        await con.close()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Credenciales de maquina de los agentes (ADR-A10).")
    sub = ap.add_subparsers(dest="accion", required=True)
    a = sub.add_parser("alta", help="Da de alta (o reemplaza) la credencial de una empresa")
    a.add_argument("--empresa", type=int, required=True)
    a.add_argument("--client-id", required=True)
    b = sub.add_parser("baja", help="Desactiva la credencial de una empresa")
    b.add_argument("--empresa", type=int, required=True)
    sub.add_parser("listar", help="Empresas con credencial activa (sin secretos)")
    args = ap.parse_args(argv)

    cfg = cargar()
    if args.accion == "alta":
        if not cfg.clave_credenciales:
            print("Falta AGENTE_CLAVE_CREDENCIALES: sin ella no se puede cifrar el secreto.", file=sys.stderr)
            return 2
        secreto = getpass.getpass("Secreto del cliente (no se muestra): ").strip()
        if not secreto:
            print("El secreto no puede estar vacío.", file=sys.stderr)
            return 2
        asyncio.run(_alta(cfg, args.empresa, args.client_id, secreto))
        print(f"Credencial de la empresa {args.empresa} guardada (cifrada).")
    elif args.accion == "baja":
        n = asyncio.run(_baja(cfg, args.empresa))
        print("Desactivada." if n else f"La empresa {args.empresa} no tenía credencial.")
    else:
        for e in asyncio.run(_listar(cfg)):
            print(e)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
