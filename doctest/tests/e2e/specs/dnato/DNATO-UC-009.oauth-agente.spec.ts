/**
 * Caso de uso: DNATO-UC-009 — Iniciar sesión desde un agente de IA (OAuth 2.1)
 * Catálogo: catalogo/dnato/DNATO-UC-009.yaml
 * Gherkin:  features/dnato/DNATO-UC-009.iniciar-sesion-desde-un-agente-de-ia-oauth-2-1.feature
 *
 * Acá se prueba la PANTALLA de ingreso del agente. El intercambio de tokens y el
 * consumo de tools son de la suite Hurl (F4).
 */

import { expect, test } from '@playwright/test';

import { credenciales } from '../../fixtures/auth.ts';
import { urlDnato } from '../../config/apps.ts';

/**
 * Usuario que pertenece a MAS DE UNA empresa. No esta en las fixtures normales
 * —`empresa1`/`empresa2` son dos usuarios de una empresa cada uno— asi que se
 * lee aparte. Como el resto de las credenciales, lo provee el PM por entorno y
 * nunca se commitea. Sin estas variables, los tests del paso 2 se saltean con
 * un motivo visible en vez de dar un verde que no probo nada.
 */
function credencialesMultiempresa(): { email: string; password: string } | null {
  const email = process.env.DOCTEST_MULTIEMPRESA_USER?.trim();
  const password = process.env.DOCTEST_MULTIEMPRESA_PASS?.trim();
  return email && password ? { email, password } : null;
}

/** Completa el paso 1 y deja la pagina donde haya quedado. */
async function ingresar(page: import('@playwright/test').Page, email: string, password: string): Promise<void> {
  await page.goto(urlOauth(), { waitUntil: 'domcontentloaded' });
  await page.locator('input[name="email"]').fill(email);
  await page.locator('input[name="password"]').fill(password);
  await page.locator('button[type="submit"], input[type="submit"]').first().click();
  await page.waitForLoadState('domcontentloaded');
}

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
  // ---------------------------------------------------------------------------
  // Paso 2 — seleccion de empresa (v0.4)
  //
  // Antes el ingreso OAuth rechazaba a los usuarios con mas de una empresa. Desde
  // traz-comp-dnato#47 muestra las mismas empresas que el ingreso web, porque sale
  // de la misma consulta (getEmpresasDeUsuario).
  // ---------------------------------------------------------------------------

  test('con varias empresas muestra la selección, no un error', async ({ page }) => {
    const cred = credencialesMultiempresa();
    test.skip(!cred, 'Falta DOCTEST_MULTIEMPRESA_USER / _PASS: un usuario que pertenezca a mas de una empresa.');

    await ingresar(page, cred!.email, cred!.password);

    expect(page.url()).toContain('oauth/login/empresa');

    const texto = (await page.locator('body').innerText()).replace(/\s+/g, ' ');
    expect(texto).toMatch(/Con qu[ée] empresa quer[ée]s ingresar/i);
    // Lo que el caso garantiza: no se corta con "configuracion no soportada".
    expect(texto).not.toMatch(/no est[áa] soportad|contacte al administrador/i);

    await expect(page.locator('.tz-sel__item form')).toHaveCount(await page.locator('.tz-sel__item form').count());
    expect(await page.locator('.tz-sel__item form').count()).toBeGreaterThan(1);
  });

  test('elegir una empresa devuelve el control al agente', async ({ page }) => {
    const cred = credencialesMultiempresa();
    test.skip(!cred, 'Falta DOCTEST_MULTIEMPRESA_USER / _PASS: un usuario que pertenezca a mas de una empresa.');

    const vueltaEsperada = 'https://claude.ai/api/mcp/auth_callback';
    let vuelta = '';
    page.on('request', (r) => {
      if (!vuelta && r.url().startsWith(vueltaEsperada)) vuelta = r.url();
    });

    await ingresar(page, cred!.email, cred!.password);
    expect(page.url()).toContain('oauth/login/empresa');

    await page.locator('.tz-sel__item form button[type="submit"]').first().click({ noWaitAfter: true });

    await expect.poll(() => vuelta, { timeout: 90_000 }).toMatch(/auth_callback\?code=[A-Za-z0-9]+/);
    expect(vuelta).toContain('state=doctest');
  });

  test('rechaza una empresa que no es del usuario', async ({ page }) => {
    const cred = credencialesMultiempresa();
    test.skip(!cred, 'Falta DOCTEST_MULTIEMPRESA_USER / _PASS: un usuario que pertenezca a mas de una empresa.');

    await ingresar(page, cred!.email, cred!.password);
    expect(page.url()).toContain('oauth/login/empresa');

    // Se altera el empr_id del formulario antes de enviarlo: el servidor tiene que
    // revalidarlo contra las empresas del usuario, no confiar en lo que llega.
    await page.locator('.tz-sel__item form input[name="empr_id"]').first().evaluate((el) => {
      (el as HTMLInputElement).value = '999999';
    });
    await page.locator('.tz-sel__item form button[type="submit"]').first().click();
    await page.waitForLoadState('domcontentloaded');

    const texto = (await page.locator('body').innerText()).replace(/\s+/g, ' ');
    expect(texto).toMatch(/empresa seleccionada no es v[áa]lida/i);
  });
});
