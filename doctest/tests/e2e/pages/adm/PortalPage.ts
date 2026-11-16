/**
 * Portal de la empresa — módulo Administración (`traz-comp-adm`).
 *
 * En REQ-002 la pantalla es solo el marco: barra, empresa, menú con "Inicio" y saludo.
 * Los localizadores viven acá; los specs no usan selectores.
 */

import { type Locator, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../../config/apps.ts';

/** URL del Portal, con una ruta o query opcional (por ejemplo `?empr_id=1`). */
export function urlPortal(sufijo = ''): string {
  const base = requerirUrlDeApp('tools').replace(/\/$/, '');

  return `${base}/traz-comp-adm/portal${sufijo}`;
}

export class PortalPage {
  constructor(private readonly page: Page) {}

  /** Marco del Portal. */
  get raiz(): Locator {
    return this.page.locator('[data-testid="adm-portal"]');
  }

  /** Inicial y nombre de la empresa activa. */
  get empresa(): Locator {
    return this.page.locator('[data-testid="adm-portal-empresa"]');
  }

  /** Menú lateral (en REQ-002 solo "Inicio"). */
  get menu(): Locator {
    return this.page.locator('[data-testid="adm-portal-menu"]');
  }

  /** Saludo "Hola, <nombre>". */
  get saludo(): Locator {
    return this.page.locator('[data-testid="adm-portal-saludo"]');
  }

  /** Vuelta al tablero de Tools. */
  get irATools(): Locator {
    return this.page.locator('[data-testid="adm-ir-a-tools"]');
  }

  /** Pantalla de error: sin permiso (403). */
  get sinPermiso(): Locator {
    return this.page.locator('[data-testid="adm-sin-permiso"]');
  }

  /** Pantalla de error: la página no existe (404). */
  get noExiste(): Locator {
    return this.page.locator('[data-testid="adm-no-existe"]');
  }

  /** Abre el Portal, con una ruta o query opcional. */
  async abrir(sufijo = ''): Promise<void> {
    await this.page.goto(urlPortal(sufijo));
  }

  /** Texto visible de la página, normalizado. */
  async texto(): Promise<string> {
    return (await this.page.locator('body').innerText()).replace(/\s+/g, ' ').trim();
  }
}
