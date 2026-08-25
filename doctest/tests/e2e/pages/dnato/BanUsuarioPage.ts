/**
 * BanUsuarioPage — "Gestión de Usuarios → Habilitar/Deshabilitar Usuario"
 * (DNATO-UC-016). Es la baja lógica del sistema: la que sí conserva al usuario.
 *
 * ⚠️ Selectores: sin `data-testid` todavía; van por un PR propio en `traz-comp-dnato`.
 */

import type { Locator, Page } from '@playwright/test';

import { urlDnato } from '../../config/apps.ts';

export class BanUsuarioPage {
  readonly page: Page;
  /** La pantalla elige al usuario con un desplegable, no con una grilla. */
  readonly usuario: Locator;
  readonly estado: Locator;

  constructor(page: Page) {
    this.page = page;
    this.usuario = page.locator('select[name="email"]');
    this.estado = page.locator('select[name="banuser"]');
  }

  async abrir(): Promise<void> {
    await this.page.goto(urlDnato('main/banuser'), { waitUntil: 'domcontentloaded' });
    await this.usuario.waitFor({ state: 'visible', timeout: 60_000 }).catch(() => {});
  }

  /** Correos ofrecidos para habilitar o inhabilitar. */
  async correos(): Promise<string[]> {
    const opciones = await this.usuario.locator('option').allInnerTexts();
    return opciones
      .map((o) => /[\w.+-]+@[\w.-]+\.\w+/.exec(o)?.[0])
      .filter((c): c is string => !!c);
  }

  async enPantalla(): Promise<boolean> {
    return this.page.url().includes('main/banuser');
  }
}
