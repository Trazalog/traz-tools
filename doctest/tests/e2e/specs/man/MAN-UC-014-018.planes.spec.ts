/**
 * Casos de uso: MAN-UC-014 (preventivo), 015 (backlog), 016 (parametrizar predictivo), 018 (predictivo)
 * Catálogo: catalogo/man/MAN-UC-014.yaml … MAN-UC-018.yaml
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { ShellMan, type PantallaMan } from '../../pages/man/ShellMan.ts';
import type { Page, TestInfo } from '@playwright/test';

async function columnas(pagina: Page, pantalla: PantallaMan, testInfo: TestInfo): Promise<string> {
  const man = new ShellMan(pagina);
  await man.abrir(pantalla, testInfo);
  return man.encabezados();
}

test.describe('@man @MAN-UC-014 Preventivo', () => {
  test('el listado muestra período, frecuencia y horas hombre', async ({ paginaMan }, testInfo) => {
    const texto = await columnas(paginaMan, 'preventivo', testInfo);
    for (const c of ['Tarea', 'Equipo', 'Periodo', 'Frecuencia', 'Fecha Base', 'Horas Hombre']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-015 Backlog', () => {
  test('el listado muestra el estado de cada pendiente', async ({ paginaMan }, testInfo) => {
    const texto = await columnas(paginaMan, 'backlog', testInfo);
    for (const c of ['Equipo', 'Componente', 'Sistema', 'Tarea', 'Estado']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-016 Parametrizar Predictivo', () => {
  test('pide equipo, parámetro y los límites', async ({ paginaMan }, testInfo) => {
    const texto = await columnas(paginaMan, 'parametrizar', testInfo);
    for (const c of ['Equipo', 'Parámetro', 'Máximo', 'Mínimo']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-018 Predictivo', () => {
  test('el listado muestra equipo, tarea y período', async ({ paginaMan }, testInfo) => {
    const texto = await columnas(paginaMan, 'predictivo', testInfo);
    for (const c of ['Equipo', 'Tarea', 'Periodo']) {
      expect(texto).toContain(c);
    }
  });
});
