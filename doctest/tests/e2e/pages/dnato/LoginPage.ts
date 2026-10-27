/**
 * LoginPage — pantalla de ingreso de Dnato ("Bienvenido").
 *
 * Es la puerta de entrada de todas las apps: Dnato autentica y redirige a Tools.
 * La usan las fixtures de sesión (`fixtures/auth.ts`) y el caso DNATO-UC-006.
 *
 * ⚠️ El ingreso tiene DOS PASOS desde el PR #26 de `traz-comp-dnato` (desplegado
 * en demo como v2.5.0.2), que implementó la decisión del PM del 2026-08-19:
 *
 *   Paso 1 — sólo correo y contraseña. La pantalla ya NO trae un desplegable de
 *            empresas: antes listaba todas las del sistema a cualquiera que
 *            abriera el login sin sesión.
 *   Paso 2 — sólo si el usuario pertenece a más de una empresa. Se muestran sus
 *            empresas como tarjetas y elige una. Con una sola empresa, el paso 2
 *            no aparece y entra directo.
 *
 * Por eso `ingresar()` resuelve los dos casos solo: completa credenciales y, si
 * aparece el paso 2, elige la empresa que venga en las credenciales. Los tests
 * no tienen que saber cuántas empresas tiene el usuario de prueba.
 *
 * ⚠️ Selectores: la vista de Dnato todavía no tiene `data-testid` (eso entra por
 * un PR propio en `traz-comp-dnato`, que es PHP 5.6). Hasta entonces se usan los
 * `id` del formulario y las clases del paso 2, que quedan acá aislados: cuando
 * lleguen los `data-testid` se cambia este archivo y nada más.
 */

import type { Locator, Page } from '@playwright/test';

export interface CredencialesEmpresa {
  /**
   * Nombre de la empresa tal como aparece en la tarjeta del paso 2.
   * Sólo se usa si el usuario tiene más de una empresa; con una sola se ignora.
   */
  empresa: string;
  email: string;
  password: string;
}

/** Mensajes que el login puede mostrar. Salen de `Main.php` (login / seleccionar_empresa). */
const MENSAJES_DE_ERROR: readonly RegExp[] = [
  /Correo o contraseña incorrectos\./i,
  /Tu usuario no tiene ninguna empresa asignada en el sistema\./i,
  /La empresa seleccionada no corresponde a tu usuario\./i,
  /Token de seguridad inválido\./i,
  /Tu sesión expiró\. Ingresá nuevamente\./i,
  /Elegí una empresa para continuar\./i,
  /temporalmente inhabilitado/i,
  /Error de inicio de sesión en BPM\./i,
];

export class LoginPage {
  readonly page: Page;
  /** Paso 1 */
  readonly email: Locator;
  readonly password: Locator;
  readonly ingresar_: Locator;
  /** Paso 2 — cada empresa es un `<button>` real dentro de su propio form. */
  readonly tarjetasEmpresa: Locator;
  /** Paso 2 — sólo el nombre de cada empresa, sin el logo. */
  readonly nombresEmpresa: Locator;

  constructor(page: Page) {
    this.page = page;
    this.email = page.locator('#email');
    this.password = page.locator('#password');
    this.ingresar_ = page.locator('button[type="submit"], input[type="submit"]');
    this.tarjetasEmpresa = page.locator('.tz-sel__card-btn');
    this.nombresEmpresa = page.locator('.tz-sel__nombre');
  }

  async abrir(urlLogin: string): Promise<void> {
    await this.page.goto(urlLogin);
    await this.email.waitFor();
  }

  /** True si el ingreso quedó parado en el paso 2 (selección de empresa). */
  async enSeleccionDeEmpresa(): Promise<boolean> {
    return (await this.tarjetasEmpresa.count()) > 0;
  }

  /**
   * Empresas ofrecidas en el paso 2.
   *
   * Devuelve `[]` si el ingreso no llegó a ese paso — o sea, si el usuario tiene
   * una sola empresa, o si todavía no se enviaron las credenciales. A diferencia
   * del login viejo, esta lista NO existe antes de autenticarse: ese era
   * justamente el hallazgo H4 que el cambio de v3 vino a cerrar.
   */
  async empresasDisponibles(): Promise<string[]> {
    if (!(await this.enSeleccionDeEmpresa())) return [];
    const todas = await this.nombresEmpresa.allInnerTexts();
    return todas.map((e) => e.trim()).filter(Boolean);
  }

  /** Paso 1: completa correo y contraseña. La empresa ya no se elige acá. */
  async completar({ email, password }: CredencialesEmpresa): Promise<void> {
    await this.email.fill(email);
    await this.password.fill(password);
  }

  /**
   * Envía el paso 1. No espera la navegación en el click: el ingreso encadena
   * una consulta al sistema de procesos y un redirect a Tools, que puede tardar.
   */
  async enviar(): Promise<void> {
    await this.ingresar_.first().click({ noWaitAfter: true });
    await this.page.waitForLoadState('networkidle', { timeout: 120_000 }).catch(() => {});
  }

  /**
   * Paso 2: elige una empresa por su nombre.
   * Falla con un mensaje accionable si esa empresa no está entre las ofrecidas,
   * en vez de dejar que el click se quede esperando un selector que no existe.
   */
  async elegirEmpresa(nombre: string): Promise<void> {
    const tarjeta = this.tarjetasEmpresa.filter({ hasText: nombre }).first();
    if ((await tarjeta.count()) === 0) {
      const ofrecidas = await this.empresasDisponibles();
      throw new Error(
        `La empresa "${nombre}" no aparece entre las ofrecidas en el paso 2: ${ofrecidas.join(', ') || '(ninguna)'}. ` +
          `Revisá DOCTEST_EMPRESA*_NOMBRE en doctest/.env: tiene que coincidir con el nombre que muestra la tarjeta.`,
      );
    }
    await tarjeta.click({ noWaitAfter: true });
    await this.page.waitForLoadState('networkidle', { timeout: 120_000 }).catch(() => {});
  }

  /**
   * Ingreso completo, resolviendo los dos pasos.
   * Si el usuario tiene una sola empresa el paso 2 no aparece y `empresa` no se usa.
   */
  async ingresar(credenciales: CredencialesEmpresa): Promise<void> {
    await this.completar(credenciales);
    await this.enviar();
    if (await this.enSeleccionDeEmpresa()) {
      await this.elegirEmpresa(credenciales.empresa);
    }
  }

  /** Mensaje de error visible, o `null` si el ingreso no mostró ninguno. */
  async mensajeDeError(): Promise<string | null> {
    const texto = await this.page.locator('body').innerText();
    for (const patron of MENSAJES_DE_ERROR) {
      const encontrado = patron.exec(texto);
      if (encontrado) return encontrado[0];
    }
    return null;
  }

  /**
   * True si la sesión quedó abierta.
   *
   * No alcanza con mirar si el formulario desapareció: entre el paso 1 y el 2 no
   * hay formulario de ingreso y la sesión todavía no está abierta. Por eso se
   * exige además haber salido de las dos pantallas de entrada.
   */
  async sesionIniciada(): Promise<boolean> {
    if (/\/main\/(login|seleccionar_empresa)/i.test(this.page.url())) return false;
    if (await this.enSeleccionDeEmpresa()) return false;
    return (await this.password.count()) === 0;
  }
}
