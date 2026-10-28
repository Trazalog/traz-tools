/**
 * Casos de uso: TAR-UC-019 — Administrar tareas estándar
 *               TAR-UC-020 — Administrar subtareas
 *               TAR-UC-021 — Administrar plantillas
 * Catálogo: catalogo/tar/TAR-UC-019.yaml · TAR-UC-020.yaml · TAR-UC-021.yaml (en borrador)
 * Casos de prueba del spec: doc/specs/TAR-spec-modulo-tareas.md §7.19 (TAR-CP-019-*, 020-*, 021-*)
 *
 * El catálogo de tareas es la base del resto del módulo: las tareas que se agregan a un hito
 * salen de acá. Los tests van en orden (un solo worker) y comparten los datos de la corrida: se
 * crea, se usa, se edita y se elimina lo mismo. No es `describe.serial` a propósito: con serial,
 * el primer bug que aparece saltea todos los demás, y esta suite existe para encontrarlos todos.
 */

import { expect, test } from '@playwright/test';

import { paginaDeRol } from '../../fixtures/roles-tar.ts';
import { sufijoDeCorrida } from '../../pages/tar/ShellTar.ts';
import { TareasEstandarPage } from '../../pages/tar/TareasEstandarPage.ts';

const SUF = sufijoDeCorrida();
const TAREA = `DT Insp ${SUF}`;
const TAREA_2 = `DT Limp ${SUF}`;
const PLANTILLA = `DT PL ${SUF}`;

test.describe('@tar @TAR-UC-019 @TAR-UC-020 @TAR-UC-021 Catálogo de tareas estándar y plantillas', () => {
  let tst: TareasEstandarPage;

  test.beforeAll(async ({ browser }) => {
    tst = new TareasEstandarPage(await paginaDeRol(browser, 'planificador'));
  });

  test.afterAll(async () => {
    await tst?.page.context().close();
  });

  test('TAR-CP-019-01 alta de una tarea estándar completa: aparece en la lista', async ({}, testInfo) => {
    await tst.abrir('tareasEstandar', testInfo);
    await tst.crearTareaOk({ nombre: TAREA, descripcion: 'Inspección de bomba (DocTest)', duracion: '02:00' });
    await tst.crearTareaOk({ nombre: TAREA_2, descripcion: 'Limpieza (DocTest)', duracion: '01:00' });

    const datos = await tst.datosTarea(TAREA);
    expect(datos?.duracion).toBe('02:00');
  });

  test('TAR-CP-019-07 "Proceso Asociado" ofrece el proceso de tarea planificada TST001 (H-093)', async ({}, testInfo) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-093 #580 (B-03): el selector solo ofrece Reparacion Neumaticos y Fabricación');
    await tst.abrir('tareasEstandar', testInfo);
    expect(await tst.procesosOfrecidos()).toContain('TST001');
  });

  test('TAR-CP-019-02 sin nombre o sin duración: avisa que faltan obligatorios y no guarda', async ({}, testInfo) => {
    for (const [caso, datos] of [
      ['sin nombre', { nombre: '', duracion: '01:00' }],
      ['sin duración', { nombre: `DT SinDur ${SUF}`, duracion: '' }],
    ] as const) {
      await tst.abrir('tareasEstandar', testInfo);
      const antes = await tst.tablaTareas.locator('tbody tr.data-json').count();
      await tst.crearTarea(datos);
      const aviso = await tst.dialogo();
      await tst.cerrarDialogos();
      await tst.abrir('tareasEstandar', testInfo);
      const despues = await tst.tablaTareas.locator('tbody tr.data-json').count();
      expect.soft(aviso.texto, `${caso}: el aviso no es el de obligatorios`).toMatch(/Falta completar campos obligatorios/i);
      expect.soft(despues, `${caso}: se creó una tarea estándar`).toBe(antes);
    }
  });

  test('TAR-CP-019-03 una duración imposible (99:99) no se acepta', async ({}, testInfo) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-098 #585 (B-08): la máscara acepta 99:99');
    // Duda D-21 del spec: el rango válido no está definido. Lo que sí es seguro es que 99:99
    // no es una duración HH:MM: con minutos > 59 el fin de la tarea se calcula mal.
    await tst.abrir('tareasEstandar', testInfo);
    const nombre = `DT Dur ${SUF}`;
    await tst.crearTarea({ nombre, duracion: '99:99' });
    await tst.esperarCarga();
    await tst.cerrarDialogos();
    await tst.abrir('tareasEstandar', testInfo);
    const creada = await tst.filaTarea(nombre).count();
    if (creada) await tst.eliminarTarea(nombre).catch(() => {});
    expect(creada, 'se guardó una tarea estándar con duración 99:99').toBe(0);
  });

  test('@quarantine TAR-CP-020-01 agregar 3 subtareas y eliminar 1: quedan 2', async ({}, testInfo) => {
    await tst.abrir('tareasEstandar', testInfo);
    await tst.abrirSubtareas(TAREA);
    for (const n of ['Aislar equipo', 'Revisar sellos', 'Registrar lectura']) {
      await tst.agregarSubtarea(`${n} ${SUF}`);
      await tst.esperarCarga();
      await tst.cerrarDialogos();
    }
    await expect(tst.filasSubtareas).toHaveCount(3, { timeout: 30_000 });
    await tst.eliminarSubtarea(2);
    await tst.cerrarDialogos();
    await expect(tst.filasSubtareas).toHaveCount(2, { timeout: 30_000 });
    await tst.cerrarSubtareas();
  });

  test('TAR-CP-020-03 subtarea sin nombre: no se guarda', async ({}, testInfo) => {
    await tst.abrir('tareasEstandar', testInfo);
    await tst.abrirSubtareas(TAREA_2);
    const antes = await tst.filasSubtareas.count();
    await tst.agregarSubtarea('');
    expect((await tst.dialogo()).texto).toMatch(/complete los campos obligatorios/i);
    await tst.cerrarDialogos();
    await expect(tst.filasSubtareas).toHaveCount(antes);
    await tst.cerrarSubtareas();
  });

  test('TAR-CP-021-01 crear plantilla y asociar 2 tareas: el selector ya no las ofrece', async ({}, testInfo) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-100 #587 (B-10): el selector ofrece tareas ya asociadas');
    await tst.abrir('tareasEstandar', testInfo);
    await tst.crearPlantilla(PLANTILLA);
    await expect(tst.filaPlantilla(PLANTILLA)).toHaveCount(1, { timeout: 30_000 });

    await tst.verTareasDePlantilla(PLANTILLA);
    await tst.asociarTarea(TAREA);
    await tst.asociarTarea(TAREA_2);
    await expect(tst.tareasDePlantilla).toHaveCount(2, { timeout: 30_000 });

    const ofrecidas = (await tst.opcionesParaAsociar()).join(' | ');
    expect(ofrecidas, 'las tareas ya asociadas se siguen ofreciendo').not.toContain(TAREA);
    await tst.cerrarTareasDePlantilla();
  });

  test('TAR-CP-021-02 editar una plantilla precarga su nombre y no toca el formulario de tareas (HIP-TAR-16)', async ({}, testInfo) => {
    await tst.abrir('tareasEstandar', testInfo);
    await tst.irAPlantillas();
    const enModal = await tst.abrirEdicionPlantilla(PLANTILLA);
    const enFormTarea = await tst.nombreEnFormularioDeTarea();
    await tst.page.locator('#nueva_plantilla [data-dismiss="modal"]').first().click().catch(() => {});

    expect.soft(enFormTarea, 'el nombre de la plantilla se escribió en el formulario de alta de tareas').not.toBe(PLANTILLA);
    expect(enModal, 'el modal de edición no muestra el nombre actual de la plantilla').toBe(PLANTILLA);
  });

  test('TAR-CP-019-04 editar nombre y duración de una tarea estándar', async ({}, testInfo) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-095 #582 (B-05): updateTarea castea vacío a integer');
    await tst.abrir('tareasEstandar', testInfo);
    const nuevo = `${TAREA} v2`;
    await tst.editarTarea(TAREA, { nombre: nuevo, duracion: '03:00' });
    await tst.esperarCarga();
    expect((await tst.dialogo()).texto).toMatch(/Se editó la tarea estandar/i);
    await tst.cerrarDialogos();
    await tst.abrir('tareasEstandar', testInfo);
    expect((await tst.datosTarea(nuevo))?.duracion).toBe('03:00');
    // Se vuelve al nombre original: los specs de planificación la buscan por ese nombre.
    await tst.editarTarea(nuevo, { nombre: TAREA, duracion: '02:00' });
    await tst.esperarCarga();
    await tst.cerrarDialogos();
  });

  test('TAR-CP-021-04 eliminar una tarea estándar que está en una plantilla: la plantilla ya no la muestra', async ({}, testInfo) => {
    await tst.abrir('tareasEstandar', testInfo);
    await tst.eliminarTarea(TAREA_2);
    await tst.abrir('tareasEstandar', testInfo);
    await expect(tst.filaTarea(TAREA_2)).toHaveCount(0);

    await tst.irAPlantillas();
    await tst.verTareasDePlantilla(PLANTILLA);
    await expect(tst.tareasDePlantilla.filter({ hasText: TAREA_2 })).toHaveCount(0);
    await tst.cerrarTareasDePlantilla();
  });

  test('TAR-CP-021-03 desasociar una tarea y eliminar la plantilla', async ({}, testInfo) => {
    await tst.abrir('tareasEstandar', testInfo);
    await tst.irAPlantillas();
    await tst.verTareasDePlantilla(PLANTILLA);
    await tst.desasociarTarea(TAREA);
    await expect(tst.tareasDePlantilla.filter({ hasText: TAREA })).toHaveCount(0);
    await tst.cerrarTareasDePlantilla();

    await tst.eliminarPlantilla(PLANTILLA);
    await tst.abrir('tareasEstandar', testInfo);
    await tst.irAPlantillas();
    await expect(tst.filaPlantilla(PLANTILLA)).toHaveCount(0);
  });
});
