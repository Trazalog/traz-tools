/**
 * Caso de uso: DNATO-UC-022 — Ver la lista de empresas del sistema
 * Catálogo: catalogo/dnato/DNATO-UC-022.yaml
 * Gherkin:  features/dnato/DNATO-UC-022.ver-la-lista-de-empresas-del-sistema.feature
 *
 * El camino principal lo ejecuta el superusuario del ambiente, que no es ninguna de
 * las empresas de test: acá se verifica la otra mitad de la regla, que es la que
 * protege al sistema — un administrador común no entra.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { LoginPage } from '../../pages/dnato/LoginPage.ts';
import { urlDnato } from '../../config/apps.ts';

test.describe('@dnato @DNATO-UC-022 Ver la lista de empresas del sistema', () => {
  test('@smoke un administrador común no ve el menú de Gestión de Empresas', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('main/users'), { waitUntil: 'domcontentloaded' });
    const menu = await paginaEmpresa1.locator('nav').first().innerText();

    expect(menu).toContain('Gestión de Usuarios');
    expect(menu).not.toContain('Gestión de Empresas');
  });

  test('un administrador común no accede a la lista de empresas por dirección directa', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('empresa/listarEmpresas'), { waitUntil: 'domcontentloaded' });

    // El sistema lo saca de la pantalla: no ve el listado de empresas ajenas.
    expect(paginaEmpresa1.url()).not.toContain('listarEmpresas');
  });

  test('sin sesión, la lista de empresas manda al ingreso', async ({ page }) => {
    await page.goto(urlDnato('empresa/listarEmpresas'), { waitUntil: 'domcontentloaded' });
    await expect(new LoginPage(page).empresa).toBeVisible();
  });
});
