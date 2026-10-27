/**
 * Caso de uso: DNATO-UC-007 — Cerrar sesión
 * Catálogo: catalogo/dnato/DNATO-UC-007.yaml
 * Gherkin:  features/dnato/DNATO-UC-007.cerrar-sesion.feature
 *
 * ⚠️ Este caso NO usa la sesión compartida de las fixtures: cerrar sesión ejecuta un
 * `sess_destroy()` en el servidor, que invalida la sesión para TODOS los contextos
 * que estén usando esa misma cookie. Si tomara la sesión compartida, dejaría sin
 * sesión al resto de la suite. Por eso abre la suya y la cierra.
 */

import { expect, test } from '@playwright/test';

import { LoginPage } from '../../pages/dnato/LoginPage.ts';
import { UsuariosListPage } from '../../pages/dnato/UsuariosListPage.ts';
import { credenciales } from '../../fixtures/auth.ts';
import { requerirUrlDeApp, urlDnato } from '../../config/apps.ts';

test.describe('@dnato @DNATO-UC-007 Cerrar sesión', () => {
  test('@smoke al salir vuelve a la pantalla de ingreso y no se puede volver atrás', async ({ page }) => {
    const login = new LoginPage(page);
    await login.abrir(requerirUrlDeApp('dnato'));
    await login.ingresar(credenciales('empresa1'));
    await expect.poll(() => login.sesionIniciada()).toBe(true);

    const usuarios = new UsuariosListPage(page);
    await usuarios.abrir();
    expect(await usuarios.visible()).toBe(true);

    await page.goto(urlDnato('main/logout'), { waitUntil: 'domcontentloaded' });
    await expect(login.email).toBeVisible();

    // Volver a una pantalla interna después de salir tiene que devolver al ingreso.
    await page.goto(urlDnato('main/users'), { waitUntil: 'domcontentloaded' });
    await expect(login.email).toBeVisible();
  });
});
