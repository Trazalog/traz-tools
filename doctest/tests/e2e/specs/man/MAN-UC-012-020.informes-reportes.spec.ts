/**
 * Casos de uso: MAN-UC-012 (informe de servicio), 017 (lecturas), 019 (bandeja), 020 (reportes)
 * Catálogo: catalogo/man/MAN-UC-012.yaml, 017, 019, 020
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

test.describe('@man @MAN-UC-012 Informe de servicio', () => {
  test('@smoke el listado muestra las horas y los recursos de cada informe', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('informes', testInfo);
    const texto = await man.encabezados();
    for (const c of ['Nº Informe', 'Nº OT', 'Equipo', 'Recursos Humanos']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-017 Registro de parámetros', () => {
  test('pide equipo, parámetro, fecha y valor', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('lecturas', testInfo);
    const texto = await man.encabezados();
    for (const c of ['Equipo', 'Parámetro', 'Fecha', 'Valor']) {
      expect(texto).toContain(c);
    }
  });
});

test.describe('@man @MAN-UC-019 Bandeja de tareas', () => {
  test('@smoke la bandeja de Tools lista las tareas del proceso de Mantenimiento', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('bandeja', testInfo);
    await paginaMan.locator('table#tareas').waitFor({ timeout: 90_000 });
    // Las tareas de MAN llegan a la misma bandeja que el resto de los procesos (MIG-7).
    const filas = paginaMan.locator('table#tareas tbody tr.item');
    expect(await filas.count(), 'el usuario de MAN tiene tareas pendientes en la bandeja').toBeGreaterThan(0);
  });
});

test.describe('@man @MAN-UC-020 Reportes', () => {
  test('el menú ofrece los tres reportes de Mantenimiento', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    for (const r of ['repEquipo', 'repInformes', 'repOrdenes'] as const) {
      expect(await man.tieneMenu(r), `falta el ítem de menú ${r}`).toBe(true);
    }
  });

  test('Rep Ordenes de trabajo se filtra por equipo, estado y fecha y lista las órdenes', async ({ paginaMan }, testInfo) => {
    test.setTimeout(5 * 60_000);
    const man = new ShellMan(paginaMan);
    await man.abrir('repOrdenes', testInfo);
    const cuerpo = await man.textoContenido();
    for (const filtro of ['Equipo', 'Estado', 'Desde', 'Hasta']) {
      expect(cuerpo).toContain(filtro);
    }
    await man.contenido.getByRole('button', { name: /Consultar/i }).first().click();
    await man.esperarCarga(240_000);
    const texto = await man.encabezados();
    for (const c of ['Orden de Trabajo', 'Equipo', 'Origen', 'Estado']) {
      expect(texto).toContain(c);
    }
    // La grilla se llena después de la consulta: se espera a que traiga filas.
    await expect.poll(() => man.filas('#rot-tabla'), { timeout: 60_000 }).toBeGreaterThan(0);
  });

  test('Rep Informe de Servicios ofrece sus filtros y la columna de horas hombre', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('repInformes', testInfo);
    await expect(man.contenido.getByRole('button', { name: /Consultar/i }).first()).toBeVisible({ timeout: 30_000 });
    const cuerpo = await man.textoContenido();
    for (const filtro of ['Sector', 'Equipo', 'Desde', 'Hasta']) {
      expect(cuerpo).toContain(filtro);
    }
    expect(await man.encabezados()).toMatch(/H\.H\s*Ejecutadas/i);
  });

  test('Rep Equipo muestra la disponibilidad de los equipos', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('repEquipo', testInfo);
    expect(await man.textoContenido()).toMatch(/Disponibilidad/i);
    expect(man.erroresJs, 'la pantalla no tiene que tirar errores de JavaScript').toEqual([]);
  });
});
