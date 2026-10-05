/**
 * Casos de uso: DNATO-UC-018 (roles de trabajo) y DNATO-UC-019 (perfil de Dnato)
 * Catálogo: catalogo/dnato/DNATO-UC-018.yaml y DNATO-UC-019.yaml
 *
 * Los dos viven en la misma pantalla, "Cambio de Rol", y se guardan juntos. Acá se
 * verifica la pantalla y la carga de roles por empresa **sin guardar nada**: cambiar
 * roles de verdad toca las membresías en el sistema de procesos y deja al usuario de
 * prueba en otro estado.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { UsuariosListPage } from '../../pages/dnato/UsuariosListPage.ts';
import { credenciales } from '../../fixtures/auth.ts';

test.describe('@dnato @DNATO-UC-018 @DNATO-UC-019 Cambio de Rol', () => {
  test('muestra el perfil del usuario y sus roles por empresa', async ({ paginaEmpresa1 }) => {
    const usuarios = new UsuariosListPage(paginaEmpresa1);
    await usuarios.abrir();
    await paginaEmpresa1.locator('a[href*="changeleveluser"]').first().click();
    await paginaEmpresa1.waitForLoadState('domcontentloaded');

    const texto = (await paginaEmpresa1.locator('body').innerText()).replace(/\s+/g, ' ');
    expect(texto).toMatch(/cambio de rol/i);
    expect(texto).toMatch(/perfil/i);
    expect(texto).toMatch(/roles en el sistema/i);

    // El perfil de Dnato es un vocabulario chico y cerrado (DNATO-UC-019).
    const perfiles = (await paginaEmpresa1.locator('#level option').allInnerTexts()).map((p) => p.trim());
    expect(perfiles.length).toBeGreaterThan(1);
  });

  test('ofrece los roles de trabajo de la empresa elegida', async ({ paginaEmpresa1 }) => {
    const usuarios = new UsuariosListPage(paginaEmpresa1);
    await usuarios.abrir();
    await paginaEmpresa1.locator('a[href*="changeleveluser"]').first().click();
    await paginaEmpresa1.waitForLoadState('domcontentloaded');

    await paginaEmpresa1.getByText('Agregar Rol', { exact: false }).first().click();
    await paginaEmpresa1.waitForTimeout(1000);
    await paginaEmpresa1.locator('#groups').selectOption({ label: credenciales('empresa1').empresa });

    // Los roles se cargan al elegir la empresa: se espera a que aparezcan.
    await expect
      .poll(async () => (await paginaEmpresa1.locator('#roles option').allInnerTexts()).length, { timeout: 30_000 })
      .toBeGreaterThan(1);

    const roles = (await paginaEmpresa1.locator('#roles option').allInnerTexts()).join(' | ');
    // El alta de empresa crea los 16 roles del catálogo: tienen que estar los de siempre.
    expect(roles).toMatch(/Responsable de Almacén|Solicitante de Almacén|Supervisor de Mantenimiento/);
  });
});
