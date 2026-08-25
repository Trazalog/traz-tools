/**
 * Caso de uso: DNATO-UC-012 — Cambiar la contraseña propia
 * Catálogo: catalogo/dnato/DNATO-UC-012.yaml (v0.3, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-012.cambiar-la-contrasena-propia.feature
 *
 * Cambiar la contraseña del usuario de prueba es delicado: si el test se corta a la
 * mitad, la credencial del entorno queda distinta de la del `.env`. Por eso corre
 * sobre la SEGUNDA empresa de test, deja la contraseña como estaba y lo verifica al
 * final.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { credenciales } from '../../fixtures/auth.ts';
import { urlDnato } from '../../config/apps.ts';

const NUEVA = 'Doctest2026#Temporal';

/** Valida credenciales por el ingreso OAuth, que no pide empresa. */
async function credencialesValidas(page: import('@playwright/test').Page, email: string, password: string): Promise<boolean> {
  const params = new URLSearchParams({
    client_id: 'trazalog-mcp-connector',
    redirect_uri: 'https://claude.ai/api/mcp/auth_callback',
    response_type: 'code',
    code_challenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    code_challenge_method: 'S256',
    state: 'doctest',
  });
  let vuelta = '';
  const vueltaEsperada = 'https://claude.ai/api/mcp/auth_callback';
  const escucha = (r: import('@playwright/test').Request) => {
    if (!vuelta && r.url().startsWith(vueltaEsperada)) vuelta = r.url();
  };
  page.on('request', escucha);
  await page.goto(`${urlDnato('oauth/login')}?${params}`, { waitUntil: 'domcontentloaded' });
  await page.locator('input[name="email"]').fill(email);
  await page.locator('input[name="password"]').fill(password);
  await page.locator('button[type="submit"], input[type="submit"]').first().click({ noWaitAfter: true });
  await page.waitForTimeout(6000);
  page.off('request', escucha);
  const texto = (await page.locator('body').innerText().catch(() => '')).replace(/\s+/g, ' ');
  return vuelta !== '' || /no tiene empresa asignada|m[úu]ltiples empresas/i.test(texto);
}

/** La pantalla de perfil separa los datos de la contraseña en dos solapas. */
async function abrirSolapaContrasena(page: import('@playwright/test').Page): Promise<void> {
  await page.goto(urlDnato('main/changeuser'), { waitUntil: 'domcontentloaded' });
  const solapa = page.getByRole('link', { name: /contrase/i }).first();
  if (await solapa.count()) await solapa.click();
  else await page.getByText(/contrase/i).first().click().catch(() => {});
  await page.locator('input[name="password"]').waitFor({ state: 'visible', timeout: 15_000 });
}

async function cambiarPassword(page: import('@playwright/test').Page, nueva: string): Promise<string> {
  await abrirSolapaContrasena(page);
  await page.locator('input[name="password"]').fill(nueva);
  await page.locator('input[name="passconf"]').fill(nueva);
  await page.locator('input[type="submit"], button[type="submit"]').last().click({ noWaitAfter: true });
  await page.waitForTimeout(2500);
  return (await page.locator('body').innerText()).replace(/\s+/g, ' ');
}

test.describe('@dnato @DNATO-UC-012 Cambiar la contraseña propia', () => {
  test('la pantalla pide la contraseña nueva y su confirmación', async ({ paginaEmpresa2 }) => {
    await abrirSolapaContrasena(paginaEmpresa2);

    await expect(paginaEmpresa2.locator('input[name="password"]')).toBeVisible();
    await expect(paginaEmpresa2.locator('input[name="passconf"]')).toBeVisible();
  });

  test('cambia la contraseña y la nueva queda vigente', async ({ paginaEmpresa2, page }) => {
    test.slow();
    const datos = credenciales('empresa2');

    try {
      const mensaje = await cambiarPassword(paginaEmpresa2, NUEVA);
      expect(mensaje).toMatch(/actualizada|correctamente/i);
      expect(await credencialesValidas(page, datos.email, NUEVA)).toBe(true);
    } finally {
      // Pase lo que pase, la contraseña vuelve a ser la que conoce el `.env`.
      await cambiarPassword(paginaEmpresa2, datos.password).catch(() => {});
    }

    expect(await credencialesValidas(page, datos.email, datos.password)).toBe(true);
  });
});
