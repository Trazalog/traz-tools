/**
 * registrar-empresa.ts — alta completa de una empresa nueva por la registración real
 * de Trazalog (DNATO-UC-001 a UC-005), reutilizable desde un spec y con capturas.
 *
 * Es la misma secuencia del seed `seeds/crear-empresa-test.ts`, extraída como función
 * para poder ENCADENARLA con el ciclo de OT en un solo recorrido, e instrumentada con
 * el capturador (`fixtures/capturas.ts`) para dejar la evidencia paso a paso.
 *
 * Crea su propia casilla descartable (mail.tm), así cada corrida estrena una empresa
 * nueva y un administrador propio, sin credenciales que guardar. Devuelve con qué
 * seguir: el administrador (quien se registró) y el dominio de los 5 usuarios de rol
 * que el alta crea (usuario@, almacen@, panol@, produccion@, mantenimiento@).
 *
 * ⚠️ Escribe datos reales en el entorno: una empresa, 16 roles, establecimiento,
 * depósito y 5 usuarios. Pensada para demo/local, nunca producción (lo impide apps.ts).
 */

import { type Page } from '@playwright/test';

import { urlDnato } from '../config/apps.ts';
import { type Capturador } from '../fixtures/capturas.ts';
import { casillaBase, esperarEnlaceActivacion, hayImap, variantePorPuntos } from '../fixtures/mail-imap.ts';

export interface EmpresaRegistrada {
  razonSocial: string;
  cuit: string;
  /** Dominio corporativo declarado — el de los usuarios de rol. */
  dominio: string;
  /** El administrador: quien se registró (casilla descartable). Es login válido. */
  admin: { email: string; password: string };
  /** Los 5 usuarios que crea el alta, por su correo `<rol>@<dominio>`. */
  usuariosRol: {
    usuario: string;
    almacen: string;
    panol: string;
    produccion: string;
    mantenimiento: string;
  };
}

const BASE = {
  nombre: 'DocTest',
  apellido: 'Ciclo',
  telefono: '+54 92645123456',
  pais: 'Argentina',
  razonSocial: 'DocTest Ciclo',
  password: process.env.DOCTEST_SEED_PASSWORD || 'Doctest2026!',
  provincia: 'San Juan',
  dominioEmpresa: process.env.DOCTEST_SEED_DOMINIO || 'doctest-empresa.com',
  comoEnteraste: 'Internet',
  actividad: 'Minería',
  empleados: '5 a 20',
};

/**
 * Envía el formulario visible. El registro no usa un control uniforme (input submit,
 * botones sin type, botones con texto), así que se prueban las variantes en orden.
 * Copiado del seed, que lo validó contra el DEMO.
 */
async function enviarFormulario(
  page: Page,
  etiquetas = ['Aceptar', 'Guardar', 'Continuar', 'Siguiente', 'Enviar', 'Registrar', 'Crear'],
): Promise<void> {
  const candidatos = [
    page.locator('input[type="submit"]'),
    page.locator('button[type="submit"]'),
    ...etiquetas.map((t) => page.getByRole('button', { name: new RegExp(t, 'i') })),
    ...etiquetas.map((t) => page.locator(`a.btn:has-text("${t}")`)),
  ];
  for (const c of candidatos) {
    const visible = c.first();
    if ((await visible.count()) && (await visible.isVisible().catch(() => false))) {
      await visible.click({ noWaitAfter: true });
      await page.waitForLoadState('networkidle', { timeout: 180_000 }).catch(() => {});
      return;
    }
  }
  const controles = await page
    .locator('input[name], button, a.btn')
    .evaluateAll((els) =>
      els
        .map((e) => `${e.tagName}:${(e as HTMLInputElement).name || e.className}:${(e.textContent ?? '').trim().slice(0, 20)}`)
        .join(' | '),
    );
  throw new Error(`No encontré con qué enviar el formulario en ${page.url()}.\n  Controles: ${controles}`);
}

export async function registrarEmpresa(page: Page, cap: Capturador): Promise<EmpresaRegistrada> {
  if (!hayImap()) {
    throw new Error('Falta DOCTEST_MAIL_IMAP_* en .env: la registración lee el mail de activación por IMAP (Gmail).');
  }
  const sufijo = new Date().toISOString().slice(2, 16).replace(/[-:T]/g, '');
  // Administrador: una variante por puntos de la casilla Gmail configurada, irrepetible.
  const email = variantePorPuntos(casillaBase(), Math.floor(Math.random() * 2048));
  const datos = {
    ...BASE,
    email,
    razonSocial: `${BASE.razonSocial} ${sufijo}`,
    cuit: `30-${sufijo.slice(-8)}-9`,
    // Dominio corporativo ÚNICO por corrida: el sistema lo exige único por empresa, y si
    // no se setea toma el del correo (el de mail.tm, compartido) → "ya está en uso".
    dominioEmpresa: `dt${sufijo.slice(-10)}.com`,
  };
  console.log(`[ciclo] registrando empresa "${datos.razonSocial}" · admin ${datos.email}`);

  // ── Paso 1: registro ───────────────────────────────────────────────────────
  await page.goto(urlDnato('main/register'), { waitUntil: 'domcontentloaded' });
  await page.fill('input[name="firstname"]', datos.nombre);
  await page.fill('input[name="lastname"]', datos.apellido);
  await page.fill('input[name="email"]', datos.email);
  await page.fill('input[name="reg_razon_social"]', datos.razonSocial);
  await page.fill('input[name="telefono"]', datos.telefono);
  const opcionPais = await page
    .locator('select[name="reg_pais_id"] option')
    .filter({ hasText: new RegExp(datos.pais, 'i') })
    .first()
    .getAttribute('value');
  if (opcionPais) await page.selectOption('select[name="reg_pais_id"]', opcionPais);
  await cap.shot(page, 'registro-formulario', { fullPage: true });
  await enviarFormulario(page);
  const textoReg = await page.locator('body').innerText();
  if (/ya existe|no es válido/i.test(textoReg)) {
    throw new Error(`Registro rechazado: ${textoReg.split('\n').find((l) => /ya existe|válido/i.test(l))}`);
  }
  await cap.shot(page, 'registro-confirmado', { fullPage: true });
  console.log('[ciclo] 1. cuenta registrada, mail de activación enviado');

  // ── Paso 2: activación (lee el enlace de la casilla descartable) ────────────
  const enlace = await esperarEnlaceActivacion(datos.email);
  await page.goto(enlace, { waitUntil: 'domcontentloaded' });
  await page.fill('input[name="password"]', datos.password);
  await page.fill('input[name="passconf"]', datos.password);
  await cap.shot(page, 'activacion-definir-password');
  await enviarFormulario(page);
  console.log('[ciclo] 2. cuenta activada →', page.url());

  // ── Paso 3: información adicional (3 preguntas) ─────────────────────────────
  await page.getByText(datos.comoEnteraste, { exact: true }).first().click();
  await page.getByText(datos.actividad, { exact: true }).first().click();
  await page.getByText(datos.empleados, { exact: true }).first().click();
  await cap.shot(page, 'informacion-adicional');
  await enviarFormulario(page);
  console.log('[ciclo] 3. información adicional guardada →', page.url());

  // ── Paso 4: alta de la empresa ──────────────────────────────────────────────
  await page.locator('input[name="cuit"]').waitFor({ timeout: 60_000 });
  // El campo "Dominio de la Empresa" viene prellenado con el dominio del correo y su
  // `name` no siempre es `company_domain`; se ubica de forma robusta y se reemplaza por
  // el dominio único de esta corrida.
  // Con un correo de Gmail (webmail reconocido) el alta pide un dominio corporativo
  // APARTE y editable: `company_domain`. Se completa con el dominio único de la corrida.
  const dominioInput = page.locator('input[name="company_domain"]:not([readonly]):not([disabled])');
  if (await dominioInput.count()) {
    await dominioInput.first().fill(datos.dominioEmpresa);
    console.log(`[ciclo] dominio de empresa → ${datos.dominioEmpresa}`);
  } else {
    const campos = await page
      .locator('form input')
      .evaluateAll((els) =>
        els.map((e) => ({ name: (e as HTMLInputElement).name, ro: (e as HTMLInputElement).readOnly })),
      );
    console.log('[ciclo] ⚠ no hay campo de dominio editable. Campos:', JSON.stringify(campos));
  }
  await page.fill('input[name="cuit"]', datos.cuit);
  await page.selectOption('select[name="prov_id"]', { label: datos.provincia });
  await page
    .locator('select[name="loca_id"] option')
    .nth(1)
    .waitFor({ state: 'attached', timeout: 60_000 });
  await page.selectOption('select[name="loca_id"]', { index: 1 });
  await cap.shot(page, 'alta-empresa-formulario', { fullPage: true });
  await enviarFormulario(page);
  await page
    .locator('body')
    .filter({ hasText: /Registro Completado|alert-main-text|No se pudo|ya existe/i })
    .first()
    .waitFor({ timeout: 180_000 })
    .catch(() => {});
  const textoFinal = await page.locator('body').innerText();
  if (!/Registro Completado|bienvenid/i.test(textoFinal)) {
    throw new Error(
      `El alta de empresa no llegó a la bienvenida (sigue en ${page.url()}). ` +
        `Pantalla: ${textoFinal.replace(/\n+/g, ' | ').slice(0, 300)}`,
    );
  }
  await cap.shot(page, 'bienvenida', { fullPage: true });
  console.log('[ciclo] 4. empresa creada:', datos.razonSocial);

  const dominio = datos.dominioEmpresa;
  return {
    razonSocial: datos.razonSocial,
    cuit: datos.cuit,
    dominio,
    admin: { email: datos.email, password: datos.password },
    usuariosRol: {
      usuario: `usuario@${dominio}`,
      almacen: `almacen@${dominio}`,
      panol: `panol@${dominio}`,
      produccion: `produccion@${dominio}`,
      mantenimiento: `mantenimiento@${dominio}`,
    },
  };
}
