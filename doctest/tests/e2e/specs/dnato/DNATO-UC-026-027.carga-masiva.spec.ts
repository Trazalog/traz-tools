/**
 * Casos de uso: DNATO-UC-026 (descargar plantilla) y DNATO-UC-027 (cargar planilla)
 * Catálogo: catalogo/dnato/DNATO-UC-026.yaml y DNATO-UC-027.yaml
 *
 * ⚠️ No se ejecuta ninguna carga válida: una carga que termina bien **no se puede
 * deshacer** (regla validada por el PM), así que automatizarla dejaría datos en la
 * empresa de prueba en cada corrida. Se prueban la pantalla, la descarga de la
 * plantilla y los caminos de rechazo, que no escriben nada.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { urlDnato } from '../../config/apps.ts';

test.describe('@dnato @DNATO-UC-026 @DNATO-UC-027 Carga masiva', () => {
  test('ofrece las entidades que se pueden cargar', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('bulkload'), { waitUntil: 'domcontentloaded' });
    await paginaEmpresa1.waitForTimeout(1500);

    const texto = (await paginaEmpresa1.locator('body').innerText()).replace(/\s+/g, ' ');
    expect(texto).toMatch(/carga masiva/i);

    // Las entidades salen de una tabla de configuración, así que la lista va a crecer:
    // se verifica que estén las que el PM dio por vigentes, no la lista completa.
    const entidades = (await paginaEmpresa1.locator('select[name="entidad_negocio"] option').allInnerTexts())
      .map((e) => e.trim())
      .join(' | ');
    expect(entidades).toContain('Articulos');
    expect(entidades).toContain('Herramientas');
    expect(entidades).toContain('Stock Articulos');
  });

  test('la plantilla de una entidad se puede obtener', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('bulkload'), { waitUntil: 'domcontentloaded' });
    await paginaEmpresa1.waitForTimeout(1500);
    // El acceso a la plantilla aparece recién cuando se elige qué se va a cargar.
    await paginaEmpresa1.locator('select[name="entidad_negocio"]').selectOption({ index: 1 });
    await expect(paginaEmpresa1.getByText('Template', { exact: false }).first()).toBeVisible();

    // La descarga la dispara el JS de la pantalla; acá se pide el archivo por la misma
    // dirección que usa ese botón, con la sesión del navegador.
    const respuesta = await paginaEmpresa1.request.get(urlDnato('bulkload/descargarTemplate/0'));
    expect(respuesta.status()).toBe(200);
    const cuerpo = await respuesta.body();
    expect(cuerpo.length).toBeGreaterThan(0);
  });

  test('rechaza un archivo que no es una planilla', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('bulkload'), { waitUntil: 'domcontentloaded' });
    await paginaEmpresa1.waitForTimeout(1500);

    await paginaEmpresa1.locator('select[name="entidad_negocio"]').selectOption({ index: 1 });
    await paginaEmpresa1.locator('input[type="file"]').setInputFiles({
      name: 'doctest-no-es-planilla.txt',
      mimeType: 'text/plain',
      buffer: Buffer.from('esto no es una planilla'),
    });
    await paginaEmpresa1.locator('button[type="submit"], input[type="submit"]').first().click({ noWaitAfter: true });
    await paginaEmpresa1.waitForTimeout(3000);

    expect((await paginaEmpresa1.locator('body').innerText()).replace(/\s+/g, ' ')).toMatch(
      /formato de archivo no v[áa]lido|solo se permiten archivos excel/i,
    );
  });

  test('no deja procesar si no se elige la entidad', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('bulkload'), { waitUntil: 'domcontentloaded' });
    await paginaEmpresa1.waitForTimeout(1500);

    await paginaEmpresa1.locator('input[type="file"]').setInputFiles({
      name: 'doctest.xlsx',
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      buffer: Buffer.from('PK'),
    });

    // La pantalla ni siquiera muestra el botón de cargar mientras no se elija qué cargar.
    await expect(paginaEmpresa1.getByRole('button', { name: /cargar/i })).toBeHidden();

    // Y al elegir la entidad, aparece.
    await paginaEmpresa1.locator('select[name="entidad_negocio"]').selectOption({ index: 1 });
    await expect(paginaEmpresa1.getByRole('button', { name: /cargar/i })).toBeVisible();
  });
});
