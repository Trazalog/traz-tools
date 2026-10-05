/**
 * Esperar una grilla de AssetPlanner.
 *
 * Las grillas se llenan por DataTables después de la carga, y el DEMO es una máquina chica: cuando
 * corre la suite completa, un listado pesado —el de informes tiene decenas de filas— tarda bastante
 * más que abierto solo. Esperar el encabezado con un timeout corto hacía fallar un test que pasaba
 * en aislamiento, que es la peor clase de falla: la que no dice nada del sistema.
 */

import { expect, type Page } from '@playwright/test';

/** Espera a que la grilla esté visible y devuelve sus encabezados como un solo texto. */
export async function encabezadosDeGrilla(page: Page, timeout = 60_000): Promise<string> {
  const encabezados = page.locator('table thead th');
  await expect(encabezados.first()).toBeVisible({ timeout });
  return (await encabezados.allInnerTexts()).join(' | ');
}

/**
 * Los encabezados sin exigir que se vean. Las pantallas de Reportes arman la tabla pero la dejan
 * oculta hasta que se consulta, así que ahí la estructura se verifica sin visibilidad.
 */
export async function encabezadosOcultos(page: Page): Promise<string> {
  return (await page.locator('table thead th').allTextContents()).join(' | ');
}
