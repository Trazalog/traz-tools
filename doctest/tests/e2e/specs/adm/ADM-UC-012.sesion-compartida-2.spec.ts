/**
 * Caso de uso: ADM-UC-012 — Ingresar por DNATO y entrar al módulo sin volver a ingresar
 * Catálogo: catalogo/adm/ADM-UC-012.yaml
 *
 * Sentido 2 de la sesión compartida: la sesión que abre DNATO sirve en el módulo. El
 * fixture `paginaEmpresa1` inicia sesión por DNATO; el Portal se abre con esa misma
 * sesión, y la empresa activa es la que eligió DNATO.
 */

import { expect, test, credenciales } from '../../fixtures/auth.ts';
import { PortalPage } from '../../pages/adm/PortalPage.ts';
import { urlLoginAdm } from '../../pages/adm/LoginAdmPage.ts';

test.describe('@adm @ADM-UC-012 Ingresar por DNATO y entrar al módulo', () => {
  test('@smoke la sesión abierta por DNATO sirve en el Portal', async ({ paginaEmpresa1 }) => {
    const portal = new PortalPage(paginaEmpresa1);

    // El Portal se abre con la sesión que inició DNATO, sin volver a pedir credenciales.
    await portal.abrir();

    await expect(portal.raiz).toBeVisible();
    await expect(portal.empresa).toContainText(credenciales('empresa1').empresa);
  });

  test('con sesión abierta, el ingreso del módulo manda al tablero', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlLoginAdm());
    await paginaEmpresa1.waitForLoadState('domcontentloaded');

    await expect(paginaEmpresa1.locator('#email')).toHaveCount(0);
  });
});
