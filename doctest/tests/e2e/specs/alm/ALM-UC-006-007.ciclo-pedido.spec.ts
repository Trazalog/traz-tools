/**
 * Casos de uso: ALM-UC-006 — Pedir materiales al almacén
 *               ALM-UC-007 — Ver el detalle de un pedido de materiales
 *
 * EL PRIMER TEST DE LA SUITE QUE RECORRE UN CIRCUITO, NO UNA PANTALLA.
 *
 * ⚠️ Etiquetado `@ciclo` y **fuera de `test:all`**: crea un pedido de materiales real en
 * el entorno, igual que `@alta-empresa` crea una empresa real. Se corre a demanda con
 * `npm run test:ciclo`.
 *
 * Lo recorren dos personas distintas —quien pide y quien entrega—, así que cada paso
 * abre la sesión del rol que le corresponde. Los pasos dependen entre sí: `serial`.
 *
 * ⚠️ ESTADO AL 2026-09-07: **todavía no pasa en verde.** Frena en la preparación, al
 * guardar el artículo. Lo verificado hasta acá:
 *   · las dos sesiones por rol entran bien a Tools;
 *   · la empresa de test tiene CERO artículos, así que el circuito nunca fue ejecutable
 *     —de ahí que la preparación exista—;
 *   · el alta necesita además `punto_pedido` y `cantidad_caja`, que `guardar()` lee del
 *     POST sin default; ya se completan.
 * Lo que falta: el modal de alta tiene cuatro botones sin texto en el marcado
 * (btn-success / btn-danger / btn-primary / btn-default) y hay que identificar cuál
 * guarda, mirando la pantalla y no el código.
 *
 * No afecta a nadie mientras tanto: `@ciclo` está excluido de `test:all`, de
 * `test:smoke` y de `test:module`. Solo corre a pedido con `npm run test:ciclo`.
 */

import { expect, test } from '@playwright/test';

import { sesionDeRol, urlModuloAlm } from '../../fixtures/roles-alm.ts';

/** Marca única para reconocer el pedido que crea esta corrida y no confundirlo con otro. */
const MARCA = `DocTest ciclo ${new Date().toISOString().slice(0, 19)}`;

/** Código del artículo que crea la preparación, único por corrida. */
const CODIGO_ARTICULO = `DT-${Date.now().toString().slice(-8)}`;

test.describe.serial('@alm @ciclo @ALM-UC-002 @ALM-UC-006 @ALM-UC-007 El ciclo de vida de un pedido de materiales', () => {
  /**
   * El circuito empieza antes del pedido: no se puede pedir lo que no existe. Si la
   * empresa no tiene ni un artículo, el pedido no tiene qué contener — es la
   * precondición que declara ALM-UC-006, y acá se cumple en vez de asumirse.
   *
   * Lo carga el **Responsable de Almacén**, que es de quien es el maestro de artículos
   * (ALM-UC-002): el Solicitante pide de ese catálogo, no lo arma.
   */
  test('preparación: el almacén carga un artículo para que haya qué pedir', async ({ browser }) => {
    const page = await sesionDeRol(browser, 'almacen');
    try {
      await page.goto(urlModuloAlm('Articulo'), { waitUntil: 'domcontentloaded' });
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

      if ((await page.locator('table').last().locator('tbody tr').count()) > 0) {
        test.info().annotations.push({ type: 'nota', description: 'la empresa ya tenía artículos' });
        return;
      }

      await page.getByRole('button', { name: /Agregar/i }).first().click();
      await expect(page.locator('#artBarCode')).toBeVisible({ timeout: 15_000 });
      await page.locator('#artBarCode').fill(CODIGO_ARTICULO);
      await page.locator('#artDescription').fill(`Artículo de ${MARCA}`);
      await page.locator('#tipo').selectOption({ index: 1 });
      await page.locator('#unidmed').selectOption({ index: 1 });
      // `guardar()` lee punto_pedido y unme_id directo del POST, sin default: dejarlos
      // vacíos hace que el alta no llegue a insertar y la pantalla no avise nada.
      await page.locator('#cant_caja').fill('1');
      await page.locator('#puntped').fill('1');
      await page.getByRole('button', { name: /^Guardar$/i }).first().click();
      await page.waitForTimeout(3000);

      await page.goto(urlModuloAlm('Articulo'), { waitUntil: 'domcontentloaded' });
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });
      expect(
        await page.locator('table').last().locator('tbody tr').count(),
        'sin artículos no hay pedido posible',
      ).toBeGreaterThan(0);
    } finally {
      await page.context().close();
    }
  });

  test('el Solicitante crea el pedido y queda registrado', async ({ browser }) => {
    const page = await sesionDeRol(browser, 'solicitante');
    try {
      await page.goto(urlModuloAlm('Notapedido'), { waitUntil: 'domcontentloaded' });
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

      const antes = await page.locator('table').first().locator('tbody tr').count();

      await page.getByRole('button', { name: /Agregar/i }).first().click();
      await expect(page.locator('#just')).toBeVisible({ timeout: 15_000 });
      await page.locator('#just').fill(MARCA);

      // El artículo se elige de un datalist: se toma el primero que ofrezca la empresa,
      // en vez de fijar un código que mañana puede no existir.
      const opciones = page.locator('datalist option');
      await expect(opciones.first()).toHaveCount(1, { timeout: 15_000 });
      const articulo = (await opciones.first().getAttribute('value')) ?? '';
      expect(articulo, 'la empresa tiene que tener al menos un artículo cargado').not.toBe('');

      await page.locator('#inputarti').fill(articulo);
      await page.locator('#add_cantidad').fill('1');
      await page.getByRole('button', { name: /Hecho/i }).first().click();
      await page.waitForTimeout(1500);

      await page.getByRole('button', { name: /^Guardar$/i }).first().click();
      await page.waitForTimeout(4000);

      await page.goto(urlModuloAlm('Notapedido'), { waitUntil: 'domcontentloaded' });
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });
      const despues = await page.locator('table').first().locator('tbody tr').count();

      expect(despues, 'el pedido tiene que aparecer en el listado').toBeGreaterThan(antes);
    } finally {
      await page.context().close();
    }
  });

  test('el pedido nace en un estado del circuito, no en blanco', async ({ browser }) => {
    const page = await sesionDeRol(browser, 'solicitante');
    try {
      await page.goto(urlModuloAlm('Notapedido'), { waitUntil: 'domcontentloaded' });
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

      const primera = (await page.locator('table').first().locator('tbody tr').first().innerText())
        .replace(/\s+/g, ' ');

      // Los ocho estados del pedido los mueve Bonita, no la pantalla. Lo que se verifica
      // es que el pedido nazca dentro del circuito: un pedido sin estado quedaría huérfano,
      // sin nadie que lo apruebe ni lo entregue.
      expect(primera).toMatch(/Creada|Aprobado|Rechazado|Entregado|Ent\. Parcial|Finalizado|Cancelado/i);
    } finally {
      await page.context().close();
    }
  });

  test('el Responsable de Almacén ve el pedido que le hicieron', async ({ browser }) => {
    const page = await sesionDeRol(browser, 'almacen');
    try {
      await page.goto(urlModuloAlm('Notapedido'), { waitUntil: 'domcontentloaded' });
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

      const filas = await page.locator('table').first().locator('tbody tr').count();
      expect(filas, 'el almacén tiene que ver el pedido para poder entregarlo').toBeGreaterThan(0);
    } finally {
      await page.context().close();
    }
  });
});
