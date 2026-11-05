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
import { abrirTareaDelCaso, asignarOrden, guardarInforme, pulsarHecho } from '../../pages/man/BandejaMan.ts';
import { copiarPreventivo, isoDia, programarOrden, varMan, type OrdenCalendario } from '../../pages/man/datos.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

const PREVENTIVO = Number(varMan('PREVENTIVO') || 0);
const RESPONSABLE = varMan('RESPONSABLE');

/** La pestaña "Herramientas e Insumos" está y muestra el pedido de la orden. */
async function verificarMateriales(page: Page, conVales: boolean): Promise<void> {
  const mat = page.locator('#matOT');
  await expect(mat, 'la tarea muestra la pestaña Herramientas e Insumos').toHaveCount(1, { timeout: 90_000 });
  await expect(mat.locator('#matInsumos tbody tr').first(), 'el pedido de materiales se ve en la tarea').toBeAttached({ timeout: 30_000 });
  await expect(page.locator('#matAbrirVales')).toHaveCount(conVales ? 1 : 0);
}

test.describe('@man @ciclo @MAN-UC-030 Ciclo de vida de una orden de trabajo', () => {
  test.skip(!PREVENTIVO || !RESPONSABLE, 'Faltan DOCTEST_<AMBIENTE>_MAN_PREVENTIVO y _MAN_RESPONSABLE');
  test.setTimeout(20 * 60_000);

  test('programar → asignar con pedido → ejecutar → informe → verificar → conformidad', async ({ paginaMan, paginaSupervisor, paginaSolicitante }) => {
    const man = new ShellMan(paginaMan);
    const supervisor = new ShellMan(paginaSupervisor);
    const page = paginaMan;
    await man.enElShell();
    await supervisor.enElShell();
    const solicitante = new ShellMan(paginaSolicitante);
    await solicitante.enElShell();

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
      const r = await asignarOrden(man, orden, RESPONSABLE, 'Prueba DocTest del ciclo de la OT');
      expect(r.status, `Asignar OT: ${r.msj ?? ''}`).toBe(true);
      expect(r.pedido?.status, `el pedido de materiales: ${r.pedido?.msj ?? 'no se envió'}`).toBe(true);
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
      await verificarMateriales(page, true);
      await guardarInforme(man);
    });

    // 5. Verifica informe: el supervisor ve la pestaña con vales y aprueba (MAN-UC-013)
    await test.step('verificar', async () => {
      await abrirTareaDelCaso(supervisor, caso, /Verifica Informe/i);
      await verificarMateriales(paginaSupervisor, true);
      await paginaSupervisor.locator('input[name="opcion"][value="true"]').first().check({ force: true });
      await pulsarHecho(supervisor);
    });

    // 6. Presta conformidad: la tarea le llega al Solicitante; ve la pestaña (solo lectura) y da la conformidad
    await test.step('conformidad', async () => {
      await abrirTareaDelCaso(solicitante, caso, /Presta conformidad/i);
      await verificarMateriales(paginaSolicitante, false);
      await paginaSolicitante.locator('input[name="opcion"][value="true"]').first().check({ force: true });
      await pulsarHecho(solicitante);
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
