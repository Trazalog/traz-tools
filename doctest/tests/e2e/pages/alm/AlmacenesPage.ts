/**
 * Acceso a las pantallas de Almacenes.
 *
 * Almacenes es un módulo dentro de Trazalog Tools (`ALM = 'traz-comp-almacenes/'` en
 * `constants.php`), así que usa la sesión de Tools —la de `fixtures/auth.ts`— y no una propia:
 * a diferencia de AssetPlanner, acá no hay un padrón aparte.
 *
 * Las grillas del módulo las arma DataTables después de la carga y varias se paginan **contra el
 * servidor**, así que hay que esperar al encabezado y no al `load` de la página.
 */

import { expect, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../../config/apps.ts';

/** Las pantallas que hoy tienen caso relevado, por el controlador que las dibuja. */
export const PANTALLAS = {
  articulos: 'Articulo',
  stock: 'Lote/indexStock',
  ajustes: 'Ajustestock',
  movimientosInternos: 'Movimientointerno',
  historico: 'Reportes/historicoArticulos',
} as const;

export type Pantalla = keyof typeof PANTALLAS;

/** URL de una pantalla de Almacenes en el entorno configurado. */
export function urlAlm(pantalla: Pantalla): string {
  const base = requerirUrlDeApp('tools').replace(/\/$/, '');
  return `${base}/traz-comp-almacenes/${PANTALLAS[pantalla]}`;
}

export class AlmacenesPage {
  constructor(private readonly page: Page) {}

  async abrir(pantalla: Pantalla): Promise<void> {
    await this.page.goto(urlAlm(pantalla), { waitUntil: 'domcontentloaded' });
  }

  /**
   * Encabezados de la grilla, como un solo texto.
   *
   * El timeout es largo a propósito: el DEMO es una máquina chica y, con la suite completa
   * corriendo, una grilla que se pagina contra el servidor tarda bastante más que abierta sola.
   * Un timeout corto hace fallar un test que pasa en aislamiento, que es la peor clase de falla.
   */
  async encabezados(timeout = 60_000): Promise<string> {
    const th = this.page.locator('table thead th');
    await expect(th.first()).toBeVisible({ timeout });
    return (await th.allInnerTexts()).join(' | ');
  }

  /** Texto completo de la pantalla, normalizado, para buscar rótulos y mensajes. */
  async texto(): Promise<string> {
    return (await this.page.locator('body').innerText()).replace(/\s+/g, ' ');
  }

  /** ¿La pantalla quedó en el ingreso? Señal de que la sesión no viajó. */
  async pideIngreso(): Promise<boolean> {
    return /iniciar sesi[oó]n|ingres(ar|o)|password/i.test(await this.texto());
  }
}
