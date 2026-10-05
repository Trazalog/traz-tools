/**
 * Casos de uso: MAN-UC-014, MAN-UC-015, MAN-UC-016 y MAN-UC-018
 * Los cuatro orígenes de trabajo planificado: preventivo, backlog, parámetros y predictivo.
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';
import { encabezadosDeGrilla } from '../../pages/man/grilla.ts';

const MAN = () => requerirUrlDeApp('man');

async function columnas(paginaMan: import('@playwright/test').Page, ruta: string): Promise<string> {
  await paginaMan.goto(`${MAN()}/${ruta}`, { waitUntil: 'domcontentloaded' });
  return encabezadosDeGrilla(paginaMan);
}

test.describe('@man @MAN-UC-014 Preventivo', () => {
  test('el listado muestra período, frecuencia y horas hombre', async ({ paginaMan }) => {
    const texto = await columnas(paginaMan, 'Preventivo');
    for (const c of ['Tarea', 'Equipo', 'Periodo', 'Frecuencia', 'Fecha Base', 'Horas Hombre']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-015 Backlog', () => {
  test('el listado muestra el estado de cada pendiente', async ({ paginaMan }) => {
    const texto = await columnas(paginaMan, 'Backlog');
    for (const c of ['Equipo', 'Componente', 'Sistema', 'Tarea', 'Estado']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-016 Parametrizar Predictivo', () => {
  test('pide equipo, parámetro y los límites', async ({ paginaMan }) => {
    const texto = await columnas(paginaMan, 'Parametro');
    for (const c of ['Equipo', 'Parametro', 'Maximo', 'Minimo']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-018 Predictivo', () => {
  test('el listado muestra equipo, tarea y período', async ({ paginaMan }) => {
    const texto = await columnas(paginaMan, 'Predictivo');
    for (const c of ['Equipo', 'Tarea', 'Periodo']) {
      expect(texto).toContain(c);
    }
  });
});
