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
  console.log(`[ciclo] maestros creados: area=${area} proceso=${proceso} crit=${criticidad} etapa=${etapa} grupo=${grupo} marca=${marca}`);

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
      cliente: '',
      numse: 'SN-0001',
      fecha_ingreso: '2026-01-10',
      fecha_garantia: '2027-01-10',
      fecha_ultima: '',
      ultima_lectura: '0',
      destec: '',
      unin: '',
    },
  });
  const resp = (await guardar.text()).trim();
  if (!/ok|exitoso/i.test(resp)) throw new Error(`guardar_equipo no confirmó: ${resp.slice(0, 150)}`);
  console.log(`[ciclo] equipo ${equipoCodigo} creado: ${resp.slice(0, 80)}`);

  // Captura del listado de equipos con el recién creado.
  await page.goto(`${base}/Equipo`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(4000);
  await cap.shot(page, 'equipos-listado', { fullPage: false });

  return { equipoCodigo, ids: { area, proceso, criticidad, etapa, grupo, marca } };
}
