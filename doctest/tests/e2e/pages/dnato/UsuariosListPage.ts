/**
 * UsuariosListPage — "Gestión de Usuarios → Lista de Usuarios" de Dnato.
 *
 * Cubre DNATO-UC-013 (ver la lista) y es la puerta de entrada de las acciones
 * sobre un usuario: asignar rol (UC-018/UC-019) y eliminar (UC-017).
 *
 * ⚠️ La grilla usa DataTables, que **duplica la cabecera en una tabla aparte**.
 * Por eso se apunta a la tabla que tiene filas de datos y no a `table` a secas:
 * es el error que hace contar cero filas cuando la pantalla muestra diez.
 *
 * ⚠️ Selectores: la vista todavía no tiene `data-testid` (van por un PR propio en
 * `traz-comp-dnato`, PHP 5.6). Quedan todos acá.
 */

import type { Locator, Page } from '@playwright/test';

import { urlDnato } from '../../config/apps.ts';

export class UsuariosListPage {
  readonly page: Page;
  /** La tabla de datos, no la cabecera clonada de DataTables. */
  readonly tabla: Locator;
  readonly filas: Locator;
  readonly buscador: Locator;

  constructor(page: Page) {
    this.page = page;
    this.tabla = page.locator('table').filter({ has: page.locator('tbody tr') }).last();
    this.filas = this.tabla.locator('tbody tr');
    this.buscador = page.getByLabel('Buscar:');
  }

  async abrir(): Promise<void> {
    await this.page.goto(urlDnato('main/users'), { waitUntil: 'domcontentloaded' });
    // Se espera la grilla concreta y no `networkidle`: la pantalla tiene componentes
    // que siguen pidiendo datos y el "silencio de red" nunca llega de forma confiable.
    await this.filas.first().waitFor({ state: 'visible', timeout: 60_000 }).catch(() => {});
    // La grilla pagina de a 10: se pide el máximo para que buscar y contar sean fiables.
    await this.page
      .locator('select[name$="_length"]')
      .first()
      .selectOption('100')
      .catch(() => {});
  }

  async columnas(): Promise<string[]> {
    const encabezados = await this.page.locator('table thead th').allInnerTexts();
    return [...new Set(encabezados.map((c) => c.trim()).filter(Boolean))];
  }

  /** Correos de los usuarios visibles en la grilla. */
  async correos(): Promise<string[]> {
    const filas = await this.filas.allInnerTexts();
    return filas.map((f) => /[\w.+-]+@[\w.-]+\.\w+/.exec(f)?.[0]).filter((c): c is string => !!c);
  }

  async buscar(texto: string): Promise<void> {
    await this.buscador.fill(texto);
    await this.page.waitForTimeout(400); // DataTables filtra en el cliente, sin request
  }

  fila(correo: string): Locator {
    return this.filas.filter({ hasText: correo });
  }

  /** True si la pantalla se abrió de verdad y no redirigió por falta de permisos. */
  async visible(): Promise<boolean> {
    return this.page.url().includes('main/users') && (await this.filas.count()) > 0;
  }
}
