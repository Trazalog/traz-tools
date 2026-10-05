/**
 * Sesión de AssetPlanner para los tests de Mantenimiento.
 *
 * Es una fixture aparte de la de Tools a propósito: **MAN tiene su propio ingreso y su propio
 * padrón de usuarios**, así que la sesión de Tools no sirve acá (ver `pages/man/LoginManPage.ts`).
 *
 * Como en el resto de DocTest, las credenciales **nunca se hardcodean**: si falta una, el test
 * falla diciendo exactamente qué variable completar.
 */

import { test as base, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../config/apps.ts';
import { LoginManPage, type CredencialesMan } from '../pages/man/LoginManPage.ts';

export function credencialesMan(): CredencialesMan {
  const usuario = process.env.DOCTEST_MAN_USER;
  const password = process.env.DOCTEST_MAN_PASS;
  if (!usuario || !password) {
    throw new Error(
      'Faltan las credenciales de AssetPlanner. Completá DOCTEST_MAN_USER y DOCTEST_MAN_PASS en\n' +
        'doctest/.env — son las de un usuario de Mantenimiento, que NO son las de Tools: la app\n' +
        'tiene su propio padrón (ver issue #489).',
    );
  }
  return { usuario, password };
}

export const test = base.extend<{ paginaMan: Page }>({
  paginaMan: async ({ browser }, usar) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const page = await contexto.newPage();
    const login = new LoginManPage(page);
    await login.abrir(requerirUrlDeApp('man'));
    await login.ingresar(credencialesMan());
    if (await login.sigueEnElIngreso()) {
      throw new Error(
        'No se pudo ingresar a AssetPlanner con las credenciales de DOCTEST_MAN_USER.\n' +
          'Si el usuario se creó por la registración, es esperable: la contraseña se guarda sin\n' +
          'hashear y asset la compara contra MD5 (issue #489).',
      );
    }
    await usar(page);
    await contexto.close();
  },
});

export { expect } from '@playwright/test';
