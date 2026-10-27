/**
 * Caso de uso: ALM-UC-020 — Ver el listado de movimientos internos
 * Catálogo: catalogo/alm/ALM-UC-020.yaml
 * Gherkin:  features/alm/ALM-UC-020.ver-el-listado-de-movimientos-internos.feature
 *
 * Pantalla nueva de develop (v2.4.x). Cada usuario ve solo los movimientos de los
 * depósitos que tiene a cargo —origen o destino—, así que la grilla puede venir
 * vacía sin que eso sea una falla: lo que se verifica es la estructura, no el
 * contenido.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { AlmacenesPage } from '../../pages/alm/AlmacenesPage.ts';

test.describe('@alm @ALM-UC-020 Ver el listado de movimientos internos', () => {
  test('@smoke la grilla muestra las dos puntas del movimiento y su estado', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('movimientosInternos');

    const encabezados = await alm.encabezados();
    // Origen y destino son lo que distingue a esta grilla: un movimiento tiene dos puntas.
    for (const columna of [
      'Remito',
      'Fecha y Hora',
      'Establecimiento Origen',
      'Deposito Origen',
      'Establecimiento Destino',
      'Deposito Destino',
      'Estado',
    ]) {
      expect(encabezados).toContain(columna);
    }
  });

  test('es también el acceso a las dos operaciones', async ({ paginaEmpresa1 }) => {
    const alm = new AlmacenesPage(paginaEmpresa1);
    await alm.abrir('movimientosInternos');
    await alm.encabezados();

    const texto = await alm.texto();
    expect(texto).toMatch(/Nueva Salida/i);
    expect(texto).toMatch(/Nueva Recepci[oó]n/i);
  });
});
