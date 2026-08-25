/**
 * Caso de uso: DNATO-UC-023 — Dar de alta una empresa desde la administración
 * Catálogo: catalogo/dnato/DNATO-UC-023.yaml (v0.2, validado 2026-08-24)
 *
 * El camino principal es del superusuario del ambiente, que no es ninguna de las
 * empresas de test. Se verifica la mitad que protege al sistema.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { LoginPage } from '../../pages/dnato/LoginPage.ts';
import { urlDnato } from '../../config/apps.ts';

test.describe('@dnato @DNATO-UC-023 Dar de alta una empresa desde la administración', () => {
  test('un administrador común no puede abrir el alta de empresas', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('empresa/agregarEmpresa'), { waitUntil: 'domcontentloaded' });

    expect(paginaEmpresa1.url()).not.toContain('agregarEmpresa');
    await expect(paginaEmpresa1.locator('input[name="cuit"]')).toHaveCount(0);
  });

  test('sin sesión, el alta de empresas manda al ingreso', async ({ page }) => {
    await page.goto(urlDnato('empresa/agregarEmpresa'), { waitUntil: 'domcontentloaded' });
    await expect(new LoginPage(page).empresa).toBeVisible();
  });
});
