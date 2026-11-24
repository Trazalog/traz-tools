/**
 * Caso de uso: ADM-UC-030 — Llegar al Portal y a la Consola desde la barra de Tools
 * Catálogo: catalogo/adm/ADM-UC-030.yaml
 *
 * Depende del ADMDataService desplegado (el Contexto lo consulta) y de los usuarios de
 * prueba del caso: un administrador de la empresa, un no-admin y un superusuario con la
 * marca en el ambiente de test.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { BarraToolsPage } from '../../pages/adm/BarraToolsPage.ts';

const BLOQUEO = 'Requiere el ADMDataService desplegado en el MI y los usuarios de prueba del caso (REQ-004 Tarea 9).';

test.describe('@adm @ADM-UC-030 Llegar al Portal y a la Consola desde la barra de Tools', () => {
  test('el administrador de la empresa ve "Mi empresa" en el tablero', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO);
    const barra = new BarraToolsPage(paginaEmpresa1);
    await barra.abrirTablero();
    await expect(barra.miEmpresa).toBeVisible();
  });

  test('"Mi empresa" lleva al Portal de la empresa', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO);
    const barra = new BarraToolsPage(paginaEmpresa1);
    await barra.abrirTablero();
    await expect(barra.miEmpresa).toHaveAttribute('href', /traz-comp-adm\/portal/);
  });

  test('un usuario sin rol de administrador no ve los botones', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO + ' Falta un usuario no-admin de test.');
    const barra = new BarraToolsPage(paginaEmpresa1);
    await barra.abrirTablero();
    await expect(barra.miEmpresa).toHaveCount(0);
  });

  test('un superusuario ve "Consola"', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO + ' Falta un usuario con la marca de superusuario.');
    const barra = new BarraToolsPage(paginaEmpresa1);
    await barra.abrirTablero();
    await expect(barra.consola).toBeVisible();
  });
});
