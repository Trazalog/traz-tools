/**
 * Caso de uso: MAN-UC-030 — El ciclo de vida de una orden de trabajo, de punta a punta, en Tools.
 * Recorre también MAN-UC-009 (programar), 011 (asignar con herramientas y pedido), 012 (informe),
 * 013 (verificar y conformidad) y 038 (la pestaña "Herramientas e Insumos" en cada paso).
 * Catálogo: catalogo/man/MAN-UC-030.yaml
 *
 * Es un circuito largo (@ciclo): crea una orden real con su caso de Bonita y su pedido al almacén, y
 * la lleva hasta "Conforme". Solo corre en el modo full. Datos del ambiente:
 *
 *   DOCTEST_<AMBIENTE>_MAN_PREVENTIVO   preventivo de plantilla con al menos un insumo (DEV: 179); la
 *                                       prueba lo copia, porque programar una orden única lo cierra
 *   DOCTEST_<AMBIENTE>_MAN_RESPONSABLE  el número de usuario de Mantenimiento del usuario de la prueba
 *                                       (sisusers.usrId; DEV: 213), para que las tareas le lleguen a él
 *
 * Cada paso se hace desde su pantalla: la ventana de la orden en el Plan de Mantenimiento y el panel de
 * la tarea en la bandeja de Tools ("Mis Tareas").
 */

import type { Page } from '@playwright/test';

import { test, expect } from '../../fixtures/auth-man.ts';
import { entornoActual, requerirUrlDeApp } from '../../config/apps.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';
import { copiarPreventivo, programarOrden } from '../../pages/man/datos.ts';

const PREFIJO: Record<string, string> = { local: 'LOCAL', demo: 'DEMO', 'staging-v3': 'STAGING' };
const env = (k: string) => process.env[`DOCTEST_${PREFIJO[entornoActual()]}_MAN_${k}`]?.trim() ?? '';
const PREVENTIVO = Number(env('PREVENTIVO') || 0);
const RESPONSABLE = env('RESPONSABLE');

interface OrdenCalendario {
  id_orden: string;
  estado: string;
  case_id: string | number | null;
  fecha_program: string;
}

const dos = (n: number) => String(n).padStart(2, '0');
const isoDia = (d: Date) => `${d.getFullYear()}-${dos(d.getMonth() + 1)}-${dos(d.getDate())}`;
const ahora = (min = 0) => {
  const d = new Date(Date.now() + min * 60_000);
  return `${isoDia(d)} ${d.getHours()}:${dos(d.getMinutes())}:00`;
};

/** Abre la tarea del caso en "Mis Tareas" (clic en su tarjeta), esperando a que Bonita la cree, y la toma. */
async function abrirTareaDelCaso(man: ShellMan, caso: string, nombre: RegExp): Promise<void> {
  const page = man.page;
  const fila = page.locator('table#tareas tbody tr.item').filter({ hasText: new RegExp(`case\\D{0,10}${caso}(?!\\d)`) }).filter({ hasText: nombre });
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
}

/**
 * Abre el panel de la tarea con un clic en su tarjeta y espera el panel NUEVO: el viejo queda marcado,
 * porque si se toca su botón mientras llega el nuevo, el nuevo lo pisa y la acción se pierde.
 */
async function abrirPanel(page: Page, fila: import('@playwright/test').Locator): Promise<void> {
  await page.evaluate(() => document.querySelectorAll('#btnHecho').forEach((b) => b.setAttribute('data-viejo', '1')));
  await fila.click();
  await page.locator('#btnHecho:not([data-viejo])').first().waitFor({ state: 'attached', timeout: 120_000 });
  await page.waitForLoadState('networkidle', { timeout: 60_000 }).catch(() => {});
}

/** La pestaña "Herramientas e Insumos" está y muestra el pedido de la orden. */
async function verificarMateriales(page: Page, conVales: boolean, man?: ShellMan): Promise<void> {
  const mat = page.locator('#matOT');
  const diag = async () =>
    page.evaluate(() => {
      const w = window as unknown as { $: (s: string) => { length: number; html: () => string | undefined } };
      return `modalInforme=${document.querySelectorAll('[id="modalInforme"]').length} servicios=${document.querySelectorAll('[id="modalInformeServicios"]').length} llenos=${Array.from(document.querySelectorAll('[id="modalInformeServicios"]')).map((x) => x.innerHTML.length + (x.closest('#content') ? 'c' : 'f') + (x.closest('#miniView') ? 'm' : ''))} ` +
        `html=${(w.$('#modalInformeServicios').html() ?? '').slice(0, 200)} view=${w.$('#view').length} miniView=${w.$('#miniView').length}`;
    });
  await expect(mat, 'la tarea muestra la pestaña Herramientas e Insumos').toHaveCount(1, { timeout: 90_000 }).catch(async (e) => {
    throw new Error(`${e.message}\nDiagnóstico: ${await diag()} · errores=${JSON.stringify(man?.erroresJs)} · avisos=${JSON.stringify(man?.avisos)}`);
  });
  await expect(mat.locator('#matInsumos tbody tr').first(), 'el pedido de materiales se ve en la tarea').toBeAttached({ timeout: 30_000 });
  await expect(page.locator('#matAbrirVales')).toHaveCount(conVales ? 1 : 0);
}

async function pulsarHecho(man: ShellMan): Promise<void> {
  await man.page.locator('#btnHecho').first().evaluate((b: HTMLElement) => b.click());
  await man.esperarCarga();
}

test.describe('@man @ciclo @MAN-UC-030 Ciclo de vida de una orden de trabajo', () => {
  test.skip(!PREVENTIVO || !RESPONSABLE, 'Faltan DOCTEST_<AMBIENTE>_MAN_PREVENTIVO y _MAN_RESPONSABLE');
  test.setTimeout(20 * 60_000);

  test('programar → asignar con pedido → ejecutar → informe → verificar → conformidad', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    const page = paginaMan;
    const origen = new URL(requerirUrlDeApp('tools')).origin;
    await page.context().grantPermissions(['geolocation'], { origin: origen });
    await page.context().setGeolocation({ latitude: -31.5375, longitude: -68.5364 });
    await man.enElShell();

    // 1. Programar el preventivo para mañana: cae dentro del margen y se lanza con su caso (MAN-UC-009)
    const orden = await test.step('programar', async () => {
      const preventivo = await copiarPreventivo(man, PREVENTIVO);
      const nueva = await programarOrden(man, preventivo, 1);
      expect(Number(nueva.case_id), 'dentro del margen se lanza con caso de Bonita').toBeGreaterThan(0);
      return nueva;
    });
    const caso = String(orden.case_id);
    testInfoAnotar(`OT ${orden.id_orden}, caso ${caso}`);

    // 2. Asignar desde la ventana de la orden del Plan, con el pedido prearmado con los insumos (MAN-UC-011)
    await test.step('asignar con herramientas y pedido', async () => {
      await man.abrir('plan');
      await page.evaluate((id) => (window as unknown as { verDetalleOT: (x: string) => void }).verDetalleOT(id), orden.id_orden);
      await page.locator('#id_operario').waitFor({ state: 'attached', timeout: 60_000 });
      await man.esperarCarga();
      await expect(page.getByText('Pedido Materiales').first(), 'la ventana tiene la pestaña del pedido').toBeAttached();
      // La ventana pide la ubicación del navegador y recién después envía: se espera la respuesta.
      const asignada = page.waitForResponse(/Otrabajo\/EjecutarOT/, { timeout: 180_000 });
      await page.evaluate(
        ({ resp }) => {
          // El navegador solo da la ubicación en sitios https o localhost; se simula el GPS del dispositivo.
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
          $('#tareaOpcional').val('Prueba DocTest del ciclo de la OT');
          (window as unknown as { EjecutarOT: () => void }).EjecutarOT();
        },
        { resp: RESPONSABLE },
      );
      const respuesta = await asignada.catch((e) => {
        throw new Error(`Asignar OT no se envió. Avisos de la pantalla: ${JSON.stringify(man.avisos)} · ${e}`);
      });
      const r = (await respuesta.json()) as { status: boolean; msj?: string; pedido?: { status: boolean; msj?: string } };
      expect(r.status, `Asignar OT: ${r.msj ?? ''}`).toBe(true);
      expect(r.pedido?.status, `el pedido de materiales: ${r.pedido?.msj ?? 'no se envió'}`).toBe(true);
      await man.esperarCarga();
      const insumos = (await man.pedir('traz-tools-man/Ordenservicio/getInsumosPorOT', { id_ot: orden.id_orden })) as unknown[];
      expect(insumos.length, 'al asignar se envió el pedido de materiales al almacén').toBeGreaterThan(0);
      expect(man.avisos.filter((a) => /Falla|no se pudo/i.test(a)), 'sin avisos de error').toEqual([]);
    });

    // 3. Ejecutar OT: la pestaña muestra el pedido; se inicia y se termina
    await test.step('ejecutar', async () => {
      await abrirTareaDelCaso(man, caso, /Ejecutar OT/i);
      await verificarMateriales(page, false);
      await man.pedir('traz-tools-man/Tarea/inicioTarea', { id_OT: orden.id_orden, lat: '-31.5375', lon: '-68.5364' });
      await pulsarHecho(man);
    });

    // 4. Confecciona informe: la pestaña ofrece asociar vales; se carga y se guarda (MAN-UC-012)
    await test.step('informe', async () => {
      await abrirTareaDelCaso(man, caso, /Confecciona informe/i);
      await pulsarHecho(man);
      const modal = page.locator('#modalInforme');
      await expect(modal).toBeVisible({ timeout: 60_000 });
      await verificarMateriales(page, true, man);
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
    });

    // 5. Verifica informe: el supervisor ve la pestaña con vales y aprueba (MAN-UC-013)
    await test.step('verificar', async () => {
      await abrirTareaDelCaso(man, caso, /Verifica Informe/i);
      await verificarMateriales(page, true);
      await page.locator('input[name="opcion"][value="true"]').first().check({ force: true });
      await pulsarHecho(man);
    });

    // 6. Presta conformidad: la pestaña se ve (solo lectura) y se da la conformidad
    await test.step('conformidad', async () => {
      await abrirTareaDelCaso(man, caso, /Presta conformidad/i);
      await verificarMateriales(page, false);
      await page.locator('input[name="opcion"][value="true"]').first().check({ force: true });
      await pulsarHecho(man);
    });

    // 7. La orden quedó cerrada y su caso ya no tiene tareas en la bandeja
    await test.step('orden cerrada', async () => {
      const d = orden.fecha_program.slice(0, 10);
      const sig = isoDia(new Date(new Date(`${d}T12:00:00`).getTime() + 86_400_000));
      const filas = ((await man.pedir('traz-tools-man/Calendario/getcalendarot', { desde: d, hasta: sig })) as OrdenCalendario[]) || [];
      const final = filas.find((o) => o.id_orden === orden.id_orden);
      expect(['CN', 'CE', 'T'], `estado final de la OT ${orden.id_orden}`).toContain(final?.estado);
      expect(man.erroresJs.filter((e) => !/lectura/.test(e)), 'sin errores de JavaScript en el recorrido (H40 aparte)').toEqual([]);
    });

    function testInfoAnotar(texto: string) {
      test.info().annotations.push({ type: 'orden', description: texto });
    }
  });
});
