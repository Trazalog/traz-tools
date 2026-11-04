/**
 * Casos de uso: MAN-UC-033 (plan preventivo), 034 (plan predictivo) y 035 (pendiente del backlog):
 * editar o eliminar. Catálogo: catalogo/man/MAN-UC-033.yaml, 034, 035
 *
 * Cada prueba crea su equipo y su plan, para servir también en una empresa recién creada y vacía.
 */

import type { Page } from '@playwright/test';

import { test, expect } from '../../fixtures/auth-man.ts';
import {
  crearBacklog, crearEquipo, crearPredictivo, crearPreventivo, crearTarea, idsDeListado, LISTADOS, sufijo,
} from '../../pages/man/datos.ts';
import { ShellMan, type PantallaMan } from '../../pages/man/ShellMan.ts';

async function shell(pagina: Page): Promise<ShellMan> {
  const man = new ShellMan(pagina);
  await man.enElShell();
  return man;
}

/** La fila del plan en su grilla, buscada por número, para ver qué acciones ofrece. */
async function verAcciones(man: ShellMan, pantalla: PantallaMan, id: number, conEditar = true): Promise<void> {
  await man.abrir(pantalla);
  await man.encabezados();
  await man.page.evaluate((x) => {
    const $ = (window as unknown as { $: (s: string) => { DataTable: () => { search: (t: string) => { draw: () => void } } } }).$;
    $('#content table.dataTable').DataTable().search(x).draw();
  }, String(id));
  const fila = man.contenido.locator(`table.dataTable tbody tr[id="${id}"]`);
  await expect(fila, `la fila ${id} está en la grilla`).toBeVisible({ timeout: 30_000 });
  await expect(fila.locator('.fa-times-circle'), 'ofrece Eliminar').toHaveCount(1);
  if (conEditar) await expect(fila.locator('.fa-pencil'), 'ofrece Editar').toHaveCount(1);
}

const primero = <T>(v: T | T[]): T => (Array.isArray(v) ? v[0] : v);

// Cada prueba crea sus maestros, su equipo y su plan: pasa holgada del tiempo por defecto.
test.setTimeout(6 * 60_000);

test.describe('@man @MAN-UC-033 Editar o eliminar un preventivo', () => {
  test('se edita la frecuencia y al eliminarlo deja de figurar', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const equipo = await crearEquipo(man);
    const id = await crearPreventivo(man, equipo);
    await verAcciones(man, 'preventivo', id, false);

    const info = (await man.pedir('traz-tools-man/Preventivo/geteditar', { idprev: id })) as { datos: unknown };
    const d = primero(info.datos) as Record<string, string>;
    const r = await man.pedir('traz-tools-man/Preventivo/editar_preventivo', {
      id_prevent: id, id_equipo: d.id_equipo, id_tarea: d.id_tarea, perido: d.perido, cantidad: 3, ultimo: String(d.ultimo).slice(0, 10),
      id_componente: d.id_componente, horash: d.horash, prev_duracion: d.prev_duracion, unidad: d.id_unidad, cantOper: d.prev_canth,
    });
    expect(r, 'la edición se guardó').toBeTruthy();
    const despues = (await man.pedir('traz-tools-man/Preventivo/geteditar', { idprev: id })) as { datos: unknown };
    expect(Number((primero(despues.datos) as Record<string, string>).cantidad)).toBe(3);

    await man.pedir('traz-tools-man/Preventivo/baja_preventivo', { idprev: id });
    expect(await idsDeListado(man, LISTADOS.preventivo), 'dejó de figurar').not.toContain(id);
  });
});

test.describe('@man @MAN-UC-033 @MAN-UC-034 Editar un plan recién creado', () => {
  // Falla conocida, igual que en asset: los planes nacen en estado C y el lápiz solo se muestra en S o PL
  // (views/preventivo/list.php:43, views/predictivo/list.php), así que un plan recién creado no se puede editar.
  test('el listado ofrece Editar en un preventivo recién creado', async ({ paginaMan }) => {
    test.fail();
    const man = await shell(paginaMan);
    const id = await crearPreventivo(man, await crearEquipo(man));
    await verAcciones(man, 'preventivo', id);
  });

  test('el listado ofrece Editar en un predictivo recién creado', async ({ paginaMan }) => {
    test.fail();
    const man = await shell(paginaMan);
    const id = await crearPredictivo(man, await crearEquipo(man));
    await verAcciones(man, 'predictivo', id);
  });
});

test.describe('@man @MAN-UC-034 Editar o eliminar un predictivo', () => {
  test('se edita la tarea y al eliminarlo deja de figurar', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const equipo = await crearEquipo(man);
    const id = await crearPredictivo(man, equipo);
    await verAcciones(man, 'predictivo', id, false);

    const info = (await man.pedir('traz-tools-man/Predictivo/getEditar', { idpred: id, datos: equipo.id })) as { datos: unknown };
    const d = primero(info.datos) as Record<string, string>;
    expect(d, 'el predictivo se abre para editar').toBeTruthy();
    const tarea = await crearTarea(man);
    const r = await man.pedir('traz-tools-man/Predictivo/updatePredictivo', {
      id_Predictivo: id, tarea, fecha: String(d.fecha).slice(0, 10), periodo: d.periodo, cantidad: 2, horash: d.hh,
      duracion: d.duracion, unidad: d.unidtiempo, operarios: d.operarios,
    });
    expect(r, 'la edición se guardó').toBeTruthy();
    const despues = (await man.pedir('traz-tools-man/Predictivo/getEditar', { idpred: id, datos: equipo.id })) as { datos: unknown };
    expect((primero(despues.datos) as Record<string, string>).id_tarea).toBe(tarea);

    await man.pedir('traz-tools-man/Predictivo/baja_predictivo', { idpre: id });
    expect(await idsDeListado(man, LISTADOS.predictivo), 'dejó de figurar').not.toContain(id);
  });
});

test.describe('@man @MAN-UC-035 Editar o eliminar un pendiente del backlog', () => {
  test('se edita la tarea opcional y al eliminarlo deja de figurar', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const equipo = await crearEquipo(man);
    const id = await crearBacklog(man, equipo);
    await verAcciones(man, 'backlog', id);

    const url = `traz-tools-man/Backlog/geteditar?idpred=${id}&datos=${equipo.id}`;
    const info = (await man.pedir(url)) as { datos: unknown };
    const d = primero(info.datos) as Record<string, string>;
    expect(d, 'el pendiente se abre para editar').toBeTruthy();
    const texto = `Pendiente editado ${sufijo()}`;
    const r = (await man.pedir('traz-tools-man/Backlog/editar_backlog', {
      backid: id, tarea: d.id_tarea, fecha: String(d.fecha).slice(0, 10), hshombre: 2, duracion: d.back_duracion, id_unidad: d.id_unidad,
      back_canth: d.back_canth, tareaOpcional: texto, tipo: 'edit',
    })) as { status: boolean; msj?: string };
    expect(r.status, r.msj).toBe(true);
    const despues = (await man.pedir(url)) as { datos: unknown };
    expect((primero(despues.datos) as Record<string, string>).tarea_opcional).toBe(texto);

    await man.pedir('traz-tools-man/Backlog/baja_backlog_estado_Borrado', { gloid: id });
    expect(await idsDeListado(man, LISTADOS.backlog), 'dejó de figurar').not.toContain(id);
  });
});
