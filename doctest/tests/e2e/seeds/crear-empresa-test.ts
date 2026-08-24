/**
 * crear-empresa-test.ts — crea desde cero la empresa de test de DocTest.
 *
 * DÓNDE SE EJECUTA: en una terminal, parado en `doctest/`.
 *
 *   npm run seed:empresa                 # usa lo que haya en doctest/.env
 *   npm run seed:empresa -- --dry-run    # muestra los datos y no toca nada
 *
 * QUÉ HACE: recorre el alta real de una empresa, tal como la haría una persona
 * (DNATO-UC-001 a UC-005), con navegador visible o headless:
 *
 *   1. Registro           → deja la cuenta creada y dispara el mail de activación
 *   2. Enlace de activación → lo lee de la casilla por IMAP, o lo pide por consola
 *   3. Activación         → define la contraseña
 *   4. Información adicional → responde las tres preguntas obligatorias
 *   5. Alta de empresa    → identificador tributario, provincia, localidad y dominio
 *
 * Al terminar imprime la empresa creada y los cinco usuarios iniciales, que son
 * los datos que hay que dejar en `doctest/.env`.
 *
 * ⚠️ Escribe datos reales en el entorno bajo prueba: crea una empresa, sus 16
 * roles, un establecimiento, un depósito y cinco usuarios. No tiene vuelta atrás
 * automática (ver el pendiente de "procedimiento de limpieza" en el registro de
 * hallazgos). Está pensado para correrse pocas veces, no en cada suite.
 */

import { chromium, type Page } from '@playwright/test';
import { createInterface } from 'node:readline/promises';
import { connect as tlsConnect } from 'node:tls';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { config as cargarEnv } from 'dotenv';

import { requerirUrlDeApp } from '../config/apps.ts';

const HERE = dirname(fileURLToPath(import.meta.url));
cargarEnv({ path: resolve(HERE, '..', '..', '..', '.env'), quiet: true });

const DRY_RUN = process.argv.includes('--dry-run');
const HEADED = process.argv.includes('--headed');
/** Solo el paso 1: registra y sale, para que el mail de activación llegue mientras tanto. */
const SOLO_REGISTRO = process.argv.includes('--solo-registro');
/** Retoma desde el enlace de activación: `--desde-enlace <url>`. Sirve cuando el enlace se copia a mano. */
const DESDE_ENLACE = (() => {
  const i = process.argv.indexOf('--desde-enlace');
  return i >= 0 ? process.argv[i + 1] : undefined;
})();

/** Datos del alta. Todo configurable por entorno para no hardcodear nada. */
const DATOS = {
  // Quien se registra (tiene que ser una casilla que podamos leer).
  email: process.env.DOCTEST_SEED_EMAIL ?? '',
  nombre: process.env.DOCTEST_SEED_NOMBRE ?? 'DocTest',
  apellido: process.env.DOCTEST_SEED_APELLIDO ?? 'Automatizado',
  // El teléfono se valida por país: Argentina exige /^\+?54\s?9?\d{4}\s?\d{6}$/
  telefono: process.env.DOCTEST_SEED_TELEFONO ?? '+54 92645123456',
  pais: process.env.DOCTEST_SEED_PAIS ?? 'Argentina',
  razonSocial: process.env.DOCTEST_SEED_RAZON_SOCIAL ?? 'DocTest Empresa SA',
  password: process.env.DOCTEST_SEED_PASSWORD ?? '',
  // Datos de la empresa.
  cuit: process.env.DOCTEST_SEED_CUIT ?? '30-71234567-8',
  provincia: process.env.DOCTEST_SEED_PROVINCIA ?? 'San Juan',
  localidad: process.env.DOCTEST_SEED_LOCALIDAD ?? '',
  // Dominio corporativo: solo se pide si el correo es de un webmail público.
  dominioEmpresa: process.env.DOCTEST_SEED_DOMINIO ?? 'doctest-empresa.com',
  // Respuestas del formulario de información adicional.
  comoEnteraste: process.env.DOCTEST_SEED_COMO ?? 'Internet',
  actividad: process.env.DOCTEST_SEED_ACTIVIDAD ?? 'Minería',
  empleados: process.env.DOCTEST_SEED_EMPLEADOS ?? '5 a 20',
};

const IMAP = {
  host: process.env.DOCTEST_MAIL_IMAP_HOST ?? '',
  port: Number(process.env.DOCTEST_MAIL_IMAP_PORT ?? 993),
  user: process.env.DOCTEST_MAIL_IMAP_USER ?? DATOS.email,
  pass: process.env.DOCTEST_MAIL_IMAP_PASS ?? '',
};

function abortar(motivo: string): never {
  console.error(`\n✖ ${motivo}\n`);
  process.exit(2);
}

// ─────────────────────────────────────────────────────────────────────────────
// Enlace de activación: por IMAP, o pegado a mano
// ─────────────────────────────────────────────────────────────────────────────

/** Cliente IMAP mínimo (LOGIN → SELECT → SEARCH → FETCH), sin dependencias. */
function imapBuscarEnlace(asunto: string, minutos = 30): Promise<string | null> {
  return new Promise((resolveP, rejectP) => {
    const socket = tlsConnect({ host: IMAP.host, port: IMAP.port, servername: IMAP.host });
    let buffer = '';
    let paso = 0;
    const enviar = (cmd: string) => socket.write(`a${++paso} ${cmd}\r\n`);
    const desde = new Date(Date.now() - minutos * 60_000)
      .toUTCString()
      .replace(/^\w+, (\d+) (\w+) (\d+).*$/, '$1-$2-$3');

    socket.setEncoding('utf8');
    socket.on('error', rejectP);
    socket.on('data', (chunk: string) => {
      buffer += chunk;
      if (paso === 0 && buffer.includes('* OK')) {
        enviar(`LOGIN "${IMAP.user}" "${IMAP.pass}"`);
      } else if (paso === 1 && /a1 OK/.test(buffer)) {
        buffer = '';
        enviar('SELECT INBOX');
      } else if (paso === 2 && /a2 OK/.test(buffer)) {
        buffer = '';
        enviar(`SEARCH SINCE ${desde} SUBJECT "${asunto}"`);
      } else if (paso === 3 && /a3 OK/.test(buffer)) {
        const ids = (/\* SEARCH([^\r\n]*)/.exec(buffer)?.[1] ?? '').trim().split(/\s+/).filter(Boolean);
        if (ids.length === 0) {
          socket.end();
          resolveP(null);
          return;
        }
        buffer = '';
        enviar(`FETCH ${ids[ids.length - 1]} BODY[TEXT]`);
      } else if (paso === 4 && /a4 OK/.test(buffer)) {
        const cuerpo = buffer.replace(/=\r\n/g, '').replace(/=3D/g, '=');
        const enlace = /https?:\/\/[^\s"'<>]*main\/complete\/token\/[A-Za-z0-9_-]+/.exec(cuerpo)?.[0] ?? null;
        socket.end();
        resolveP(enlace);
      } else if (/a\d+ (NO|BAD)/.test(buffer)) {
        const err = buffer.trim().split('\n').pop();
        socket.end();
        rejectP(new Error(`IMAP rechazó el comando: ${err}`));
      }
    });
  });
}

async function obtenerEnlaceActivacion(): Promise<string> {
  if (IMAP.host && IMAP.pass) {
    console.log(`→ Buscando el mail de activación en ${IMAP.user} (${IMAP.host})...`);
    for (let intento = 1; intento <= 10; intento++) {
      const enlace = await imapBuscarEnlace('Activar cuenta');
      if (enlace) {
        console.log('✓ Enlace de activación encontrado');
        return enlace;
      }
      console.log(`   todavía no llegó (intento ${intento}/10), reintento en 15 s`);
      await new Promise((r) => setTimeout(r, 15_000));
    }
    abortar('El mail de activación no llegó en 2,5 minutos. Revisá la casilla y volvé a correr con el enlace a mano.');
  }

  console.log('\n→ No hay acceso IMAP configurado (DOCTEST_MAIL_IMAP_*).');
  console.log('  Abrí la casilla, buscá el mail "Activar cuenta en Trazalog.com" y pegá acá el enlace del botón.');
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const enlace = (await rl.question('  Enlace de activación: ')).trim();
  rl.close();
  if (!/main\/complete\/token\//.test(enlace)) abortar('Ese no parece un enlace de activación válido.');
  return enlace;
}


/**
 * Envía el formulario visible. Las pantallas del registro no usan un control
 * uniforme (hay `input[type=submit]`, botones sin type y botones con texto),
 * así que se prueban las variantes en orden y, si ninguna aparece, se listan los
 * controles de la pantalla para que el error diga algo útil.
 */
async function enviarFormulario(page: Page, etiquetas = ['Aceptar', 'Guardar', 'Continuar', 'Siguiente', 'Enviar', 'Registrar', 'Crear']): Promise<void> {
  const candidatos = [
    page.locator('input[type="submit"]'),
    page.locator('button[type="submit"]'),
    ...etiquetas.map((t) => page.getByRole('button', { name: new RegExp(t, 'i') })),
    ...etiquetas.map((t) => page.locator(`a.btn:has-text("${t}")`)),
  ];
  for (const c of candidatos) {
    const visible = c.first();
    if ((await visible.count()) && (await visible.isVisible().catch(() => false))) {
      // El paso de activación dispara la creación del usuario en Bonita y en Asset:
      // puede tardar bastante, así que no se espera la navegación en el click.
      await visible.click({ noWaitAfter: true });
      await page.waitForLoadState('networkidle', { timeout: 180_000 }).catch(() => {});
      return;
    }
  }
  const controles = await page
    .locator('input[name], button, a.btn')
    .evaluateAll((els) => els.map((e) => `${e.tagName}:${(e as HTMLInputElement).name || e.className}:${(e.textContent ?? '').trim().slice(0, 20)}`).join(' | '));
  abortar(`No encontré con qué enviar el formulario en ${page.url()}.\n  Controles visibles: ${controles}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Pasos del alta
// ─────────────────────────────────────────────────────────────────────────────

async function registrarse(page: Page, urlDnato: string): Promise<void> {
  const base = urlDnato.replace(/main\/login\/?$/, '');
  await page.goto(base + 'main/register');
  await page.fill('input[name="firstname"]', DATOS.nombre);
  await page.fill('input[name="lastname"]', DATOS.apellido);
  await page.fill('input[name="email"]', DATOS.email);
  await page.fill('input[name="reg_razon_social"]', DATOS.razonSocial);
  await page.fill('input[name="telefono"]', DATOS.telefono);
  // El texto de la opción trae la bandera y espacios ("🇦🇷 Argentina"), así que se busca por contenido.
  const opcionPais = await page
    .locator('select[name="reg_pais_id"] option')
    .filter({ hasText: new RegExp(DATOS.pais, 'i') })
    .first()
    .getAttribute('value');
  if (!opcionPais) abortar(`El país "${DATOS.pais}" no está en la lista del formulario de registro.`);
  await page.selectOption('select[name="reg_pais_id"]', opcionPais);
  await enviarFormulario(page);
  await page.waitForLoadState('networkidle');
  const texto = await page.locator('body').innerText();
  if (/ya existe|no es válido|ya existe en el sistema/i.test(texto)) {
    abortar(`El registro fue rechazado: ${texto.split('\n').find((l) => /ya existe|válido/i.test(l))}`);
  }
  console.log('✓ Paso 1: cuenta registrada, mail de activación enviado');
}

async function activar(page: Page, enlace: string): Promise<void> {
  await page.goto(enlace);
  await page.fill('input[name="password"]', DATOS.password);
  await page.fill('input[name="passconf"]', DATOS.password);
  await enviarFormulario(page);
  await page.waitForLoadState('networkidle');
  console.log('✓ Paso 2: cuenta activada y contraseña definida →', page.url());
}

async function completarFormulario(page: Page): Promise<void> {
  await page.getByText(DATOS.comoEnteraste, { exact: true }).first().click();
  await page.getByText(DATOS.actividad, { exact: true }).first().click();
  await page.getByText(DATOS.empleados, { exact: true }).first().click();
  await enviarFormulario(page);
  await page.waitForLoadState('networkidle');
  console.log('✓ Paso 3: información adicional guardada →', page.url());
}

async function crearEmpresa(page: Page): Promise<void> {
  // El dominio corporativo solo se pide si el correo del registro es de un webmail público.
  const dominio = page.locator('input[name="company_domain"]');
  if (await dominio.count()) {
    await dominio.fill(DATOS.dominioEmpresa);
    console.log(`   (correo de webmail: se declara el dominio ${DATOS.dominioEmpresa})`);
  }
  await page.fill('input[name="cuit"]', DATOS.cuit);

  await page.selectOption('select[name="prov_id"]', { label: DATOS.provincia });
  // Las localidades se cargan por AJAX al elegir la provincia: se espera a que aparezcan
  // en vez de dormir un tiempo fijo (RNF-03: nada de esperas arbitrarias).
  await page
    .locator('select[name="loca_id"] option')
    .nth(1)
    .waitFor({ state: 'attached', timeout: 60_000 })
    .catch(() => abortar('El combo de localidades nunca se pobló para la provincia elegida.'));
  if (DATOS.localidad) {
    await page.selectOption('select[name="loca_id"]', { label: DATOS.localidad });
  } else {
    await page.selectOption('select[name="loca_id"]', { index: 1 });
  }
  const localidadElegida = await page.locator('select[name="loca_id"]').inputValue();
  console.log(`   provincia ${DATOS.provincia} · localidad ${localidadElegida}`);

  await enviarFormulario(page);
  // El alta encadena varias llamadas (core, Asset, Bonita, roles, establecimiento):
  // se espera a que aparezca la bienvenida o un mensaje de error, sin fijar la URL,
  // porque el redirect final llega después del 303 de guardarEmpresa.
  await page
    .locator('body')
    .filter({ hasText: /Registro Completado|alert-main-text|No se pudo|ya existe/i })
    .first()
    .waitFor({ timeout: 180_000 })
    .catch(() => {});

  const texto = await page.locator('body').innerText();
  if (!/Registro Completado|bienvenid/i.test(texto)) {
    const alerta = await page
      .locator('.alert, .error, .flash, [class*="danger"]')
      .allInnerTexts()
      .catch(() => [] as string[]);
    abortar(
      `El alta de empresa no llegó a la bienvenida (sigue en ${page.url()}).\n` +
        `  Mensajes en pantalla: ${alerta.filter(Boolean).join(' | ') || '(ninguno)'}\n` +
        `  Primeras líneas: ${texto.replace(/\n+/g, ' | ').slice(0, 300)}`,
    );
  }
  console.log('✓ Paso 4: empresa creada');
  console.log('\n--- Pantalla de bienvenida ---\n' + texto.slice(0, 900));
}

// ─────────────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const urlDnato = requerirUrlDeApp('dnato');
  if (!DATOS.email) abortar('Falta DOCTEST_SEED_EMAIL: la casilla desde la que se registra la empresa.');
  if (!DATOS.password) abortar('Falta DOCTEST_SEED_PASSWORD: la contraseña que va a tener el administrador.');

  console.log('\nDocTest · alta de la empresa de test');
  console.log('  entorno   :', urlDnato);
  console.log('  registra  :', DATOS.email);
  console.log('  empresa   :', DATOS.razonSocial, '| CUIT', DATOS.cuit, '|', DATOS.provincia);
  console.log('  dominio   :', DATOS.dominioEmpresa, '(solo se usa si el correo es de webmail)');
  console.log('  modo      :', DESDE_ENLACE ? 'retomar desde el enlace de activación' : SOLO_REGISTRO ? 'solo el paso 1 (registro)' : 'completo');
  if (DRY_RUN) {
    console.log('\n(--dry-run: no se ejecuta nada)\n');
    return;
  }

  const browser = await chromium.launch({ headless: !HEADED });
  const page = await browser.newPage({ ignoreHTTPSErrors: true, locale: 'es-AR' });
  page.setDefaultNavigationTimeout(180_000);
  page.setDefaultTimeout(60_000);
  try {
    if (!DESDE_ENLACE) {
      await registrarse(page, urlDnato);
      if (SOLO_REGISTRO) {
        console.log('\n→ Paso 1 hecho. Cuando llegue el mail de activación, seguí con:');
        console.log('   npm run seed:empresa -- --desde-enlace "<url del botón Activar mi cuenta>"\n');
        return;
      }
    }
    const enlace = DESDE_ENLACE ?? (await obtenerEnlaceActivacion());
    await activar(page, enlace);
    await completarFormulario(page);
    await crearEmpresa(page);
    console.log('\n✓ Listo. Anotá en doctest/.env:');
    console.log(`  DOCTEST_EMPRESA1_NOMBRE=${DATOS.razonSocial}`);
    console.log(`  DOCTEST_EMPRESA1_USER=${DATOS.email}`);
    console.log('  DOCTEST_EMPRESA1_PASS=<la que definiste>');
    console.log(`\n  Usuarios iniciales creados: usuario@ almacen@ panol@ produccion@ mantenimiento@${DATOS.dominioEmpresa}`);
  } finally {
    await browser.close();
  }
}

await main();
