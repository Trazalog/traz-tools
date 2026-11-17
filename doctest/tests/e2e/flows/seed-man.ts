/**
 * seed-man.ts — los datos de Mantenimiento que una empresa recién registrada no trae.
 *
 * Lo corre el modo `full` sobre la empresa 1. Crea, con las mismas acciones que usan las pantallas de
 * Tools: un artículo con stock, un pañol con una herramienta, un equipo, un preventivo de plantilla con
 * ese insumo y esa herramienta, y una orden con pedido, entrega y vale del pañol (MAN-UC-038/039).
 *
 * Reemplaza a `seed-asset.ts`: Mantenimiento ya no se opera en asset sino en `traz-tools-man`.
 * El artículo y el stock los carga el Responsable de Almacén, que es el dueño de esos datos
 * (`pages/alm/FlujoAlmacen.ts`). La entrega se registra directo, sin pasar por la bandeja del almacén:
 * ese recorrido ya lo prueba ALM-UC-010.
 */

import { expect, type Page } from '@playwright/test';

import { asignarOrden } from '../pages/man/BandejaMan.ts';
import {
  copiarPreventivo, crearComponente, crearEquipo, crearTarea, idsDeListado, LISTADOS, isoDia, periodo,
  programarOrden, sufijo, unidadTiempo,
} from '../pages/man/datos.ts';
import { ShellMan } from '../pages/man/ShellMan.ts';
import { asegurarArticulo, asegurarProveedor, recepcionar } from '../pages/alm/FlujoAlmacen.ts';

export interface SembradoMan {
  equipoCodigo: string;
  herramientaCodigo: string;
  /** Preventivo de plantilla: las pruebas lo copian, porque programar una orden única lo cierra. */
  preventivo: string;
  /** Número de usuario de Mantenimiento (sisusers.usrId) del administrador, para que le lleguen las tareas. */
  responsable: string;
  /** Orden con pedido, entrega y vale del pañol. */
  otMateriales: string;
}

interface Autocompletar {
  value: number | string;
  codigo?: string;
  label: string;
}

type FilaUsuario = Record<string, string>;

const lista = <T>(r: unknown): T[] => (Array.isArray(r) ? (r as T[]) : []);

/** Las opciones con valor de un `<select id="...">` de un fragmento de HTML. */
function opcionesDe(html: string, id: string): string[] {
  const select = html.match(new RegExp(`<select[^>]*id="${id}"[^>]*>([\\s\\S]*?)</select>`))?.[1] ?? '';
  return [...select.matchAll(/<option[^>]*value="([^"]+)"/g)].map((m) => m[1]);
}

/** Crea un pañol y una herramienta en él. */
async function crearHerramienta(man: ShellMan): Promise<{ pano: string; herr: string; codigo: string }> {
  const s = sufijo();
  const salida = String(await man.pedir('traz-comp-pan/Movimientoherramientas/nuevaSalida'));
  const esta = opcionesDe(salida, 'esta_id')[0];
  expect(esta, 'la empresa tiene un establecimiento (lo crea el alta)').toBeTruthy();
  await man.pedir('core/Establecimiento/guardarPanol', {
    data: { nombre: `Pañol DocTest ${s}`, descripcion: 'Creado por DocTest', esta_id: esta },
  });
  const panoles = lista<{ pano_id: string; nombre?: string }>(
    await man.pedir('traz-comp-pan/Herramienta/obtenerPanoles', { esta_id: esta }),
  );
  const pano = panoles.find((p) => p.nombre === `Pañol DocTest ${s}`)?.pano_id ?? panoles[0]?.pano_id;
  expect(pano, 'el pañol nuevo aparece en el establecimiento').toBeTruthy();
  const codigo = `HRR-${s}`;
  // La marca es una opción de la empresa: el listado cruza con ella, y con un texto libre no aparece.
  // Una empresa nueva no trae marcas de herramientas: se carga una por la lista de valores (H50).
  await man.pedir('core/Valor/guardarValor', {
    datos: { tabla: 'marcas_herramientas', valor: `Marca ${s}`, descripcion: `Marca ${s}`, valor2: '', valor3: '', empr_id: '' },
  });
  const marcas = lista<{ tabl_id: string }>(await man.pedir('traz-comp-pan/Herramienta/obtenerMarcas', {}));
  expect(marcas.length, 'la empresa tiene marcas de herramientas').toBeGreaterThan(0);
  await man.pedir('traz-comp-pan/Herramienta/guardar', {
    datos: { pano_id: pano, codigo, descripcion: `Herramienta DocTest ${s}`, modelo: 'TP-500', marca: marcas[0].tabl_id, tipo: 'Electrica' },
  });
  const disponibles = lista<Autocompletar>(await man.pedir('traz-tools-man/Preventivo/getHerramientasB', {}));
  const h = disponibles.find((x) => x.codigo === codigo);
  expect(h, `la herramienta ${codigo} aparece como disponible`).toBeTruthy();
  return { pano: String(pano), herr: String(h!.value), codigo };
}

/** El preventivo de plantilla, con su herramienta y su insumo. */
async function crearPlantilla(man: ShellMan, equipo: string, herr: string, arti: string): Promise<number> {
  const antes = new Set(await idsDeListado(man, LISTADOS.preventivo));
  const r = (await man.pedir('traz-tools-man/Preventivo/guardar_preventivo', {
    id_equipo: equipo,
    tarea: await crearTarea(man),
    periodo: await periodo(man),
    cantidad: 1,
    ultimo: isoDia(new Date()),
    id_componente: await crearComponente(man),
    alerta: '',
    hshombre: 1,
    duracion: 60,
    unidad: await unidadTiempo(man),
    cantOper: 1,
    lectura_base: '',
    id_her: [herr],
    cant_herr: [1],
    id_insumo: [arti],
    cant_insumo: [2],
  })) as { resPrenvent?: unknown };
  expect(r?.resPrenvent, 'alta del preventivo de plantilla').toBeTruthy();
  const nuevo = (await idsDeListado(man, LISTADOS.preventivo)).filter((x) => !antes.has(x))[0];
  expect(nuevo, 'el preventivo de plantilla aparece en el listado').toBeGreaterThan(0);
  return nuevo;
}

/** Registra la entrega de lo pedido, desde el lote del artículo. */
async function entregarPedido(man: ShellMan, almacen: ShellMan, otId: string, arti: string): Promise<void> {
  const pedidos = lista<{ pema_id: string }>(
    await man.pedir('traz-tools-man/Ordenservicio/getEntregasPorOT', { id_ot: otId }),
  );
  const pema = pedidos[0]?.pema_id;
  expect(pema, 'la orden tiene su pedido de materiales').toBeTruthy();
  // Los lotes los ve el encargado del depósito: la entrega la registra el Responsable de Almacén.
  const lotes = String(await almacen.pedir(`traz-comp-almacenes/Articulo/getLotes/${arti}`));
  const json = lotes.match(/lote_id&quot;:&quot;(\d+)|"lote_id":"?(\d+)/);
  const depo = lotes.match(/depo_id&quot;:&quot;(\d+)|"depo_id":"?(\d+)/);
  const lote = json?.[1] ?? json?.[2];
  expect(lote, 'el artículo tiene un lote con stock').toBeTruthy();
  const r = (await almacen.pedir('traz-comp-almacenes/new/Entrega_Material/guardarEntrega', {
    pema_id: pema,
    completa: 'false',
    info_entrega: JSON.stringify({ comprobante: 'S/C', fecha: isoDia(new Date()), solicitante: 'DocTest', dni: '', pema_id: pema }),
    detalles: [{ arti_id: arti, lote_id: lote, depo_id: depo?.[1] ?? depo?.[2] ?? '', cantidad: 1, prov_id: '', precio: 0 }],
    cantidades: [{ arti_id: arti, resto: 1 }],
  })) as { status?: boolean };
  expect(r.status, `entrega del pedido ${pema}`).toBe(true);
}

/** El pañolero entrega la herramienta con un vale asociado a la orden (origen PANOLERO). */
async function valeDelPanol(man: ShellMan, pano: string, herr: string, otId: string): Promise<void> {
  const sapa = await man.pedir('traz-comp-pan/Order/guardar', {
    // Sin formulario dinámico la pantalla manda info_id vacío y el servicio lo rechaza (H52): va un 0.
    datos: { pano_id: pano, observaciones: 'Vale DocTest', info_id: '0' },
    tools: JSON.stringify([herr]),
    ot_id: otId,
  });
  expect(Number(sapa), 'el pañol registra el vale').toBeGreaterThan(0);
}

export async function sembrarMan(man: ShellMan, paginaAlmacen: Page, empresa: string): Promise<SembradoMan> {
  const s = sufijo();
  const codigoArticulo = `DT-INS-${s}`;
  await asegurarArticulo(paginaAlmacen, { codigo: codigoArticulo, descripcion: `Insumo DocTest ${s}` });
  await asegurarProveedor(paginaAlmacen, { nombre: `Proveedor DocTest ${s}`, cuit: '30-71234567-8' });
  await recepcionar(paginaAlmacen, { codigo: codigoArticulo, cantidad: 50, comprobante: `DT-${s}` });

  await man.enElShell();
  const articulos = lista<Autocompletar>(await man.pedir('traz-tools-man/Preventivo/getinsumo', {}));
  const arti = articulos.find((a) => a.codigo === codigoArticulo);
  expect(arti, `el artículo ${codigoArticulo} se ofrece como insumo`).toBeTruthy();

  const usuarios = lista<FilaUsuario>(await man.pedir('traz-tools-man/Otrabajo/getusuario', {}));
  // La lista solo trae nombres. Los usuarios de rol del alta llevan la empresa en el apellido; el administrador, no.
  const fila = usuarios.find((u) => !u.usrLastName.includes(empresa));
  expect(fila, 'el administrador de la empresa está en Mantenimiento').toBeTruthy();
  const responsable = String(fila!.usrId);

  const { pano, herr, codigo } = await crearHerramienta(man);
  const equipo = await crearEquipo(man);
  const plantilla = await crearPlantilla(man, equipo.id, herr, String(arti!.value));

  // Lanzada con su caso y su pedido; queda asignada, sin avanzar: las pruebas solo leen sus materiales.
  const orden = await programarOrden(man, await copiarPreventivo(man, plantilla), 1);
  const asignada = await asignarOrden(man, orden, responsable, 'Orden de materiales de DocTest');
  expect(asignada.status, `asignar la orden: ${asignada.msj ?? ''}`).toBe(true);
  expect(asignada.pedido?.status, `pedido de la orden: ${asignada.pedido?.msj ?? 'no se envió'}`).toBe(true);
  await entregarPedido(man, new ShellMan(paginaAlmacen), orden.id_orden, String(arti!.value));
  await valeDelPanol(man, pano, herr, orden.id_orden);

  return {
    equipoCodigo: equipo.codigo,
    herramientaCodigo: codigo,
    preventivo: String(plantilla),
    responsable,
    otMateriales: orden.id_orden,
  };
}
