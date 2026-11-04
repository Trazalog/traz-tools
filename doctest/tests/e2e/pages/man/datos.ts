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

/**
 * Programa una orden única a `dias` de hoy y devuelve la orden nueva del calendario.
 * `tipo`: 2 solicitud urgente, 3 preventivo, 4 backlog, 5 predictivo.
 */
export async function programarOrden(man: ShellMan, origen: number, dias: number, tipo = 3): Promise<OrdenCalendario> {
  const d = new Date(Date.now() + dias * 86_400_000);
  const desde = isoDia(d);
  const hasta = isoDia(new Date(d.getTime() + 86_400_000));
  const ordenes = async () =>
    ((await man.pedir('traz-tools-man/Calendario/getcalendarot', { desde, hasta })) as OrdenCalendario[]) || [];
  const antes = new Set((await ordenes()).map((o) => o.id_orden));
  const r = (await man.pedir('traz-tools-man/Calendario/programar', {
    tipo,
    id_origen: origen,
    fecha_progr: `${dos(d.getDate())}-${dos(d.getMonth() + 1)}-${d.getFullYear()}`,
    hora_progr: '08:00',
    evento: 1,
    cant_meses: '',
    horas: 0,
  })) as { status: boolean; msj?: string };
  expect(r.status, `programar el origen ${origen} (tipo ${tipo}): ${r.msj ?? ''}`).toBe(true);
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

// ── Datos propios de cada prueba: sirven también en una empresa recién creada y vacía ─────────────

type Respuesta = Record<string, unknown>;

/** Sufijo corto y único para los datos que crean las pruebas. */
export const sufijo = (): string => Date.now().toString(36).toUpperCase();

function aDato<T>(valor: T | T[]): T {
  return Array.isArray(valor) ? valor[0] : valor;
}

/** Filas de una respuesta de lista: las acciones de MAN contestan "nada" cuando no hay. */
function lista<T>(respuesta: unknown): T[] {
  return Array.isArray(respuesta) ? (respuesta as T[]) : [];
}

async function altaRapida(man: ShellMan, accion: string, parametros: Record<string, string>): Promise<string> {
  const r = String(await man.pedir(`traz-tools-man/Equipo/${accion}`, { parametros })).trim();
  expect(r, `${accion} tiene que devolver el número creado`).toMatch(/^[1-9]\d*$/);
  return r;
}

export interface Maestros {
  area: string;
  proceso: string;
  criticidad: string;
  etapa: string;
  grupo: string;
  marca: string;
  cliente: string;
}

let maestrosCreados: Promise<Maestros> | undefined;

/** Los maestros que exige un equipo, creados una vez por corrida con las altas rápidas de su formulario. */
export function maestros(man: ShellMan): Promise<Maestros> {
  maestrosCreados ??= (async () => {
    const s = sufijo();
    return {
      area: await altaRapida(man, 'agregar_area', { descripcion: `Área DocTest ${s}` }),
      proceso: await altaRapida(man, 'agregar_proceso', { descripcion: `Proceso DocTest ${s}` }),
      criticidad: await altaRapida(man, 'agregar_criti', { descripcion: `Criticidad DocTest ${s}` }),
      etapa: await altaRapida(man, 'agregar_etapa', { descripcion: `Etapa DocTest ${s}` }),
      grupo: await altaRapida(man, 'agregar_grupo', { descripcion: `Grupo DocTest ${s}` }),
      marca: await altaRapida(man, 'agregar_marca', { marcadescrip: `Marca DocTest ${s}`, estado: 'AC' }),
      cliente: await altaRapida(man, 'agregar_cliente', { cliRazonSocial: `Cliente DocTest ${s}` }),
    };
  })();
  return maestrosCreados;
}

export interface FilaEquipo {
  id_equipo: string;
  codigo: string;
  deeq: string;
  estadoEquipo: string;
  meta_disp: string | null;
}

/** El equipo como lo muestra el listado (`Equipo/paginado`, sin los dados de baja), o undefined. */
export async function equipoEnListado(man: ShellMan, codigo: string): Promise<FilaEquipo | undefined> {
  const r = (await man.pedir('traz-tools-man/Equipo/paginado', {
    draw: 1,
    start: 0,
    length: 25,
    search: { value: codigo },
  })) as { data?: FilaEquipo[] };
  return (r.data ?? []).find((f) => f.codigo === codigo);
}

export interface EquipoCreado {
  id: string;
  codigo: string;
}

/** Da de alta un equipo con los mismos datos que manda el formulario. */
export async function crearEquipo(man: ShellMan): Promise<EquipoCreado> {
  const m = await maestros(man);
  const codigo = `DT-${sufijo()}`;
  // La unidad industrial no se elige: el formulario la manda en un campo oculto, y se usa ese valor.
  const formulario = String(await man.pedir('traz-tools-man/Equipo/cargarequipo/Add-Edit-Del'));
  const unin = formulario.match(/id="unin"[^>]*value="(\d*)"/)?.[1] ?? '';
  const r = (await man.pedir('traz-tools-man/Equipo/guardar_equipo', {
    codigo,
    descripcion: `Equipo DocTest ${codigo}`,
    marca: m.marca,
    ubicacion: 'Planta 1',
    area: m.area,
    proceso: m.proceso,
    criticidad: m.criticidad,
    etapa: m.etapa,
    grupo: m.grupo,
    cliente: m.cliente,
    unin,
    numse: `SN-${codigo}`,
    fecha_ingreso: '2026-01-10',
    fecha_garantia: '2027-01-10',
    fecha_ultima: '',
    ultima_lectura: '0',
    destec: '',
  })) as { status?: string; code?: string; msj?: string };
  expect(r.code, `alta del equipo ${codigo}: ${r.msj ?? ''}`).toBe('200');
  const fila = await equipoEnListado(man, codigo);
  expect(fila, `el equipo ${codigo} aparece en el listado`).toBeTruthy();
  return { id: fila!.id_equipo, codigo };
}

/** Crea una tarea estándar y devuelve su número. */
export async function crearTarea(man: ShellMan): Promise<string> {
  const descripcion = `Tarea DocTest ${sufijo()}`;
  const ok = await man.pedir('traz-tools-man/Tareaestandar/Guardar_Tarea', { descripcion });
  expect(ok, 'alta de la tarea estándar').toBe(true);
  const tareas = lista<{ label: string; value: string }>(await man.pedir('traz-tools-man/Preventivo/gettarea', {}));
  const t = tareas.find((x) => x.label === descripcion);
  expect(t, 'la tarea estándar nueva aparece en la lista').toBeTruthy();
  return t!.value;
}

/** Primera unidad de tiempo disponible. */
export async function unidadTiempo(man: ShellMan): Promise<string> {
  const u = lista<{ id_unidad: string }>(await man.pedir('traz-tools-man/Predictivo/getUnidTiempo', {}));
  expect(u.length, 'hay unidades de tiempo').toBeGreaterThan(0);
  return u[0].id_unidad;
}

/** El período mensual de la empresa (o el primero que tenga). */
export async function periodo(man: ShellMan): Promise<string> {
  const p = lista<{ idperiodo: string; descripcion: string }>(await man.pedir('traz-tools-man/Calendario/getperiodo', { periodoId: 0 }));
  expect(p.length, 'la empresa tiene períodos para los planes').toBeGreaterThan(0);
  return (p.find((x) => x.descripcion === 'Mensual') ?? p[0]).idperiodo;
}

/** Filas `<tr id="...">` de una pantalla armada del lado del servidor. */
export async function idsDeListado(man: ShellMan, ruta: string): Promise<number[]> {
  const html = String(await man.pedir(ruta));
  return [...html.matchAll(/<tr id="(\d+)"/g)].map((m) => Number(m[1]));
}

async function nuevoId(man: ShellMan, ruta: string, crear: () => Promise<void>): Promise<number> {
  const antes = new Set(await idsDeListado(man, ruta));
  await crear();
  const nuevo = (await idsDeListado(man, ruta)).filter((x) => !antes.has(x)).sort((a, b) => b - a)[0];
  expect(nuevo, `aparece una fila nueva en ${ruta}`).toBeGreaterThan(0);
  return nuevo;
}

const RUTA_PREDICTIVO = 'traz-tools-man/Predictivo/index/Add-Edit-Del';
const RUTA_BACKLOG = 'traz-tools-man/Backlog/index/Add-Edit-Del';
const RUTA_PREVENTIVO = 'traz-tools-man/Preventivo/index/Add-Edit-Del';
export const LISTADOS = { predictivo: RUTA_PREDICTIVO, backlog: RUTA_BACKLOG, preventivo: RUTA_PREVENTIVO };

const hoyBarras = (): string => {
  const d = new Date();
  return `${dos(d.getDate())}/${dos(d.getMonth() + 1)}/${d.getFullYear()}`;
};

/** Crea un componente en el catálogo y devuelve su número. */
export async function crearComponente(man: ShellMan): Promise<string> {
  const { marca } = await maestros(man);
  const descripcion = `Componente DocTest ${sufijo()}`;
  await man.pedir('traz-tools-man/Componente/agregar_componente', {
    parametros: { descripcion, informacion: 'Creado por DocTest', marcaid: marca, pdf: '' },
  });
  const catalogo = lista<{ label: string; value: string }>(await man.pedir('traz-tools-man/Componente/getcomponente', {}));
  const c = catalogo.find((x) => x.label.startsWith(descripcion));
  expect(c, 'el componente nuevo aparece en el catálogo').toBeTruthy();
  return c!.value;
}

/** Un sistema de la empresa; si no hay ninguno, lo crea. */
export async function sistema(man: ShellMan): Promise<string> {
  const buscar = async () => lista<{ sistemaid: string }>(await man.pedir('traz-tools-man/Componente/getsistema', {}));
  let s = await buscar();
  if (!s.length) {
    await man.pedir('traz-tools-man/SistemaABM/agregarSistema', { descripcion: `Sistema DocTest ${sufijo()}` });
    s = await buscar();
  }
  expect(s.length, 'la empresa tiene un sistema').toBeGreaterThan(0);
  return s[0].sistemaid;
}

/** Crea un preventivo mensual sobre el equipo. */
export async function crearPreventivo(man: ShellMan, equipo: EquipoCreado): Promise<number> {
  const componente = await crearComponente(man);
  const datos = {
    id_equipo: equipo.id,
    tarea: await crearTarea(man),
    periodo: await periodo(man),
    cantidad: 1,
    ultimo: isoDia(new Date()),
    id_componente: componente,
    alerta: '',
    hshombre: 1,
    duracion: 60,
    unidad: await unidadTiempo(man),
    cantOper: 1,
    lectura_base: '',
  };
  return nuevoId(man, RUTA_PREVENTIVO, async () => {
    const r = (await man.pedir('traz-tools-man/Preventivo/guardar_preventivo', datos)) as Respuesta;
    expect(r?.resPrenvent, 'alta del preventivo').toBeTruthy();
  });
}

/** Crea un predictivo sobre el equipo. */
export async function crearPredictivo(man: ShellMan, equipo: EquipoCreado): Promise<number> {
  const datos = {
    equipo: equipo.id,
    id_tarea: await crearTarea(man), // el predictivo guarda en `tarea_descrip` el número de tarea estándar
    vfecha: hoyBarras().replace(/\//g, '-'),
    periodo: await periodo(man),
    cantidad: 1,
    hshombre: 1,
    duracion: 60,
    cantOper: 1,
    unidad: await unidadTiempo(man),
  };
  return nuevoId(man, RUTA_PREDICTIVO, async () => {
    expect(await man.pedir('traz-tools-man/Predictivo/guardar_predictivo', datos), 'alta del predictivo').toBeTruthy();
  });
}

/** Anota un pendiente en el backlog del equipo. */
export async function crearBacklog(man: ShellMan, equipo: EquipoCreado): Promise<number> {
  const datos = {
    equipo: equipo.id,
    id_tarea: await crearTarea(man),
    vfecha: hoyBarras(),
    hshombre: 1,
    duracion: 60,
    unidad: await unidadTiempo(man),
    cantOper: 1,
    idcomponenteequipo: '',
    tareaOpcional: '',
  };
  return nuevoId(man, RUTA_BACKLOG, async () => {
    expect(await man.pedir('traz-tools-man/Backlog/guardar_backlog', datos), 'alta del backlog').toBeTruthy();
  });
}

export interface SolicitudCreada {
  id_solicitud: string;
  case_id: string;
  estado: string;
  id_orden: string | null;
  urgente: string | null;
}

/** La solicitud del equipo con esa falla (el buscador del listado busca por equipo, no por la falla). */
export async function buscarSolicitud(man: ShellMan, equipo: EquipoCreado, falla: string): Promise<SolicitudCreada | undefined> {
  const r = (await man.pedir('traz-tools-man/Sservicio/paginado', {
    draw: 1,
    start: 0,
    length: 10,
    search: { value: equipo.codigo },
    showConformes: 'true',
  })) as { data?: Array<SolicitudCreada & { causa: string }> };
  return (r.data ?? []).find((f) => f.causa === falla);
}

/** Crea una solicitud de servicio: da el alta y lanza su caso de Bonita. */
export async function crearSolicitud(man: ShellMan, equipo: EquipoCreado, falla: string): Promise<SolicitudCreada> {
  const r = (await man.pedir('traz-tools-man/Sservicio/lanzarProcesoBPM', { equipo: equipo.id, id_equipo: equipo.id, falla })) as {
    status: boolean;
    msj?: string;
  };
  expect(r.status, `alta de la solicitud: ${r.msj ?? ''}`).toBe(true);
  const s = await buscarSolicitud(man, equipo, falla);
  expect(s, 'la solicitud aparece en el listado').toBeTruthy();
  expect(Number(s!.case_id), 'la solicitud tiene su caso de Bonita').toBeGreaterThan(0);
  return s!;
}

export { aDato };
