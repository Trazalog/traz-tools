/**
 * Lo común a los circuitos de Mantenimiento en "Mis Tareas" (la bandeja de Tools) y en la ventana de la
 * orden del Plan de Mantenimiento. Lo usan las pruebas @ciclo.
 */

import { expect, type Locator, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../../config/apps.ts';
import { isoDia, type OrdenCalendario } from './datos.ts';
import type { ShellMan } from './ShellMan.ts';

const dos = (n: number) => String(n).padStart(2, '0');

/** Fecha y hora en el formato del informe (`YYYY-MM-DD H:mm:ss`), corrida `min` minutos. */
export const ahora = (min = 0): string => {
  const d = new Date(Date.now() + min * 60_000);
  return `${isoDia(d)} ${d.getHours()}:${dos(d.getMinutes())}:00`;
};

function filaDelCaso(page: Page, caso: string, nombre: RegExp): Locator {
  return page
    .locator('table#tareas tbody tr.item')
    .filter({ hasText: new RegExp(`case\\D{0,10}${caso}(?!\\d)`) })
    .filter({ hasText: nombre });
}

/** Deja la tarjeta de la tarea del caso en pantalla, esperando a que Bonita la cree. */
export async function buscarTareaDelCaso(man: ShellMan, caso: string, nombre: RegExp): Promise<Locator> {
  const page = man.page;
  const fila = filaDelCaso(page, caso, nombre);
  for (let intento = 0; intento < 8; intento++) {
    // Se recarga la página antes de entrar a la bandeja: cada vez que se entra a "Mis Tareas" sin recargar,
    // la bandeja vuelve a enganchar el clic de las tarjetas y el panel se carga varias veces (hallazgo H41).
    await page.goto(requerirUrlDeApp('tools'), { waitUntil: 'domcontentloaded' });
    await man.abrir('bandeja');
    await page.locator('table#tareas tbody tr').first().waitFor({ timeout: 90_000 });
    // La bandeja pagina de a 10: se muestran todas para encontrar la del caso.
    await page.evaluate(() => {
      const $ = (window as unknown as { $: (s: string) => { DataTable: () => { page: { len: (n: number) => { draw: () => void } } } } }).$;
      $('#tareas').DataTable().page.len(200).draw();
    });
    await man.esperarCarga();
    if (await fila.first().waitFor({ timeout: 20_000 }).then(() => true, () => false)) break;
  }
  await expect(fila, `la tarea ${nombre} del caso ${caso} llega a la bandeja`).toHaveCount(1);
  return fila;
}

/**
 * Abre el panel de la tarea con un clic en su tarjeta y espera el panel NUEVO: el viejo queda marcado,
 * porque si se toca su botón mientras llega el nuevo, el nuevo lo pisa y la acción se pierde.
 */
export async function abrirPanel(page: Page, fila: Locator): Promise<void> {
  await page.evaluate(() => document.querySelectorAll('#btnHecho').forEach((b) => b.setAttribute('data-viejo', '1')));
  await fila.click();
  await page.locator('#btnHecho:not([data-viejo])').first().waitFor({ state: 'attached', timeout: 120_000 });
  await page.waitForLoadState('networkidle', { timeout: 60_000 }).catch(() => {});
}

/** Abre la tarea del caso en "Mis Tareas" y la toma. Devuelve el número de tarea de Bonita. */
export async function abrirTareaDelCaso(man: ShellMan, caso: string, nombre: RegExp): Promise<string> {
  const page = man.page;
  const fila = await buscarTareaDelCaso(man, caso, nombre);
  const idTarea = (await fila.getAttribute('id')) ?? '';
  await abrirPanel(page, fila);
  await man.esperarCarga(90_000, false);
  const tomar = page.locator('.btn-tomar:visible');
  if (await tomar.count()) {
    await tomar.first().click();
    await man.esperarCarga(90_000, false);
    // Tomar la tarea recarga el panel: se vuelve a abrir desde la tarjeta para trabajar sobre un panel limpio.
    await abrirPanel(page, fila);
    await man.esperarCarga(90_000, false);
  }
  // Con la tarea tomada se va el velo y aparecen los controles de trabajo.
  await expect(page.locator('#view > .overlay')).toHaveCount(0, { timeout: 30_000 });
  return idTarea;
}

export async function pulsarHecho(man: ShellMan): Promise<void> {
  await man.page.locator('#btnHecho').first().evaluate((b: HTMLElement) => b.click());
  await man.esperarCarga();
}

export interface RespuestaAsignar {
  status: boolean;
  msj?: string;
  pedido?: { status: boolean; msj?: string };
}

/** Asigna la orden desde su ventana del Plan de Mantenimiento ("Asignar OT"). */
export async function asignarOrden(man: ShellMan, orden: OrdenCalendario, responsable: string, tarea: string): Promise<RespuestaAsignar> {
  const page = man.page;
  await man.abrir('plan');
  await page.evaluate((id) => (window as unknown as { verDetalleOT: (x: string) => void }).verDetalleOT(id), orden.id_orden);
  await page.locator('#id_operario').waitFor({ state: 'attached', timeout: 60_000 });
  await man.esperarCarga();
  await expect(page.getByText('Pedido Materiales').first(), 'la ventana tiene la pestaña del pedido').toBeAttached();
  // La ventana pide la ubicación del navegador y recién después envía: se espera la respuesta.
  const asignada = page.waitForResponse(/Otrabajo\/EjecutarOT/, { timeout: 180_000 });
  await page.evaluate(
    ({ resp, tarea: t }) => {
      // El navegador solo da la ubicación en sitios https o localhost; se simula el GPS del dispositivo (H43).
      Object.defineProperty(navigator, 'geolocation', {
        configurable: true,
        value: {
          getCurrentPosition: (ok: (p: { coords: { latitude: number; longitude: number } }) => void) =>
            ok({ coords: { latitude: -31.5375, longitude: -68.5364 } }),
        },
      });
      const $ = (window as unknown as { $: (s: string) => { val: (v?: string) => unknown; trigger: (e: string) => void } }).$;
      $('#id_operario').val(resp);
      $('#id_operario').trigger('change');
      $('#tareaOpcional').val(t);
      (window as unknown as { EjecutarOT: () => void }).EjecutarOT();
    },
    { resp: responsable, tarea },
  );
  const respuesta = await asignada.catch((e) => {
    throw new Error(`Asignar OT no se envió. Avisos de la pantalla: ${JSON.stringify(man.avisos)} · ${e}`);
  });
  const r = (await respuesta.json()) as RespuestaAsignar;
  await man.esperarCarga();
  return r;
}

/** Carga y guarda el informe en la ventana ya abierta (`#modalInforme`). */
export async function guardarInforme(man: ShellMan): Promise<void> {
  const page = man.page;
  const modal = page.locator('#modalInforme');
  await page.evaluate(({ inicio, fin }) => {
    const $ = (window as unknown as { $: (s: string) => { val: (v?: string) => string; text: () => string; length: number } }).$;
    $('#fecha_inicio').val(inicio);
    $('#fecha_fin').val(fin);
    const base = Number($('#spanNuevaLectura').text() || 0) || 0;
    $('#lectura_inicio').val(String(base));
    $('#lectura_fin').val(String(base + 1));
    $('#form_order #tareas').val('Revisión hecha por la prueba DocTest');
    (window as unknown as { armarTablaTareas: () => void }).armarTablaTareas();
  }, { inicio: ahora(-60), fin: ahora() });
  await modal.locator('#hecho').click();
  const seguir = page.locator('.swal2-confirm:visible');
  if (await seguir.count().then((n) => n > 0, () => false)) await seguir.first().click();
  await page.locator('.swal2-confirm:visible').first().click({ timeout: 5000 }).catch(() => {});
  await man.esperarCarga();
  await expect(modal).toBeHidden({ timeout: 60_000 });
}

/** Lleva una orden ya asignada hasta tener el informe guardado: queda terminada (`T`) y en "Verifica Informe". */
export async function ejecutarEInformar(man: ShellMan, orden: OrdenCalendario): Promise<void> {
  const caso = String(orden.case_id);
  await abrirTareaDelCaso(man, caso, /Ejecutar OT/i);
  await man.pedir('traz-tools-man/Tarea/inicioTarea', { id_OT: orden.id_orden, lat: '-31.5375', lon: '-68.5364' });
  await pulsarHecho(man);
  await abrirTareaDelCaso(man, caso, /Confecciona informe/i);
  await pulsarHecho(man);
  await expect(man.page.locator('#modalInforme')).toBeVisible({ timeout: 60_000 });
  await expect(man.page.locator('#matOT'), 'la ventana del informe terminó de cargar').toHaveCount(1, { timeout: 90_000 });
  await guardarInforme(man);
}
