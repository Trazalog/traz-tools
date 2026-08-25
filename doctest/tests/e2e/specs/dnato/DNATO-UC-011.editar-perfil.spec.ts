/**
 * Caso de uso: DNATO-UC-011 — Editar los datos del perfil propio
 * Catálogo: catalogo/dnato/DNATO-UC-011.yaml (v0.3, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-011.editar-los-datos-del-perfil-propio.feature
 */

import { expect, test } from '../../fixtures/auth.ts';
import { credenciales } from '../../fixtures/auth.ts';
import { urlDnato } from '../../config/apps.ts';

test.describe('@dnato @DNATO-UC-011 Editar los datos del perfil propio', () => {
  test('el correo no se puede editar', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('main/changeuser'), { waitUntil: 'domcontentloaded' });
    const correo = paginaEmpresa1.locator('input[name="emailuser"]');
    await expect(correo).toBeVisible();

    // Regla validada por el PM: el correo es la identidad del usuario y no se cambia.
    await expect(correo).toHaveValue(credenciales('empresa1').email);
    await expect(correo).toHaveAttribute('readonly', /.*/);
  });

  test('guarda un cambio de nombre y lo deja aplicado', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('main/changeuser'), { waitUntil: 'domcontentloaded' });
    const nombre = paginaEmpresa1.locator('input[name="firstnameuser"]');
    const apellido = paginaEmpresa1.locator('input[name="lastnameuser"]');
    await expect(nombre).toBeVisible();

    const original = await nombre.inputValue();
    const nuevo = `${original} ✎`;

    await nombre.fill(nuevo);
    await paginaEmpresa1.locator('input[type="submit"], button[type="submit"]').first().click({ noWaitAfter: true });
    await paginaEmpresa1.waitForTimeout(1500);

    await paginaEmpresa1.goto(urlDnato('main/changeuser'), { waitUntil: 'domcontentloaded' });
    await expect(nombre).toHaveValue(nuevo);

    // Se deja como estaba: el dato de prueba tiene que sobrevivir a la corrida.
    await nombre.fill(original);
    await apellido.fill(await apellido.inputValue());
    await paginaEmpresa1.locator('input[type="submit"], button[type="submit"]').first().click({ noWaitAfter: true });
    await paginaEmpresa1.waitForTimeout(1500);
    await paginaEmpresa1.goto(urlDnato('main/changeuser'), { waitUntil: 'domcontentloaded' });
    await expect(nombre).toHaveValue(original);
  });
});
