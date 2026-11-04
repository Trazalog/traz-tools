/**
 * Casos de uso: MAN-UC-021 (entregar órdenes terminadas) y MAN-UC-037 (ver un informe y verificar en bloque)
 * Catálogo: catalogo/man/MAN-UC-021.yaml, 037
 *
 * Las pruebas @ciclo llevan una orden propia hasta tener el informe guardado: es la única forma de que
 * haya una orden terminada en una empresa recién creada. Necesitan DOCTEST_<AMBIENTE>_MAN_RESPONSABLE.
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { asignarOrden, ejecutarEInformar } from '../../pages/man/BandejaMan.ts';
import {
  crearEquipo, crearPreventivo, ordenEnCalendario, programarOrden, varMan, type EquipoCreado, type OrdenCalendario,
} from '../../pages/man/datos.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

const RESPONSABLE = varMan('RESPONSABLE');

/** Una orden propia, terminada y con el informe guardado. */
async function ordenTerminada(man: ShellMan): Promise<{ orden: OrdenCalendario; equipo: EquipoCreado }> {
  const equipo = await crearEquipo(man);
  const orden = await programarOrden(man, await crearPreventivo(man, equipo), 1);
  const r = await asignarOrden(man, orden, RESPONSABLE, 'Prueba DocTest de entrega e informe');
  expect(r.status, `Asignar OT: ${r.msj ?? ''}`).toBe(true);
  await ejecutarEInformar(man, orden);
  return { orden, equipo };
}

test.describe('@man @MAN-UC-021 Administrar Ordenes', () => {
  test('la pantalla lista las órdenes con sus columnas', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('administrarOrdenes', testInfo);
    const texto = await man.encabezados();
    for (const c of ['ID', 'Numero', 'Fecha Inicio', 'Fecha Entrega', 'Fecha Terminada', 'Fecha Aviso', 'Detalle', 'Estado']) {
      expect(texto).toContain(c);
    }
  });

  test('no entrega ni reprograma una orden que no es de la empresa', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    expect(await man.pedir('traz-tools-man/Envio/entrega', { id_orden: 999999999 })).toBe(false);
    expect(await man.pedir('traz-tools-man/Envio/ModificarFecha', { ido: 999999999, fe: '01-01-2030' })).toBe(false);
  });

  test('@ciclo una orden terminada se entrega y sale de la lista', async ({ paginaMan }) => {
    test.skip(!RESPONSABLE, 'Falta DOCTEST_<AMBIENTE>_MAN_RESPONSABLE');
    test.setTimeout(15 * 60_000);
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const { orden } = await ordenTerminada(man);
    const lista = () => man.pedir('traz-tools-man/Envio/index/Add-Edit-Del').then(String);
    expect(await lista(), 'la orden terminada figura en la lista').toContain(`<tr id="${orden.id_orden}"`);
    expect(await man.pedir('traz-tools-man/Envio/entrega', { id_orden: orden.id_orden })).toBe(true);
    expect(await lista(), 'la orden entregada sale de la lista').not.toContain(`<tr id="${orden.id_orden}"`);
  });
});

test.describe('@man @MAN-UC-037 Detalle de un informe', () => {
  test('el listado ofrece Ver Informe y seleccionar todos', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('informes', testInfo);
    await man.encabezados();
    await expect(man.contenido.locator('#check_todos')).toBeAttached();
  });

  test('sin informes seleccionados la verificación en bloque avisa', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const r = (await man.pedir('traz-tools-man/Ordenservicio/cierreMasivoVerificaInforme', {})) as { status: boolean; msj: string };
    expect(r.status).toBe(false);
    expect(r.msj).toMatch(/No se seleccionaron/);
  });

  test('@ciclo el informe se ve completo y la verificación en bloque cierra la orden', async ({ paginaMan }) => {
    test.skip(!RESPONSABLE, 'Falta DOCTEST_<AMBIENTE>_MAN_RESPONSABLE');
    test.setTimeout(15 * 60_000);
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const { orden, equipo } = await ordenTerminada(man);
    const informe = String(await man.pedir(`traz-tools-man/Ordenservicio/verInforme/${orden.id_orden}/${equipo.id}`));
    expect(informe, 'el informe muestra qué se hizo').toContain('Revisión hecha por la prueba DocTest');

    const r = (await man.pedir('traz-tools-man/Ordenservicio/cierreMasivoVerificaInforme', {
      selected: [{ id_orden: orden.id_orden, id_ot: orden.id_orden }],
    })) as Array<{ status: string; msj?: string }>;
    expect(r[0]?.status, r[0]?.msj).toBe('OK');
    expect((await ordenEnCalendario(man, orden))?.estado, 'la orden queda cerrada').toBe('CE');
  });
});
