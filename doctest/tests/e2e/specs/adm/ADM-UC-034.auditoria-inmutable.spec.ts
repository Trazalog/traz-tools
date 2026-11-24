/**
 * Caso de uso: ADM-UC-034 — Dejar rastro de cada cambio sin que se pueda borrar
 * Catálogo: catalogo/adm/ADM-UC-034.yaml
 *
 * La inmutabilidad de seg.auditoria se verifica a nivel BASE (prueba técnica: el
 * disparador rechaza UPDATE y DELETE), no con un flujo de usuario. Esta prueba E2E
 * queda documentada y salteada; el caso se cubre con la prueba técnica del script
 * REQ-004-base-y-atributos.sql.
 */

import { test } from '../../fixtures/auth.ts';

const BLOQUEO = 'ADM-UC-034 se verifica a nivel base (prueba técnica de inmutabilidad), no con un flujo E2E (REQ-004 Tarea 8/9).';

test.describe('@adm @ADM-UC-034 Dejar rastro de cada cambio sin que se pueda borrar', () => {
  test('cada cambio de variable deja su fila de auditoría', async () => {
    test.skip(true, BLOQUEO);
  });

  test('la base rechaza modificar o borrar una fila de auditoría', async () => {
    test.skip(true, BLOQUEO + ' Se corre contra la base de DEV con el rol de la aplicación.');
  });
});
