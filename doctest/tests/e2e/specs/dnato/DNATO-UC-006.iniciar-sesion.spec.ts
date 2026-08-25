/**
 * Caso de uso: DNATO-UC-006 — Iniciar sesión eligiendo la empresa
 * Catálogo: catalogo/dnato/DNATO-UC-006.yaml (v0.3, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-006.iniciar-sesion-eligiendo-la-empresa.feature
 *
 * Es la puerta de entrada de todo el sistema: si esto falla, no hay suite.
 */

import { expect, test } from '@playwright/test';

import { LoginPage } from '../../pages/dnato/LoginPage.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';
import { credenciales } from '../../fixtures/auth.ts';

const empresa1 = () => credenciales('empresa1');
const empresa2 = () => credenciales('empresa2');

test.describe('@dnato @DNATO-UC-006 Iniciar sesión eligiendo la empresa', () => {
  test('@smoke entra con las credenciales de su empresa', async ({ page }) => {
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));

    await expect(login.empresa).toBeVisible();
    await expect(login.email).toBeVisible();
    await expect(login.password).toBeVisible();

    await login.ingresar(empresa1());

    expect(await login.mensajeDeError()).toBeNull();
    await expect.poll(() => login.sesionIniciada()).toBe(true);
  });

  test('rechaza a un usuario que no pertenece a la empresa elegida', async ({ page }) => {
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));
    // Credenciales válidas de la empresa 1, pero eligiendo la empresa 2.
    await login.ingresar({ ...empresa1(), empresa: empresa2().empresa });

    expect(await login.mensajeDeError()).toMatch(/no corresponde a la empresa seleccionada/i);
    expect(await login.sesionIniciada()).toBe(false);
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

  test('ofrece registrarse y recuperar la contraseña', async ({ page }) => {
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));

    await expect(page.getByRole('link', { name: /regístrese|registrese/i })).toBeVisible();
    await expect(page.getByRole('link', { name: /recupere contraseña/i })).toBeVisible();
  });
});
