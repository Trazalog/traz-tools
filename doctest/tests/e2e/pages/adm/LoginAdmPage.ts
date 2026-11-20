/**
 * Ingreso y páginas públicas del módulo Administración (`traz-comp-adm`).
 *
 * Localizadores de la copia del ingreso de DNATO. Los ids/name (`#email`, `#password`,
 * botón "Ingresar") son los mismos de DNATO a propósito: las pruebas DNATO-UC-001 a 008
 * corren contra la copia sin cambiar nada más que la dirección base.
 */

import { type Locator, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../../config/apps.ts';

/** URL del ingreso del módulo, con una ruta o query opcional. */
export function urlLoginAdm(sufijo = ''): string {
  const base = requerirUrlDeApp('tools').replace(/\/$/, '');

  return `${base}/traz-comp-adm/main/login${sufijo}`;
}

export class LoginAdmPage {
  constructor(private readonly page: Page) {}

  /** Campo de correo del ingreso. */
  get email(): Locator {
    return this.page.locator('#email');
  }

  /** Campo de contraseña del ingreso. */
  get password(): Locator {
    return this.page.locator('#password');
  }

  /** Botón "Ingresar". */
  get ingresar(): Locator {
    return this.page.getByRole('button', { name: 'Ingresar' });
  }

  /** Enlace "Crear cuenta gratis" (banner de autoregistro). */
  get enlaceRegistro(): Locator {
    return this.page.getByRole('link', { name: /Crear cuenta gratis/i }).first();
  }

  /** Enlace "¿Olvidaste tu contraseña?". */
  get enlaceRecuperar(): Locator {
    return this.page.getByRole('link', { name: /Olvidaste tu contraseña/i });
  }

  /** Pantalla de error: envío sin el código de seguridad (403). */
  get envioRechazado(): Locator {
    return this.page.locator('[data-testid="adm-envio-rechazado"]');
  }

  /** Pantalla de error: la página no existe (404). */
  get noExiste(): Locator {
    return this.page.locator('[data-testid="adm-no-existe"]');
  }

  /** Abre el ingreso del módulo. */
  async abrir(sufijo = ''): Promise<void> {
    await this.page.goto(urlLoginAdm(sufijo));
  }

  /** Texto visible de la página, normalizado. */
  async texto(): Promise<string> {
    return (await this.page.locator('body').innerText()).replace(/\s+/g, ' ').trim();
  }
}
