/**
 * Lo común a las pantallas de Mantenimiento (MAN) dentro de Tools.
 *
 * Las pantallas de `traz-tools-man` son **fragmentos** que el menú inyecta con `linkTo(ruta)` en el
 * shell de Tools (igual que Almacenes y Tareas): navegar derecho a la URL trae el HTML sin jQuery.
 * Por eso se abren desde el shell, por su ítem de menú si el usuario lo tiene y, si no, con el mismo
 * `linkTo()` que dispararía el menú (queda anotado en el reporte).
 *
 * Las rutas son las de `seg.menues` (doc/migracion/MENU-MAN.md del repo tools). Cada una lleva los
 * permisos en la URL (`index/Add-Edit-Del`, decisión E3): sin ellos la pantalla queda de solo lectura.
 *
 * Las pantallas portadas de asset avisan con `alert()`/`confirm()` nativos y con SweetAlert; los dos
 * se registran en `avisos` para poder verificarlos.
 */

import { expect, type Locator, type Page, type TestInfo } from '@playwright/test';

import { requerirUrlDeApp } from '../../config/apps.ts';

export const RUTAS_MAN = {
  equipos: 'traz-tools-man/Equipo/index/Add-Edit-Del-Lectura',
  bandejaMan: 'traz-tools-man/Tarea/index/Add-Edit-Del',
  componentes: 'traz-tools-man/Componente/asigna/Add-Edit-Del',
  solicitudes: 'traz-tools-man/Sservicio/index/Add-Edit-Del',
  informes: 'traz-tools-man/Ordenservicio/index/Add-Edit-Del',
  preventivo: 'traz-tools-man/Preventivo/index/Add-Edit-Del',
  parametrizar: 'traz-tools-man/Parametro/index/Add-Edit-Del',
  backlog: 'traz-tools-man/Backlog/index/Add-Edit-Del',
  predictivo: 'traz-tools-man/Predictivo/index/Add-Edit-Del',
  ordenes: 'traz-tools-man/Otrabajo/listOrden/Add-Edit-Del',
  plan: 'traz-tools-man/Calendario/indexot/Add-Edit-Del',
  lecturas: 'traz-tools-man/Lectura/index/Add-Edit-Del',
  administrarOrdenes: 'traz-tools-man/Envio/index/Add-Edit-Del',
  repEquipo: 'traz-tools-man/Kpi/index/Add-Edit-Del',
  repInformes: 'traz-tools-man/Reporte/index/Add-Edit-Del',
  repOrdenes: 'traz-tools-man/Reporteorden/index/Add-Edit-Del',
  abmArea: 'traz-tools-man/Area/index/Add-Edit-Del',
  abmProceso: 'traz-tools-man/Proceso/index/Add-Edit-Del',
  abmGrupo: 'traz-tools-man/Grupo/index/Add-Edit-Del',
  abmSector: 'traz-tools-man/Sector/index/Add-Edit-Del',
  abmContratista: 'traz-tools-man/Contratista/index/Add-Edit-Del',
  abmTareaEstandar: 'traz-tools-man/Tareaestandar/index/Add-Edit-Del',
  abmParametros: 'traz-tools-man/Altparametro/index/Add-Edit-Del',
  abmFamilia: 'traz-tools-man/Family/index/Add-Edit-Del',
  abmMarca: 'traz-tools-man/Marca/index/Add-Edit-Del',
  abmClientes: 'traz-tools-man/Cliente/index/Add-Edit-Del',
  abmCriticidad: 'traz-tools-man/Criticidad/index/Add-Edit-Del',
  abmSucursales: 'traz-tools-man/Sucursal/index/Add-Edit-Del',
  abmSistemas: 'traz-tools-man/SistemaABM/index/Add-Edit-Del',
  /** "Mis Tareas", la bandeja de Tools, donde llegan las tareas del proceso de Mantenimiento (MIG-7). */
  bandeja: 'traz-comp-bpm/Proceso2',
} as const;

export type PantallaMan = keyof typeof RUTAS_MAN;

export class ShellMan {
  /** Mensajes de alert()/confirm() nativos y de SweetAlert que mostró la pantalla. */
  readonly avisos: string[] = [];
  /** Errores de JavaScript de la página (un error de consola rompe pantallas enteras). */
  readonly erroresJs: string[] = [];

  constructor(readonly page: Page) {
    page.on('dialog', (d) => {
      this.avisos.push(d.message());
    });
    page.on('pageerror', (e) => {
      // El aviso de Firebase sale del shell en cualquier navegador sin soporte de notificaciones.
      if (!/Firebase|messaging\//i.test(e.message)) this.erroresJs.push(e.message);
    });
  }

  async enElShell(): Promise<void> {
    const listo = () =>
      this.page.evaluate(() => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function');
    if (!(await listo().catch(() => false))) {
      await this.page.goto(requerirUrlDeApp('tools'), { waitUntil: 'domcontentloaded' });
    }
    await this.page.waitForFunction(
      () => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function',
      undefined,
      { timeout: 90_000 },
    );
  }

  /** Abre una pantalla por el menú (o con `linkTo` si el usuario no tiene el ítem). */
  async abrir(pantalla: PantallaMan, testInfo?: TestInfo): Promise<void> {
    await this.abrirRuta(RUTAS_MAN[pantalla], testInfo);
  }

  async abrirRuta(ruta: string, testInfo?: TestInfo): Promise<void> {
    await this.enElShell();
    await this.cerrarModales();
    // Solo cuentan los errores de la pantalla: el shell de Tools tira los suyos al cargar.
    this.erroresJs.length = 0;
    const base = ruta.split('/').slice(0, 2).join('/');
    // La ruta tiene que coincidir entera: `Equipo/index` no es el ítem `Equipo/index/Add-Edit-Del`.
    const hecho = await this.page.evaluate((r) => {
      const esc = r.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const re = new RegExp(`${esc}['"\\)]`, 'i');
      const a = Array.from(document.querySelectorAll<HTMLElement>('.sidebar-menu a[onclick]')).find((x) =>
        re.test(x.getAttribute('onclick') ?? ''),
      );
      a?.click();
      return !!a;
    }, ruta);
    if (!hecho) {
      testInfo?.annotations.push({
        type: 'menu-ausente',
        description: `El usuario no tiene el ítem de menú de ${base}: se abrió con linkTo('${ruta}')`,
      });
      await this.page.evaluate((r) => (window as unknown as { linkTo: (x: string) => void }).linkTo(r), ruta);
    }
    await this.esperarCarga();
  }

  /** True si el usuario ve el ítem de menú de la pantalla. */
  async tieneMenu(pantalla: PantallaMan): Promise<boolean> {
    await this.enElShell();
    return (await this.page.locator(`.sidebar-menu a[onclick*="${RUTAS_MAN[pantalla]}" i]`).count()) > 0;
  }

  async cerrarModales(): Promise<void> {
    await this.page.evaluate(() => {
      const w = window as unknown as { $?: (s: string) => { modal: (a: string) => void; remove: () => void; removeClass: (c: string) => void } };
      if (!w.$) return;
      w.$('.modal').modal('hide');
      w.$('.modal-backdrop').remove();
      w.$('body').removeClass('modal-open');
    });
    for (let i = 0; i < 3 && (await this.page.locator('.swal2-popup:visible').count()) > 0; i++) {
      await this.page.locator('.swal2-confirm:visible').first().click().catch(() => {});
      await this.page.waitForTimeout(300);
    }
  }

  /** Espera a que se vaya el "Cargando ..." de tools y de las pantallas de asset (WaitingOpen). */
  async esperarCarga(timeout = 90_000, conVelos = true): Promise<void> {
    await this.page.waitForLoadState('networkidle', { timeout }).catch(() => {});
    await expect(this.page.locator('#waiting')).toBeHidden({ timeout });
    // En la bandeja, la tarea sin tomar queda con un velo (`#view > .overlay`) a propósito: ahí no se espera.
    if (conVelos) await expect(this.page.locator('.box .overlay:visible, .wbox:visible')).toHaveCount(0, { timeout });
  }

  /** El contenido de la pantalla (sin el menú). */
  get contenido(): Locator {
    return this.page.locator('#content, .content-wrapper').first();
  }

  async textoContenido(): Promise<string> {
    return ((await this.contenido.innerText()) ?? '').replace(/\s+/g, ' ');
  }

  /** Encabezados de la primera grilla visible del contenido, como un solo texto. */
  async encabezados(timeout = 60_000): Promise<string> {
    const th = this.contenido.locator('table thead th');
    await expect(th.first()).toBeAttached({ timeout });
    return (await th.allTextContents()).map((t) => t.trim()).join(' | ');
  }

  /** Cantidad de filas de datos de la grilla principal (sin la fila "sin datos" de DataTables). */
  async filas(tabla = 'table'): Promise<number> {
    return this.contenido.locator(`${tabla} tbody tr:not(:has(td.dataTables_empty))`).count();
  }

  /** Llama a un endpoint del módulo con la sesión de la página y devuelve el JSON (o el texto). */
  async pedir(ruta: string, datos?: Record<string, unknown>): Promise<unknown> {
    // Misma dirección que usan las pantallas (base_url(MAN), sin index.php).
    const url = `${requerirUrlDeApp('tools').replace(/\/$/, '')}/${ruta}`;
    const r = datos
      ? await this.page.request.post(url, { form: aplanar(datos), timeout: 120_000 })
      : await this.page.request.get(url, { timeout: 120_000 });
    const texto = await r.text();
    try {
      return JSON.parse(texto);
    } catch {
      return texto;
    }
  }
}

/** Convierte un objeto anidado al formato de formulario de PHP (`a[b][c]=x`). */
function aplanar(obj: Record<string, unknown>, prefijo = ''): Record<string, string> {
  const salida: Record<string, string> = {};
  for (const [k, v] of Object.entries(obj)) {
    const clave = prefijo ? `${prefijo}[${k}]` : k;
    if (v !== null && typeof v === 'object') Object.assign(salida, aplanar(v as Record<string, unknown>, clave));
    else salida[clave] = String(v ?? '');
  }
  return salida;
}
