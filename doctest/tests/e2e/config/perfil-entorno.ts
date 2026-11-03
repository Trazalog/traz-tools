/**
 * perfil-entorno.ts — con qué empresas se prueba en cada ambiente.
 *
 * El perfil es un archivo por ambiente, `doctest/entornos/<entorno>.json`, que escribe
 * la preparación del entorno (`npm run doctest -- casi-full|full`, spec
 * `specs/entorno/PREPARAR-entorno.spec.ts`) y que lee el modo regresión
 * (`scripts/doctest.mjs`) para pasarle a la suite las credenciales de esas empresas.
 *
 * Tiene contraseñas: no se versiona (ver `.gitignore`). La forma está en
 * `entornos/ejemplo.json`. Si un ambiente no tiene perfil, la suite usa las variables
 * del `.env`, como siempre.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
export const DIR_ENTORNOS = resolve(HERE, '..', '..', '..', 'entornos');

export interface CuentaTest {
  usuario: string;
  clave: string;
}

export interface EmpresaTest {
  nombre: string;
  dominio: string;
  /** Quien se registró: el administrador de la empresa. */
  admin: CuentaTest;
}

export interface PerfilEntorno {
  entorno: string;
  /** ISO 8601 del momento en que se creó. */
  creado: string;
  modo: 'casi-full' | 'full';
  empresa1: EmpresaTest;
  /** La segunda empresa: la usan los casos que verifican que una empresa no ve los datos de otra. */
  empresa2: EmpresaTest;
  /** Usuario de AssetPlanner (padrón propio). */
  man: CuentaTest;
  /** Usuarios de rol de almacén de la empresa 1. */
  alm: { solicitante: CuentaTest; almacen: CuentaTest };
  /** Lo que cargó el modo full, para encadenar. */
  sembrado?: { equipoCodigo?: string; herramientaCodigo?: string };
}

export function entornoActual(): string {
  return (process.env.DOCTEST_ENV ?? 'local').trim();
}

export function rutaPerfil(entorno = entornoActual()): string {
  return resolve(DIR_ENTORNOS, `${entorno}.json`);
}

export function leerPerfil(entorno = entornoActual()): PerfilEntorno | null {
  const ruta = rutaPerfil(entorno);
  if (!existsSync(ruta)) return null;
  return JSON.parse(readFileSync(ruta, 'utf8')) as PerfilEntorno;
}

export function escribirPerfil(perfil: PerfilEntorno): string {
  mkdirSync(DIR_ENTORNOS, { recursive: true });
  const ruta = rutaPerfil(perfil.entorno);
  writeFileSync(ruta, `${JSON.stringify(perfil, null, 2)}\n`, { mode: 0o600 });
  return ruta;
}
