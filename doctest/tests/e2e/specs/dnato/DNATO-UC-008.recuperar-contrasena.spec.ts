/**
 * Caso de uso: DNATO-UC-008 — Recuperar la contraseña olvidada
 * Catálogo: catalogo/dnato/DNATO-UC-008.yaml (v0.3, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-008.recuperar-la-contrasena-olvidada.feature
 *
 * El camino completo se prueba con un usuario propio y descartable: registra una
 * cuenta con casilla temporal, la activa, pide la recuperación, lee el mail y entra
 * con la contraseña nueva. Así no se toca la contraseña de las empresas de test.
 */

import { expect, test } from '@playwright/test';

import { RegistroPage } from '../../pages/dnato/RegistroPage.ts';
import { crearCasilla } from '../../fixtures/casilla-descartable.ts';
import { urlDnato } from '../../config/apps.ts';

const ENLACE_ACTIVACION = /https?:\/\/[^\s"'<>]*main\/complete\/token\/[A-Za-z0-9_-]+/;
const ENLACE_RESET = /https?:\/\/[^\s"'<>]*main\/reset_password\/token\/[A-Za-z0-9_-]+/;

/**
 * Prueba unas credenciales por el ingreso OAuth, que no pide empresa, y devuelve el
 * mensaje que muestra la pantalla. Sirve para verificar una contraseña sin depender
 * de que el usuario tenga empresa asignada.
 */
async function intentarOauth(page: import('@playwright/test').Page, email: string, password: string): Promise<string> {
  const params = new URLSearchParams({
    client_id: 'trazalog-mcp-connector',
    redirect_uri: 'https://claude.ai/api/mcp/auth_callback',
    response_type: 'code',
    code_challenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    code_challenge_method: 'S256',
    state: 'doctest',
  });
  await page.goto(`${urlDnato('oauth/login')}?${params}`, { waitUntil: 'domcontentloaded' });
  await page.locator('input[name="email"]').fill(email);
  await page.locator('input[name="password"]').fill(password);
  await page.locator('button[type="submit"], input[type="submit"]').first().click({ noWaitAfter: true });
  await page.waitForTimeout(3000);
  return (await page.locator('body').innerText()).replace(/\s+/g, ' ');
}

test.describe('@dnato @DNATO-UC-008 Recuperar la contraseña olvidada', () => {
  test('avisa cuando el correo no está registrado', async ({ page }) => {
    await page.goto(urlDnato('main/forgot'), { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="email"]').fill(`no-existe-${Date.now()}@ejemplo.test`);
    await page.locator('input[type="submit"], button[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForTimeout(2000);

    expect((await page.locator('body').innerText()).replace(/\s+/g, ' ')).toMatch(
      /no encontramos esa dirección de correo/i,
    );
  });

  test('no manda el enlace si la cuenta todavía no está activada', async ({ page }) => {
    test.slow();
    const casilla = await crearCasilla('doctest-uc008a');
    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.completar({
      nombre: 'DocTest',
      apellido: 'SinActivar',
      email: casilla.direccion,
      razonSocial: `DocTest SinActivar ${Date.now()}`,
      telefono: '+54 92645123456',
      pais: 'Argentina',
    });
    await registro.enviar();
    expect(await registro.mensaje()).toMatch(/registro exitoso/i);

    await page.goto(urlDnato('main/forgot'), { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="email"]').fill(casilla.direccion);
    await page.locator('input[type="submit"], button[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForTimeout(2500);

    expect((await page.locator('body').innerText()).replace(/\s+/g, ' ')).toMatch(/aún no está aprobada/i);
  });

  test('manda el enlace, permite cambiar la contraseña y entrar con la nueva', async ({ page }) => {
    // FALLA CONOCIDA — hallazgo H-034, issue #467: el cambio no se guarda, porque
    // `updatePassword()` escribe en `users` sin el esquema `seg.`. El correo llega y la
    // pantalla acepta la contraseña nueva, pero el usuario sigue entrando con la vieja.
    test.fail();
    test.slow();
    const casilla = await crearCasilla('doctest-uc008b');
    const passInicial = 'Doctest2026!';
    const passNueva = 'Doctest2026#Nueva';

    // 1. Cuenta propia: registro + activación (así queda aprobada, como un usuario real).
    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.completar({
      nombre: 'DocTest',
      apellido: 'Recupera',
      email: casilla.direccion,
      razonSocial: `DocTest Recupera ${Date.now()}`,
      telefono: '+54 92645123456',
      pais: 'Argentina',
    });
    await registro.enviar();
    const activacion = await casilla.esperarEnlace(/activar cuenta/i, ENLACE_ACTIVACION, 150_000);
    await page.goto(activacion, { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="password"]').fill(passInicial);
    await page.locator('input[name="passconf"]').fill(passInicial);
    await page.locator('input[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForTimeout(4000);

    // 2. Pide recuperar la contraseña.
    await page.goto(urlDnato('main/forgot'), { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="email"]').fill(casilla.direccion);
    await page.locator('input[type="submit"], button[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForTimeout(3000);

    // 3. Sigue el enlace del correo y define la contraseña nueva.
    const reset = await casilla.esperarEnlace(/restablecer contraseña/i, ENLACE_RESET, 150_000);
    await page.goto(reset, { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="password"]').fill(passNueva);
    await page.locator('input[name="passconf"]').fill(passNueva);
    await page.locator('input[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForTimeout(3000);

    // 4. Lo que importa: la contraseña nueva tiene que servir y la vieja dejar de
    // servir. Se comprueba por el ingreso OAuth, que valida credenciales sin pedir
    // empresa (esta cuenta todavía no tiene ninguna). "No tiene empresa asignada"
    // significa que las credenciales pasaron.
    expect(await intentarOauth(page, casilla.direccion, passNueva)).toMatch(/no tiene empresa asignada/i);
    expect(await intentarOauth(page, casilla.direccion, passInicial)).toMatch(/incorrectos/i);
  });

  test('el aviso de contraseña actualizada llega a la pantalla de ingreso', async ({ page }) => {
    // FALLA CONOCIDA — hallazgo H-033, issue #466: al terminar, el usuario queda en una
    // página en blanco. La contraseña sí cambia; lo que falta es el cierre del flujo.
    test.fail();
    test.slow();

    const casilla = await crearCasilla('doctest-uc008c');
    const pass = 'Doctest2026!';
    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.completar({
      nombre: 'DocTest',
      apellido: 'Aviso',
      email: casilla.direccion,
      razonSocial: `DocTest Aviso ${Date.now()}`,
      telefono: '+54 92645123456',
      pais: 'Argentina',
    });
    await registro.enviar();
    const activacion = await casilla.esperarEnlace(/activar cuenta/i, ENLACE_ACTIVACION, 150_000);
    await page.goto(activacion, { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="password"]').fill(pass);
    await page.locator('input[name="passconf"]').fill(pass);
    await page.locator('input[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForTimeout(4000);

    await page.goto(urlDnato('main/forgot'), { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="email"]').fill(casilla.direccion);
    await page.locator('input[type="submit"], button[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForTimeout(3000);

    const reset = await casilla.esperarEnlace(/restablecer contraseña/i, ENLACE_RESET, 150_000);
    await page.goto(reset, { waitUntil: 'domcontentloaded' });
    const nueva = 'Doctest2026#Otra';
    await page.locator('input[name="password"]').fill(nueva);
    await page.locator('input[name="passconf"]').fill(nueva);
    await page.locator('input[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForTimeout(3000);

    expect((await page.locator('body').innerText()).replace(/\s+/g, ' ')).toMatch(/actualiz/i);
  });
});
