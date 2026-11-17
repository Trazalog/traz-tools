/**
 * Casos de uso: MAN-UC-005 (alta de componente) y MAN-UC-006 (asignar componentes a un equipo)
 * Catálogo: catalogo/man/MAN-UC-005.yaml, MAN-UC-006.yaml
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

test.describe('@man @MAN-UC-005 @MAN-UC-006 Componentes', () => {
  test('la lista de asociaciones y su alta piden equipo, componente y código', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('componentes', testInfo);
    const texto = await man.encabezados();
    for (const c of ['Código Trazable', 'Descripción Componente', 'Código Equipo', 'Sistema']) {
      expect(texto).toContain(c);
    }
    await man.contenido.locator('#btnAgre').click();
    await man.esperarCarga();
    await expect(man.contenido.locator('#equipo')).toBeVisible({ timeout: 30_000 });
    await expect(man.contenido.locator('#componente')).toBeVisible();
    await expect(man.contenido.locator('#codigo')).toBeVisible();
    // La descripción del equipo se completa sola al elegirlo: no se carga a mano.
    await expect(man.contenido.locator('#descrip')).toBeVisible();
  });

  test('el catálogo de componentes lista marca, descripción, información y adjunto', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrirRuta('traz-tools-man/Componente/index/Add-Edit-Del', testInfo);
    const texto = await man.encabezados();
    for (const columna of ['Marca', 'Descripción', 'Información', 'Adjunto']) {
      expect(texto).toContain(columna);
    }
  });
});
