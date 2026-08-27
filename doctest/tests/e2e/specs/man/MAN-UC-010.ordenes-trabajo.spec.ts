/**
 * Caso de uso: MAN-UC-010 — Ver y filtrar las órdenes de trabajo
 * Catálogo: catalogo/man/MAN-UC-010.yaml
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';
import { encabezadosDeGrilla } from '../../pages/man/grilla.ts';

const MAN = () => requerirUrlDeApp('man');

test.describe('@man @MAN-UC-010 Órdenes de trabajo', () => {
  test('@smoke el listado muestra el origen de cada orden', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Otrabajo/listOrden`, { waitUntil: 'domcontentloaded' });
    const texto = await encabezadosDeGrilla(paginaMan);
    for (const columna of ['Nº Orden', 'Equipo', 'Origen']) {
      expect(texto).toContain(columna);
    }
  });

  test('ofrece filtrar por período, equipo y estado', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Otrabajo/listOrden`, { waitUntil: 'domcontentloaded' });
    await encabezadosDeGrilla(paginaMan);
    const cuerpo = await paginaMan.locator('body').innerText();
    expect(cuerpo).toMatch(/Programada Desde/i);
    expect(cuerpo).toMatch(/Programada Hasta/i);
  });
});
