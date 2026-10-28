/**
 * Tareas estándar, subtareas y plantillas (TAR-UC-019/020/021).
 *
 * Pantalla `traz-comp-tareasestandar/Tarea`: pestaña Tareas (`#tareas`) y pestaña Plantillas
 * (`#plantillas`). Las acciones de cada fila son íconos con `onclick` (`opcionesTabla()`), no
 * botones con texto, así que se apuntan por la función que llaman.
 *
 * ⚠️ Varias acciones avisan con `alert()` nativo ("Hecho" / "Error") y no con SweetAlert:
 * eliminar tarea, guardar y eliminar plantilla. Playwright descarta solos los diálogos nativos
 * si nadie los escucha, así que esta clase los escucha y los guarda en `alertas`.
 */

import { expect, type Locator, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../../config/apps.ts';
import { ShellTar } from './ShellTar.ts';

export interface DatosTareaEstandar {
  nombre: string;
  descripcion?: string;
  /** `HH:MM`. La máscara del campo es `99:99`. */
  duracion: string;
}

export class TareasEstandarPage extends ShellTar {
  /** Textos de los `alert()` nativos que fue mostrando la pantalla. */
  readonly alertas: string[] = [];

  constructor(page: Page) {
    super(page);
    page.on('dialog', async (d) => {
      this.alertas.push(d.message());
      await d.accept().catch(() => {});
    });
  }

  get tablaTareas(): Locator {
    return this.page.locator('#tab_1 table#tareas');
  }

  get tablaPlantillas(): Locator {
    return this.page.locator('table#plantillas');
  }

  filaTarea(nombre: string): Locator {
    return this.tablaTareas.locator('tbody tr.data-json').filter({ hasText: nombre });
  }

  filaPlantilla(nombre: string): Locator {
    return this.tablaPlantillas.locator('tbody tr.data-json').filter({ hasText: nombre });
  }

  async irATareas(): Promise<void> {
    await this.page.locator('#pnl-tareas a[href="#tab_1"]').click();
  }

  async irAPlantillas(): Promise<void> {
    await this.page.locator('#pnl-tareas a[href="#tab_2"]').click();
  }

  // ── Tareas estándar ─────────────────────────────────────────────────────────

  /** Abre el alta, completa y guarda. No espera el resultado: lo lee el test. */
  async crearTarea(datos: DatosTareaEstandar): Promise<void> {
    await this.irATareas();
    await this.page.locator('#tab_1 button[onclick*="#nuevo"]').click();
    const form = this.page.locator('#nuevo #frm-tarea');
    await form.waitFor({ state: 'visible' });
    await form.locator('#nombre').fill(datos.nombre);
    await form.locator('#descripcion').fill(datos.descripcion ?? '');
    // La máscara 99:99 se completa tecleando, no con fill().
    const dur = form.locator('#duracion');
    await dur.click();
    await dur.press('Control+A');
    await dur.pressSequentially(datos.duracion.replace(':', ''));
    await this.page.locator('#nuevo .btn-accion').click();
  }

  /** Crea la tarea y espera a verla en la lista. */
  async crearTareaOk(datos: DatosTareaEstandar): Promise<void> {
    await this.crearTarea(datos);
    await this.esperarCarga();
    await this.cerrarDialogos();
    await expect(this.filaTarea(datos.nombre)).toHaveCount(1, { timeout: 30_000 });
  }

  /**
   * Alta de tarea estándar por la API de la aplicación (el mismo `Tarea/guardar` que usa el
   * formulario), con un proceso asociado que el formulario no ofrece. Existe porque el selector
   * "Proceso Asociado" no lista `TST001` (H-093): sin esto ninguna tarea llega a la bandeja.
   */
  async crearTareaPorApi(datos: DatosTareaEstandar, procId: string): Promise<string> {
    const base = requerirUrlDeApp('tools').replace(/\/$/, '');
    const r = await this.page.context().request.post(`${base}/index.php/traz-comp-tareasestandar/Tarea/guardar`, {
      form: {
        'data[nombre]': datos.nombre,
        'data[descripcion]': datos.descripcion ?? '',
        'data[duracion]': datos.duracion,
        'data[form_id]': '',
        'data[rece_id]': '',
        'data[proc_id]': procId,
      },
    });
    return r.text();
  }

  /** Valores que ofrece el selector "Proceso Asociado" del alta. */
  async procesosOfrecidos(): Promise<string[]> {
    return this.page.locator('#frm-tarea [name="proc_id"] option').evaluateAll((os) => os.map((o) => (o as HTMLOptionElement).value).filter(Boolean));
  }

  async editarTarea(nombreActual: string, cambios: Partial<DatosTareaEstandar>): Promise<void> {
    await this.filaTarea(nombreActual).locator('[onclick*="editarTarea"]').first().click();
    const form = this.page.locator('#editar #frm-tarea-e');
    await form.waitFor({ state: 'visible' });
    if (cambios.nombre !== undefined) await form.locator('[name="nombre"]').fill(cambios.nombre);
    if (cambios.duracion !== undefined) {
      const dur = form.locator('[name="duracion"]');
      await dur.click();
      await dur.press('Control+A');
      await dur.pressSequentially(cambios.duracion.replace(':', ''));
    }
    await this.page.locator('#editar .btn-accion').click();
  }

  async eliminarTarea(nombre: string): Promise<void> {
    await this.filaTarea(nombre).locator('[onclick*="eliminarTarea"]').first().click();
    await this.aceptarDialogo();
    await this.esperarCarga();
  }

  /** `data-json` de la fila de una tarea estándar (trae `tare_id`). */
  async datosTarea(nombre: string): Promise<Record<string, string> | null> {
    return this.json(this.filaTarea(nombre).first());
  }

  // ── Subtareas ────────────────────────────────────────────────────────────────

  async abrirSubtareas(nombreTarea: string): Promise<void> {
    await this.filaTarea(nombreTarea).locator('[onclick*="agregarSubtareas"]').first().click();
    await this.page.locator('#nueva_subtarea').waitFor({ state: 'visible' });
    await this.esperarCarga();
  }

  get filasSubtareas(): Locator {
    return this.page.locator('#nueva_subtarea table#subtareas tbody tr.data-json');
  }

  async agregarSubtarea(nombre: string, duracion = '00:30', descripcion = ''): Promise<void> {
    const form = this.page.locator('#frm-subtarea');
    await form.locator('[name="nombre"]').fill(nombre);
    await form.locator('[name="duracion"]').fill(duracion);
    await form.locator('[name="descripcion"]').fill(descripcion || nombre);
    await this.page.locator('#nueva_subtarea button[onclick*="guardarSubtarea"]').click();
  }

  async eliminarSubtarea(indice: number): Promise<void> {
    await this.filasSubtareas.nth(indice).locator('[onclick*="eliminarSubtarea"]').click();
    const d = await this.dialogoSiAparece(5_000);
    if (d && (await this.page.locator('.swal2-cancel:visible').count())) await this.aceptarDialogo();
    await this.esperarCarga();
  }

  async cerrarSubtareas(): Promise<void> {
    await this.cerrarDialogos();
    await this.page.locator('#nueva_subtarea [data-dismiss="modal"]').first().click();
    await expect(this.page.locator('#nueva_subtarea')).toBeHidden();
  }

  // ── Plantillas ───────────────────────────────────────────────────────────────

  async crearPlantilla(nombre: string): Promise<void> {
    await this.irAPlantillas();
    await this.page.locator('table#plantillas thead button[onclick*="#nueva_plantilla"]').click();
    const modal = this.page.locator('#nueva_plantilla');
    await modal.waitFor({ state: 'visible' });
    await modal.locator('#frm-plantilla [name="nombre"]').fill(nombre);
    await modal.locator('button[onclick*="guardarPlantilla"]').click();
    await this.esperarCarga();
  }

  /** Abre la edición de una plantilla y devuelve lo que muestra el campo Nombre del modal. */
  async abrirEdicionPlantilla(nombre: string): Promise<string> {
    await this.filaPlantilla(nombre).locator('[onclick*="editarPlantilla"]').first().click();
    const modal = this.page.locator('#nueva_plantilla');
    await modal.waitFor({ state: 'visible' });
    return modal.locator('#frm-plantilla [name="nombre"]').inputValue();
  }

  /** Valor del campo Nombre del formulario de alta de tarea (para detectar escrituras cruzadas). */
  async nombreEnFormularioDeTarea(): Promise<string> {
    return this.page.locator('#frm-tarea [name="nombre"]').inputValue();
  }

  async guardarPlantillaAbierta(nuevoNombre: string): Promise<void> {
    const modal = this.page.locator('#nueva_plantilla');
    await modal.locator('#frm-plantilla [name="nombre"]').fill(nuevoNombre);
    await modal.locator('button[onclick*="guardarPlantilla"]').click();
    await this.esperarCarga();
  }

  async verTareasDePlantilla(nombre: string): Promise<void> {
    await this.filaPlantilla(nombre).locator('[onclick*="getTareasPlantilla"]').first().click();
    await this.page.locator('#tareas_asociadas').waitFor({ state: 'visible' });
    await this.esperarCarga();
  }

  get tareasDePlantilla(): Locator {
    return this.page.locator('#tareas_asociadas table#tareas_plantillas tbody tr.data-json');
  }

  /** Textos que ofrece el selector "Asociar Tarea" de la plantilla abierta. */
  async opcionesParaAsociar(): Promise<string[]> {
    return this.page.locator('#tareas_asociadas select#tareas option').allTextContents();
  }

  async asociarTarea(nombreTarea: string): Promise<void> {
    const select = this.page.locator('#tareas_asociadas select#tareas');
    const valor = await select.locator('option', { hasText: nombreTarea }).first().getAttribute('value');
    await select.selectOption(valor ?? '');
    await this.page.locator('#tareas_asociadas button[onclick*="asociarTareaPlantilla"]').click();
    await this.esperarCarga();
    await this.cerrarDialogos();
  }

  async desasociarTarea(nombreTarea: string): Promise<void> {
    await this.tareasDePlantilla.filter({ hasText: nombreTarea }).locator('[onclick*="eliminarTareaPlantilla"]').click();
    await this.aceptarDialogo();
    await this.esperarCarga();
    await this.cerrarDialogos();
  }

  async cerrarTareasDePlantilla(): Promise<void> {
    await this.page.locator('#tareas_asociadas [data-dismiss="modal"]').first().click();
  }

  async eliminarPlantilla(nombre: string): Promise<void> {
    await this.filaPlantilla(nombre).locator('[onclick*="eliminarPlantilla"]').first().click();
    await this.aceptarDialogo();
    await this.esperarCarga();
  }
}
