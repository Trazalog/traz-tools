/**
 * Bandeja de entrada y ejecución de una tarea planificada (TAR-UC-016 a 018).
 *
 * La bandeja (`traz-comp-bpm/Proceso`) lista una fila `tr.item` por tarea de Bonita, con
 * `id = taskId` y las etiquetas que arma el model del proceso (`Tsttareas::map()` para las tareas
 * planificadas: Estado, Origen, Id Ped.Trabajo, Nro Pedido...). El doble clic abre el detalle con
 * `linkTo('traz-comp-bpm/Proceso/detalleTarea/<taskId>')`, que es lo que hace este page object.
 *
 * El detalle (`notificacion_estandar.php` + `tarea_generica.php`) tiene "Tomar tarea",
 * "Soltar tarea", "Inicializar tarea" (`#btnIniciar_tarea`), el checklist de subtareas
 * (`input[name="terminado[]"]`) y "Hecho" (`#btnHecho`).
 */

import { expect, type Locator, type Page, type Response } from '@playwright/test';

import { ShellTar } from './ShellTar.ts';

export class BandejaTareaPage extends ShellTar {
  readonly respuestas: Array<{ url: string; status: number; texto: string }> = [];

  constructor(page: Page) {
    super(page);
    page.on('response', (r) => void this.capturar(r));
  }

  private async capturar(r: Response): Promise<void> {
    if (/iniciarTareaPlanificada|terminarTareaPlanificada|Proceso\/(cerrarTarea|tomarTarea|soltarTarea)/.test(r.url())) {
      this.respuestas.push({ url: r.url(), status: r.status(), texto: await r.text().catch(() => '') });
    }
  }

  async abrirBandeja(testInfo?: Parameters<ShellTar['abrir']>[1]): Promise<void> {
    await this.abrir('bandeja', testInfo);
    await this.page.locator('table#tareas').waitFor({ timeout: 90_000 });
    await this.esperarCarga(90_000);
  }

  item(nombreTarea: string): Locator {
    return this.page.locator('table#tareas tbody tr.item').filter({ hasText: nombreTarea });
  }

  async buscar(texto: string): Promise<void> {
    const filtro = this.page.locator('#tareas_filter input');
    if (await filtro.count()) await filtro.fill(texto);
  }

  /** Etiquetas (`p.label`) de la fila de una tarea. */
  async etiquetas(nombreTarea: string): Promise<string[]> {
    return (await this.item(nombreTarea).first().locator('p.label').allInnerTexts()).map((t) => t.trim());
  }

  async abrirTarea(nombreTarea: string): Promise<void> {
    const taskId = await this.item(nombreTarea).first().getAttribute('id');
    await this.page.evaluate((id) => (window as unknown as { linkTo: (x: string) => void }).linkTo(`traz-comp-bpm/Proceso/detalleTarea/${id}`), taskId);
    await this.page.locator('#view, #btnHecho').first().waitFor({ timeout: 90_000 });
    await this.esperarCarga(90_000);
  }

  get tomar(): Locator {
    return this.page.locator('.btn-tomar');
  }

  get soltar(): Locator {
    return this.page.locator('.btn-soltar');
  }

  get iniciar(): Locator {
    return this.page.locator('#btnIniciar_tarea');
  }

  get hecho(): Locator {
    return this.page.locator('#btnHecho');
  }

  get subtareas(): Locator {
    return this.page.locator('input[name="terminado[]"]');
  }

  /** Texto de la cabecera del detalle ("Detalles Tarea"). */
  async cabecera(): Promise<string> {
    return (await this.page.locator('#content').innerText()).replace(/\s+/g, ' ');
  }

  async tildarSubtareas(cuantas?: number): Promise<void> {
    const total = await this.subtareas.count();
    for (let i = 0; i < (cuantas ?? total); i++) {
      // Son iCheck: el input real está oculto, se marca y se avisa el cambio.
      await this.subtareas.nth(i).evaluate((c: HTMLInputElement) => {
        c.checked = true;
        c.dispatchEvent(new Event('change', { bubbles: true }));
      });
    }
  }

  async pulsarHecho(): Promise<void> {
    await expect(this.hecho).toBeEnabled();
    await this.hecho.click();
  }
}
