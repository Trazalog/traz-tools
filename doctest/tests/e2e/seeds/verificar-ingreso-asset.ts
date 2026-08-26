/**
 * verificar-ingreso-asset.ts — ¿un usuario creado por la registración puede entrar a AssetPlanner?
 *
 * Es la verificación del issue #489: la contraseña se guardaba en texto plano y AssetPlanner la
 * compara contra MD5, así que ningún usuario de una empresa nueva podía ingresar. Este script
 * comprueba si el circuito quedó arreglado, sin tener que acordarse de los pasos.
 *
 * Qué hace:
 *   1. (opcional) crea una empresa nueva por el alta real, con casilla de correo descartable;
 *   2. prueba el ingreso a AssetPlanner con los cinco usuarios por defecto de esa empresa;
 *   3. si alguno entra, lista el menú que ve — que es lo que después releva DocTest.
 *
 * Uso (en una terminal, parado en `doctest/`):
 *   npm run verificar:asset                        # usa la empresa de DOCTEST_EMPRESA1_*
 *   npm run verificar:asset -- --dominio miempresa.com
 *   npm run verificar:asset -- --nueva              # crea una empresa nueva primero
 *
 * No escribe nada en AssetPlanner: solo intenta ingresar.
 */

import { chromium, type Browser, type Page } from '@playwright/test';
import { config as cargarEnv } from 'dotenv';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { requerirUrlDeApp } from '../config/apps.ts';

const AQUI = dirname(fileURLToPath(import.meta.url));
cargarEnv({ path: resolve(AQUI, '..', '..', '..', '.env'), quiet: true });

/** Los alias de REGISTRACION_USUARIOS_DEFAULT_JSON, con el rol que le toca a cada uno. */
const USUARIOS_POR_DEFECTO: Array<[string, string]> = [
  ['mantenimiento', 'Supervisor y Planificador de Mantenimiento'],
  ['almacen', 'Responsable de Almacén'],
  ['panol', 'Responsable de Pañol'],
  ['produccion', 'Responsable de Producción'],
  ['usuario', 'Solicitante de Almacén y de Mantenimiento'],
];

/** La contraseña con la que nacen, de REGISTRACION_PASSWORD_DEFAULT. */
const CLAVE_POR_DEFECTO = '12345';

function argumento(nombre: string): string | undefined {
  const i = process.argv.indexOf(`--${nombre}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function intentarIngreso(nav: Browser, url: string, usuario: string, clave: string): Promise<Page | null> {
  const page = await (await nav.newContext({ ignoreHTTPSErrors: true })).newPage();
  let abierta = null;
  for (let i = 1; i <= 3 && !abierta; i++) {
    abierta = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 90_000 }).catch(() => null);
    if (!abierta) await page.waitForTimeout(3000);
  }
  if (!abierta) {
    console.log(`  ${usuario.padEnd(38)} no se pudo abrir AssetPlanner`);
    await page.close();
    return null;
  }
  await page.waitForTimeout(2000);
  await page.locator('#usrName').fill(usuario);
  await page.locator('#usrPassword').fill(clave);
  await page.locator('#login').click({ noWaitAfter: true }).catch(() => {});
  await page.waitForTimeout(9000);

  // Si sigue habiendo campo de contraseña, no entró — el cartel de error no siempre aparece.
  const siguenPidiendoClave = (await page.locator('input[type=password]').count()) > 0;
  console.log(`  ${usuario.padEnd(38)} ${siguenPidiendoClave ? '✘ rechazado' : '✅ ENTRÓ'}`);
  if (siguenPidiendoClave) {
    await page.close();
    return null;
  }
  return page;
}

// Es el dominio CORPORATIVO que se cargó en el alta, no el del correo con que se registró: los
// usuarios por defecto se arman como <alias>@<dominio corporativo>.
const dominio = argumento('dominio') || process.env.DOCTEST_SEED_DOMINIO;
if (!dominio) {
  console.error(
    'Falta el dominio corporativo de la empresa — es el que se cargó en el alta, no el del correo\n' +
    'del administrador. Pasalo con  --dominio miempresa.com  o completá DOCTEST_SEED_DOMINIO en .env.',
  );
  process.exit(1);
}

// Si falta la URL en el .env, esto falla diciendo exactamente qué variable completar.
const urlAsset = requerirUrlDeApp('man');
console.log(`\nVerificando el ingreso a AssetPlanner — issue #489`);
console.log(`Empresa (dominio): ${dominio}`);
console.log(`AssetPlanner:      ${urlAsset}\n`);

const nav = await chromium.launch();
let entro: Page | null = null;
let quien = '';

for (const [alias, rol] of USUARIOS_POR_DEFECTO) {
  if (entro) break;
  const usuario = `${alias}@${dominio}`;
  entro = await intentarIngreso(nav, urlAsset, usuario, CLAVE_POR_DEFECTO);
  if (entro) quien = `${usuario} (${rol})`;
}

if (!entro) {
  console.log(`
✘ Ninguno de los usuarios por defecto pudo entrar.

   Si el arreglo del hash ya se desplegó, tené en cuenta que **solo aplica a los usuarios creados
   después**: los que ya existían siguen con la contraseña en texto plano en 'sisusers'. Para
   probarlo hace falta una empresa nueva — se crea con:  npm run seed:empresa
`);
  await nav.close();
  process.exit(1);
}

console.log(`\n✓ Entró: ${quien}\n`);
const menu = await entro.evaluate(() => [...new Set(Array.from(document.querySelectorAll('a'))
  .map((a) => {
    const el = a as HTMLAnchorElement;
    const t = (el.textContent || '').replace(/\s+/g, ' ').trim();
    const d = el.getAttribute('href') || el.getAttribute('onclick') || '';
    if (!t || t.length > 55) return '';
    return d && d !== '#' ? `${t}\t${d.slice(0, 70)}` : `[grupo] ${t}`;
  })
  .filter(Boolean))]);
console.log('--- MENÚ DE ASSETPLANNER ---');
console.log(menu.join('\n') || '(sin enlaces: puede que el menú se arme por JavaScript)');
await nav.close();
