/**
 * fallo-conocido.ts — dice QUÉ falla exacta espera una prueba marcada con `test.fail()`.
 *
 * `test.fail()` acepta cualquier falla: si la prueba se corta antes de llegar al error anotado,
 * igual cuenta como "falló como se esperaba" y el error queda dado por confirmado sin serlo.
 * Con esta línea, el informe de la corrida compara el mensaje de la falla:
 *
 *   debeFallarCon(/la empresa 2 eliminó un pedido/);
 *   test.fail(true, 'H-119 (B-25): la empresa 2 elimina un pedido de la empresa 1 por URL');
 *
 * Si la falla no coincide, la prueba queda "se cortó en otro punto" y la corrida da rojo.
 * Sin esta línea, `test.fail()` sigue funcionando, y el informe la muestra "sin comprobar".
 * El patrón se busca en el mensaje de error completo, incluido el selector que no apareció.
 */

import { test } from '@playwright/test';

export const ANOTACION_FALLA_ESPERADA = 'debe-fallar-con';

export function debeFallarCon(patron: RegExp): void {
  test.info().annotations.push({ type: ANOTACION_FALLA_ESPERADA, description: patron.source });
}
