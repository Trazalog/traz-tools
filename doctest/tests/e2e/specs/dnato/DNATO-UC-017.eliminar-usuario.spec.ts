/**
 * Caso de uso: DNATO-UC-017 — Eliminar un usuario de la empresa
 * Catálogo: catalogo/dnato/DNATO-UC-017.yaml (v0.3, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-017.eliminar-un-usuario-de-la-empresa.feature
 *
 * ⚠️ Este caso NO ejecuta la eliminación. Hoy el sistema borra físicamente (hallazgo
 * H-002, issue #451) y el PM definió que la baja tiene que ser lógica: automatizar el
 * borrado sería destruir datos de prueba en cada corrida para probar algo que además
 * está mal. Se verifica lo que sí corresponde: que la acción pide confirmación y que
 * cancelar no hace nada.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { UsuariosListPage } from '../../pages/dnato/UsuariosListPage.ts';

test.describe('@dnato @DNATO-UC-017 Eliminar un usuario de la empresa', () => {
  test('la acción está disponible y no elimina nada hasta confirmar', async ({ paginaEmpresa1 }) => {
    const usuarios = new UsuariosListPage(paginaEmpresa1);
    await usuarios.abrir();
    const antes = await usuarios.correos();
    expect(antes.length).toBeGreaterThan(0);

    const eliminar = paginaEmpresa1.locator('a[href*="deleteuser"], [title="Eliminar Usuario"]').first();
    await expect(eliminar).toBeVisible();

    // El enlace lleva el id del usuario y su empresa: es la acción de baja.
    expect((await eliminar.getAttribute('href')) ?? '').toMatch(/deleteuser/);

    // Se abre el pedido de confirmación y se sale sin confirmar.
    await eliminar.click();
    await paginaEmpresa1.waitForTimeout(1000);
    await paginaEmpresa1.keyboard.press('Escape');
    await paginaEmpresa1.waitForTimeout(500);

    await usuarios.abrir();
    expect(await usuarios.correos()).toEqual(antes);
  });
});
