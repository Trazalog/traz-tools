/**
 * Caso de uso: ALM-UC-005 — Consultar el stock por establecimiento y depósito
 * Catálogo: catalogo/alm/ALM-UC-005.yaml
 * Gherkin:  features/alm/ALM-UC-005.consultar-el-stock-por-establecimiento-y-deposit.feature
 *
 * La pantalla no muestra la grilla hasta que se toca Filtrar —y eso confunde la
 * primera vez—, así que lo que se verifica al entrar son los filtros.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { AlmacenesPage } from '../../pages/alm/AlmacenesPage.ts';

test.describe('@alm @ALM-UC-005 Consultar el stock por establecimiento y depósito', () => {
  test('@smoke ofrece los filtros de la consulta', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('stock');
    await expect(paginaEmpresa1.getByText('Stock', { exact: false }).first()).toBeVisible({ timeout: 60_000 });

    const texto = await alm.texto();
    for (const filtro of ['Establecimiento', 'Depósito', 'Tipo de Artículo']) {
      expect(texto).toContain(filtro);
    }
  });

  test('el tipo de artículo ofrece las categorías del almacén', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('stock');
    await expect(paginaEmpresa1.getByText('Stock', { exact: false }).first()).toBeVisible({ timeout: 60_000 });

    // Son las categorías que separan lo que se compra de lo que se produce.
    const texto = await alm.texto();
    for (const tipo of ['Insumo', 'Materia prima', 'Producto en proceso', 'Producto final']) {
      expect(texto).toContain(tipo);
    }
  });
});
