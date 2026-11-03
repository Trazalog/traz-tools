/**
 * Caso de uso: MAN-UC-001 — Ver el listado de equipos
 * Catálogo: catalogo/man/MAN-UC-001.yaml
 *
 * MAN dentro de Tools: se entra por DNATO y la pantalla se abre desde el menú Mantenimiento. Es
 * también el test que verifica que la sesión de MAN funciona: si el ingreso o la vinculación de la
 * empresa se rompen, este lo dice antes que ningún otro.
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

test.describe('@man @MAN-UC-001 Ver el listado de equipos', () => {
  test('@smoke el menú Mantenimiento ofrece Equipos y la grilla muestra sus columnas', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    expect(await man.tieneMenu('equipos'), 'el usuario de MAN tiene que ver Mantenimiento → Equipos').toBe(true);
    await man.abrir('equipos', testInfo);
    const texto = await man.encabezados();
    for (const columna of ['Equipo', 'Descripción', 'Área', 'Criticidad', 'Estado']) {
      expect(texto).toContain(columna);
    }
    expect(await man.textoContenido()).not.toMatch(/no est[aá] vinculada con Mantenimiento/i);
  });

  test('con permisos en la URL ofrece el alta de un equipo', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('equipos', testInfo);
    await man.encabezados();
    await expect(man.contenido.getByRole('button', { name: /Agregar/i }).first()).toBeVisible();
  });

  test('sin permisos en la URL la pantalla queda de solo lectura (E3)', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrirRuta('traz-tools-man/Equipo/index', testInfo);
    await man.encabezados();
    await expect(man.contenido.getByRole('button', { name: /Agregar/i })).toHaveCount(0);
  });
});
