/**
 * Caso de uso: MAN-UC-001 — Ver el listado de equipos
 * Catálogo: catalogo/man/MAN-UC-001.yaml
 *
 * Es también el que verifica que la fixture de sesión propia de MAN funciona: si el ingreso a
 * AssetPlanner se rompe, este test lo dice antes que ningún otro.
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';
import { encabezadosDeGrilla } from '../../pages/man/grilla.ts';

const MAN = () => requerirUrlDeApp('man');

test.describe('@man @MAN-UC-001 Ver el listado de equipos', () => {
  test('@smoke la grilla muestra sus columnas', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Equipo`, { waitUntil: 'domcontentloaded' });
    // La grilla se llena por DataTables: se espera al encabezado, no a un tiempo fijo.
    const texto = await encabezadosDeGrilla(paginaMan);
    for (const columna of ['Codigo Equipo', 'Descripción', 'Área', 'Criticidad', 'Estado']) {
      expect(texto).toContain(columna);
    }
  });

  test('ofrece el alta de un equipo', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Equipo`, { waitUntil: 'domcontentloaded' });
    await encabezadosDeGrilla(paginaMan);
    await expect(paginaMan.getByRole('button', { name: /Agregar/i }).first()).toBeVisible();
  });
});
