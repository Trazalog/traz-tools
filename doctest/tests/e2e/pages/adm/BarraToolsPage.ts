/**
 * Barra superior de Tools — módulo Administración (`traz-comp-adm`).
 *
 * Los botones "🏢 Mi empresa" (administradores) y "🔑 Consola" (superusuarios) los
 * dibuja `application/views/layout/perfil.php` a partir del Contexto que pide
 * `Dash::index()`. Este page object junta los localizadores de esa barra.
 */

import { type Locator, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../../config/apps.ts';

/** URL del tablero de Tools (donde se dibuja la barra). */
export function urlTableroTools(): string {
  return requerirUrlDeApp('tools');
}

export class BarraToolsPage {
  constructor(private readonly page: Page) {}

  /** Botón "🏢 Mi empresa": solo administradores de la empresa activa. */
  get miEmpresa(): Locator {
    return this.page.locator('[data-testid="adm-tools-mi-empresa"]');
  }

  /** Botón "🔑 Consola": solo superusuarios. */
  get consola(): Locator {
    return this.page.locator('[data-testid="adm-tools-consola"]');
  }

  /** Abre el tablero de Tools (donde se arma la barra). */
  async abrirTablero(): Promise<void> {
    await this.page.goto(urlTableroTools());
    await this.page.waitForLoadState('domcontentloaded');
  }
}
