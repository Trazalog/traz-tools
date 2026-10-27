/**
 * Prepara en la empresa de test 1 los datos base que necesita la suite de TAR y que el módulo
 * no crea por sí mismo (spec TAR §7.1, semillas S4):
 *
 *   - 2 clientes ACTIVOS ("DT Cliente Norte", "DT Cliente Sur")      → ABM Clientes
 *   - la lista de valores `tipos_pedidos_trabajo` con 2 tipos        → ABM Lista de Valores
 *
 * Es **idempotente**: si el dato ya está, no lo vuelve a crear (README de seeds, regla 2).
 * Va por la pantalla, con el usuario planificador de TAR, igual que lo haría una persona.
 *
 * Lo que **no** puede hacer, y por eso queda como requisito para el PM (S1 del spec): la empresa
 * necesita una fila en `pro.procesos` (`PROCESO-STANDAR`) para que el pedido de trabajo tome su
 * estado inicial, su formulario y decida si lanza el caso de Bonita. No hay pantalla para eso.
 *
 * Dónde se ejecuta: en una terminal, parado en `doctest/`:
 *
 *   npm run seed:tar             # crea lo que falte
 *   npm run seed:tar -- --dry-run  # solo muestra qué haría
 */

import { chromium, type Page } from '@playwright/test';
import { config as cargarEnv } from 'dotenv';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
cargarEnv({ path: resolve(HERE, '..', '..', '..', '..', '.env'), quiet: true });

const { contextoDeRol } = await import('../../fixtures/roles-tar.ts');
const { requerirUrlDeApp } = await import('../../config/apps.ts');

const { CLIENTES_TAR, LISTA_TIPOS, TIPOS_TAR } = await import('./datos-tar.ts');

const DRY = process.argv.includes('--dry-run');

async function irA(page: Page, ruta: string): Promise<void> {
  await page.evaluate((r) => (window as unknown as { linkTo: (x: string) => void }).linkTo(r), ruta);
  await page.waitForLoadState('networkidle').catch(() => {});
  await page.locator('#waiting').waitFor({ state: 'hidden', timeout: 60_000 });
}

async function asegurarClientes(page: Page): Promise<void> {
  await irA(page, 'core/Cliente');
  const tabla = page.locator('#tabla_clientes');
  await tabla.waitFor();
  for (const nombre of CLIENTES_TAR) {
    await page.locator('#tabla_clientes_filter input').fill(nombre);
    const existe = (await tabla.locator('tbody tr', { hasText: nombre }).count()) > 0;
    console.log(`  · cliente "${nombre}": ${existe ? 'ya existe' : DRY ? 'se crearía' : 'se crea'}`);
    if (existe || DRY) continue;
    await page.locator('#botonAgregar').click();
    await page.locator('#nombre').fill(nombre);
    await page.locator('#dir_entrega').fill('Ruta 40 km 3 (DocTest)');
    await page.locator('#ticl_id').selectOption({ index: 1 });
    await page.locator('button[onclick*="guardar(\'nueva\')"]').click();
    await page.locator('#waiting').waitFor({ state: 'hidden', timeout: 60_000 });
    await irA(page, 'core/Cliente');
  }
}

async function asegurarTipos(page: Page): Promise<void> {
  await irA(page, 'core/Valor');
  const select = page.locator('#selectTabla');
  await select.waitFor();
  const listas = await select.locator('option').evaluateAll((os) => os.map((o) => (o as HTMLOptionElement).value));
  if (!listas.includes(LISTA_TIPOS)) {
    console.log(`  · lista "${LISTA_TIPOS}": ${DRY ? 'se crearía' : 'se crea'}`);
    if (DRY) return;
    await page.locator('#botonAgregar').click();
    await page.locator('#nombreLista').fill(LISTA_TIPOS);
    await page.locator('button[onclick*="agregarLista"]').click();
  } else {
    console.log(`  · lista "${LISTA_TIPOS}": ya existe`);
  }
  await select.selectOption(LISTA_TIPOS);
  await page.locator('#waiting').waitFor({ state: 'hidden', timeout: 60_000 });
  const tabla = page.locator('#tabla_valores');
  for (const tipo of TIPOS_TAR) {
    const existe = (await tabla.locator('tbody tr', { hasText: tipo }).count()) > 0;
    console.log(`  · tipo de trabajo "${tipo}": ${existe ? 'ya existe' : DRY ? 'se crearía' : 'se crea'}`);
    if (existe || DRY) continue;
    await page.locator('#agregarValor').click();
    await page.locator('#descripcion').fill(tipo);
    await page.locator('#valor').fill(tipo);
    await page.locator('#btnsave_edit[onclick*="guardarValor"]').click();
    await page.locator('#waiting').waitFor({ state: 'hidden', timeout: 60_000 });
  }
}

const browser = await chromium.launch();
try {
  const ctx = await contextoDeRol(browser, 'planificador');
  const page = await ctx.newPage();
  page.on('dialog', (d) => d.accept().catch(() => {}));
  await page.goto(requerirUrlDeApp('tools'), { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function', undefined, { timeout: 60_000 });
  console.log(`Datos base de TAR${DRY ? ' (dry-run)' : ''}:`);
  await asegurarClientes(page);
  await asegurarTipos(page);
  console.log('\nListo. Requisito que no cubre este seed: pro.procesos PROCESO-STANDAR de la empresa (lo carga el PM).');
} finally {
  await browser.close();
}
