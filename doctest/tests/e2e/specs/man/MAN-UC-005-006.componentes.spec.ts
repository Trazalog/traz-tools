/**
 * Casos de uso: MAN-UC-005 y MAN-UC-006 — Componentes: catálogo y asociación a un equipo
 * Catálogo: catalogo/man/MAN-UC-005.yaml y MAN-UC-006.yaml
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';
import { encabezadosDeGrilla } from '../../pages/man/grilla.ts';

const MAN = () => requerirUrlDeApp('man');

test.describe('@man @MAN-UC-005 @MAN-UC-006 Componentes', () => {
  test('el catálogo de componentes lista marca, descripción, información y adjunto', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Componente`, { waitUntil: 'domcontentloaded' });
    const texto = await encabezadosDeGrilla(paginaMan);
    for (const columna of ['Marca', 'Descripción', 'Información', 'Adjunto']) {
      expect(texto).toContain(columna);
    }
  });

  test('la pantalla de asociar pide equipo, componente y código', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Componente/asigna/Add-Edit-Del-View`, { waitUntil: 'domcontentloaded' });
    await expect(paginaMan.locator('#equipo')).toBeVisible({ timeout: 30_000 });
    await expect(paginaMan.locator('#componente')).toBeVisible();
    await expect(paginaMan.locator('#codigo')).toBeVisible();
    // La descripción del equipo se completa sola al elegirlo: no se carga a mano.
    await expect(paginaMan.locator('#descrip')).toBeVisible();
  });
});
