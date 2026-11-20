/**
 * Caso de uso: ADM-UC-011 — Ingresar por el módulo y seguir trabajando en Tools y en DNATO
 * Catálogo: catalogo/adm/ADM-UC-011.yaml
 *
 * Sentido 1 de la sesión compartida: la sesión que abre la copia sirve, sin volver a
 * ingresar, en DNATO (las dos escriben las mismas claves en ci_session).
 */

import { expect, test, credenciales } from '../../fixtures/auth.ts';
import { requerirUrlDeApp, urlDnato } from '../../config/apps.ts';
import { LoginAdmPage } from '../../pages/adm/LoginAdmPage.ts';

const BASE_TOOLS = requerirUrlDeApp('tools').replace(/\/$/, '');

test.describe('@adm @ADM-UC-011 Ingresar por el módulo y seguir en DNATO', () => {
  test('@smoke la sesión abierta por la copia sirve en DNATO', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    // Ingresa por la copia.
    await login.abrir();
    await login.email.fill(credenciales('empresa1').email);
    await login.password.fill(credenciales('empresa1').password);
    await login.ingresar.click();
    await pagina.waitForLoadState('domcontentloaded');

    // DNATO reconoce la misma sesión: el perfil se abre, no el ingreso.
    await pagina.goto(urlDnato('main/profile'));
    await pagina.waitForLoadState('domcontentloaded');

    expect(pagina.url()).not.toContain('main/login');
    await contexto.close();
  });

  test('salir desde la copia cierra la sesión', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    await login.abrir();
    await login.email.fill(credenciales('empresa1').email);
    await login.password.fill(credenciales('empresa1').password);
    await login.ingresar.click();
    await pagina.waitForLoadState('domcontentloaded');

    // Sale por la copia.
    await pagina.goto(`${BASE_TOOLS}/traz-comp-adm/main/logout`);
    await pagina.waitForLoadState('domcontentloaded');

    // DNATO ya no reconoce la sesión: manda al ingreso.
    await pagina.goto(urlDnato('main/profile'));
    await expect(pagina).toHaveURL(/main\/login/);
    await contexto.close();
  });
});
