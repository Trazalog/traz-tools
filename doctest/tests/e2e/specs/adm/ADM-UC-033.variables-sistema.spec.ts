/**
 * Caso de uso: ADM-UC-033 — Editar las variables de sistema y volver atrás
 * Catálogo: catalogo/adm/ADM-UC-033.yaml
 *
 * Depende del ADMDataService desplegado (GET /variables, PUT /variable, historial) y de
 * un usuario de test con la marca de superusuario.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { ConsolaPage } from '../../pages/adm/ConsolaPage.ts';

const BLOQUEO = 'Requiere el ADMDataService desplegado y un usuario de test con la marca de superusuario (REQ-004 Tarea 9).';

test.describe('@adm @ADM-UC-033 Editar las variables de sistema y volver atrás', () => {
  test('un administrador sin la marca no ve las variables', async ({ paginaEmpresa1 }) => {
    const consola = new ConsolaPage(paginaEmpresa1);
    await consola.abrir('/variables');
    await expect(consola.sinPermiso).toBeVisible();
  });

  test('el superusuario ve la tabla de variables', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO);
    const consola = new ConsolaPage(paginaEmpresa1);
    await consola.abrir('/variables');
    await expect(paginaEmpresa1.locator('[data-testid="adm-variables-tabla"]')).toBeVisible();
    await expect(paginaEmpresa1.locator('[data-testid="adm-variable-validez_invitacion_dias"]')).toBeVisible();
  });

  test('cambia una variable, la guarda y puede volver atrás', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO);
    const consola = new ConsolaPage(paginaEmpresa1);
    await consola.abrir('/variables');

    const fila = paginaEmpresa1.locator('[data-testid="adm-variable-validez_invitacion_dias"]');
    const input = fila.locator('input');
    await input.fill('10');
    await paginaEmpresa1.locator('[data-testid="adm-variables-guardar"]').click();
    await expect(paginaEmpresa1.locator('[data-testid="adm-variables-ok"]')).toBeVisible();

    await fila.locator('a', { hasText: 'Historial' }).click();
    await expect(paginaEmpresa1.locator('[data-testid="adm-variable-historial"]')).toBeVisible();
    await paginaEmpresa1.locator('[data-testid="adm-variable-volver"]').first().click();
    await expect(paginaEmpresa1.locator('[data-testid="adm-variables-ok"]')).toBeVisible();
  });
});
