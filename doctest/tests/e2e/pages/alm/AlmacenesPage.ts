/**
 * Acceso a las pantallas de Almacenes.
 *
 * Almacenes es un módulo dentro de Trazalog Tools (`ALM = 'traz-comp-almacenes/'` en
 * `constants.php`), así que usa la sesión de Tools —la de `fixtures/auth.ts`— y no una propia:
 * a diferencia de AssetPlanner, acá no hay un padrón aparte.
 *
 * Las grillas del módulo las arma DataTables después de la carga y varias se paginan **contra el
 * servidor**, así que hay que esperar al encabezado y no al `load` de la página.
 */

import { expect, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../../config/apps.ts';

/** Las pantallas que hoy tienen caso relevado, por el controlador que las dibuja. */
export const PANTALLAS = {
  articulos: 'Articulo',
  stock: 'Lote/indexStock',
  ajustes: 'Ajustestock',
  movimientosInternos: 'Movimientointerno',
  historico: 'Reportes/historicoArticulos',
  pedidos: 'Notapedido',
} as const;

export type Pantalla = keyof typeof PANTALLAS;

/** Ruta del módulo, tal como la usa el menú de Tools. */
export function rutaAlm(pantalla: Pantalla): string {
  return `traz-comp-almacenes/${PANTALLAS[pantalla]}`;
}

/** URL directa. **Solo para diagnóstico**: ver `abrir()` para saber por qué no se usa. */
export function urlAlm(pantalla: Pantalla): string {
  return `${requerirUrlDeApp('tools').replace(/\/$/, '')}/${rutaAlm(pantalla)}`;
}

export class AlmacenesPage {
  constructor(private readonly page: Page) {}

  /**
   * Abre la pantalla **como la abre el usuario**: desde el shell de Tools.
   *
   * ⚠️ No se navega a la URL del módulo directamente, y esto no es un detalle. El menú
   * usa `linkTo(ruta)`, que hace `$('#content').load(...)`: las vistas del módulo son
   * **fragmentos** que se inyectan en el shell, y es el shell el que trae jQuery y
   * DataTables. Yendo derecho a la URL se obtiene el fragmento pelado: los `<th>`
   * estáticos están —así que un test flojo pasa igual— pero **no hay jQuery, no se
   * inicializa ninguna grilla y ningún botón funciona**. Cualquier prueba que
   * interactúe fallaría con un `$ is not defined` que no dice nada del sistema.
   */
  async abrir(pantalla: Pantalla): Promise<void> {
    const base = requerirUrlDeApp('tools');
    const enElShell = async () =>
      this.page.evaluate(() => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function');

    if (!(await enElShell().catch(() => false))) {
      // Una sola recarga de reintento: contra el DEMO cargado, el shell a veces no
      // termina de armar sus scripts en el primer intento. Reintentar es más honesto
      // que subir el margen otra vez, que es tapar el síntoma (H-066).
      await this.page.goto(base, { waitUntil: 'domcontentloaded' });
      if (!(await enElShell().catch(() => false))) {
        await this.page.reload({ waitUntil: 'domcontentloaded' });
      }
    }
    // El tercer parámetro son las opciones; el segundo es el argumento de la función.
    // Pasar `{ timeout }` en el medio lo convierte en argumento y el timeout queda en el
    // default de 15 s, que contra el DEMO cargado no alcanza.
    await this.page.waitForFunction(
      () => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function',
      undefined,
      { timeout: 60_000 },
    );
    await this.page.evaluate((ruta) => {
      (window as unknown as { linkTo: (r: string) => void }).linkTo(ruta);
    }, rutaAlm(pantalla));
    await this.page.waitForTimeout(1500);
  }

  /**
   * Encabezados de la grilla, como un solo texto.
   *
   * El timeout es largo a propósito: el DEMO es una máquina chica y, con la suite completa
   * corriendo, una grilla que se pagina contra el servidor tarda bastante más que abierta sola.
   * Un timeout corto hace fallar un test que pasa en aislamiento, que es la peor clase de falla.
   */
  async encabezados(timeout = 60_000): Promise<string> {
    const th = this.page.locator('table thead th');
    await expect(th.first()).toBeVisible({ timeout });
    return (await th.allInnerTexts()).join(' | ');
  }

  /** Texto completo de la pantalla, normalizado, para buscar rótulos y mensajes. */
  async texto(): Promise<string> {
    return (await this.page.locator('body').innerText()).replace(/\s+/g, ' ');
  }

  /** ¿La pantalla quedó en el ingreso? Señal de que la sesión no viajó. */
  async pideIngreso(): Promise<boolean> {
    return /iniciar sesi[oó]n|ingres(ar|o)|password/i.test(await this.texto());
  }
}
