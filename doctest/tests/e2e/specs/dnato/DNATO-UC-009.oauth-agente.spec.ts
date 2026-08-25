/**
 * Caso de uso: DNATO-UC-009 — Iniciar sesión desde un agente de IA (OAuth 2.1)
 * Catálogo: catalogo/dnato/DNATO-UC-009.yaml (v0.2, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-009.iniciar-sesion-desde-un-agente-de-ia-oauth-2-1.feature
 *
 * Acá se prueba la PANTALLA de ingreso del agente. El intercambio de tokens y el
 * consumo de tools son de la suite Hurl (F4).
 */

import { expect, test } from '@playwright/test';

import { credenciales } from '../../fixtures/auth.ts';
import { urlDnato } from '../../config/apps.ts';

function urlOauth(): string {
  const params = new URLSearchParams({
    client_id: 'trazalog-mcp-connector',
    redirect_uri: 'https://claude.ai/api/mcp/auth_callback',
    response_type: 'code',
    code_challenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    code_challenge_method: 'S256',
    state: 'doctest',
  });
  return `${urlDnato('oauth/login')}?${params}`;
}

test.describe('@dnato @DNATO-UC-009 Iniciar sesión desde un agente de IA', () => {
  test('muestra quién pide el acceso y pide las credenciales', async ({ page }) => {
    await page.goto(urlOauth(), { waitUntil: 'domcontentloaded' });

    const texto = (await page.locator('body').innerText()).replace(/\s+/g, ' ');
    expect(texto).toMatch(/solicita acceder a Trazalog/i);
    await expect(page.locator('input[name="email"]')).toBeVisible();
    await expect(page.locator('input[name="password"]')).toBeVisible();
  });

  test('rechaza credenciales incorrectas', async ({ page }) => {
    await page.goto(urlOauth(), { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="email"]').fill(credenciales('empresa1').email);
    await page.locator('input[name="password"]').fill('Contrasena-Incorrecta-2026!');
    await page.locator('button[type="submit"], input[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForTimeout(2500);

    expect((await page.locator('body').innerText()).replace(/\s+/g, ' ')).toMatch(/incorrectos/i);
  });

  test('con credenciales válidas devuelve el control al agente', async ({ page }) => {
    // El regreso al cliente se intercepta y se corta acá: lo que hay que verificar es
    // que Trazalog devuelve el control con un código de autorización, no lo que haga
    // claude.ai después (que, sin sesión en este navegador, manda a su propio login).
    // Ojo: la URL de ida ya contiene "auth_callback" dentro de `redirect_uri`, así que
    // se busca el pedido que EMPIEZA con la dirección de vuelta del cliente.
    const vueltaEsperada = 'https://claude.ai/api/mcp/auth_callback';
    let vuelta = '';
    page.on('request', (r) => {
      if (!vuelta && r.url().startsWith(vueltaEsperada)) vuelta = r.url();
    });

    await page.goto(urlOauth(), { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="email"]').fill(credenciales('empresa1').email);
    await page.locator('input[name="password"]').fill(credenciales('empresa1').password);
    await page.locator('button[type="submit"], input[type="submit"]').first().click({ noWaitAfter: true });

    // El paso por Bonita hace que la vuelta tarde: se espera al regreso, no un tiempo fijo.
    await expect.poll(() => vuelta, { timeout: 90_000 }).toMatch(/auth_callback\?code=[A-Za-z0-9]+/);
    expect(vuelta).toContain('state=doctest');
  });

  test('sin los parámetros del agente no muestra el formulario', async ({ page }) => {
    await page.goto(urlDnato('oauth/login'), { waitUntil: 'domcontentloaded' });

    const texto = (await page.locator('body').innerText()).replace(/\s+/g, ' ');
    expect(texto).toMatch(/par[áa]metros OAuth no encontrados|inicie el flujo desde el cliente/i);
  });
});
