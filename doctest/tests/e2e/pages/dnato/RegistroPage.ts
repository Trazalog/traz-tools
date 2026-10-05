/**
 * RegistroPage — formulario público de registración de Dnato (DNATO-UC-001).
 *
 * Es la única pantalla del módulo que se usa sin sesión. La usan el caso de
 * registro y el seed que crea las empresas de test.
 *
 * ⚠️ Selectores: la vista todavía no tiene `data-testid`; van por un PR propio en
 * `traz-comp-dnato` (PHP 5.6). Quedan todos acá.
 */

import { expect, type Locator, type Page } from '@playwright/test';

import { urlDnato } from '../../config/apps.ts';

export interface DatosRegistro {
  nombre: string;
  apellido: string;
  email: string;
  razonSocial: string;
  telefono: string;
  /** Texto del país tal como aparece en la lista (la opción incluye la bandera). */
  pais: string;
}

export class RegistroPage {
  readonly page: Page;
  readonly nombre: Locator;
  readonly apellido: Locator;
  readonly email: Locator;
  readonly razonSocial: Locator;
  readonly telefono: Locator;
  readonly pais: Locator;
  readonly enviar_: Locator;

  constructor(page: Page) {
    this.page = page;
    this.nombre = page.locator('input[name="firstname"]');
    this.apellido = page.locator('input[name="lastname"]');
    this.email = page.locator('input[name="email"]');
    this.razonSocial = page.locator('input[name="reg_razon_social"]');
    this.telefono = page.locator('input[name="telefono"]');
    this.pais = page.locator('select[name="reg_pais_id"]');
    this.enviar_ = page.locator('input[type="submit"], button[type="submit"]');
  }

  async abrir(): Promise<void> {
    await this.page.goto(urlDnato('main/register'), { waitUntil: 'domcontentloaded' });
    await this.nombre.waitFor();
  }

  async completar(d: DatosRegistro): Promise<void> {
    await this.nombre.fill(d.nombre);
    await this.apellido.fill(d.apellido);
    await this.email.fill(d.email);
    await this.razonSocial.fill(d.razonSocial);
    await this.telefono.fill(d.telefono);
    // La opción trae la bandera en el texto ("🇦🇷 Argentina"), así que se busca por contenido.
    const valor = await this.pais
      .locator('option')
      .filter({ hasText: new RegExp(d.pais, 'i') })
      .first()
      .getAttribute('value');
    if (valor) await this.pais.selectOption(valor);
  }

  async enviar(): Promise<void> {
    await this.enviar_.first().click({ noWaitAfter: true });
    await this.page.waitForLoadState('networkidle', { timeout: 120_000 }).catch(() => {});
  }

  /** Mensaje que quedó en pantalla después de enviar (éxito o rechazo). */
  async mensaje(): Promise<string> {
    return (await this.page.locator('body').innerText()).replace(/\s+/g, ' ');
  }

  /**
   * Espera hasta que la pantalla muestre el mensaje esperado y lo devuelve.
   *
   * Leer el body una sola vez apenas vuelve el POST es una carrera: cuando el
   * DEMO está cargado, la respuesta todavía no terminó de pintar y el test falla
   * sin que haya nada roto en el sistema.
   */
  async esperarMensaje(esperado: RegExp, timeout = 20_000): Promise<string> {
    const leer = async () => (await this.page.locator('body').innerText()).replace(/\s+/g, ' ');
    await expect.poll(leer, { timeout }).toMatch(esperado);
    return leer();
  }
}
