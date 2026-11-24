/**
 * Caso de uso: ADM-UC-031 — Ser superusuario por la marca en el usuario
 * Catálogo: catalogo/adm/ADM-UC-031.yaml
 *
 * Depende de la marca `seg.users.superusuario` en el ambiente de test (M-6) y del
 * ADMDataService desplegado. El correo de TOOLS_ADMIN_USER ya no autoriza en el módulo.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { ConsolaPage } from '../../pages/adm/ConsolaPage.ts';

const BLOQUEO = 'Requiere el ADMDataService desplegado y un usuario de test con la marca de superusuario (REQ-004 Tarea 9).';

test.describe('@adm @ADM-UC-031 Ser superusuario por la marca en el usuario', () => {
  test('con la marca, el superusuario entra a la Consola', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO);
    const consola = new ConsolaPage(paginaEmpresa1);
    await consola.abrir();
    await expect(consola.raiz).toBeVisible();
  });

  test('sin la marca, el correo de TOOLS_ADMIN_USER no entra a la Consola', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO + ' Falta un usuario de test cuyo correo sea el de TOOLS_ADMIN_USER.');
    const consola = new ConsolaPage(paginaEmpresa1);
    await consola.abrir();
    await expect(consola.sinPermiso).toBeVisible();
  });
});
