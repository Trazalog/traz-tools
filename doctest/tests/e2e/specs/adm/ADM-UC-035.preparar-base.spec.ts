/**
 * Caso de uso: ADM-UC-035 — Preparar la base nueva sin que el sistema actual note nada
 * Catálogo: catalogo/adm/ADM-UC-035.yaml
 *
 * Las pruebas que se pueden correr sin el ADMDataService: el tablero de Tools sigue
 * cargando y el ingreso del módulo sigue respondiendo. La comparación "antes/después"
 * del menú (M-2) se hace en la corrida de migración, no en la suite E2E.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { BarraToolsPage } from '../../pages/adm/BarraToolsPage.ts';
import { LoginAdmPage } from '../../pages/adm/LoginAdmPage.ts';

test.describe('@adm @ADM-UC-035 Preparar la base nueva sin que el sistema actual note nada', () => {
  test('el tablero de Tools carga con la barra lateral', async ({ paginaEmpresa1 }) => {
    const barra = new BarraToolsPage(paginaEmpresa1);
    await barra.abrirTablero();

    await expect(paginaEmpresa1).not.toHaveURL(/traz-comp-dnato\/main\/login/);
    await expect(paginaEmpresa1.locator('aside.main-sidebar')).toBeVisible();
  });

  test('el ingreso del módulo sigue respondiendo', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();
    const login = new LoginAdmPage(pagina);

    await login.abrir();
    await expect(login.email).toBeVisible();
    await expect(login.password).toBeVisible();
    await contexto.close();
  });

  test('el menú de Tools es el mismo antes y después de la migración', async () => {
    test.skip(
      true,
      'La comparación antes/después de M-2 se hace en la corrida de migración (REQ-004 Tarea 2), no en la suite E2E.',
    );
  });
});
