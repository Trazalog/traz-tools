/**
 * auth.ts — sesiones ya iniciadas para los tests (Doc 3 §4.3).
 *
 * El ingreso real cuesta ~10 segundos (Dnato valida, consulta el sistema de
 * procesos y redirige a Tools). Hacerlo en cada test sería lento y frágil, así que
 * se hace **una vez por worker** y la sesión se reutiliza serializada con
 * `storageState`, que es lo que pide el Doc 3 §4.3.
 *
 * ✅ Compatibilidad verificada (2026-08-24), que era la duda que el Doc 3 dejaba
 * abierta: la sesión de CodeIgniter (`ci_session`) **se puede reutilizar** entre
 * contextos del navegador. Probado con las dos empresas de test: la sesión guardada
 * abre `main/users` sin volver a pasar por el formulario, y cada una ve solo sus
 * usuarios. No hay session fixation ni atado a User-Agent/IP que lo impida en el
 * entorno bajo prueba. Si algún día dejara de funcionar, el reemplazo es hacer el
 * login por formulario una vez por worker (misma interfaz, sin tocar los tests).
 *
 * Nota para quien escriba los specs: la grilla de usuarios usa DataTables, que
 * duplica la cabecera en una tabla aparte. Hay que apuntar a la tabla de datos —
 * `page.locator('table').last()` o el id concreto—, no a `table` a secas.
 *
 * Uso en un spec:
 *
 *   import { test, expect } from '../../fixtures/auth.ts';
 *
 *   test('@dnato ...', async ({ paginaEmpresa1 }) => {
 *     await paginaEmpresa1.goto(urlDeApp('tools')!);
 *   });
 */

import { test as base, type Browser, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { LoginPage, type CredencialesEmpresa } from '../pages/dnato/LoginPage.ts';
import { requerirUrlDeApp } from '../config/apps.ts';

const HERE = dirname(fileURLToPath(import.meta.url));
const DIR_SESIONES = resolve(HERE, '..', '.auth');

export type Empresa = 'empresa1' | 'empresa2';

/** Credenciales de una empresa de test, leídas del entorno (nunca del repo). */
export function credenciales(empresa: Empresa): CredencialesEmpresa {
  const n = empresa === 'empresa1' ? '1' : '2';
  const faltan: string[] = [];
  const leer = (sufijo: string): string => {
    const clave = `DOCTEST_EMPRESA${n}_${sufijo}`;
    const valor = process.env[clave]?.trim();
    if (!valor) faltan.push(clave);
    return valor ?? '';
  };
  const datos = { empresa: leer('NOMBRE'), email: leer('USER'), password: leer('PASS') };
  if (faltan.length) {
    throw new Error(
      `Faltan credenciales de la empresa de test: ${faltan.join(', ')}. ` +
        `Completalas en doctest/.env (plantilla en .env.example) o en los secrets del workflow. ` +
        `Las provee el PM — no se inventan ni se commitean.`,
    );
  }
  return datos;
}

/**
 * Inicia sesión de verdad y devuelve el path del estado serializado.
 * Se llama una vez por worker y por empresa.
 */
async function iniciarSesion(browser: Browser, empresa: Empresa): Promise<string> {
  const datos = credenciales(empresa);
  const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await contexto.newPage();
  page.setDefaultNavigationTimeout(120_000);

  const login = new LoginPage(page);
  await login.abrir(requerirUrlDeApp('dnato'));
  await login.ingresar(datos);

  const error = await login.mensajeDeError();
  if (error || !(await login.sesionIniciada())) {
    await contexto.close();
    throw new Error(
      `No se pudo iniciar sesión con la ${empresa} (${datos.email} / ${datos.empresa}): ${error ?? 'el formulario de ingreso sigue en pantalla'}`,
    );
  }

  mkdirSync(DIR_SESIONES, { recursive: true });
  const destino = join(DIR_SESIONES, `${empresa}.json`);
  await contexto.storageState({ path: destino });
  await contexto.close();
  return destino;
}

interface FixturesDeSesion {
  /** Página con la sesión de la empresa de test 1 ya iniciada. */
  paginaEmpresa1: Page;
  /** Página con la sesión de la empresa de test 2 — sirve para probar aislamiento. */
  paginaEmpresa2: Page;
}

interface FixturesDeWorker {
  sesionEmpresa1: string;
  sesionEmpresa2: string;
}

export const test = base.extend<FixturesDeSesion, FixturesDeWorker>({
  sesionEmpresa1: [
    async ({ browser }, use) => {
      await use(await iniciarSesion(browser, 'empresa1'));
    },
    { scope: 'worker' },
  ],
  sesionEmpresa2: [
    async ({ browser }, use) => {
      await use(await iniciarSesion(browser, 'empresa2'));
    },
    { scope: 'worker' },
  ],
  paginaEmpresa1: async ({ browser, sesionEmpresa1 }, use) => {
    const contexto = await browser.newContext({ storageState: sesionEmpresa1, ignoreHTTPSErrors: true });
    const page = await contexto.newPage();
    await use(page);
    await contexto.close();
  },
  paginaEmpresa2: async ({ browser, sesionEmpresa2 }, use) => {
    const contexto = await browser.newContext({ storageState: sesionEmpresa2, ignoreHTTPSErrors: true });
    const page = await contexto.newPage();
    await use(page);
    await contexto.close();
  },
});

export { expect } from '@playwright/test';
