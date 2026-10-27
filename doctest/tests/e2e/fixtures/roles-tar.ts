/**
 * Sesiones por ROL para las pruebas del módulo de Tareas (TAR).
 *
 * El circuito de TAR lo recorren personas distintas: quien planifica (crea el pedido de
 * trabajo, los hitos y las tareas, y las asigna) y quien recibe la tarea en su bandeja y la
 * ejecuta. Para probar la reasignación hacen falta **dos** responsables, y para probar el
 * aislamiento entre empresas, una sesión de la empresa 2.
 *
 * Como en `roles-alm.ts`, los usuarios **nunca se hardcodean**: si falta uno, el test falla
 * diciendo qué variable completar. Son usuarios de la empresa de test 1 (los iniciales que
 * crea la registración sirven), y el de la empresa 2 es su administrador.
 *
 * Cada sesión se abre **una vez por corrida** y se reutiliza serializada (`storageState`),
 * igual que `auth.ts`: el ingreso cuesta ~10-40 s contra el DEMO.
 */

import { type Browser, type BrowserContext, type Page } from '@playwright/test';
import { existsSync, mkdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { requerirUrlDeApp } from '../config/apps.ts';
import { LoginPage } from '../pages/dnato/LoginPage.ts';

export type RolTar = 'planificador' | 'responsable1' | 'responsable2' | 'empresa2';

const VARIABLES: Record<RolTar, { usuario: string; clave: string; empresa: string; queHace: string }> = {
  planificador: {
    usuario: 'DOCTEST_TAR_PLANIFICADOR_USER',
    clave: 'DOCTEST_TAR_PLANIFICADOR_PASS',
    empresa: 'DOCTEST_EMPRESA1_NOMBRE',
    queHace: 'crea pedidos de trabajo, hitos y tareas, y las asigna',
  },
  responsable1: {
    usuario: 'DOCTEST_TAR_RESPONSABLE1_USER',
    clave: 'DOCTEST_TAR_RESPONSABLE1_PASS',
    empresa: 'DOCTEST_EMPRESA1_NOMBRE',
    queHace: 'recibe la tarea en su bandeja y la ejecuta',
  },
  responsable2: {
    usuario: 'DOCTEST_TAR_RESPONSABLE2_USER',
    clave: 'DOCTEST_TAR_RESPONSABLE2_PASS',
    empresa: 'DOCTEST_EMPRESA1_NOMBRE',
    queHace: 'recibe la tarea cuando se la reasignan',
  },
  empresa2: {
    usuario: 'DOCTEST_EMPRESA2_USER',
    clave: 'DOCTEST_EMPRESA2_PASS',
    empresa: 'DOCTEST_EMPRESA2_NOMBRE',
    queHace: 'es de la otra empresa: sirve para probar el aislamiento',
  },
};

const HERE = dirname(fileURLToPath(import.meta.url));
const DIR_SESIONES = resolve(HERE, '..', '.auth');
/** Una sesión de CodeIgniter dura 2 h; se renueva antes para no morir a mitad de corrida. */
const VIDA_SESION_MS = 90 * 60 * 1000;

/** Usuario (correo) de un rol, leído del entorno. */
export function usuarioDeRol(rol: RolTar): string {
  const valor = process.env[VARIABLES[rol].usuario]?.trim();
  if (!valor) throw new Error(faltante(rol));
  return valor;
}

function faltante(rol: RolTar): string {
  const v = VARIABLES[rol];
  return (
    `Falta el usuario con rol "${rol}" (el que ${v.queHace}).\n` +
    `Completá ${v.usuario}, ${v.clave} y ${v.empresa} en doctest/.env (plantilla en .env.example).\n` +
    `Son usuarios de las empresas de test: los provee el PM, no se inventan.`
  );
}

async function iniciarSesion(browser: Browser, rol: RolTar, destino: string): Promise<void> {
  const v = VARIABLES[rol];
  const email = process.env[v.usuario]?.trim();
  const password = process.env[v.clave]?.trim();
  const empresa = process.env[v.empresa]?.trim();
  if (!email || !password || !empresa) throw new Error(faltante(rol));

  const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await contexto.newPage();
  page.setDefaultNavigationTimeout(120_000);
  const login = new LoginPage(page);
  await login.abrir(requerirUrlDeApp('dnato'));
  await login.ingresar({ email, password, empresa });
  await page.waitForURL(/traz-tools/, { timeout: 120_000 }).catch(() => {});
  if (!/traz-tools/.test(page.url())) {
    const motivo = (await login.mensajeDeError()) ?? `quedó en ${page.url()}`;
    await contexto.close();
    throw new Error(`No se pudo entrar a Tools con el rol "${rol}" (${email}): ${motivo}`);
  }
  mkdirSync(DIR_SESIONES, { recursive: true });
  await contexto.storageState({ path: destino });
  await contexto.close();
}

/** Path de la sesión guardada de un rol; la crea (o la renueva si está por vencer). */
export async function sesionTar(browser: Browser, rol: RolTar): Promise<string> {
  const destino = join(DIR_SESIONES, `tar-${rol}.json`);
  const vigente = existsSync(destino) && Date.now() - statSync(destino).mtimeMs < VIDA_SESION_MS;
  if (!vigente) await iniciarSesion(browser, rol, destino);
  return destino;
}

/** Abre un contexto nuevo con la sesión del rol. Quien lo abre lo cierra. */
export async function contextoDeRol(browser: Browser, rol: RolTar): Promise<BrowserContext> {
  return browser.newContext({
    storageState: await sesionTar(browser, rol),
    ignoreHTTPSErrors: true,
    locale: 'es-AR',
    timezoneId: 'America/Argentina/San_Juan',
  });
}

/** Página nueva con la sesión del rol, ya parada en el shell de Tools. */
export async function paginaDeRol(browser: Browser, rol: RolTar): Promise<Page> {
  const contexto = await contextoDeRol(browser, rol);
  const page = await contexto.newPage();
  await page.goto(requerirUrlDeApp('tools'), { waitUntil: 'domcontentloaded' });
  return page;
}
