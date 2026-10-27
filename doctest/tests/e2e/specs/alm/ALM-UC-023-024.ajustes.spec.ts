/**
 * Casos de uso: ALM-UC-023 — Ver el listado de ajustes de stock
 *               ALM-UC-024 — Ver el detalle de un ajuste de stock
 * Catálogo: catalogo/alm/ALM-UC-023.yaml · catalogo/alm/ALM-UC-024.yaml
 *
 * El ajuste es la operación más delicada del módulo: cambia cantidades sin que haya
 * entrado ni salido nada, y es el único camino para corregir una recepción, una
 * entrega o un movimiento interno mal registrados.
 *
 * Ojo al escribir aserciones acá: la pantalla tiene DOS tablas —la grilla y el modal
 * de detalle, que está en el DOM aunque no se vea—, así que mirar todos los `th` de la
 * página mezcla las dos. Por eso el detalle se verifica por sus rótulos.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { AlmacenesPage } from '../../pages/alm/AlmacenesPage.ts';

test.describe('@alm @ALM-UC-023 @ALM-UC-024 Ajustes de stock', () => {
  test('@smoke la grilla lista un ajuste por fila, con su comprobante', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('ajustes');
    await alm.encabezados();

    // La grilla es la primera tabla; la segunda es el modal de detalle.
    const grilla = paginaEmpresa1.locator('table').first();
    const columnas = (await grilla.locator('thead th').allInnerTexts()).map((t) => t.trim()).join(' | ');
    for (const columna of ['Comprobante', 'Fecha / Hora', 'Establecimiento', 'Depósito']) {
      expect(columnas).toContain(columna);
    }
  });

  test('ofrece el alta de un ajuste', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('ajustes');
    await alm.encabezados();

    expect(await alm.texto()).toMatch(/Nuevo Ajuste/i);
  });

  test('el detalle contempla la justificación, que es lo que explica el ajuste', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('ajustes');
    await alm.encabezados();

    // El modal existe en la pantalla aunque no esté abierto: se verifica que
    // contemple los tres datos de cabecera, sin depender de que haya ajustes cargados.
    for (const campo of ['#idAjuste', '#tipoAjuste', '#justificacion']) {
      await expect(paginaEmpresa1.locator(campo)).toHaveCount(1);
    }
  });
});
