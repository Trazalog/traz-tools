/**
 * Casos de uso: MAN-UC-003 (editar), 004 (eliminar), 022 (habilitar o inhabilitar),
 *               026 (meta) y 028 (ciclo de vida de un equipo)
 * Catálogo: catalogo/man/MAN-UC-003.yaml, 004, 022, 026, 028
 *
 * Cada prueba crea su propio equipo: sirven también en una empresa recién creada y vacía.
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { crearEquipo, equipoEnListado, type EquipoCreado } from '../../pages/man/datos.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';
import type { Page } from '@playwright/test';

const EQUIPO = 'traz-tools-man/Equipo';

async function shell(pagina: Page): Promise<ShellMan> {
  const man = new ShellMan(pagina);
  await man.enElShell();
  return man;
}

async function datosParaEditar(man: ShellMan, equipo: EquipoCreado): Promise<Record<string, string>> {
  const r = (await man.pedir(`${EQUIPO}/getEditar`, { idEquipo: equipo.id })) as unknown;
  expect(r && typeof r === 'object', 'el equipo se puede abrir para editar').toBe(true);
  const d = (Array.isArray(r) ? r[0] : (r as Record<string, unknown>).datos ?? r) as Record<string, unknown>;
  return (Array.isArray(d) ? d[0] : d) as Record<string, string>;
}

/** Primer "Habilitar": el equipo nace en estado de alta (AL). */
async function habilitar(man: ShellMan, equipo: EquipoCreado): Promise<void> {
  await man.pedir(`${EQUIPO}/estado_alta`, { idequipo: equipo.id });
  expect((await equipoEnListado(man, equipo.codigo))?.estadoEquipo).toBe('AC');
}

/** Busca el equipo en la grilla, como lo haría el usuario, y devuelve su fila. */
async function filaEnGrilla(man: ShellMan, codigo: string) {
  await man.abrir('equipos');
  await man.encabezados();
  await man.page.evaluate((c) => {
    const $ = (window as unknown as { $: (s: string) => { DataTable: () => { search: (x: string) => { draw: () => void } } } }).$;
    $('#content table.dataTable').DataTable().search(c).draw();
  }, codigo);
  await man.esperarCarga();
  const fila = man.contenido.locator('table.dataTable tbody tr').filter({ hasText: codigo }).first();
  await expect(fila).toBeVisible({ timeout: 30_000 });
  return fila;
}

test.describe('@man @MAN-UC-003 Editar un equipo', () => {
  test('la edición cambia la descripción y el listado la muestra', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const equipo = await crearEquipo(man);
    const d = await datosParaEditar(man, equipo);
    expect(d.codigo).toBe(equipo.codigo);
    const nueva = `Editado ${equipo.codigo}`;
    const r = await man.pedir(`${EQUIPO}/editar_equipo`, {
      idEquipo: equipo.id,
      data: {
        // Los mismos campos que arma la pantalla a partir de `getEditar`.
        descripcion: nueva,
        fecha_ingreso: String(d.fecha_ingreso ?? '').slice(0, 10),
        fecha_garantia: String(d.fecha_garantia ?? '').slice(0, 10),
        marca: d.marcaid,
        codigo: d.codigo,
        ubicacion: d.ubicacion ?? '',
        id_sector: d.id_sector,
        id_grupo: d.id_grupo,
        id_area: d.id_area,
        id_proceso: d.id_proceso,
        id_criticidad: d.id_criti,
        id_customer: d.cliId,
        numero_serie: d.numero_serie ?? '',
        estado: d.estado,
        fecha_ultimalectura: d.fecha_ultimalectura ?? '',
        ultima_lectura: d.ultima_lectura ?? '0',
        descrip_tecnica: d.descrip_tecnica ?? '',
      },
    });
    expect(r, 'la edición se guardó').toBeTruthy();
    expect((await equipoEnListado(man, equipo.codigo))?.deeq).toBe(nueva);
  });

  test('un equipo que no es de la empresa no se abre (E4)', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    expect(await man.pedir(`${EQUIPO}/getEditar`, { idEquipo: 999999999 })).toBe('nada');
  });
});

test.describe('@man @MAN-UC-004 Eliminar un equipo', () => {
  test('la baja lo saca del listado sin borrar el registro', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const equipo = await crearEquipo(man);
    const fila = await filaEnGrilla(man, equipo.codigo);
    await expect(fila.locator('i[title="Eliminar"]'), 'la fila ofrece Eliminar').toHaveCount(1);
    await man.pedir(`${EQUIPO}/baja_equipo`, { idEquipo: equipo.id });
    expect(await equipoEnListado(man, equipo.codigo), 'ya no figura en el listado').toBeUndefined();
    // El registro queda en AN (no se borra): la aplicación ya no lo ofrece ni para editar.
    expect(await man.pedir(`${EQUIPO}/getEditar`, { idEquipo: equipo.id })).toBe('nada');
  });
});

test.describe('@man @MAN-UC-022 Habilitar o inhabilitar', () => {
  test('la acción ofrecida depende del estado y el estado cambia', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const equipo = await crearEquipo(man);
    await habilitar(man, equipo);
    let fila = await filaEnGrilla(man, equipo.codigo);
    await expect(fila.locator('i[title="Inhabilitar"]'), 'a un equipo activo se le ofrece Inhabilitar').toHaveCount(1);

    await man.pedir(`${EQUIPO}/cambio_equipo`, { idequipo: equipo.id });
    expect((await equipoEnListado(man, equipo.codigo))?.estadoEquipo).toBe('IN');
    fila = await filaEnGrilla(man, equipo.codigo);
    await expect(fila.locator('i[title="Habilitar"]'), 'a un equipo inactivo se le ofrece Habilitar').toHaveCount(1);

    await man.pedir(`${EQUIPO}/estado_alta`, { idequipo: equipo.id });
    expect((await equipoEnListado(man, equipo.codigo))?.estadoEquipo).toBe('AC');
  });
});

test.describe('@man @MAN-UC-026 Meta de un equipo', () => {
  test('nace sin meta y se le asigna un valor', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const equipo = await crearEquipo(man);
    expect((await equipoEnListado(man, equipo.codigo))?.meta_disp, 'la meta es opcional').toBeFalsy();
    const r = (await man.pedir(`${EQUIPO}/asignarMeta`, { eq: equipo.id, meta: 85 })) as { msj: string };
    expect(r.msj).toBe('OK');
    expect(Number((await equipoEnListado(man, equipo.codigo))?.meta_disp)).toBe(85);
  });
});

test.describe('@man @MAN-UC-028 Ciclo de vida de un equipo', () => {
  test('activo → con historia → inhabilitado → activo, sin perder la historia → dado de baja', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const equipo = await crearEquipo(man);
    // Nace en estado de alta (AL) y se activa con Habilitar, que deja la lectura de alta en la historia.
    expect((await equipoEnListado(man, equipo.codigo))?.estadoEquipo).toBe('AL');
    await habilitar(man, equipo);

    const lectura = await man.pedir(`${EQUIPO}/setLectura`, {
      id_equipo: equipo.id, lectura: 100, operario: 'DocTest', turno: 'Mañana', observacion: 'Lectura de prueba', estado: 'AC',
    });
    expect(lectura, 'el equipo acumula una lectura').toBeTruthy();
    const historia = async () => (await man.pedir(`${EQUIPO}/getHistoriaLect`, { idequipo: equipo.id, id_equipo: equipo.id })) as unknown[];
    const antes = (await historia()).length;
    expect(antes, 'la lectura queda en la historia').toBeGreaterThan(0);

    await man.pedir(`${EQUIPO}/cambio_equipo`, { idequipo: equipo.id });
    expect((await equipoEnListado(man, equipo.codigo))?.estadoEquipo).toBe('IN');
    await man.pedir(`${EQUIPO}/estado_alta`, { idequipo: equipo.id });
    expect((await equipoEnListado(man, equipo.codigo))?.estadoEquipo).toBe('AC');
    expect((await historia()).length, 'la historia se conserva').toBeGreaterThanOrEqual(antes);

    await man.pedir(`${EQUIPO}/baja_equipo`, { idEquipo: equipo.id });
    expect(await equipoEnListado(man, equipo.codigo)).toBeUndefined();
    expect((await historia()).length, 'la historia se conserva después de la baja').toBeGreaterThanOrEqual(antes);
  });
});
