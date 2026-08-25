/**
 * Caso de uso: DNATO-UC-025 — Asignar opciones de menú a un rol de una empresa
 * Catálogo: catalogo/dnato/DNATO-UC-025.yaml (v0.2, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-025.asignar-opciones-de-menu-a-un-rol-de-una-emp.feature
 *
 * No se guarda ninguna asignación: tocar los menúes cambia lo que ven todos los
 * usuarios de esa empresa. Se verifica la pantalla y la regla de aislamiento.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { credenciales } from '../../fixtures/auth.ts';
import { urlDnato } from '../../config/apps.ts';

test.describe('@dnato @DNATO-UC-025 Asignar opciones de menú a un rol', () => {
  test('muestra la grilla de asignaciones con sus columnas', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('menu/rolesList'), { waitUntil: 'domcontentloaded' });
    await paginaEmpresa1.locator('table').first().waitFor({ timeout: 60_000 });

    const columnas = (await paginaEmpresa1.locator('table thead th').allInnerTexts())
      .map((c) => c.trim().toLowerCase())
      .join(' | ');
    for (const esperada of ['grupo', 'módulo', 'opciones', 'roles', 'estado']) {
      expect(columnas).toContain(esperada);
    }
  });

  test('la empresa recién creada ya tiene menúes asignados a sus roles', async ({ paginaEmpresa1 }) => {
    await paginaEmpresa1.goto(urlDnato('menu/rolesList'), { waitUntil: 'domcontentloaded' });
    await paginaEmpresa1.locator('table').first().waitFor({ timeout: 60_000 });
    await paginaEmpresa1.locator('select[name$="_length"]').first().selectOption('100').catch(() => {});
    await paginaEmpresa1.waitForTimeout(500);

    // El alta de empresa deja las asignaciones iniciales cargadas (trigger de base).
    const texto = await paginaEmpresa1.locator('table').last().innerText();
    expect(texto).toContain(credenciales('empresa1').empresa);
  });

  test('solo ofrece empresas del administrador para asignar menúes', async ({ paginaEmpresa1 }) => {
    // Regla del PM, verificada: la vista arma el combo con las empresas del conectado.
    // (El hallazgo H-020 nació de leer el controlador; este test lo desmintió.)
    await paginaEmpresa1.goto(urlDnato('menu/rolesList'), { waitUntil: 'domcontentloaded' });
    const opciones = (await paginaEmpresa1.locator('select[name="groups"] option').allInnerTexts()).map((o) => o.trim());

    expect(opciones.join(' | ')).toContain(credenciales('empresa1').empresa);
    expect(opciones.join(' | ')).not.toContain(credenciales('empresa2').empresa);
  });
});
