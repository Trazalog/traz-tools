/**
 * LoginManPage — el ingreso propio de AssetPlanner.
 *
 * Mantenimiento **no comparte la sesión de Tools**: tiene su propio formulario y su propio padrón
 * de usuarios (la tabla `sisusers` de asset, no `seg.users` de Dnato). Por eso MAN necesita su
 * propia fixture de sesión y el `storageState` de Tools no le sirve.
 *
 * ⚠️ Hoy **ningún usuario creado por la registración puede entrar**: la contraseña se guarda sin
 * hashear y AssetPlanner la compara contra MD5 (issue #489). Los tests corren con un usuario
 * provisto aparte, que se configura en `.env`.
 */

import type { Locator, Page } from '@playwright/test';

export interface CredencialesMan {
  usuario: string;
  password: string;
}

export class LoginManPage {
  readonly page: Page;
  readonly usuario: Locator;
  readonly password: Locator;
  readonly ingresar_: Locator;

  constructor(page: Page) {
    this.page = page;
    this.usuario = page.locator('#usrName');
    this.password = page.locator('#usrPassword');
    this.ingresar_ = page.locator('#login');
  }

  /**
   * Abre el ingreso. El DEMO corta la conexión de vez en cuando al abrir esta app, así que
   * reintenta: un fallo de red no es un fallo del sistema.
   */
  async abrir(urlBase: string): Promise<void> {
    let abierta = null;
    for (let intento = 1; intento <= 3 && !abierta; intento++) {
      abierta = await this.page
        .goto(urlBase, { waitUntil: 'domcontentloaded', timeout: 90_000 })
        .catch(() => null);
      if (!abierta) await this.page.waitForTimeout(3000);
    }
    if (!abierta) throw new Error(`No se pudo abrir AssetPlanner en ${urlBase} después de 3 intentos.`);
    await this.usuario.waitFor({ timeout: 30_000 });
  }

  async ingresar({ usuario, password }: CredencialesMan): Promise<void> {
    await this.usuario.fill(usuario);
    await this.password.fill(password);
    await this.ingresar_.click({ noWaitAfter: true });
    // El ingreso encadena consultas al proceso de Bonita y tarda; se espera al panel.
    await this.page.waitForTimeout(11_000);
  }

  /**
   * `true` si sigue en el ingreso. Se mira el campo de contraseña y no el cartel de error, porque
   * un rechazo no siempre muestra mensaje — verificado contra el DEMO.
   */
  async sigueEnElIngreso(): Promise<boolean> {
    return (await this.password.count()) > 0;
  }
}
