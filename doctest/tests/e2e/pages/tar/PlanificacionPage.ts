/**
 * Planificación de Trabajos (TAR-UC-005 a 015): pedidos → hitos → tareas.
 *
 * Pantalla `traz-comp-bpm/Pedidotrabajo/dash`, tres columnas que se recargan en cadena:
 *   - `#tbl-pedidos`  lista de pedidos de la empresa (botón por pedido + menú ⋮ "Trabajo Terminado")
 *   - `#tbl-hitos`    hitos del pedido elegido ("Nuevo Hito" y menú ⋮ "Ver Detalle")
 *   - `#pnl-tareas`   el componente de planificación del hito: pestaña Calendario (`#tareas-calendario`)
 *                     y pestaña Planificación Tareas (`#tareas-planificadas`, `#tareas`, `#plantilla`)
 *
 * Cada tarea planificada es una fila `.data-json` cuyo JSON se actualiza en el navegador después de
 * cada guardado (`setJson`): de ahí sale el `tapl_id`, la fecha, el usuario y el `case_id`.
 *
 * Las acciones de una tarea (📅 👤 ⚙️ ☑ 📄 🗑) son botones sin texto: se apuntan por su clase o
 * su `title`.
 */

import { expect, type Locator, type Page, type Response } from '@playwright/test';

import { ShellTar } from './ShellTar.ts';

export interface DatosHito {
  codigo: string;
  descripcion: string;
  /** `DD-MM-YYYY` como lo pide el datepicker. */
  fechaInicio: string;
  /** Texto visible del encargado (first_name). Si no se indica, el primero. */
  encargado?: string;
  objetivo: string;
  unidad?: string;
  /** Path de un archivo a adjuntar. */
  documento?: string;
}

export interface TareaPlanificada {
  tapl_id?: string;
  nombre?: string;
  fecha?: string;
  fec_inicio?: string;
  fec_fin?: string;
  user_id?: string;
  case_id?: string;
  estado?: string;
  info_id?: string;
  equipos?: Array<{ recu_id: string; codigo: string }>;
  __json_invalido__?: string;
  [k: string]: unknown;
}

export interface EventoCalendario {
  titulo: string;
  dia_inicio: string;
  dia_fin: string;
  [k: string]: unknown;
}

export class PlanificacionPage extends ShellTar {
  /** Respuestas crudas de los guardados de tareas (para detectar JSON roto o warnings de PHP). */
  readonly respuestasGuardado: Array<{ url: string; status: number; texto: string }> = [];
  /** Último lote de eventos que pidió el calendario. */
  eventos: EventoCalendario[] = [];

  constructor(page: Page) {
    super(page);
    page.on('response', (r) => void this.capturar(r));
  }

  private async capturar(r: Response): Promise<void> {
    const url = r.url();
    if (/Tarea\/(guardarPlanificada|guardarTareaPlanificada|eliminarPlanificada)|Pedidotrabajo\/hitos\/|finalizarTrabajo|validarEstadoProceso/.test(url)) {
      this.respuestasGuardado.push({ url, status: r.status(), texto: await r.text().catch(() => '') });
    }
    if (/calendario\/getEventos/.test(url)) {
      try {
        this.eventos = JSON.parse(await r.text());
      } catch {
        this.eventos = [];
      }
    }
  }

  async abrirPlanificacion(testInfo?: Parameters<ShellTar['abrir']>[1]): Promise<void> {
    await this.abrir('planificacion', testInfo);
    await this.page.locator('#tbl-pedidos').waitFor({ timeout: 60_000 });
  }

  // ── Pedidos ─────────────────────────────────────────────────────────────────

  celdaPedido(codigo: string): Locator {
    return this.page.locator('#tbl-pedidos tbody td[data-json]').filter({ hasText: codigo }).first();
  }

  async datosPedido(codigo: string): Promise<Record<string, string> | null> {
    return this.json(this.celdaPedido(codigo));
  }

  async elegirPedido(codigo: string): Promise<void> {
    await this.celdaPedido(codigo).locator('button.code').click();
    await this.page.locator('#tbl-hitos').waitFor({ timeout: 60_000 });
    await this.esperarCarga();
  }

  /** Menú ⋮ del pedido → "Trabajo Terminado". */
  async marcarTrabajoTerminado(codigo: string): Promise<{ status: number; texto: string }> {
    const celda = this.celdaPedido(codigo);
    await celda.locator('.dropdown-toggle').click();
    const resp = this.page.waitForResponse((r) => /finalizarTrabajo/.test(r.url()), { timeout: 60_000 });
    await celda.locator('a[onclick*="finalizarTrabajo"]').click();
    const r = await resp;
    await this.esperarCarga();
    return { status: r.status(), texto: await r.text() };
  }

  // ── Hitos ───────────────────────────────────────────────────────────────────

  filaHito(codigo: string): Locator {
    return this.page.locator('#tbl-hitos tbody tr').filter({ hasText: codigo }).first();
  }

  async nuevoHito(d: DatosHito): Promise<{ status: number; texto: string }> {
    await this.page.locator('#tbl-hitos button[onclick*="nuevoHito"]').click();
    const form = this.page.locator('#frm-hito');
    await form.waitFor({ state: 'visible', timeout: 30_000 });
    await this.esperarCarga();
    await form.locator('[name="numero"]').fill(d.codigo);
    await form.locator('[name="descripcion"]').fill(d.descripcion);
    await form.locator('[name="fec_inicio"]').fill(d.fechaInicio);
    await form.locator('[name="fec_inicio"]').press('Escape').catch(() => {});
    if (d.documento) await form.locator('#documento').setInputFiles(d.documento);
    await this.elegirPrimero(form.locator('[name="user_id"]'), d.encargado);
    await form.locator('[name="objetivo"]').fill(d.objetivo);
    await this.elegirPrimero(form.locator('[name="unidad_tiempo"]'), d.unidad);
    await this.elegirPrimero(form.locator('[name="esta_id"]'));
    const resp = this.page.waitForResponse((r) => /Pedidotrabajo\/hitos\//.test(r.url()) && r.request().method() === 'POST', { timeout: 30_000 }).catch(() => null);
    await this.page.locator('#mdl-hito .modal-footer button[onclick*="guardarHito"], #mdl-hito button[onclick*="guardarHito"]').first().click();
    const r = await resp;
    await this.esperarCarga();
    return r ? { status: r.status(), texto: await r.text() } : { status: 0, texto: '' };
  }

  private async elegirPrimero(select: Locator, etiqueta?: string): Promise<void> {
    if (etiqueta) {
      await select.selectOption({ label: etiqueta }, { force: true });
    } else {
      const valores = await select.locator('option').evaluateAll((os) => os.map((o) => (o as HTMLOptionElement).value).filter(Boolean));
      if (valores[0]) await select.selectOption(valores[0], { force: true });
    }
    await select.dispatchEvent('change');
  }

  /**
   * Abre la planificación de un origen sin pasar por el tablero, con el mismo `linkTo()` que usa
   * el tablero al elegir un hito. Sirve para probar el ciclo de la tarea cuando la empresa no puede
   * crear pedidos (sin `PROCESO-STANDAR`): ver `ORIGEN_SINTETICO` en el spec del ciclo.
   */
  async abrirPlanificacionDeOrigen(ortaId: string, testInfo?: Parameters<ShellTar['abrir']>[1]): Promise<void> {
    await this.enElShell();
    await this.cerrarModales();
    testInfo?.annotations.push({ type: 'origen-sintetico', description: `planificación abierta sobre PETR/${ortaId}` });
    const resp = this.page.waitForResponse((r) => /tarea\/planificar\/PETR\//i.test(r.url()), { timeout: 60_000 });
    await this.page.evaluate((id) => (window as unknown as { linkTo: (x: string) => void }).linkTo(`traz-comp-tareasestandar/tarea/planificar/PETR/${id}`), ortaId);
    await resp;
    await this.page.locator('#pnl-tareas').waitFor({ timeout: 60_000 });
    await this.esperarCarga();
  }

  /** Abre la planificación de un hito (click en su botón). */
  async elegirHito(codigo: string): Promise<void> {
    const resp = this.page.waitForResponse((r) => /tarea\/planificar\/PETR\//i.test(r.url()), { timeout: 60_000 });
    await this.filaHito(codigo).locator('button.code').click();
    await resp;
    await this.page.locator('#pnl-tareas').waitFor({ timeout: 60_000 });
    await this.esperarCarga();
  }

  /** El `orta_id` con el que quedó abierta la planificación (input `#origen`). */
  async origenActual(): Promise<{ orta_id: string; origen: string } | null> {
    return this.json(this.page.locator('#pnl-tareas #origen'));
  }

  /** `hito_id` real de un hito, leído del onclick de su botón. */
  async idHito(codigo: string): Promise<string> {
    const onclick = (await this.filaHito(codigo).locator('button.code').getAttribute('onclick')) ?? '';
    return /,(\d+)\)/.exec(onclick)?.[1] ?? '';
  }

  async verDetalleHito(codigo: string): Promise<void> {
    await this.filaHito(codigo).locator('.dropdown-toggle').click();
    await this.filaHito(codigo).locator('a', { hasText: 'Ver Detalle' }).click();
    await this.page.locator('#mdl-hito').waitFor({ state: 'visible' });
    await this.esperarCarga();
  }

  // ── Tareas del hito ─────────────────────────────────────────────────────────

  async pestanaPlanificacionTareas(): Promise<void> {
    await this.page.locator('#pnl-tareas a[href="#tab_22"]').click();
  }

  /**
   * Va a la pestaña Calendario **solo si no está activa**. Hacer clic en la pestaña ya activa
   * dispara `copiarTareas()`, que copia la lista (vacía) de "Planificación Tareas" encima y deja
   * la pantalla en "No hay Tareas Planificadas" — es un bug de la vista (TAR-CP-009-09), no algo
   * que el test tenga que provocar en cada paso.
   */
  async pestanaCalendario(): Promise<void> {
    const pestana = this.page.locator('#pnl-tareas a[href="#tab_11"]');
    if ((await pestana.getAttribute('aria-expanded')) === 'true' && (await this.page.locator('#tab_11.active').count())) return;
    await pestana.click();
  }

  /** Clic en la pestaña Calendario aunque ya esté activa (para reproducir TAR-CP-009-09). */
  async clicPestanaCalendarioActiva(): Promise<void> {
    await this.page.locator('#pnl-tareas a[href="#tab_11"]').click();
  }

  /** Filas de tareas planificadas de la pestaña Calendario (la que tiene las acciones). */
  get filasCalendario(): Locator {
    return this.page.locator('#tareas-calendario tbody tr.data-json');
  }

  get filasPlanificadas(): Locator {
    return this.page.locator('#tareas-planificadas tbody tr.data-json');
  }

  filaTarea(nombre: string): Locator {
    return this.filasCalendario.filter({ hasText: nombre }).first();
  }

  async datosTarea(nombre: string): Promise<TareaPlanificada | null> {
    return this.json<TareaPlanificada>(this.filaTarea(nombre));
  }

  /** "Nueva Tarea" libre. Espera la respuesta del guardado. */
  async agregarTareaLibre(nombre: string): Promise<{ status: number; texto: string }> {
    await this.pestanaPlanificacionTareas();
    await this.page.locator('#nueva-tarea').fill(nombre);
    const resp = this.page.waitForResponse((r) => /guardarTareaPlanificada/.test(r.url()), { timeout: 30_000 }).catch(() => null);
    await this.page.locator('#tab_22 button[onclick*="agregarTareaPlanificada"]').click();
    const r = await resp;
    await this.esperarCarga();
    return r ? { status: r.status(), texto: await r.text() } : { status: 0, texto: '' };
  }

  /** + en una tarea del catálogo. */
  async agregarTareaEstandar(nombre: string): Promise<{ status: number; texto: string }> {
    await this.pestanaPlanificacionTareas();
    const resp = this.page.waitForResponse((r) => /guardarTareaPlanificada/.test(r.url()), { timeout: 30_000 });
    await this.page.locator('#tab_22 table#tareas tbody tr', { hasText: nombre }).first().locator('.btnAccionPlantilla').click();
    const r = await resp;
    await this.esperarCarga();
    return { status: r.status(), texto: await r.text() };
  }

  /** Elige una plantilla y "Agregar Todas". Devuelve las respuestas de los guardados. */
  async agregarPlantilla(nombre: string, esperadas: number): Promise<Array<{ status: number; texto: string }>> {
    await this.pestanaPlanificacionTareas();
    await this.page.locator('#tab_22 #plantilla').selectOption({ label: nombre });
    const desde = this.respuestasGuardado.length;
    await this.page.locator('#btn-agregar').click();
    await expect
      .poll(() => this.respuestasGuardado.length - desde, { timeout: 60_000 })
      .toBeGreaterThanOrEqual(esperadas);
    await this.esperarCarga();
    return this.respuestasGuardado.slice(desde);
  }

  /** Recarga la planificación del hito actual, como al volver a elegirlo. */
  async recargarHito(codigo: string): Promise<void> {
    await this.elegirHito(codigo);
  }

  // ── Calendario, hora, responsable, equipos ──────────────────────────────────

  /** 📅 en la tarea → clic en el día → elige la hora → Planificar. */
  async planificar(nombre: string, fecha: Date, hora: string): Promise<{ status: number; texto: string }> {
    await this.pestanaCalendario();
    await this.filaTarea(nombre).locator('.btn-planificar').click();
    await this.irAlMesDe(fecha);
    await this.clickDia(fecha);
    // A veces el clic no dispara el `dateClick` de FullCalendar (pasa contra el DEMO, sin patrón
    // claro). Si no se abrió ni el modal de hora ni un aviso, se invoca el mismo manejador que
    // FullCalendar llama en `dateClick` —`clickCalendario(info)` de la vista—, con la misma fecha.
    const abrio = await this.page.locator('#mdl-hora, .swal2-popup').first().waitFor({ state: 'visible', timeout: 5_000 }).then(() => true, () => false);
    if (!abrio) {
      await this.page.evaluate((f) => {
        const w = window as unknown as { clickCalendario: (i: { date: Date; dateStr: string }) => void };
        w.clickCalendario({ date: new Date(`${f}T00:00:00`), dateStr: f });
      }, iso(fecha));
    }
    await this.page.locator('#mdl-hora').waitFor({ state: 'visible' });
    await this.page.locator('#mdl-hora #hora').fill(hora);
    // El desplegable del timepicker queda abierto y tapa el botón "Planificar".
    await this.page.evaluate(() => document.querySelectorAll<HTMLElement>('.ui-timepicker-container').forEach((e) => (e.style.display = 'none')));
    const resp = this.page.waitForResponse((r) => /guardarPlanificada/.test(r.url()), { timeout: 60_000 });
    await this.page.locator('#mdl-hora button[onclick*="planificarTarea"]').click();
    const r = await resp;
    await this.esperarCarga();
    return { status: r.status(), texto: await r.text() };
  }

  /** Clic en un día sin haber pulsado 📅 antes (para probar fechas pasadas). */
  async clickDia(fecha: Date): Promise<void> {
    await this.irAlMesDe(fecha);
    await this.page.locator(`#calendar td.fc-day[data-date="${iso(fecha)}"]`).first().click({ force: true });
  }

  private async irAlMesDe(fecha: Date): Promise<void> {
    await this.page.evaluate((f) => {
      const w = window as unknown as { calendar?: { gotoDate: (d: string) => void; changeView?: (v: string) => void } };
      w.calendar?.changeView?.('dayGridMonth');
      w.calendar?.gotoDate(f);
    }, iso(fecha));
  }

  /** 👤 en la tarea → elige usuario → confirma. Devuelve el diálogo que haya quedado. */
  async asignar(nombre: string, usernick: string): Promise<void> {
    await this.pestanaCalendario();
    await this.filaTarea(nombre).locator('.btn-asignar').click();
    await this.page.locator('#mdl-usuarios').waitFor({ state: 'visible' });
    await this.page.locator(`#mdl-usuarios table#usuarios tr[id="${usernick}"]`).click();
  }

  /** Usuarios que ofrece el modal de asignación (usernick). */
  async usuariosAsignables(): Promise<string[]> {
    return this.page.locator('#mdl-usuarios table#usuarios tbody tr').evaluateAll((trs) => trs.map((t) => t.id));
  }

  /** Espera el guardado que dispara la confirmación de la asignación. */
  async confirmarAsignacion(): Promise<{ status: number; texto: string }> {
    const resp = this.page.waitForResponse((r) => /guardarPlanificada/.test(r.url()), { timeout: 90_000 });
    await this.page.locator('.swal2-confirm:visible').click();
    const r = await resp;
    await this.esperarCarga();
    await this.cerrarDialogos();
    return { status: r.status(), texto: await r.text() };
  }

  /** ⚙️ Rec.Trabajo: elige sector y equipos y guarda. */
  async asignarEquipos(nombre: string, sector: string, equipos: string[]): Promise<void> {
    await this.pestanaCalendario();
    await this.filaTarea(nombre).locator('button[title="Rec.Trabajo"]').click();
    const modal = this.page.locator('#mdl-pere');
    await modal.waitFor({ state: 'visible' });
    await modal.locator('#pl-sector').selectOption({ label: sector });
    for (const e of equipos) {
      await this.page.evaluate((cod) => {
        const w = window as unknown as { $: (s: string) => { find: (s: string) => { filter: (f: (i: number, o: HTMLOptionElement) => boolean) => { prop: (k: string, v: boolean) => void } }; trigger: (e: string) => void } };
        w.$('#pl-equipo').find('option').filter((_i, o) => o.textContent === cod).prop('selected', true);
        w.$('#pl-equipo').trigger('change');
      }, e);
    }
    const resp = this.page.waitForResponse((r) => /guardarPlanificada/.test(r.url()), { timeout: 60_000 });
    await modal.locator('button[onclick*="guardarEquipos"]').click();
    await resp;
    await this.esperarCarga();
  }

  /** Sectores que ofrece el modal de equipos y, por sector, los equipos que trae su data-json. */
  async sectoresDeEquipos(): Promise<Array<{ sector: string; equipos: string[] }>> {
    return this.page.locator('#mdl-pere #pl-sector option').evaluateAll((os) =>
      os
        .filter((o) => (o as HTMLOptionElement).value !== '0')
        .map((o) => {
          let eq: Array<{ codigo?: string }> = [];
          try {
            eq = JSON.parse(o.getAttribute('data-json') || '[]') || [];
          } catch {
            eq = [];
          }
          return { sector: (o.textContent || '').trim(), equipos: (eq || []).map((e) => e?.codigo ?? '?') };
        }),
    );
  }

  /** 🗑 en la tarea y confirma. */
  async eliminarTarea(nombre: string): Promise<{ status: number; texto: string } | null> {
    await this.pestanaCalendario();
    const resp = this.page.waitForResponse((r) => /eliminarPlanificada/.test(r.url()), { timeout: 30_000 }).catch(() => null);
    await this.filaTarea(nombre).locator('button[title="Eliminar tarea"]').click();
    await this.aceptarDialogo();
    const r = await resp;
    await this.esperarCarga();
    return r ? { status: r.status(), texto: await r.text() } : null;
  }
}

export function iso(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** `DD-MM-YYYY`, el formato de los datepickers del módulo. */
export function ddmmyyyy(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getDate())}-${p(d.getMonth() + 1)}-${d.getFullYear()}`;
}

export function enDias(n: number): Date {
  const d = new Date();
  d.setHours(12, 0, 0, 0);
  d.setDate(d.getDate() + n);
  return d;
}
