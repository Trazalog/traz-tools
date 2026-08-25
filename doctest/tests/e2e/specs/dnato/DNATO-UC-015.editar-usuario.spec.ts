/**
 * Caso de uso: DNATO-UC-015 — Editar un usuario de la empresa
 * Catálogo: catalogo/dnato/DNATO-UC-015.yaml (v0.3, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-015.editar-un-usuario-de-la-empresa.feature
 *
 * ⚠️ El caso describe lo que el PM validó que tiene que pasar. Hoy no pasa: la
 * pantalla de edición **no existe** (hallazgo H-035, issue #468), así que los dos
 * tests están marcados como falla conocida. Cuando se implemente, la corrida se pone
 * en rojo avisando que hay que sacar las marcas.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { UsuariosListPage } from '../../pages/dnato/UsuariosListPage.ts';
import { urlDnato } from '../../config/apps.ts';

/** Id de un usuario de la empresa, tomado del enlace "Asignar Rol" de su fila. */
async function idDeUnUsuario(usuarios: UsuariosListPage): Promise<string> {
  const enlace = await usuarios.page.locator('a[href*="changeleveluser"]').first().getAttribute('href');
  return /changeleveluser\/(\d+)/.exec(enlace ?? '')?.[1] ?? '';
}

test.describe('@dnato @DNATO-UC-015 Editar un usuario de la empresa', () => {
  test('abre el formulario de edición con los datos del usuario', async ({ paginaEmpresa1 }) => {
    // FALLA CONOCIDA — H-035 / #468: `main/edituser/{id}` devuelve una página vacía
    // porque el controlador no carga ninguna vista.
    test.fail();

    const usuarios = new UsuariosListPage(paginaEmpresa1);
    await usuarios.abrir();
    const id = await idDeUnUsuario(usuarios);
    expect(id).not.toBe('');

    await paginaEmpresa1.goto(urlDnato(`main/edituser/${id}`), { waitUntil: 'domcontentloaded' });
    await expect(paginaEmpresa1.locator('input[name="firstname"], input[name="firstnameuser"]').first()).toBeVisible();
  });

  test('editar los datos no obliga a cambiar la contraseña', async ({ paginaEmpresa1 }) => {
    // FALLA CONOCIDA — H-007 / #457, hoy supeditado a H-035: las reglas exigen
    // contraseña y confirmación, pero la pantalla ni siquiera se muestra.
    test.fail();

    const usuarios = new UsuariosListPage(paginaEmpresa1);
    await usuarios.abrir();
    const id = await idDeUnUsuario(usuarios);
    await paginaEmpresa1.goto(urlDnato(`main/edituser/${id}`), { waitUntil: 'domcontentloaded' });

    const password = paginaEmpresa1.locator('input[name="password"]');
    await expect(password).toBeVisible();
    await expect(password).not.toHaveAttribute('required', /.*/);
  });
});
