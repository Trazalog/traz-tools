/**
 * Caso de uso: ALM-UC-018 — Consultar los movimientos históricos de un artículo
 * Catálogo: catalogo/alm/ALM-UC-018.yaml
 * Gherkin:  features/alm/ALM-UC-018.consultar-los-movimientos-historicos-de-un-artic.feature
 *
 * Es la pantalla a la que se va cuando un número no cierra: incluye todos los tipos de
 * movimiento, así que sumándolos se reconstruye el stock. El reporte lo arma koolreport
 * y tarda más que el resto, de ahí el timeout largo.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { AlmacenesPage } from '../../pages/alm/AlmacenesPage.ts';

test.describe('@alm @ALM-UC-018 Consultar los movimientos históricos de un artículo', () => {
  test('@smoke pide el período y ofrece filtrar por tipo de movimiento', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('historico');
    await expect(paginaEmpresa1.getByText('Movimientos de Stock', { exact: false }).first()).toBeVisible({
      timeout: 60_000,
    });

    const texto = await alm.texto();
    // El período es lo único obligatorio del informe.
    expect(texto).toContain('Desde');
    expect(texto).toContain('Hasta');
    expect(texto).toContain('Tipo Movimiento');
  });

  test('contempla todos los tipos de movimiento que alteran el stock', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('historico');
    await expect(paginaEmpresa1.getByText('Movimientos de Stock', { exact: false }).first()).toBeVisible({
      timeout: 60_000,
    });

    // Que estén los cuatro es lo que hace que el informe sirva para reconstruir el stock:
    // si faltara uno, la suma no cerraría y el informe mentiría sin avisar.
    const texto = await alm.texto();
    for (const tipo of ['Recepción Materiales', 'Entrega Materiales', 'Mov. Interno Ingreso', 'Mov. Interno Egreso']) {
      expect(texto).toContain(tipo);
    }
  });
});
