/**
 * Caso de uso: ADM-UC-001 — Entrar al Portal de la empresa
 * Catálogo: catalogo/adm/ADM-UC-001.yaml
 *
 * El Portal es el marco de la empresa (barra, empresa, menú y saludo). Lo que se prueba
 * acá es el control de acceso: entra el administrador de la empresa activa, no entra
 * quien no es administrador, y sin sesión manda al ingreso.
 */

import { expect, test, credenciales } from '../../fixtures/auth.ts';
import { sesionDeRol } from '../../fixtures/roles-alm.ts';
import { PortalPage, urlPortal } from '../../pages/adm/PortalPage.ts';

test.describe('@adm @ADM-UC-001 Entrar al Portal de la empresa', () => {
  test('@smoke el administrador entra y ve el marco de su empresa', async ({ paginaEmpresa1 }) => {
    const portal = new PortalPage(paginaEmpresa1);
    await portal.abrir();

    await expect(portal.raiz).toBeVisible();
    await expect(portal.empresa).toContainText(credenciales('empresa1').empresa);
    await expect(portal.menu).toContainText('Inicio');
    await expect(portal.saludo).toContainText('Hola');
  });

  test('"Ir a Tools" vuelve al tablero con la misma sesión', async ({ paginaEmpresa1 }) => {
    const portal = new PortalPage(paginaEmpresa1);
    await portal.abrir();
    await portal.irATools.click();
    await paginaEmpresa1.waitForLoadState('domcontentloaded');

    expect(paginaEmpresa1.url()).not.toContain('traz-comp-adm');
    // Sigue con sesión: no aparece el formulario de ingreso.
    await expect(paginaEmpresa1.locator('body')).not.toContainText('Ingresá a tu cuenta');
  });

  test('sin sesión, el Portal manda al ingreso', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const portal = new PortalPage(pagina);

    await portal.abrir();

    await expect(pagina).toHaveURL(/\/main\/login/);
    await expect(portal.raiz).toHaveCount(0);
    await contexto.close();
  });

  test('un usuario que no es administrador ve "sin permiso"', async ({ browser }) => {
    const pagina = await sesionDeRol(browser, 'almacen');
    const portal = new PortalPage(pagina);

    await portal.abrir();

    await expect(portal.sinPermiso).toBeVisible();
    await expect(portal.empresa).toHaveCount(0);
    await expect(portal.menu).toHaveCount(0);
    await pagina.context().close();
  });

  test('la empresa que viene en la dirección se ignora', async ({ paginaEmpresa1 }) => {
    const portal = new PortalPage(paginaEmpresa1);
    await portal.abrir('?empr_id=1');

    await expect(portal.empresa).toContainText(credenciales('empresa1').empresa);
  });

  test('una página inexistente dice "no existe", no "sin permiso"', async ({ paginaEmpresa1 }) => {
    const portal = new PortalPage(paginaEmpresa1);
    await portal.abrir('/no-existe');

    await expect(portal.noExiste).toBeVisible();
    await expect(portal.noExiste).toContainText('Esa página no existe.');
    await expect(portal.sinPermiso).toHaveCount(0);
  });
});

// La URL del Portal también se exporta para que otros casos del módulo la reusen.
export { urlPortal };
