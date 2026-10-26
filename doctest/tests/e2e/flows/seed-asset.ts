/**
 * seed-asset.ts — siembra de datos maestros en AssetPlanner para una empresa nueva.
 *
 * Una empresa recién registrada está VACÍA: no tiene equipos, ni los maestros que el
 * equipo exige (área, proceso, criticidad, etapa, grupo, marca). Este módulo los crea
 * como admin, usando los endpoints reales del frontend (los mismos que dispara la UI al
 * "Agregar"), lo que es más rápido y estable que manejar cada modal — y deja el circuito
 * listo para el ciclo de la OT.
 *
 * Los endpoints y nombres de campo salen del código de asset:
 *   - application/controllers/Equipo.php: agregar_area/criti/proceso/etapa/grupo/marca, guardar_equipo
 *   - application/views/equipo/view_.php: qué `parametros` arma cada "Agregar"
 *
 * La guía para hacerlo A MANO (o que un agente acompañe a un cliente) está en
 * doctest/doc/onboarding-empresa-nueva.md.
 */

import { type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../config/apps.ts';
import { type Capturador } from '../fixtures/capturas.ts';

/** Ingreso a AssetPlanner (padrón propio, distinto de Tools). */
export async function loginAssetAdmin(page: Page, email: string, password: string): Promise<void> {
  const base = requerirUrlDeApp('man');
  for (let i = 1; i <= 3; i++) {
    const ok = await page.goto(base, { waitUntil: 'domcontentloaded', timeout: 90_000 }).catch(() => null);
    if (ok) break;
    await page.waitForTimeout(3000);
  }
  await page.locator('#usrName').waitFor({ timeout: 30_000 });
  await page.locator('#usrName').fill(email);
  await page.locator('#usrPassword').fill(password);
  await page.locator('#login').click({ noWaitAfter: true });
  await page.waitForTimeout(11_000);
  if ((await page.locator('#usrPassword').count()) > 0) {
    throw new Error(`No se pudo entrar a AssetPlanner con ${email} (¿contraseña o empresa sin usuario de asset?).`);
  }
}

export interface MaestrosEquipo {
  equipoCodigo: string;
  /** id del equipo (ya listable), para encadenar la solicitud de servicio. */
  equipoId: string;
  ids: Record<string, string>;
}

/**
 * Crea los maestros base y un equipo. Devuelve el código del equipo y los ids de los
 * maestros, para encadenar (la solicitud de servicio necesita un equipo).
 */
export async function seedEquipo(page: Page, cap: Capturador): Promise<MaestrosEquipo> {
  const base = requerirUrlDeApp('man');
  const post = async (ep: string, form: Record<string, string>): Promise<string> => {
    const r = await page.request.post(`${base}/index.php/Equipo/${ep}`, { form });
    const t = (await r.text()).trim();
    if (r.status() !== 200 || !/^\d+$/.test(t)) {
      throw new Error(`${ep} falló: HTTP ${r.status()} ${t.slice(0, 120)}`);
    }
    return t;
  };

  const area = await post('agregar_area', { 'parametros[descripcion]': 'Área Minería' });
  const proceso = await post('agregar_proceso', { 'parametros[descripcion]': 'Molienda' });
  const criticidad = await post('agregar_criti', { 'parametros[descripcion]': 'Alta' });
  const etapa = await post('agregar_etapa', { 'parametros[descripcion]': 'Operación' });
  const grupo = await post('agregar_grupo', { 'parametros[descripcion]': 'Bombas' });
  // marca usa otra columna (marcadescrip) y exige estado — verificado en view_.php
  const marca = await post('agregar_marca', { 'parametros[marcadescrip]': 'ACME', 'parametros[estado]': 'AC' });
  // CLAVE: una empresa nueva NO tiene unidad_industrial ni cliente, y equiposPaginados
  // los INNER-JOINea. Sin ellos el equipo se guarda pero NO lista (y la solicitud de
  // servicio no lo encuentra). Por eso se crean y se pasan como `unin` y `cliente`.
  const unidad = await post('agregar_unidad', { 'parametros[descripcion]': 'Planta Principal' });
  const cliente = await post('agregar_cliente', { 'parametros[cliRazonSocial]': 'Cliente Interno' });
  console.log(`[ciclo] maestros: area=${area} proc=${proceso} crit=${criticidad} etapa=${etapa} grupo=${grupo} marca=${marca} unidad=${unidad} cliente=${cliente}`);

  // Código único por corrida: el alta rechaza códigos repetidos (incluso de otra empresa).
  const equipoCodigo = `EQ-${Date.now().toString().slice(-7)}`;
  const guardar = await page.request.post(`${base}/index.php/Equipo/guardar_equipo`, {
    form: {
      codigo: equipoCodigo,
      descripcion: 'Bomba centrífuga 100HP',
      marca,
      ubicacion: 'Planta 1',
      area,
      proceso,
      criticidad,
      etapa,
      grupo,
      cliente,
      unin: unidad,
      numse: `SN-${Date.now().toString().slice(-5)}`,
      fecha_ingreso: '2026-01-10',
      fecha_garantia: '2027-01-10',
      fecha_ultima: '',
      ultima_lectura: '0',
      destec: '',
    },
  });
  const resp = (await guardar.text()).trim();
  if (!/ok|exitoso/i.test(resp)) throw new Error(`guardar_equipo no confirmó: ${resp.slice(0, 150)}`);
  console.log(`[ciclo] equipo ${equipoCodigo} creado: ${resp.slice(0, 80)}`);

  // Captura del listado de equipos con el recién creado.
  await page.goto(`${base}/Equipo`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(4000);
  await cap.shot(page, 'equipos-listado', { fullPage: false });

  // El equipo ahora lista: obtener su id para encadenar la solicitud de servicio.
  let equipoId = '';
  try {
    const pag = await page.request.post(`${base}/index.php/Equipo/paginado`, {
      form: { draw: '1', start: '0', length: '50' },
    });
    const j = JSON.parse(await pag.text()) as { data?: Array<{ codigo: string; id_equipo: string }> };
    equipoId = (j.data ?? []).find((r) => r.codigo === equipoCodigo)?.id_equipo ?? '';
  } catch {
    /* si no se puede parsear, queda vacío; la solicitud lo reportará */
  }
  console.log(`[ciclo] equipo id=${equipoId}`);

  return { equipoCodigo, equipoId, ids: { area, proceso, criticidad, etapa, grupo, marca, unidad, cliente } };
}

/**
 * Crea una herramienta en Pañol. Reusa una marca (de `marcasequipos`, las mismas del
 * equipo). El depósito es opcional (una empresa nueva no trae ninguno).
 * Endpoint: Herramienta/agregar_herramienta — ver controllers/Herramienta.php.
 */
export async function seedHerramienta(page: Page, cap: Capturador, marcaId: string): Promise<string> {
  const base = requerirUrlDeApp('man');
  const codigo = `HRR-${Date.now().toString().slice(-7)}`;
  const r = await page.request.post(`${base}/index.php/Herramienta/agregar_herramienta`, {
    form: {
      'parametros[herrcodigo]': codigo,
      'parametros[herrdescrip]': 'Taladro percutor',
      'parametros[herrmarca]': 'TP-500',
      'parametros[modid]': marcaId,
      'parametros[depositoId]': '',
    },
  });
  const t = (await r.text()).trim();
  if (r.status() !== 200 || t === 'existe' || t === '0') {
    throw new Error(`agregar_herramienta falló: HTTP ${r.status()} ${t.slice(0, 120)}`);
  }
  console.log(`[ciclo] herramienta ${codigo} creada (id ${t})`);
  await page.goto(`${base}/Herramienta`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3500);
  await cap.shot(page, 'herramientas-listado', { fullPage: false });
  return codigo;
}

/**
 * Crea una Solicitud de Servicio para un equipo. Esto INSERTA la solicitud y **lanza el
 * proceso de mantenimiento en Bonita** (`Sservicio/lanzarProcesoBPM`), que es la puerta de
 * entrada al circuito correctivo. La OT se genera después, al avanzar el proceso (supervisor:
 * Planificar Solicitud → Asignar Recursos y Tareas), que lo orquesta el controller Calendario.
 */
export async function crearSolicitudServicio(
  page: Page,
  cap: Capturador,
  equipoId: string,
  equipoCodigo: string,
): Promise<void> {
  const base = requerirUrlDeApp('man');
  const r = await page.request.post(`${base}/index.php/Sservicio/lanzarProcesoBPM`, {
    form: { id_equipo: equipoId, equipo: equipoCodigo, falla: 'Ruido anormal y vibración en la bomba' },
  });
  const t = (await r.text()).trim();
  if (r.status() !== 200 || !/"status"\s*:\s*true|OK/i.test(t)) {
    throw new Error(`lanzarProcesoBPM falló: HTTP ${r.status()} ${t.slice(0, 150)}`);
  }
  console.log(`[ciclo] solicitud de servicio creada, proceso Bonita lanzado: ${t.slice(0, 80)}`);
  await page.goto(`${base}/Sservicio`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(4000);
  await cap.shot(page, 'solicitud-servicio', { fullPage: false });
}
