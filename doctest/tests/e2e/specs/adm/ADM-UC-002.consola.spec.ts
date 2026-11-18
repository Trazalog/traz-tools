/**
 * Caso de uso: ADM-UC-002 — Entrar a la Consola de Trazalog
 * Catálogo: catalogo/adm/ADM-UC-002.yaml
 *
 * La Consola es el marco de la plataforma (barra "Trazalog · Consola", leyenda
 * "solo súper usuarios" y las vueltas al Portal y a Tools). Lo que se prueba es el
 * control de acceso: entra el superusuario del ambiente y nadie más.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { sesionSuperusuario } from '../../fixtures/auth-super.ts';
import { ConsolaPage } from '../../pages/adm/ConsolaPage.ts';
import { PortalPage } from '../../pages/adm/PortalPage.ts';

test.describe('@adm @ADM-UC-002 Entrar a la Consola de Trazalog', () => {
  test('@smoke el superusuario ve el botón en el Portal y entra a la Consola', async ({ browser }) => {
    const pagina = await sesionSuperusuario(browser);

    // Desde el Portal de su empresa: el botón aparece y lleva a la Consola.
    const portal = new PortalPage(pagina);
    await portal.abrir();
    await expect(portal.irAConsola).toBeVisible();
    await portal.irAConsola.click();

    const consola = new ConsolaPage(pagina);
    await expect(consola.raiz).toBeVisible();
    await expect(consola.raiz).toContainText('Consola');
    await expect(consola.raiz).toContainText('solo súper usuarios');
    await expect(consola.irATools).toBeVisible();
    await expect(consola.irAPortal).toBeVisible();

    await pagina.context().close();
  });

  test('"Mi empresa" vuelve al Portal', async ({ browser }) => {
    const pagina = await sesionSuperusuario(browser);
    const consola = new ConsolaPage(pagina);
    await consola.abrir();
    await consola.irAPortal.click();
    await pagina.waitForLoadState('domcontentloaded');

    expect(pagina.url()).toContain('traz-comp-adm/portal');
    await pagina.context().close();
  });

  test('"Ir a Tools" vuelve al tablero con la misma sesión', async ({ browser }) => {
    const pagina = await sesionSuperusuario(browser);
    const consola = new ConsolaPage(pagina);
    await consola.abrir();
    await consola.irATools.click();
    await pagina.waitForLoadState('domcontentloaded');

    expect(pagina.url()).not.toContain('traz-comp-adm');
    await expect(pagina.locator('body')).not.toContainText('Ingresá a tu cuenta');
    await pagina.context().close();
  });

  test('un administrador que no es superusuario no ve el botón ni entra', async ({ paginaEmpresa1 }) => {
    const portal = new PortalPage(paginaEmpresa1);
    await portal.abrir();
    await expect(portal.irAConsola).toHaveCount(0);

    const consola = new ConsolaPage(paginaEmpresa1);
    await consola.abrir();
    await expect(consola.sinPermiso).toBeVisible();
    await expect(consola.raiz).toHaveCount(0);
  });

  test('sin sesión, la Consola manda al ingreso', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const consola = new ConsolaPage(pagina);

    await consola.abrir();

    await expect(pagina).toHaveURL(/\/main\/login/);
    await expect(consola.raiz).toHaveCount(0);
    await contexto.close();
  });
});
