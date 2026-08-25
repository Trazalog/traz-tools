/**
 * Casos de uso: DNATO-UC-002 (activación), UC-003 (información adicional),
 * UC-004 (alta de la empresa) y UC-005 (bienvenida).
 * Catálogo: catalogo/dnato/DNATO-UC-00{2,3,4,5}.yaml (validados 2026-08-24)
 *
 * ⚠️ Etiquetado `@alta-empresa` y EXCLUIDO de las corridas normales: cada ejecución
 * crea una empresa real con sus 16 roles, su establecimiento, su depósito y cinco
 * usuarios, y no hay forma automática de darla de baja (queda anotado como deuda en
 * el registro de hallazgos). Se corre a demanda:
 *
 *     npm run test:alta-empresa
 *
 * Es el mismo recorrido que hace `npm run seed:empresa`, pero como test: verifica los
 * cuatro casos de punta a punta, incluida la lectura del correo de activación.
 */

import { expect, test } from '@playwright/test';

import { RegistroPage } from '../../pages/dnato/RegistroPage.ts';
import { crearCasilla } from '../../fixtures/casilla-descartable.ts';

const ENLACE_ACTIVACION = /https?:\/\/[^\s"'<>]*main\/complete\/token\/[A-Za-z0-9_-]+/;

test.describe('@dnato @alta-empresa @DNATO-UC-002 @DNATO-UC-003 @DNATO-UC-004 @DNATO-UC-005 Alta completa de una empresa', () => {
  test('registra, activa, completa los datos y deja la empresa lista para usar', async ({ page }) => {
    test.setTimeout(600_000);
    const casilla = await crearCasilla('doctest-alta');
    const marca = new Date().toISOString().slice(2, 16).replace(/[-:T]/g, '');
    const razonSocial = `DocTest Alta ${marca}`;
    const password = 'Doctest2026!';

    // DNATO-UC-001 — registro
    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.completar({
      nombre: 'DocTest',
      apellido: 'Alta',
      email: casilla.direccion,
      razonSocial,
      telefono: '+54 92645123456',
      pais: 'Argentina',
    });
    await registro.enviar();
    expect(await registro.mensaje()).toMatch(/registro exitoso/i);

    // DNATO-UC-002 — activación: el enlace llega por correo y lo lee el propio test
    const enlace = await casilla.esperarEnlace(/activar cuenta/i, ENLACE_ACTIVACION, 180_000);
    await page.goto(enlace, { waitUntil: 'domcontentloaded' });
    await page.locator('input[name="password"]').fill(password);
    await page.locator('input[name="passconf"]').fill(password);
    await page.locator('input[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForLoadState('networkidle', { timeout: 180_000 }).catch(() => {});

    // DNATO-UC-003 — información adicional: tres preguntas obligatorias
    await expect(page.getByText(/informaci[óo]n adicional/i).first()).toBeVisible({ timeout: 60_000 });
    for (const respuesta of ['Internet', 'Minería', '5 a 20']) {
      await page.getByText(respuesta, { exact: true }).first().click();
    }
    await page.locator('input[type="submit"], button[type="submit"]').first().click({ noWaitAfter: true });
    await page.waitForLoadState('networkidle', { timeout: 180_000 }).catch(() => {});

    // DNATO-UC-004 — alta de la empresa
    for (let intento = 0; intento < 3; intento++) {
      try {
        await page.goto(page.url().replace(/register\/.*$/, 'register/crearEmpresa'), { waitUntil: 'domcontentloaded' });
        break;
      } catch {
        await page.waitForTimeout(2000);
      }
    }
    const dominio = page.locator('input[name="company_domain"]');
    if (await dominio.count()) await dominio.fill(`doctest-${marca}.com`);
    await page.locator('input[name="cuit"]').fill(`30-${marca.slice(-8)}-9`);
    await page.locator('select[name="prov_id"]').selectOption({ label: 'San Juan' });
    await page.locator('select[name="loca_id"] option').nth(1).waitFor({ state: 'attached', timeout: 60_000 });
    await page.locator('select[name="loca_id"]').selectOption({ index: 1 });
    await page.locator('input[type="submit"], button[type="submit"]').first().click({ noWaitAfter: true });

    // DNATO-UC-005 — bienvenida con los usuarios iniciales
    await expect(page.getByText(/registro completado/i).first()).toBeVisible({ timeout: 180_000 });
    const texto = (await page.locator('body').innerText()).replace(/\s+/g, ' ');
    for (const alias of ['usuario@', 'almacen@', 'panol@', 'produccion@', 'mantenimiento@']) {
      expect(texto).toContain(alias);
    }
  });
});
