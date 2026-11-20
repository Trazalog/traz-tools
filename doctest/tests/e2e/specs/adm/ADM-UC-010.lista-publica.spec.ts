/**
 * Caso de uso: ADM-UC-010 — Entrar sin sesión solo a las páginas públicas de identidad del módulo
 * Catálogo: catalogo/adm/ADM-UC-010.yaml
 *
 * Lo que se prueba es el CONTROL DE ACCESO, no el comportamiento de cada página (eso lo
 * prueban DNATO-UC-001 a 008 corridos contra la copia): qué se puede abrir sin sesión,
 * qué manda al ingreso del módulo y qué da "no existe". También la protección de envíos
 * en las páginas públicas (sin el código de seguridad, no se ejecuta nada).
 */

import { expect, test } from '../../fixtures/auth.ts';
import { LoginAdmPage, urlLoginAdm } from '../../pages/adm/LoginAdmPage.ts';
import { PortalPage } from '../../pages/adm/PortalPage.ts';

test.describe('@adm @ADM-UC-010 Entrar sin sesión solo a las páginas públicas del módulo', () => {
  test('@smoke sin sesión, el ingreso del módulo muestra la pantalla', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    await login.abrir();

    await expect(login.email).toBeVisible();
    await expect(login.password).toBeVisible();
    await expect(login.ingresar).toBeVisible();
    await contexto.close();
  });

  test('el enlace de registro lleva al registro del módulo', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    await login.abrir();
    await login.enlaceRegistro.click();
    await pagina.waitForLoadState('domcontentloaded');

    await expect(pagina).toHaveURL(/traz-comp-adm\/main\/register/);
    await contexto.close();
  });

  test('el enlace de recuperación lleva a recuperar contraseña del módulo', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    await login.abrir();
    await login.enlaceRecuperar.click();
    await pagina.waitForLoadState('domcontentloaded');

    await expect(pagina).toHaveURL(/traz-comp-adm\/main\/forgot/);
    await contexto.close();
  });

  test('una pantalla no pública sin sesión manda al ingreso del módulo', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const portal = new PortalPage(pagina);

    await portal.abrir();

    await expect(pagina).toHaveURL(/traz-comp-adm\/main\/login/);
    await expect(portal.raiz).toHaveCount(0);
    await contexto.close();
  });

  test('un método auxiliar del registro no es ruteable', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    await pagina.goto(urlLoginAdm().replace(/main\/login$/, 'main/procesarRegistro'));

    await expect(login.noExiste).toBeVisible();
    await expect(login.noExiste).toContainText('Esa página no existe.');
    await contexto.close();
  });

  test('una pantalla de DNATO que no se copió da "no existe"', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    await pagina.goto(urlLoginAdm().replace(/main\/login$/, 'main/users'));

    await expect(login.noExiste).toBeVisible();
    await contexto.close();
  });

  test('un envío del ingreso sin el código de seguridad se rechaza', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();

    const respuesta = await pagina.request.post(urlLoginAdm(), {
      form: { email: 'nadie@ejemplo.com', password: 'x' },
    });

    expect(respuesta.status()).toBe(403);
    await contexto.close();
  });

  test('con sesión, el ingreso manda al tablero de Tools', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlLoginAdm());
    await paginaEmpresa1.waitForLoadState('domcontentloaded');

    // No muestra el formulario de ingreso: ya hay sesión.
    await expect(paginaEmpresa1.locator('#email')).toHaveCount(0);
  });
});
