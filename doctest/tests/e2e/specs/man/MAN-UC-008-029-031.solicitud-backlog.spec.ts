/**
 * Casos de uso: MAN-UC-008 (analizar una solicitud), 029 (ciclo de una solicitud) y 031 (ciclo de un backlog)
 * Catálogo: catalogo/man/MAN-UC-008.yaml, 029, 031
 *
 * Circuitos largos (@ciclo): crean casos reales de Bonita y solo corren en el modo full. Cada prueba
 * crea su equipo y su solicitud. La urgencia es la única decisión del análisis y define el camino:
 * urgente → Planificar Solicitud; no urgente → Editar Backlog → Planificar Backlog.
 * Quien pide y programa es el administrador; las tareas de Bonita le llegan al Supervisor (actor "Supervisor Taller").
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { abrirTareaDelCaso, buscarTareaDelCaso, pulsarHecho } from '../../pages/man/BandejaMan.ts';
import {
  buscarSolicitud, crearEquipo, crearSolicitud, crearTarea, idsDeListado, isoDia, LISTADOS, programarOrden, sufijo, unidadTiempo,
} from '../../pages/man/datos.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

/** Abre el análisis de la solicitud y decide. */
async function analizar(man: ShellMan, caso: string, falla: string, urgente: boolean): Promise<void> {
  await abrirTareaDelCaso(man, caso, /Analisis de Solicitud/i);
  // La falla está en un campo de la caja plegable de la solicitud, en la cabecera del panel.
  await expect
    .poll(
      () =>
        man.page.evaluate(
          (t) => Array.from(document.querySelectorAll<HTMLInputElement>('#miniView input, #miniView textarea')).some((c) => c.value.includes(t)),
          falla,
        ),
      { message: 'el análisis muestra la falla reportada', timeout: 30_000 },
    )
    .toBe(true);
  await man.page.locator(`input[name="opcion"][value="${urgente}"]`).first().check({ force: true });
  await pulsarHecho(man);
}

test.describe('@man @ciclo @MAN-UC-008 @MAN-UC-029 @MAN-UC-031 Solicitud y backlog', () => {
  test.setTimeout(15 * 60_000);

  test('urgente: la planifica el supervisor y la solicitud queda ligada a su orden', async ({ paginaMan, paginaSupervisor }) => {
    const man = new ShellMan(paginaMan);
    const supervisor = new ShellMan(paginaSupervisor);
    await man.enElShell();
    await supervisor.enElShell();
    const equipo = await crearEquipo(man);
    const falla = `Falla urgente DocTest ${sufijo()}`;
    const solicitud = await crearSolicitud(man, equipo, falla);
    expect(solicitud.estado, 'nace solicitada').toBe('S');

    await analizar(supervisor, solicitud.case_id, falla, true);
    await buscarTareaDelCaso(supervisor, solicitud.case_id, /Planificar Solicitud/i);
    expect((await buscarSolicitud(man, equipo, falla))?.urgente, 'queda marcada urgente').toBeTruthy();

    const orden = await programarOrden(man, Number(solicitud.id_solicitud), 1, 2);
    const despues = await buscarSolicitud(man, equipo, falla);
    expect(despues?.id_orden, 'el listado muestra el Nº de OT').toBe(orden.id_orden);
  });

  test('no urgente: se convierte en backlog y al programarlo queda planificado', async ({ paginaMan, paginaSupervisor }) => {
    const man = new ShellMan(paginaMan);
    const supervisor = new ShellMan(paginaSupervisor);
    await man.enElShell();
    await supervisor.enElShell();
    const equipo = await crearEquipo(man);
    const falla = `Falla no urgente DocTest ${sufijo()}`;
    const solicitud = await crearSolicitud(man, equipo, falla);
    const antes = new Set(await idsDeListado(man, LISTADOS.backlog));

    await analizar(supervisor, solicitud.case_id, falla, false);
    const idTarea = await abrirTareaDelCaso(supervisor, solicitud.case_id, /Editar Backlog/i);
    const r = (await supervisor.pedir('traz-tools-man/Backlog/editar_backlog', {
      tipo: 'editNuevo', idTarBonita: idTarea, tarea: await crearTarea(man), fecha: isoDia(new Date()), hshombre: 1, duracion: 60,
      id_unidad: await unidadTiempo(man), back_canth: 1, tareaOpcional: '', idcomponenteequipo: '',
    })) as { status: boolean; msj?: string };
    expect(r.status, `Editar Backlog: ${r.msj ?? ''}`).toBe(true);

    // El proceso lo genera en borrador (B), fuera del listado; al completarlo aparece como pendiente.
    const backlog = (await idsDeListado(man, LISTADOS.backlog)).filter((x) => !antes.has(x)).sort((a, b) => b - a)[0];
    expect(backlog, 'el proceso generó el backlog').toBeGreaterThan(0);

    await buscarTareaDelCaso(supervisor, solicitud.case_id, /Planificar Backlog/i);
    const orden = await programarOrden(man, backlog, 1, 4);
    expect(orden.id_orden, 'el backlog generó su orden').toBeTruthy();
    const info = (await man.pedir(`traz-tools-man/Backlog/geteditar?idpred=${backlog}&datos=${equipo.id}`)) as {
      datos: Array<{ estado: string }>;
    };
    expect(info.datos[0].estado, 'el backlog deja de estar pendiente').not.toBe('C');
  });
});
