/**
 * Caso de uso: MAN-UC-043 — Administrar los catálogos de mantenimiento (ABM de Mantenimiento)
 * Catálogo: catalogo/man/MAN-UC-043.yaml
 *
 * Los trece ABM del menú "ABM de Mantenimiento" (decisión E56). Cada uno se abre por el menú, lista
 * su grilla sin errores de JavaScript y no dice que la empresa no está vinculada.
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { ShellMan, type PantallaMan } from '../../pages/man/ShellMan.ts';

const ABMS: Array<[PantallaMan, string]> = [
  ['abmArea', 'Área'],
  ['abmProceso', 'Procesos'],
  ['abmGrupo', 'Grupo'],
  ['abmSector', 'Sector'],
  ['abmContratista', 'Contratista'],
  ['abmTareaEstandar', 'Tareas estándar'],
  ['abmParametros', 'Parámetros'],
  ['abmFamilia', 'Familia'],
  ['abmMarca', 'Marca'],
  ['abmClientes', 'Clientes'],
  ['abmCriticidad', 'Criticidad'],
  ['abmSucursales', 'Sucursales'],
  ['abmSistemas', 'Sistemas'],
];

test.describe('@man @MAN-UC-043 Catálogos de mantenimiento', () => {
  for (const [pantalla, nombre] of ABMS) {
    test(`${nombre}: abre por el menú y lista su grilla`, async ({ paginaMan }, testInfo) => {
      const man = new ShellMan(paginaMan);
      expect(await man.tieneMenu(pantalla), `falta ABM de Mantenimiento → ${nombre}`).toBe(true);
      await man.abrir(pantalla, testInfo);
      await man.encabezados();
      expect(await man.textoContenido()).not.toMatch(/no est[aá] vinculada/i);
      await expect(man.contenido.getByRole('button', { name: /Agregar|Nuevo/i }).first()).toBeVisible();
      expect(man.erroresJs).toEqual([]);
    });
  }
});
