/**
 * AltaUsuarioPage — "Gestión de Usuarios → Agregar Usuario" (DNATO-UC-014).
 *
 * ⚠️ Selectores: la vista todavía no tiene `data-testid`; van por un PR propio en
 * `traz-comp-dnato` (PHP 5.6). Quedan todos acá.
 */

import type { Locator, Page } from '@playwright/test';

import { urlDnato } from '../../config/apps.ts';

export interface DatosUsuario {
  nombre: string;
  apellido: string;
  email: string;
  empresa: string;
  /** Perfil de Dnato: la etiqueta de la pantalla dice "Rol" (hallazgo H-025). */
  perfil?: string;
  password: string;
  telefono?: string;
  dni?: string;
}

export class AltaUsuarioPage {
  readonly page: Page;
  readonly nombre: Locator;
  readonly apellido: Locator;
  readonly email: Locator;
  readonly empresa: Locator;
  readonly perfil: Locator;
  readonly password: Locator;
  readonly passconf: Locator;
  readonly guardar: Locator;

  constructor(page: Page) {
    this.page = page;
    this.nombre = page.locator('input[name="firstname"]');
    this.apellido = page.locator('input[name="lastname"]');
    this.email = page.locator('input[name="email"]');
    this.empresa = page.locator('select[name="business"]');
    this.perfil = page.locator('select[name="role"]');
    this.password = page.locator('input[name="password"]');
    this.passconf = page.locator('input[name="passconf"]');
    this.guardar = page.locator('input[type="submit"], button[type="submit"]');
  }

  async abrir(): Promise<void> {
    await this.page.goto(urlDnato('main/adduser'), { waitUntil: 'domcontentloaded' });
    await this.nombre.waitFor({ timeout: 60_000 });
  }

  /** Empresas ofrecidas en el desplegable, sin la opción de placeholder. */
  async empresasOfrecidas(): Promise<string[]> {
    const todas = await this.empresa.locator('option').allInnerTexts();
    return todas.map((e) => e.trim()).filter((e) => e && !/^-?\s*seleccione/i.test(e));
  }

  async completar(d: DatosUsuario): Promise<void> {
    await this.nombre.fill(d.nombre);
    await this.apellido.fill(d.apellido);
    await this.email.fill(d.email);
    if (d.telefono) await this.page.locator('input[name="telefono"]').fill(d.telefono);
    if (d.dni) await this.page.locator('input[name="dni"]').fill(d.dni);
    await this.empresa.selectOption({ label: d.empresa });
    await this.perfil.selectOption({ index: 1 });
    await this.password.fill(d.password);
    await this.passconf.fill(d.password);
  }

  async enviar(): Promise<void> {
    await this.guardar.first().click({ noWaitAfter: true });
    await this.page.waitForLoadState('domcontentloaded');
  }

  async mensaje(): Promise<string> {
    return (await this.page.locator('body').innerText()).replace(/\s+/g, ' ');
  }
}
