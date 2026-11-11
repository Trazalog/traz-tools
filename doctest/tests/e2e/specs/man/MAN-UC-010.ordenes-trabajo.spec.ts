/**
 * Caso de uso: MAN-UC-010 — Ver y filtrar las órdenes de trabajo
 * Catálogo: catalogo/man/MAN-UC-010.yaml
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

test.describe('@man @MAN-UC-010 Órdenes de trabajo', () => {
  test('@smoke el listado muestra el origen de cada orden', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('ordenes', testInfo);
    const texto = await man.encabezados();
    for (const columna of ['Nº Orden', 'Equipo', 'Origen']) {
      expect(texto).toContain(columna);
    }
  });

  test('ofrece filtrar por período programado', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('ordenes', testInfo);
    await man.encabezados();
    const cuerpo = await man.textoContenido();
    expect(cuerpo).toMatch(/Programada Desde/i);
    expect(cuerpo).toMatch(/Programada Hasta/i);
  });
});
