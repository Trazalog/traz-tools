/**
 * capturas.ts — capturas de pantalla A PEDIDO para los specs de DocTest.
 *
 * Por qué existe: la suite guarda capturas SOLO cuando un test falla
 * (`screenshot: 'only-on-failure'` en playwright.config.ts). Para verificar una
 * prueba exitosa paso a paso —recorrer el ciclo y mirar cada pantalla— hace falta
 * poder sacar capturas aunque todo pase. Este helper lo hace sin tocar esa config
 * ni enlentecer las corridas normales:
 *
 *   - APAGADO por defecto: `shot()` es un no-op. No cuesta nada en `test:smoke`/`test:all`.
 *   - Se ENCIENDE con el flag `--capturas` del runner (`scripts/pw.mjs`), que setea
 *     `DOCTEST_CAPTURAS=1` y un identificador de corrida `DOCTEST_CAPTURAS_RUN`.
 *
 * Dónde quedan: en `doctest/.capturas/<corrida>/<grupo>/NN-nombre.png`. Ese
 * directorio NO es el `.test-results` efímero (que Playwright borra en cada corrida):
 * es propio y versionado en `.gitignore`, así que las capturas sobreviven.
 *
 * Uso en un spec:
 *
 *   import { crearCapturador } from '../../fixtures/capturas.ts';
 *   const cap = crearCapturador('ciclo-ot');
 *   await cap.shot(page, 'listado-de-ot');            // 01-listado-de-ot.png
 *   await cap.shot(page, 'detalle entrega', { fullPage: true });
 */

import type { Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
// fixtures → e2e → tests → doctest
const DOCTEST_ROOT = resolve(HERE, '..', '..', '..');

const ACTIVO = process.env.DOCTEST_CAPTURAS === '1';
// Un identificador de corrida compartido por todos los specs de la misma ejecución.
// Lo setea `scripts/pw.mjs` al pasar `--capturas`; si no, se arma uno por proceso.
const CORRIDA =
  process.env.DOCTEST_CAPTURAS_RUN ??
  new Date().toISOString().slice(0, 19).replace(/[-:T]/g, '').replace(/(\d{8})(\d{6})/, '$1-$2');

/** Raíz donde caen las capturas de esta corrida. Pública para que el runner la informe. */
export const CAPTURAS_DIR = resolve(DOCTEST_ROOT, '.capturas', CORRIDA);

export interface Capturador {
  /** `true` si las capturas están encendidas (flag `--capturas`). */
  readonly activo: boolean;
  /** Carpeta de este grupo de capturas. */
  readonly dir: string;
  /**
   * Saca una captura numerada. No-op si las capturas están apagadas.
   * El número se autoincrementa para que el orden del recorrido quede en el nombre.
   */
  shot(page: Page, nombre: string, opts?: { fullPage?: boolean }): Promise<void>;
}

function slug(s: string): string {
  return s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
}

/**
 * Crea un capturador para un grupo (una subcarpeta dentro de la corrida).
 * `grupo` identifica el flujo, p. ej. 'registracion', 'seed-panol', 'ciclo-ot'.
 */
export function crearCapturador(grupo: string): Capturador {
  const dir = resolve(CAPTURAS_DIR, slug(grupo));
  let n = 0;
  if (ACTIVO) mkdirSync(dir, { recursive: true });
  return {
    activo: ACTIVO,
    dir,
    async shot(page: Page, nombre: string, opts?: { fullPage?: boolean }): Promise<void> {
      if (!ACTIVO) return;
      n += 1;
      const archivo = resolve(dir, `${String(n).padStart(2, '0')}-${slug(nombre)}.png`);
      await page.screenshot({ path: archivo, fullPage: opts?.fullPage ?? false });
      // Visible en la salida del runner para saber qué se fue capturando.
      console.log(`  📸 ${archivo}`);
    },
  };
}
