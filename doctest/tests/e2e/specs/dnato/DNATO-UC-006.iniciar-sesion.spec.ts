/**
 * Caso de uso: DNATO-UC-006 — Iniciar sesión eligiendo la empresa
 * Catálogo: catalogo/dnato/DNATO-UC-006.yaml
 * Gherkin:  features/dnato/DNATO-UC-006.iniciar-sesion-eligiendo-la-empresa.feature
 *
 * Es la puerta de entrada de todo el sistema: si esto falla, no hay suite.
 *
 * El ingreso pasó a dos pasos (PR #26 de traz-comp-dnato, decisión del PM del
 * 2026-08-19): primero credenciales, y sólo si el usuario tiene más de una
 * empresa se le muestran para elegir. Ver la nota de versión 0.4 en el catálogo.
 */

import { expect, test } from '@playwright/test';

import { LoginPage } from '../../pages/dnato/LoginPage.ts';
import { requerirUrlDeApp, urlDnato } from '../../config/apps.ts';
import { credenciales } from '../../fixtures/auth.ts';

const empresa1 = () => credenciales('empresa1');

test.describe('@dnato @DNATO-UC-006 Iniciar sesión eligiendo la empresa', () => {
  test('@smoke entra con las credenciales de su empresa', async ({ page }) => {
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));

    await expect(login.email).toBeVisible();
    await expect(login.password).toBeVisible();

    await login.ingresar(empresa1());

    expect(await login.mensajeDeError()).toBeNull();
    await expect.poll(() => login.sesionIniciada()).toBe(true);
  });

  test('@smoke no revela las empresas del sistema antes de validar las credenciales', async ({ page }) => {
    // Reemplaza al escenario viejo "rechaza a un usuario que no pertenece a la
    // empresa elegida", que dejó de ser reproducible desde la interfaz: ya no se
    // elige empresa antes de autenticarse. Este es el control que ocupó su lugar
    // (hallazgo H4: el desplegable listaba TODAS las empresas sin sesión).
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));

    await expect(page.locator('select')).toHaveCount(0);
    expect(await login.empresasDisponibles()).toEqual([]);
  });

  test('no se puede saltar al paso de selección de empresa sin haber ingresado', async ({ page }) => {
    // La pertenencia se resuelve server-side: el paso 2 exige credenciales ya
    // validadas y no se puede alcanzar por dirección directa.
    const login = new LoginPage(page);
    await page.goto(urlDnato('main/seleccionar_empresa'));

    await expect(login.email).toBeVisible();
    expect(await login.mensajeDeError()).toMatch(/sesión expiró/i);
    expect(await login.sesionIniciada()).toBe(false);
  });

  test('cuando el usuario tiene más de una empresa, le ofrece elegir', async ({ page }) => {
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));
    await login.completar(empresa1());
    await login.enviar();

    test.skip(
      !(await login.enSeleccionDeEmpresa()),
      `El usuario de prueba ${empresa1().email} tiene una sola empresa, así que entra directo y el paso 2 no aplica. ` +
        `Para cubrir este escenario hace falta un usuario con membresías en dos empresas.`,
    );

    const ofrecidas = await login.empresasDisponibles();
    expect(ofrecidas.length).toBeGreaterThan(1);
    expect(ofrecidas).toContain(empresa1().empresa);

    await login.elegirEmpresa(empresa1().empresa);
    expect(await login.mensajeDeError()).toBeNull();
    await expect.poll(() => login.sesionIniciada()).toBe(true);
  });

  test('rechaza una contraseña equivocada', async ({ page }) => {
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));
    await login.ingresar({ ...empresa1(), password: 'Contrasena-Incorrecta-2026!' });

    expect(await login.mensajeDeError()).toMatch(/correo o contraseña incorrectos/i);
    expect(await login.sesionIniciada()).toBe(false);
  });

  test('no deja entrar con los campos vacíos', async ({ page }) => {
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));
    await login.enviar();

    expect(await login.sesionIniciada()).toBe(false);
  });

  test('ofrece crear una cuenta y recuperar la contraseña', async ({ page }) => {
    // El enlace de registro es configurable (LOGIN_MOSTRAR_REGISTRO en
    // constants.php) y se muestra como banner freemium, duplicado para móvil y
    // escritorio — de ahí el .first().
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));

    await expect(page.getByRole('link', { name: /crear cuenta gratis/i }).first()).toBeVisible();
    await expect(page.getByRole('link', { name: /olvidaste tu contraseña/i })).toBeVisible();
  });
});
