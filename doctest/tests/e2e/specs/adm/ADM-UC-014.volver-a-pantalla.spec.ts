/**
 * Caso de uso: ADM-UC-014 — Volver a la pantalla del módulo que pidió, después de ingresar
 * Catálogo: catalogo/adm/ADM-UC-014.yaml
 *
 * Es lo único que la copia agrega al ingreso de DNATO: si la persona llegó al ingreso
 * porque pidió una pantalla del módulo sin sesión, después de ingresar vuelve a esa
 * pantalla. Sin pantalla pedida va al tablero de Tools, como siempre. La dirección de
 * vuelta sale de la sesión, nunca de la dirección del navegador.
 */

import { expect, test, credenciales } from '../../fixtures/auth.ts';
import { LoginAdmPage, urlLoginAdm } from '../../pages/adm/LoginAdmPage.ts';
import { PortalPage, urlPortal } from '../../pages/adm/PortalPage.ts';

test.describe('@adm @ADM-UC-014 Volver a la pantalla del módulo que pidió', () => {
  test('@smoke sin sesión, el Portal lleva al ingreso y después de ingresar vuelve al Portal', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const portal = new PortalPage(pagina);
    const login = new LoginAdmPage(pagina);

    // Pide el Portal sin sesión: va al ingreso y queda la pantalla pedida en la sesión.
    await portal.abrir();
    await expect(pagina).toHaveURL(/traz-comp-adm\/main\/login/);

    // Ingresa con la empresa 1 (una sola empresa: entra directo).
    await login.email.fill(credenciales('empresa1').email);
    await login.password.fill(credenciales('empresa1').password);
    await login.ingresar.click();
    await pagina.waitForLoadState('domcontentloaded');

    // Vuelve al Portal, no al tablero de Tools.
    await expect(pagina).toHaveURL(/traz-comp-adm\/portal/);
    await expect(portal.raiz).toBeVisible();
    await contexto.close();
  });

  test('ingreso directo, sin pantalla pedida, va al tablero de Tools', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    await login.abrir();
    await login.email.fill(credenciales('empresa1').email);
    await login.password.fill(credenciales('empresa1').password);
    await login.ingresar.click();
    await pagina.waitForLoadState('domcontentloaded');

    expect(pagina.url()).not.toContain('traz-comp-adm');
    await contexto.close();
  });

  test('la dirección de vuelta de afuera se ignora', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    await login.abrir('?volver=https://otro-sitio.com');
    await login.email.fill(credenciales('empresa1').email);
    await login.password.fill(credenciales('empresa1').password);
    await login.ingresar.click();
    await pagina.waitForLoadState('domcontentloaded');

    expect(pagina.url()).not.toContain('otro-sitio.com');
    expect(pagina.url()).not.toContain('traz-comp-adm');
    await contexto.close();
  });
});

export { urlPortal, urlLoginAdm };
