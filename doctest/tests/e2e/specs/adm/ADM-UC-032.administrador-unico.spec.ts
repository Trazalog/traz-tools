/**
 * Caso de uso: ADM-UC-032 — Ser administrador de la empresa por una sola definición
 * Catálogo: catalogo/adm/ADM-UC-032.yaml
 *
 * Depende del ADMDataService desplegado (el Contexto resuelve es_admin) y de los
 * usuarios de prueba: administrador de la empresa, registrado con otro rol y membresía
 * suspendida.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { BarraToolsPage } from '../../pages/adm/BarraToolsPage.ts';
import { PortalPage } from '../../pages/adm/PortalPage.ts';

const BLOQUEO = 'Requiere el ADMDataService desplegado y los usuarios de prueba del caso (REQ-004 Tarea 9).';

test.describe('@adm @ADM-UC-032 Ser administrador de la empresa por una sola definición', () => {
  test('el administrador de la empresa ve "Mi empresa" y entra al Portal', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO);
    const barra = new BarraToolsPage(paginaEmpresa1);
    await barra.abrirTablero();
    await expect(barra.miEmpresa).toBeVisible();

    await barra.miEmpresa.click();
    const portal = new PortalPage(paginaEmpresa1);
    await expect(portal.raiz).toBeVisible();
  });

  test('el nivel general del usuario (role = 1) no hace administrador', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO + ' Falta un usuario registrado con rol Supervisor en la empresa activa.');
    const barra = new BarraToolsPage(paginaEmpresa1);
    await barra.abrirTablero();
    await expect(barra.miEmpresa).toHaveCount(0);
  });

  test('una membresía suspendida no hace administrador', async ({ paginaEmpresa1 }) => {
    test.skip(true, BLOQUEO + ' Falta una membresía en estado baneado/baja en el ambiente de test.');
    const portal = new PortalPage(paginaEmpresa1);
    await portal.abrir();
    await expect(portal.sinPermiso).toBeVisible();
  });
});
