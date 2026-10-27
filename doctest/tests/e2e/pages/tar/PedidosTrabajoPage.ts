/**
 * Listado y alta de Pedidos de Trabajo (TAR-UC-001 a 004).
 *
 * Pantalla `traz-comp-bpm/Pedidotrabajo?proccessname=...`: DataTable `#tbl-pedidos` paginado
 * **contra el servidor** (`Pedidotrabajo/paginado`), botón `#btn-agregarPedido` que abre el modal
 * `#mdl-peta` con el formulario `#frm-PedidoTrabajo`, y acciones por fila con íconos (tacho,
 * impresora, lupa).
 *
 * La respuesta JSON del paginado se guarda en `ultimoPaginado`: es lo que permite verificar los
 * contadores (`recordsTotal`/`recordsFiltered`) sin acceso a la base.
 */

import { expect, type Locator, type Page, type Response } from '@playwright/test';

import { ShellTar } from './ShellTar.ts';

export interface DatosPedido {
  codigo: string;
  objetivo?: string;
  /** Texto visible de la unidad (Dias, Meses, Años). */
  unidad?: string;
  cliente: string;
  tipo: string;
  descripcion: string;
  /** `YYYY-MM-DD`. */
  fechaEntrega?: string;
}

export interface Paginado {
  recordsTotal: number;
  recordsFiltered: number;
  data?: Array<Record<string, unknown>>;
  [k: string]: unknown;
}

export class PedidosTrabajoPage extends ShellTar {
  ultimoPaginado: Paginado | null = null;
  /** Respuestas crudas de `guardarPedidoTrabajo` (para ver si el JSON es válido). */
  readonly respuestasAlta: string[] = [];

  constructor(page: Page) {
    super(page);
    page.on('response', (r) => void this.capturar(r));
  }

  private async capturar(r: Response): Promise<void> {
    const url = r.url();
    try {
      if (/Pedidotrabajo\/paginado/.test(url)) this.ultimoPaginado = JSON.parse(await r.text());
      if (/Pedidotrabajo\/guardarPedidoTrabajo/.test(url)) this.respuestasAlta.push(await r.text());
    } catch {
      if (/paginado/.test(url)) this.ultimoPaginado = { recordsTotal: -1, recordsFiltered: -1, crudo: await r.text().catch(() => '') };
    }
  }

  get tabla(): Locator {
    return this.page.locator('table#tbl-pedidos');
  }

  get filas(): Locator {
    return this.tabla.locator('tbody tr').filter({ has: this.page.locator('td >> nth=1') });
  }

  fila(codigo: string): Locator {
    return this.tabla.locator('tbody tr', { hasText: codigo });
  }

  async abrirListado(testInfo?: Parameters<ShellTar['abrir']>[1]): Promise<void> {
    await this.abrir('pedidos', testInfo);
    await this.tabla.waitFor();
    await this.esperarCarga();
  }

  /** Espera la próxima respuesta del paginado y la devuelve. */
  async esperarPaginado(accion: () => Promise<unknown>): Promise<Paginado> {
    const resp = this.page.waitForResponse((r) => /Pedidotrabajo\/paginado/.test(r.url()), { timeout: 60_000 });
    await accion();
    const r = await resp;
    const texto = await r.text();
    try {
      this.ultimoPaginado = JSON.parse(texto);
    } catch {
      this.ultimoPaginado = { recordsTotal: -1, recordsFiltered: -1, crudo: texto };
    }
    await this.esperarCarga();
    return this.ultimoPaginado!;
  }

  async buscar(texto: string): Promise<Paginado> {
    return this.esperarPaginado(() => this.page.locator('#tbl-pedidos_filter input').fill(texto));
  }

  async mostrarTerminados(): Promise<Paginado> {
    // El checkbox está dentro de un toggle con estilo y queda fuera del viewport: se dispara su onclick.
    return this.esperarPaginado(() => this.page.locator('#pedidos_finalizados').evaluate((c: HTMLInputElement) => c.click()));
  }

  // ── Alta ────────────────────────────────────────────────────────────────────

  get form(): Locator {
    return this.page.locator('#frm-PedidoTrabajo');
  }

  async abrirAlta(): Promise<void> {
    await this.page.locator('#btn-agregarPedido').click();
    await this.form.waitFor({ state: 'visible' });
  }

  /** Completa el alta. Los select2 se manejan por el `<select>` real y se dispara `change`. */
  async completarAlta(d: DatosPedido): Promise<void> {
    await this.form.locator('#cod_proyecto').fill(d.codigo);
    if (d.objetivo !== undefined) await this.form.locator('#objetivo').fill(d.objetivo);
    if (d.unidad) await this.form.locator('#unidad_medida_tiempo').selectOption({ label: d.unidad });
    await this.elegir('#clie_id', d.cliente);
    if (d.fechaEntrega) await this.form.locator('#fec_entrega').fill(d.fechaEntrega);
    await this.elegir('#tipt_id', d.tipo);
    await this.form.locator('#descripcion').fill(d.descripcion);
  }

  private async elegir(selector: string, etiqueta: string): Promise<void> {
    if (!etiqueta) return;
    await this.form.locator(selector).selectOption({ label: etiqueta }, { force: true });
    await this.form.locator(selector).dispatchEvent('change');
  }

  async guardarAlta(): Promise<void> {
    await this.page.locator('#btn-accion.btn-guardar').click();
  }

  /** Alta completa por la pantalla. Devuelve el texto de la respuesta del servidor. */
  async crearPedido(d: DatosPedido): Promise<string> {
    await this.abrirAlta();
    await this.completarAlta(d);
    const resp = this.page.waitForResponse((r) => /guardarPedidoTrabajo/.test(r.url()), { timeout: 90_000 });
    await this.guardarAlta();
    const texto = await (await resp).text();
    await this.esperarCarga();
    return texto;
  }

  // ── Fila: eliminar, ver ─────────────────────────────────────────────────────

  async datosFila(codigo: string): Promise<Record<string, string> | null> {
    return this.fila(codigo).first().evaluate((tr) => {
      const w = window as unknown as { $: (e: Element) => { closest: (s: string) => { DataTable: () => { row: (e: Element) => { data: () => Record<string, string> } } } } };
      try {
        return w.$(tr).closest('table').DataTable().row(tr).data();
      } catch {
        return null;
      }
    });
  }

  async eliminar(codigo: string, confirmar = true): Promise<void> {
    await this.fila(codigo).first().locator('i[title="Eliminar"]').click();
    await this.dialogo();
    if (confirmar) await this.aceptarDialogo();
    else await this.cancelarDialogo();
  }

  async verDetalle(codigo: string): Promise<void> {
    await this.fila(codigo).first().locator('i[title="Ver Pedido"]').click();
    await this.page.locator('#mdl-vista').waitFor({ state: 'visible', timeout: 60_000 });
    await this.esperarCarga();
  }

  get detalle(): Locator {
    return this.page.locator('#mdl-vista');
  }

  async pestanaDetalle(nombre: RegExp): Promise<void> {
    await this.detalle.locator('a[data-toggle="tab"]', { hasText: nombre }).first().click();
    await this.esperarCarga();
  }
}

/** Código de pedido de 4 a 10 caracteres, único por corrida. */
export function codigoPedido(sufijo: string, letra = 'P'): string {
  return `${letra}${sufijo}`.slice(0, 10);
}

export async function sinErroresDeJson(respuesta: string): Promise<boolean> {
  try {
    JSON.parse(respuesta);
    return true;
  } catch {
    return false;
  }
}

export { expect };
