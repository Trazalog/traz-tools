/**
 * Consola de Trazalog — módulo Administración (`traz-comp-adm`).
 *
 * En REQ-002 la pantalla es solo el marco: barra "Trazalog · Consola", leyenda
 * "solo súper usuarios" y las vueltas al Portal y a Tools.
 */

import { type Locator, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../../config/apps.ts';

/** URL de la Consola, con una ruta o query opcional. */
export function urlConsola(sufijo = ''): string {
  const base = requerirUrlDeApp('tools').replace(/\/$/, '');

  return `${base}/traz-comp-adm/consola${sufijo}`;
}

export class ConsolaPage {
  constructor(private readonly page: Page) {}

  /** Marco de la Consola. */
  get raiz(): Locator {
    return this.page.locator('[data-testid="adm-consola"]');
  }

  /** Vuelta al Portal de la empresa. */
  get irAPortal(): Locator {
    return this.page.locator('[data-testid="adm-ir-a-portal"]');
  }

  /** Vuelta al tablero de Tools. */
  get irATools(): Locator {
    return this.page.locator('[data-testid="adm-ir-a-tools"]');
  }

  /** Pantalla de error: sin permiso (403). */
  get sinPermiso(): Locator {
    return this.page.locator('[data-testid="adm-sin-permiso"]');
  }

  /** Abre la Consola, con una ruta o query opcional. */
  async abrir(sufijo = ''): Promise<void> {
    await this.page.goto(urlConsola(sufijo));
  }
}
