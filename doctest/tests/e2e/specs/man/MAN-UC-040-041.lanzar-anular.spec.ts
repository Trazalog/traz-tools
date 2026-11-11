/**
 * Casos de uso: MAN-UC-040 (lanzar las órdenes programadas) y MAN-UC-041 (anular una orden sin lanzar)
 * Catálogo: catalogo/man/MAN-UC-040.yaml, MAN-UC-041.yaml
 *
 * Al programar, el motor (`toolsMANAPI POST /tools/man/plan/programar`) solo lanza en Bonita las
 * órdenes que caen dentro del margen (7 días por defecto, `core.tablas`); las demás quedan
 * "programadas sin lanzar": estado PL, tipo 3 o 5 y caso 0 (decisiones E58–E60).
 *
 * Copia el preventivo de plantilla DOCTEST_<AMBIENTE>_MAN_PREVENTIVO (en DEV, 179; programar una orden
 * única cierra el preventivo) y programa una orden única de la copia a 60 días —fuera del margen—.
 *
 * Lanzar crea un caso real de Bonita que no se puede deshacer: esa prueba es @ciclo (solo modo full).
 */

import type { Page } from '@playwright/test';

import { test, expect } from '../../fixtures/auth-man.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';
import { copiarPreventivo, ordenEnCalendario as enCalendario, programarOrden, varMan } from '../../pages/man/datos.ts';

const PREVENTIVO = Number(varMan('PREVENTIVO') || 0);

/** Copia el preventivo de plantilla y programa una orden única de la copia a `dias` de hoy. */
async function programarSinLanzar(man: ShellMan, dias: number) {
  return programarOrden(man, await copiarPreventivo(man, PREVENTIVO), dias);
}

async function shell(pagina: Page): Promise<ShellMan> {
  const man = new ShellMan(pagina);
  await man.enElShell();
  return man;
}

test.describe('@man @MAN-UC-040 @MAN-UC-041 Lanzar y anular órdenes programadas', () => {
  test.skip(!PREVENTIVO, 'Falta DOCTEST_<AMBIENTE>_MAN_PREVENTIVO: un preventivo de plantilla de la empresa vinculada');

  test('una orden fuera del margen queda programada sin lanzar y se puede anular', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const orden = await programarSinLanzar(man, 60);
    expect(orden.estado).toBe('PL');
    expect(String(orden.case_id), 'sin caso de Bonita todavía').toBe('0');

    const r = (await man.pedir('traz-tools-man/Otrabajo/anular', { ot: orden.id_orden })) as { status: boolean; msj?: string };
    expect(r.status, r.msj).toBe(true);
    expect(await enCalendario(man, orden), 'la orden anulada ya no aparece en el calendario').toBeUndefined();
  });

  test('no se puede anular una orden que no existe o no es de la empresa', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const r = (await man.pedir('traz-tools-man/Otrabajo/anular', { ot: 999999999 })) as { status: boolean };
    expect(r.status).toBe(false);
  });

  test('la lista de órdenes marca la orden "Sin lanzar" y le ofrece Lanzar y Anular', async ({ paginaMan }, testInfo) => {
    const man = await shell(paginaMan);
    const orden = await programarSinLanzar(man, 60);
    await man.abrir('ordenes', testInfo);
    await man.encabezados();
    // La lista arranca vacía: se filtra por el día programado, como haría el usuario.
    const dia = orden.fecha_program.slice(0, 10);
    await man.contenido.locator('#fec_desde').fill(dia);
    await man.contenido.locator('#fec_hasta').evaluate((e: HTMLInputElement, v) => {
      e.readOnly = false;
      e.value = v;
    }, dia);
    await man.contenido.getByRole('button', { name: 'Filtrar' }).click();
    await man.esperarCarga();
    // La grilla pagina en el navegador: se busca el número para que la fila esté en la página.
    await paginaMan.evaluate((id) => {
      const $ = (window as unknown as { $: (s: string) => { DataTable: () => { search: (x: string) => { draw: () => void } } } }).$;
      $('#otrabajo').DataTable().search(id).draw();
    }, orden.id_orden);
    const fila = man.contenido.locator(`tr.ot-row[id="${orden.id_orden}"]`);
    await expect(fila).toHaveAttribute('data-sinlanzar', '1');
    await expect(fila).toContainText(/Sin lanzar/i);
    await expect(fila.locator('a[onclick^="lanzarOT"]')).toHaveCount(1);
    await expect(fila.locator('a[onclick^="anularOT"]')).toHaveCount(1);
    // Se deja como estaba: la orden de prueba se anula.
    const r = (await man.pedir('traz-tools-man/Otrabajo/anular', { ot: orden.id_orden })) as { status: boolean };
    expect(r.status).toBe(true);
  });

  test('@ciclo lanzar una orden sin lanzar le crea su caso', async ({ paginaMan }) => {
    const man = await shell(paginaMan);
    const orden = await programarSinLanzar(man, 45);
    const r = (await man.pedir('traz-tools-man/Otrabajo/lanzar', { ot: orden.id_orden })) as { status: boolean; msj?: string };
    expect(r.status, r.msj).toBe(true);
    const despues = await enCalendario(man, orden);
    expect(Number(despues?.case_id), 'la orden lanzada tiene caso').toBeGreaterThan(0);
  });
});
