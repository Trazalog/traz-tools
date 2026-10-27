/**
 * Lo común a todas las pantallas de Tareas (TAR): abrirlas desde el shell de Tools, esperar
 * el "Cargando ..." y leer los diálogos de SweetAlert con que el módulo avisa todo.
 *
 * Las vistas de TAR son **fragmentos** que el menú inyecta con `linkTo(ruta)` dentro del shell
 * (mismo mecanismo que Almacenes, ver `pages/alm/AlmacenesPage.ts`): navegar derecho a la URL
 * trae el HTML sin jQuery y nada funciona. Por eso todas se abren desde el shell.
 *
 * Los mensajes salen de `lib/props/notificaciones.js`: `hecho()`, `error()`, `notificar()` y
 * `conf()` son todos `Swal.fire(...)`, así que hay un solo lugar donde leerlos.
 *
 * Varias filas guardan su estado en un atributo `data-json` (la tarea planificada, el pedido de
 * la lista de planificación, el usuario asignable). Leerlo es la forma de saber el id real de
 * un registro sin acceso a la base del DEMO, que no es alcanzable desde la VPN.
 */

import { expect, type Locator, type Page, type TestInfo } from '@playwright/test';
import { mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { requerirUrlDeApp } from '../../config/apps.ts';

/** Rutas de las pantallas, tal como las usa el menú (`linkTo(...)`). */
export const RUTAS_TAR = {
  pedidos: 'traz-comp-bpm/Pedidotrabajo?proccessname=PROCESO-STANDAR',
  planificacion: 'traz-comp-bpm/Pedidotrabajo/dash',
  tareasEstandar: 'traz-comp-tareasestandar/Tarea',
  indicadores: 'traz-comp-tareasestandar/Reportes/indicadores',
  bandeja: 'traz-comp-bpm/Proceso',
} as const;

export type PantallaTar = keyof typeof RUTAS_TAR;

/** Mensaje de un diálogo de SweetAlert. */
export interface Dialogo {
  titulo: string;
  texto: string;
}

export class ShellTar {
  constructor(readonly page: Page) {}

  /** Espera a que el shell de Tools tenga `linkTo` (jQuery y los props ya cargados). */
  async enElShell(): Promise<void> {
    const listo = () =>
      this.page.evaluate(() => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function');
    if (!(await listo().catch(() => false))) {
      await this.page.goto(requerirUrlDeApp('tools'), { waitUntil: 'domcontentloaded' });
    }
    await this.page.waitForFunction(
      () => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function',
      undefined,
      { timeout: 60_000 },
    );
  }

  /**
   * Abre una pantalla de TAR **por el menú** cuando el usuario lo tiene.
   *
   * Si el usuario no tiene el ítem de menú (hoy, en las empresas de test, nadie lo tiene: los
   * menús de TAR dependen del rol asignado en `seg.menues`), la abre con el mismo `linkTo()` que
   * dispararía el menú y lo deja anotado en el reporte del test. El test que verifica que el
   * planificador **ve** el menú es aparte (`TAR-menu`), para que la falta no se esconda.
   */
  async abrir(pantalla: PantallaTar, testInfo?: TestInfo): Promise<void> {
    await this.enElShell();
    await this.cerrarModales();
    const ruta = RUTAS_TAR[pantalla];
    const base = ruta.split('?')[0];
    // Sin distinguir mayúsculas: el menú usa `.../tarea` y la ruta del controller es `.../Tarea`.
    const item = this.page.locator(`.sidebar-menu a[onclick*="${base}" i]`).first();
    if (await item.count()) {
      // El menú puede estar colapsado: el click va igual por el onclick del <a>.
      await item.evaluate((a: HTMLElement) => a.click());
    } else {
      testInfo?.annotations.push({
        type: 'menu-ausente',
        description: `El usuario no tiene el ítem de menú de "${pantalla}": se abrió con linkTo('${ruta}')`,
      });
      await this.page.evaluate((r) => (window as unknown as { linkTo: (x: string) => void }).linkTo(r), ruta);
    }
    await this.esperarCarga();
  }

  /**
   * Cierra modales de Bootstrap y diálogos que hayan quedado abiertos. `linkTo()` reemplaza el
   * contenido pero no toca el `<body>`, así que un modal abierto deja su fondo tapando la
   * pantalla siguiente.
   */
  async cerrarModales(): Promise<void> {
    await this.cerrarDialogos();
    await this.page.evaluate(() => {
      const w = window as unknown as { $?: (s: string) => { modal: (a: string) => void; remove: () => void; removeClass: (c: string) => void } };
      if (!w.$) return;
      w.$('.modal').modal('hide');
      w.$('.modal-backdrop').remove();
      w.$('body').removeClass('modal-open');
    });
  }

  /** True si el usuario tiene el ítem de menú de la pantalla. */
  async tieneMenu(pantalla: PantallaTar): Promise<boolean> {
    await this.enElShell();
    const base = RUTAS_TAR[pantalla].split('?')[0];
    return (await this.page.locator(`.sidebar-menu a[onclick*="${base}" i]`).count()) > 0;
  }

  /** Espera a que se vaya el "Cargando ..." global (`wo()`/`wc()`) y los overlays de caja. */
  async esperarCarga(timeout = 60_000): Promise<void> {
    await this.page.waitForLoadState('networkidle', { timeout }).catch(() => {});
    await expect(this.page.locator('#waiting')).toBeHidden({ timeout });
    await expect(this.page.locator('.box .overlay:visible, .wbox:visible')).toHaveCount(0, { timeout });
  }

  // ── SweetAlert ──────────────────────────────────────────────────────────────

  get swal(): Locator {
    return this.page.locator('.swal2-popup:visible');
  }

  /** Espera un diálogo y devuelve título y texto. */
  async dialogo(timeout = 30_000): Promise<Dialogo> {
    await this.swal.first().waitFor({ state: 'visible', timeout });
    // `notificar('', ...)` deja el título vacío y SweetAlert lo oculta: se lee sin exigir visibilidad.
    const popup = this.swal.first();
    const titulo = ((await popup.locator('.swal2-title').first().textContent().catch(() => '')) ?? '').trim();
    const texto = (
      (await popup.locator('#swal2-content, .swal2-content, .swal2-html-container').first().textContent().catch(() => '')) ?? ''
    ).trim();
    return { titulo, texto };
  }

  /** Devuelve el diálogo visible si aparece dentro del plazo, o null. */
  async dialogoSiAparece(timeout = 8_000): Promise<Dialogo | null> {
    try {
      return await this.dialogo(timeout);
    } catch {
      return null;
    }
  }

  /** Acepta el diálogo visible (botón de confirmación) y espera que se cierre. */
  async aceptarDialogo(): Promise<void> {
    await this.page.locator('.swal2-confirm:visible').first().click();
    // Muchas confirmaciones encadenan otro diálogo ("Hecho!"): no se exige que no quede ninguno.
    await this.page.waitForTimeout(500);
  }

  /** Cancela el diálogo visible. */
  async cancelarDialogo(): Promise<void> {
    await this.page.locator('.swal2-cancel:visible').first().click();
  }

  /** Cierra cualquier diálogo que haya quedado abierto (los de éxito no se cierran solos). */
  async cerrarDialogos(): Promise<void> {
    for (let i = 0; i < 3 && (await this.swal.count()) > 0; i++) {
      await this.page.locator('.swal2-confirm:visible').first().click().catch(() => {});
      await this.page.waitForTimeout(300);
    }
  }

  // ── data-json ────────────────────────────────────────────────────────────────

  /** Lee y parsea el `data-json` de un elemento (o del ancestro `.data-json` más cercano). */
  async json<T = Record<string, unknown>>(elemento: Locator): Promise<T | null> {
    return elemento.evaluate((e) => {
      const el = e.classList.contains('data-json') || e.hasAttribute('data-json') ? e : e.closest('[data-json]');
      const crudo = el?.getAttribute('data-json');
      if (!crudo) return null;
      try {
        return JSON.parse(crudo);
      } catch {
        return { __json_invalido__: crudo };
      }
    }) as Promise<T | null>;
  }
}

/**
 * Sufijo corto y único por corrida para los datos que crean los tests (README de seeds, regla 3).
 * Base 36 del timestamp: 8 caracteres hasta el año 2059.
 */
export function sufijoUnico(): string {
  return Date.now().toString(36).toUpperCase();
}

/**
 * Sufijo **de la corrida**: el mismo para todos los specs de TAR de una corrida, aunque Playwright
 * reinicie el worker después de un test fallido (lo que vuelve a cargar los módulos). Así un test
 * que falla no deja huérfanos a los que siguen. Se fija con `DOCTEST_TAR_CORRIDA` o se guarda en
 * `.auth/` y se reutiliza durante 3 horas.
 */
export function sufijoDeCorrida(): string {
  const fijo = process.env.DOCTEST_TAR_CORRIDA?.trim();
  if (fijo) return fijo;
  const archivo = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '.auth', 'tar-corrida.txt');
  try {
    if (Date.now() - statSync(archivo).mtimeMs < 3 * 3600 * 1000) return readFileSync(archivo, 'utf8').trim();
  } catch {
    // no existe todavía
  }
  const nuevo = sufijoUnico();
  mkdirSync(dirname(archivo), { recursive: true });
  writeFileSync(archivo, nuevo);
  return nuevo;
}

/** Mañana a las `hora` en formato que entiende la pantalla (DD-MM-YYYY) y como Date. */
export function manana(): { dia: number; mes: number; anio: number } {
  const d = new Date(Date.now() + 24 * 3600 * 1000);
  return { dia: d.getDate(), mes: d.getMonth() + 1, anio: d.getFullYear() };
}
