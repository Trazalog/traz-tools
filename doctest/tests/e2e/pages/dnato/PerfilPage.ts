/**
 * PerfilPage — "Perfil" del usuario conectado (DNATO-UC-010).
 *
 * ⚠️ Selectores: la vista todavía no tiene `data-testid`; van por un PR propio en
 * `traz-comp-dnato` (PHP 5.6).
 */

import type { Page } from '@playwright/test';

import { urlDnato } from '../../config/apps.ts';

export class PerfilPage {
  constructor(readonly page: Page) {}

  async abrir(): Promise<void> {
    await this.page.goto(urlDnato('main/profile'), { waitUntil: 'domcontentloaded' });
  }

  /** Texto visible de la pantalla, normalizado, para verificar qué datos muestra. */
  async contenido(): Promise<string> {
    return (await this.page.locator('body').innerText()).replace(/\s+/g, ' ');
  }

  async enPantalla(): Promise<boolean> {
    return this.page.url().includes('main/profile');
  }
}
