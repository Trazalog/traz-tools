/**
 * LoginPage — pantalla de ingreso de Dnato ("Bienvenido! Ingrese por favor").
 *
 * Es la puerta de entrada de todas las apps: Dnato autentica y redirige a Tools.
 * La usan las fixtures de sesión (`fixtures/auth.ts`) y el caso DNATO-UC-006.
 *
 * ⚠️ Selectores: la vista de Dnato todavía no tiene `data-testid` (eso entra por
 * un PR propio en `traz-comp-dnato`, que es PHP 5.6). Hasta entonces se usan los
 * `id` del formulario, que son estables desde hace años, y quedan acá aislados:
 * cuando lleguen los `data-testid` se cambia este archivo y nada más.
 */

import type { Locator, Page } from '@playwright/test';

export interface CredencialesEmpresa {
  /** Nombre de la empresa tal como aparece en el desplegable. */
  empresa: string;
  email: string;
  password: string;
}

export class LoginPage {
  readonly page: Page;
  readonly empresa: Locator;
  readonly email: Locator;
  readonly password: Locator;
  readonly ingresar_: Locator;

  constructor(page: Page) {
    this.page = page;
    this.empresa = page.locator('#empr_id');
    this.email = page.locator('#email');
    this.password = page.locator('#password');
    this.ingresar_ = page.locator('input[type="submit"]');
  }

  async abrir(urlLogin: string): Promise<void> {
    await this.page.goto(urlLogin);
    await this.empresa.waitFor();
  }

  /** Empresas ofrecidas en el desplegable, sin la opción "Seleccione Empresa...". */
  async empresasDisponibles(): Promise<string[]> {
    const todas = await this.empresa.locator('option').allInnerTexts();
    return todas.map((e) => e.trim()).filter((e) => e && !/^seleccione/i.test(e));
  }

  async completar({ empresa, email, password }: CredencialesEmpresa): Promise<void> {
    await this.empresa.selectOption({ label: empresa });
    await this.email.fill(email);
    await this.password.fill(password);
  }

  /**
   * Envía el formulario. No espera la navegación en el click: el ingreso encadena
   * una consulta al sistema de procesos y un redirect a Tools, que puede tardar.
   */
  async enviar(): Promise<void> {
    await this.ingresar_.first().click({ noWaitAfter: true });
    await this.page.waitForLoadState('networkidle', { timeout: 120_000 }).catch(() => {});
  }

  async ingresar(credenciales: CredencialesEmpresa): Promise<void> {
    await this.completar(credenciales);
    await this.enviar();
  }

  /** Mensaje de error visible, o `null` si el ingreso no mostró ninguno. */
  async mensajeDeError(): Promise<string | null> {
    const texto = await this.page.locator('body').innerText();
    const conocidos = [
      /El usuario no corresponde a la empresa seleccionada\./i,
      /Correo o contraseña incorrectos\./i,
      /temporalmente inhabilitado/i,
      /Error de inicio de sesión en BPM\./i,
    ];
    for (const patron of conocidos) {
      const encontrado = patron.exec(texto);
      if (encontrado) return encontrado[0];
    }
    return null;
  }

  /** True si la sesión quedó abierta (el formulario de ingreso ya no está). */
  async sesionIniciada(): Promise<boolean> {
    return (await this.empresa.count()) === 0;
  }
}
