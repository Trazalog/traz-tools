/**
 * Datos que crean las pruebas de Mantenimiento, con las mismas acciones que usan las pantallas.
 *
 * Programar una orden única cierra el preventivo (estado CE, como en asset): por eso las pruebas que
 * programan no reusan un preventivo fijo, sino que copian uno de plantilla
 * (DOCTEST_<AMBIENTE>_MAN_PREVENTIVO) con su equipo, tarea, herramientas e insumos, y programan la copia.
 */

import { expect } from '@playwright/test';

import { entornoActual } from '../../config/apps.ts';
import type { ShellMan } from './ShellMan.ts';

const PREFIJO: Record<string, string> = { local: 'LOCAL', demo: 'DEMO', 'staging-v3': 'STAGING' };

/** Variable de Mantenimiento del ambiente actual (DOCTEST_<AMBIENTE>_MAN_<clave>). */
export function varMan(clave: string): string {
  return process.env[`DOCTEST_${PREFIJO[entornoActual()]}_MAN_${clave}`]?.trim() ?? '';
}

export interface OrdenCalendario {
  id_orden: string;
  estado: string;
  tipo: string;
  case_id: string | number | null;
  fecha_program: string;
}

const dos = (n: number) => String(n).padStart(2, '0');
export const isoDia = (d: Date) => `${d.getFullYear()}-${dos(d.getMonth() + 1)}-${dos(d.getDate())}`;

type Fila = Record<string, string>;

/** Copia el preventivo de plantilla (alta por `Preventivo/guardar_preventivo`) y devuelve el número nuevo. */
export async function copiarPreventivo(man: ShellMan, plantilla: number): Promise<number> {
  const info = (await man.pedir('traz-tools-man/Preventivo/geteditar', { idprev: plantilla })) as {
    datos: Fila[] | Fila;
    herramientas: Fila[] | 0;
    insumos: Fila[] | 0;
  };
  expect(info && typeof info === 'object', `el preventivo de plantilla ${plantilla} existe en la empresa`).toBe(true);
  const d = (Array.isArray(info.datos) ? info.datos[0] : info.datos) as Fila;
  const herr = info.herramientas || [];
  const ins = info.insumos || [];
  const ids = async () => {
    const html = String(await man.pedir('traz-tools-man/Preventivo/index/Add-Edit-Del'));
    return [...html.matchAll(/<tr id="(\d+)"/g)].map((m) => Number(m[1]));
  };
  const antes = new Set(await ids());
  const datos: Record<string, unknown> = {
    id_equipo: d.id_equipo,
    tarea: d.id_tarea,
    periodo: d.perido,
    cantidad: d.cantidad,
    ultimo: isoDia(new Date()),
    id_componente: d.id_componente,
    alerta: d.critico1 ?? '',
    hshombre: d.horash,
    duracion: d.prev_duracion,
    unidad: d.id_unidad,
    cantOper: d.prev_canth || 1,
    lectura_base: d.lectura_base ?? '',
    id_her: herr.map((h) => h.herrId),
    cant_herr: herr.map((h) => h.cantidad || 1),
    id_insumo: ins.map((i) => i.artId),
    cant_insumo: ins.map((i) => i.cantidad || 1),
  };
  const r = (await man.pedir('traz-tools-man/Preventivo/guardar_preventivo', datos)) as { resPrenvent?: unknown };
  expect(r?.resPrenvent, 'el alta del preventivo de prueba').toBeTruthy();
  const nuevo = (await ids()).filter((x) => !antes.has(x)).sort((a, b) => b - a)[0];
  expect(nuevo, 'el preventivo nuevo aparece en el listado').toBeGreaterThan(0);
  return nuevo;
}

/** Programa una orden única del preventivo a `dias` de hoy y devuelve la orden nueva del calendario. */
export async function programarOrden(man: ShellMan, preventivo: number, dias: number): Promise<OrdenCalendario> {
  const d = new Date(Date.now() + dias * 86_400_000);
  const desde = isoDia(d);
  const hasta = isoDia(new Date(d.getTime() + 86_400_000));
  const ordenes = async () =>
    ((await man.pedir('traz-tools-man/Calendario/getcalendarot', { desde, hasta })) as OrdenCalendario[]) || [];
  const antes = new Set((await ordenes()).map((o) => o.id_orden));
  const r = (await man.pedir('traz-tools-man/Calendario/programar', {
    tipo: 3,
    id_origen: preventivo,
    fecha_progr: `${dos(d.getDate())}-${dos(d.getMonth() + 1)}-${d.getFullYear()}`,
    hora_progr: '08:00',
    evento: 1,
    cant_meses: '',
    horas: 0,
  })) as { status: boolean; msj?: string };
  expect(r.status, `programar el preventivo ${preventivo}: ${r.msj ?? ''}`).toBe(true);
  const nueva = (await ordenes()).find((o) => !antes.has(o.id_orden));
  expect(nueva, 'la orden programada aparece en el calendario').toBeTruthy();
  return nueva!;
}

/** La orden tal como la devuelve el calendario de su día, o undefined si ya no aparece. */
export async function ordenEnCalendario(man: ShellMan, orden: OrdenCalendario): Promise<OrdenCalendario | undefined> {
  const dia = orden.fecha_program.slice(0, 10);
  const sig = isoDia(new Date(new Date(`${dia}T12:00:00`).getTime() + 86_400_000));
  const filas = (await man.pedir('traz-tools-man/Calendario/getcalendarot', { desde: dia, hasta: sig })) as OrdenCalendario[];
  return (filas || []).find((o) => o.id_orden === orden.id_orden);
}
