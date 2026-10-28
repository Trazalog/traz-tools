/**
 * Prepara en la empresa de test 1 los datos base que necesita la suite de TAR y que el módulo
 * no crea por sí mismo (spec TAR §7.1, semillas S4):
 *
 *   - 2 clientes ACTIVOS ("DT Cliente Norte", "DT Cliente Sur")      → ABM Clientes
 *   - la lista de valores `tipos_pedidos_trabajo` con 2 tipos        → ABM Lista de Valores
 *   - el rol "Planificador de Tareas" para el planificador           → API de DNATO (H-101)
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

/**
 * Le asigna al planificador el rol de trabajo "Planificador de Tareas <empresa>" por la API de
 * DNATO (`main/changeLevelRolUserObject`), con la sesión del administrador de la empresa 1.
 *
 * Por qué no por la pantalla: "Cambio de Rol" reenvía **todos** los roles que el usuario ya tiene
 * junto con el nuevo; `/rol/asignar` rechaza la membresía repetida y se deshace todo ("Fallo
 * asignación de roles.", H-101 / #588). El endpoint solo agrega roles —nunca quita—, así que
 * mandar únicamente el que falta es seguro: el usuario conserva los que tenía.
 */
async function asegurarRolPlanificador(): Promise<void> {
  const { LoginPage } = await import('../../pages/dnato/LoginPage.ts');
  const { urlDnato } = await import('../../config/apps.ts');
  const { usuarioDeRol } = await import('../../fixtures/roles-tar.ts');
  const empresa = process.env.DOCTEST_EMPRESA1_NOMBRE ?? '';
  const email = process.env.DOCTEST_EMPRESA1_USER ?? '';
  const password = process.env.DOCTEST_EMPRESA1_PASS ?? '';
  const usuario = usuarioDeRol('planificador');
  const rol = `Planificador de Tareas ${empresa}`;
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true });
  try {
    const page = await ctx.newPage();
    const login = new LoginPage(page);
    await login.abrir(urlDnato('main/login'));
    await login.ingresar({ email, password, empresa });
    await page.goto(urlDnato('main/users'), { waitUntil: 'networkidle' });
    await page.locator('input[type=search]').first().fill(usuario);
    await page.locator('table').last().locator('tr', { hasText: usuario }).first().locator('a[href*="changeleveluser"]').click();
    await page.waitForLoadState('networkidle');
    if ((await page.locator('body').innerText()).includes(rol)) {
      console.log(`  · rol "${rol}" de ${usuario}: ya lo tiene`);
      return;
    }
    console.log(`  · rol "${rol}" de ${usuario}: ${DRY ? 'se asignaría' : 'se asigna'}`);
    if (DRY) return;
    await page.getByText('Agregar Rol', { exact: false }).first().click();
    const grupo = page.locator('#groups');
    await grupo.selectOption({ label: empresa });
    await page.waitForFunction(() => (document.querySelector('#roles') as HTMLSelectElement)?.options.length > 1, undefined, { timeout: 30_000 });
    const groupId = (await grupo.inputValue()).split('-')[0];
    const roleId = ((await page.locator('#roles option', { hasText: rol }).first().getAttribute('value')) ?? '').split('-')[0];
    const r = await ctx.request.post(urlDnato('main/changeLevelRolUserObject'), {
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
      form: {
        'dataRole[0][email]': usuario,
        'dataRole[0][group]': empresa,
        'dataRole[0][role]': rol,
        'dataRoleBpm[0][group_id]': groupId,
        'dataRoleBpm[0][role_id]': roleId,
        email: usuario,
        level: '2',
      },
    });
    console.log(`    → ${r.status()} ${(await r.text()).slice(0, 120)}`);
  } finally {
    await ctx.close();
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
  await asegurarRolPlanificador();
  console.log('\nListo. Requisito que no cubre este seed: pro.procesos PROCESO-STANDAR de la empresa (lo carga el PM).');
} finally {
  await browser.close();
}
