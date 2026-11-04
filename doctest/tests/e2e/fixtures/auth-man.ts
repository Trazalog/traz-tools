/**
 * Sesión para los tests de Mantenimiento (MAN) **dentro de Tools**.
 *
 * Desde la migración de AssetPlanner a tools (submódulo `traz-tools-man`, 2026-11), Mantenimiento
 * ya no tiene ingreso propio: se entra por DNATO como al resto de Tools y las pantallas se abren
 * desde el menú "Mantenimiento". El ingreso viejo de asset (`pages/man/LoginManPage.ts`) queda solo
 * para las pruebas que todavía verifican asset (DNATO-UC-014-018).
 *
 * Con `npm run doctest` el usuario sale del **perfil del ambiente**: la empresa 1 recién creada por
 * casi-full/full (el alta de empresa la deja vinculada con Mantenimiento). Sin perfil se usan las
 * variables DOCTEST_<AMBIENTE>_MAN_USER / _PASS / _EMPRESA del .env y, si no están, DOCTEST_MAN_*.
 * Las credenciales nunca se hardcodean.
 *
 * El ingreso se hace una vez por worker y la sesión se reutiliza con `storageState`.
 */

import { test as base, type Browser, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { entornoActual, requerirUrlDeApp } from '../config/apps.ts';
import { LoginPage } from '../pages/dnato/LoginPage.ts';

const HERE = dirname(fileURLToPath(import.meta.url));
const DIR_SESIONES = resolve(HERE, '..', '.auth');

export interface CredencialesManTools {
  usuario: string;
  password: string;
  /** Nombre de la empresa en la tarjeta del paso 2 del ingreso (si el usuario tiene más de una). */
  empresa?: string;
}

const PREFIJO: Record<string, string> = { local: 'LOCAL', demo: 'DEMO', 'staging-v3': 'STAGING' };

function leer(sufijo: string): string | undefined {
  const propio = process.env[`DOCTEST_${PREFIJO[entornoActual()]}_MAN_${sufijo}`]?.trim();
  return propio || process.env[`DOCTEST_MAN_${sufijo}`]?.trim() || undefined;
}

export function credencialesMan(): CredencialesManTools {
  const usuario = leer('USER');
  const password = leer('PASS');
  if (!usuario || !password) {
    const p = PREFIJO[entornoActual()];
    throw new Error(
      `Faltan las credenciales de Mantenimiento. Completá DOCTEST_${p}_MAN_USER y DOCTEST_${p}_MAN_PASS\n` +
        'en doctest/.env: un usuario de Tools de una empresa vinculada con Mantenimiento y con el menú MAN.',
    );
  }
  return { usuario, password, empresa: leer('EMPRESA') };
}

/** El Supervisor de Mantenimiento: recibe "Analisis de Solicitud" y "Verifica Informe" en su bandeja. */
export function credencialesSupervisor(): CredencialesManTools {
  const usuario = leer('SUPERVISOR_USER');
  const password = leer('SUPERVISOR_PASS');
  if (!usuario || !password) {
    const p = PREFIJO[entornoActual()];
    throw new Error(
      `Falta el Supervisor de Mantenimiento. Completá DOCTEST_${p}_MAN_SUPERVISOR_USER y _PASS en doctest/.env,\n` +
        'o corré `npm run doctest -- casi-full|full`, que lo anota en el perfil (mantenimiento@ de la empresa 1).',
    );
  }
  return { usuario, password, empresa: leer('EMPRESA') };
}

async function ingresar(browser: Browser, datos: CredencialesManTools, archivo: string): Promise<string> {
  const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await contexto.newPage();
  page.setDefaultNavigationTimeout(120_000);
  const login = new LoginPage(page);
  await login.abrir(requerirUrlDeApp('dnato'));
  await login.completar({ email: datos.usuario, password: datos.password, empresa: datos.empresa ?? '' });
  await login.enviar();
  if (await login.enSeleccionDeEmpresa()) {
    const ofrecidas = await login.empresasDisponibles();
    const elegida = datos.empresa ?? (ofrecidas.length === 1 ? ofrecidas[0] : undefined);
    if (!elegida) {
      await contexto.close();
      throw new Error(
        `El usuario de Mantenimiento tiene varias empresas (${ofrecidas.join(', ')}): ` +
          `indicá cuál en DOCTEST_${PREFIJO[entornoActual()]}_MAN_EMPRESA.`,
      );
    }
    await login.elegirEmpresa(elegida);
  }
  const error = await login.mensajeDeError();
  if (error || !(await login.sesionIniciada())) {
    await contexto.close();
    throw new Error(`No se pudo ingresar a Tools con el usuario de Mantenimiento: ${error ?? 'sigue en el ingreso'}`);
  }
  mkdirSync(DIR_SESIONES, { recursive: true });
  const destino = join(DIR_SESIONES, `${archivo}-${entornoActual()}.json`);
  await contexto.storageState({ path: destino });
  await contexto.close();
  return destino;
}

async function abrirPagina(browser: Browser, sesion: string, usar: (p: Page) => Promise<void>): Promise<void> {
  const contexto = await browser.newContext({ ignoreHTTPSErrors: true, storageState: sesion });
  const page = await contexto.newPage();
  // Las pantallas de asset usan alert()/confirm() nativos: un diálogo sin atender traba la página.
  page.on('dialog', (d) => void d.accept().catch(() => {}));
  await usar(page);
  await contexto.close();
}

export const test = base.extend<{ paginaMan: Page; paginaSupervisor: Page }, { sesionMan: string; sesionSupervisor: string }>({
  sesionMan: [
    async ({ browser }, usar) => {
      await usar(await ingresar(browser, credencialesMan(), 'man'));
    },
    { scope: 'worker' },
  ],
  sesionSupervisor: [
    async ({ browser }, usar) => {
      await usar(await ingresar(browser, credencialesSupervisor(), 'man-supervisor'));
    },
    { scope: 'worker' },
  ],
  paginaMan: async ({ browser, sesionMan }, usar) => {
    await abrirPagina(browser, sesionMan, usar);
  },
  paginaSupervisor: async ({ browser, sesionSupervisor }, usar) => {
    await abrirPagina(browser, sesionSupervisor, usar);
  },
});

export { expect } from '@playwright/test';
