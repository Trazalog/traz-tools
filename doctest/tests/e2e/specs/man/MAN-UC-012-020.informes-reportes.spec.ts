/**
 * Casos de uso: MAN-UC-012, MAN-UC-017, MAN-UC-019 y MAN-UC-020
 * El informe de servicio, las lecturas, la bandeja de tareas y los reportes.
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';
import { encabezadosDeGrilla, encabezadosOcultos } from '../../pages/man/grilla.ts';

const MAN = () => requerirUrlDeApp('man');

test.describe('@man @MAN-UC-012 Informe de servicio', () => {
  test('@smoke el listado muestra las horas y los recursos de cada informe', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Ordenservicio`, { waitUntil: 'domcontentloaded' });
    const texto = await encabezadosDeGrilla(paginaMan);
    for (const c of ['Nº Informe', 'Nº OT', 'Equipo', 'Recursos Humanos']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-017 Registro de parámetros', () => {
  test('pide equipo, parámetro, fecha y valor', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Lectura`, { waitUntil: 'domcontentloaded' });
    const texto = await encabezadosDeGrilla(paginaMan);
    for (const c of ['Equipo', 'Parámetro', 'Fecha', 'Valor']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-019 Bandeja de tareas', () => {
  test('@smoke muestra qué tarea le toca a cada uno', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Tarea`, { waitUntil: 'domcontentloaded' });
    const texto = await encabezadosDeGrilla(paginaMan);
    for (const c of ['Tip. Tarea', 'Estado', 'Asignado', 'Equipo']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-020 Reportes', () => {
  test('el reporte de órdenes se filtra por equipo, estado y período', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Reporteorden`, { waitUntil: 'domcontentloaded' });
    await encabezadosDeGrilla(paginaMan);
    const cuerpo = await paginaMan.locator('body').innerText();
    for (const filtro of ['Equipo', 'Estado', 'Desde', 'Hasta']) {
      expect(cuerpo).toContain(filtro);
    }
  });

  test('el reporte de informes ofrece sus filtros y la columna de horas hombre', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Reporte`, { waitUntil: 'domcontentloaded' });
    await expect(paginaMan.getByRole('button', { name: /Consultar/i }).first()).toBeVisible({ timeout: 30_000 });

    const cuerpo = await paginaMan.locator('body').innerText();
    for (const filtro of ['Sector', 'Equipo', 'Desde', 'Hasta']) {
      expect(cuerpo).toContain(filtro);
    }

    // La tabla del reporte existe pero permanece oculta hasta consultar: es cómo funcionan las
    // tres pantallas de Reportes, así que se verifica su estructura sin exigir que se vea.
    expect(await encabezadosOcultos(paginaMan)).toMatch(/H\.H\s*Ejecutadas/i);
  });
});
