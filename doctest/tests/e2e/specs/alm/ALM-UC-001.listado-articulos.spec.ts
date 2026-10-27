/**
 * Caso de uso: ALM-UC-001 — Ver el listado de artículos del almacén
 * Catálogo: catalogo/alm/ALM-UC-001.yaml
 * Gherkin:  features/alm/ALM-UC-001.ver-el-listado-de-articulos-del-almacen.feature
 *
 * Es la puerta de entrada del módulo: el resto de Almacenes trabaja siempre sobre
 * artículos que ya existen.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { AlmacenesPage } from '../../pages/alm/AlmacenesPage.ts';

test.describe('@alm @ALM-UC-001 Ver el listado de artículos del almacén', () => {
  test('@smoke la grilla muestra sus columnas', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('articulos');

    const encabezados = await alm.encabezados();
    for (const columna of ['Código', 'Descripción', 'Tipo de Producto', 'Unidad de Medida', 'Estado']) {
      expect(encabezados).toContain(columna);
    }
  });

  test('ofrece el alta de un artículo', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('articulos');
    await alm.encabezados();

    expect(await alm.texto()).toMatch(/Agregar/i);
  });
});
