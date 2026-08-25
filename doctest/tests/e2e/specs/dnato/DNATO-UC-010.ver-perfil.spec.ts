/**
 * Caso de uso: DNATO-UC-010 — Ver el perfil propio
 * Catálogo: catalogo/dnato/DNATO-UC-010.yaml (v0.3, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-010.ver-el-perfil-propio.feature
 */

import { expect, test } from '../../fixtures/auth.ts';
import { LoginPage } from '../../pages/dnato/LoginPage.ts';
import { PerfilPage } from '../../pages/dnato/PerfilPage.ts';
import { credenciales } from '../../fixtures/auth.ts';
import { urlDnato } from '../../config/apps.ts';

test.describe('@dnato @DNATO-UC-010 Ver el perfil propio', () => {
  test('muestra los datos de la cuenta y no el nombre de usuario interno', async ({ paginaEmpresa1 }) => {
    // FALLA CONOCIDA — hallazgo H-031, issue #463: la pantalla devuelve una página en
    // blanco porque `profile.php` llama a `image()` y el helper define `imageAdmin()`.
    // `test.fail()` deja el test activo: hoy tiene que fallar, y el día que se corrija
    // el bug la corrida se pone en rojo avisando que hay que sacar esta marca.
    test.fail();
    const perfil = new PerfilPage(paginaEmpresa1);
    await perfil.abrir();

    expect(await perfil.enPantalla()).toBe(true);
    const contenido = await perfil.contenido();
    expect(contenido).toContain(credenciales('empresa1').email);
    // Regla validada por el PM: el `usernick` no se muestra al usuario.
    expect(contenido.toLowerCase()).not.toContain('usernick');
  });

  test('sin sesión, la pantalla de perfil manda al ingreso', async ({ page }) => {
    await page.goto(urlDnato('main/profile'), { waitUntil: 'domcontentloaded' });
    await expect(new LoginPage(page).empresa).toBeVisible();
  });
});
