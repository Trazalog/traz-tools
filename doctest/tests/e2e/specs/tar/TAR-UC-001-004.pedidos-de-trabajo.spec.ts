/**
 * Casos de uso: TAR-UC-001 — Listar y buscar pedidos de trabajo
 *               TAR-UC-002 — Crear un pedido de trabajo
 *               TAR-UC-003 — Ver el detalle de un pedido de trabajo
 *               TAR-UC-004 — Eliminar un pedido de trabajo
 * Catálogo: catalogo/tar/TAR-UC-001..004.yaml (en borrador)
 * Casos de prueba del spec: doc/specs/TAR-spec-modulo-tareas.md §7.3 a §7.6
 *
 * Datos: clientes y tipos de trabajo del seed (`npm run seed:tar`). Los pedidos se crean con el
 * sufijo de la corrida. El paginado se verifica leyendo su respuesta JSON, que es lo que la grilla
 * dibuja: así se ven los contadores aunque la empresa tenga pocos pedidos.
 */

import { expect, test } from '@playwright/test';

import { contextoDeRol, paginaDeRol } from '../../fixtures/roles-tar.ts';
import { CLIENTES_TAR, TIPOS_TAR } from '../../seeds/tar/datos-tar.ts';
import { codigoPedido, PedidosTrabajoPage } from '../../pages/tar/PedidosTrabajoPage.ts';
import { sufijoDeCorrida } from '../../pages/tar/ShellTar.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';

const SUF = sufijoDeCorrida();
const COD = codigoPedido(SUF, 'A');
const COD_BORRAR = codigoPedido(SUF, 'B');

/** Saltea el test si el pedido de la corrida no existe: es la consecuencia de TAR-CP-002-01 (H-091), no un bug nuevo. */
async function requierePedido(ped: PedidosTrabajoPage, codigo: string): Promise<void> {
  await ped.buscar(codigo);
  test.skip((await ped.fila(codigo).count()) === 0, `bloqueado: el pedido ${codigo} no se pudo crear (TAR-CP-002-01, H-091)`);
}

function datos(codigo: string) {
  return { codigo, objetivo: '5', unidad: 'Dias', cliente: CLIENTES_TAR[0], tipo: TIPOS_TAR[0], descripcion: `Pedido DocTest ${codigo}` };
}

test.describe('@tar @TAR-UC-001 @TAR-UC-002 @TAR-UC-003 @TAR-UC-004 Pedidos de trabajo', () => {
  let ped: PedidosTrabajoPage;

  test.beforeAll(async ({ browser }) => {
    ped = new PedidosTrabajoPage(await paginaDeRol(browser, 'planificador'));
  });

  test.afterAll(async () => {
    await ped?.page.context().close();
  });

  test('TAR-CP-002-01 alta completa con el proceso estándar: avisa el éxito y el pedido aparece en el listado (HIP-TAR-09)', async ({}, testInfo) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-091 #578 (B-01): la empresa de test no tiene PROCESO-STANDAR y el alta no crea el pedido');
    await ped.abrirListado(testInfo);
    const respuesta = await ped.crearPedido(datos(COD));

    expect.soft(() => JSON.parse(respuesta), `la respuesta del alta no es JSON válido: ${respuesta.slice(0, 300)}`).not.toThrow();
    const aviso = await ped.dialogoSiAparece(8_000);
    await ped.cerrarDialogos();
    // Sin recargar a mano: el listado tiene que mostrarlo solo.
    const visibleSinRecargar = await ped.fila(COD).count();

    await ped.abrirListado(testInfo);
    await ped.buscar(COD);
    await expect(ped.fila(COD), 'el pedido no quedó creado').toHaveCount(1);

    expect.soft(aviso, 'el alta no muestra ningún mensaje al usuario').not.toBeNull();
    expect(visibleSinRecargar, 'el pedido no aparece en el listado hasta recargar la pantalla').toBeGreaterThan(0);
  });

  test('TAR-CP-002-03 sin obligatorios: "Debes completar los campos obligatorios (*)" y no se crea nada', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    let pedidos = 0;
    ped.page.on('request', (r) => {
      if (/guardarPedidoTrabajo/.test(r.url())) pedidos++;
    });
    await ped.abrirAlta();
    await ped.guardarAlta();
    expect((await ped.dialogo()).texto).toMatch(/Debes completar los campos obligatorios/i);
    await ped.cerrarDialogos();
    expect(pedidos).toBe(0);
  });

  test('TAR-CP-002-04 código de 3 caracteres: no permite guardar', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    let pedidos = 0;
    ped.page.on('request', (r) => {
      if (/guardarPedidoTrabajo/.test(r.url())) pedidos++;
    });
    await ped.abrirAlta();
    await ped.completarAlta(datos('ABC'));
    await ped.guardarAlta();
    await ped.dialogoSiAparece(5_000);
    await ped.cerrarDialogos();
    expect(pedidos, 'se envió el alta con un código de 3 caracteres').toBe(0);
  });

  test('TAR-CP-002-05 objetivo sin unidad de tiempo: pide la unidad', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    await ped.abrirAlta();
    await ped.completarAlta({ ...datos(codigoPedido(SUF, 'X')), unidad: undefined });
    await ped.guardarAlta();
    expect((await ped.dialogo()).texto).toMatch(/Si completo objetivo, seleccione medida de tiempo/i);
    await ped.cerrarDialogos();
  });

  test('TAR-CP-002-06 fecha de entrega anterior al inicio: avisa y borra la fecha', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    await ped.abrirAlta();
    await ped.form.locator('#fec_entrega').fill('2020-01-01');
    await ped.form.locator('#fec_entrega').dispatchEvent('change');
    expect((await ped.dialogo()).texto).toMatch(/no puede ser anterior a la fecha de inicio/i);
    await ped.cerrarDialogos();
    await expect(ped.form.locator('#fec_entrega')).toHaveValue('');
  });

  test('TAR-CP-002-07 código repetido en la empresa: error claro, sin segundo pedido (HIP-TAR-07)', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    await requierePedido(ped, COD);
    await ped.abrirListado(testInfo);
    const respuesta = await ped.crearPedido(datos(COD));
    const aviso = await ped.dialogoSiAparece(8_000);
    await ped.cerrarDialogos();

    await ped.abrirListado(testInfo);
    await ped.buscar(COD);
    await expect(ped.fila(COD), 'se creó un segundo pedido con el mismo código').toHaveCount(1);
    expect.soft(() => JSON.parse(respuesta), `respuesta no JSON: ${respuesta.slice(0, 300)}`).not.toThrow();
    expect(aviso?.texto ?? '', 'el usuario no recibe un mensaje de error claro').toMatch(/No se Guard|exist|repetid|duplicad/i);
  });

  test('TAR-CP-001-03 buscar por parte del código: aparece solo ese pedido', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    await requierePedido(ped, COD);
    const pag = await ped.buscar(COD.slice(1));
    expect(pag.recordsFiltered).toBeGreaterThanOrEqual(1);
    await expect(ped.fila(COD)).toHaveCount(1);
    for (const fila of (pag.data ?? []) as Array<Record<string, string>>) {
      expect(JSON.stringify(fila)).toContain(COD.slice(1));
    }
  });

  test('TAR-CP-001-04 buscar textos con "/", "%", espacio o tilde no rompe el listado (HIP-TAR-10)', async ({}, testInfo) => {
    const problemas: string[] = [];
    for (const texto of ['ab/c', '50%', 'Peña Sur']) {
      await ped.abrirListado(testInfo);
      const pag = await ped.buscar(texto);
      if (pag.recordsTotal === -1) problemas.push(`"${texto}": respuesta no JSON`);
      const alerta = await ped.dialogoSiAparece(1_500);
      if (alerta) problemas.push(`"${texto}": ${alerta.titulo} ${alerta.texto}`);
      await ped.cerrarDialogos();
    }
    expect(problemas).toEqual([]);
  });

  test('TAR-CP-001-02 el paginado informa el total real de pedidos (HIP-TAR-10)', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    await requierePedido(ped, COD);
    // Pide una página de 1 registro: si `recordsTotal` es la cantidad de la página y no el total,
    // con 2 o más pedidos los contadores no coinciden.
    const pag = await ped.esperarPaginado(() =>
      ped.page.evaluate(() => {
        const w = window as unknown as { $: (s: string) => { DataTable: () => { page: { len: (n: number) => { draw: () => void } } } } };
        w.$('#tbl-pedidos').DataTable().page.len(1).draw();
      }),
    );
    expect(pag.recordsFiltered, 'la empresa tiene que tener al menos 2 pedidos para esta prueba').toBeGreaterThanOrEqual(2);
    expect(pag.recordsTotal, `recordsTotal=${pag.recordsTotal} recordsFiltered=${pag.recordsFiltered}`).toBe(pag.recordsFiltered);
  });

  test('TAR-CP-001-06 "Mostrar Pedidos Terminados" responde JSON válido y sigue paginando (HIP-TAR-10)', async ({}, testInfo) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-097 #584 (B-07): el paginado de terminados no trae data como lista');
    await ped.abrirListado(testInfo);
    const pag = await ped.mostrarTerminados();
    expect(pag.recordsTotal, `respuesta: ${JSON.stringify(pag).slice(0, 300)}`).not.toBe(-1);
    expect(Array.isArray(pag.data)).toBe(true);
  });

  test('TAR-CP-001-05 empresa sin pedidos: la grilla dice "sin datos", sin errores (HIP-TAR-10)', async ({ browser }, testInfo) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-097 #584 (B-07): sin pedidos el paginado devuelve recordsTotal 1 y data false');
    const otra = new PedidosTrabajoPage(await paginaDeRol(browser, 'empresa2'));
    const errores: string[] = [];
    otra.page.on('pageerror', (e) => errores.push(e.message));
    try {
      await otra.abrirListado(testInfo);
      await expect.poll(() => otra.ultimoPaginado, { timeout: 30_000 }).not.toBeNull();
      const alerta = await otra.dialogoSiAparece(2_000);
      const pag = otra.ultimoPaginado!;
      expect.soft(pag.recordsTotal, `respuesta: ${JSON.stringify(pag).slice(0, 300)}`).toBe(0);
      expect.soft(alerta, 'aparece un diálogo de error').toBeNull();
      expect(Array.isArray(pag.data), `la respuesta no trae "data": ${JSON.stringify(pag).slice(0, 300)}`).toBe(true);
    } finally {
      await otra.page.context().close();
    }
  });

  test('TAR-CP-001-08 aislamiento: la empresa 2 no ve los pedidos de la empresa 1', async ({ browser }, testInfo) => {
    const otra = new PedidosTrabajoPage(await paginaDeRol(browser, 'empresa2'));
    try {
      await otra.abrirListado(testInfo);
      // No se mira `recordsFiltered`: con 0 resultados el servidor igual dice 1 (TAR-CP-001-05).
      const pag = await otra.buscar(COD);
      expect(JSON.stringify(pag.data ?? [])).not.toContain(COD);
      await expect(otra.fila(COD)).toHaveCount(0);
    } finally {
      await otra.page.context().close();
    }
  });

  test('TAR-CP-003-02 detalle de un pedido sin hitos: "No se crearon hitos para este pedido de trabajo."', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    await requierePedido(ped, COD);
    await ped.buscar(COD);
    await ped.verDetalle(COD);
    await ped.pestanaDetalle(/Tareas Planificadas/i);
    await expect(ped.detalle).toContainText('No se crearon hitos para este pedido de trabajo.');
  });

  test('TAR-CP-004-03 cancelar la eliminación: el pedido sigue', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    await ped.crearPedido(datos(COD_BORRAR));
    await ped.cerrarDialogos();
    await ped.abrirListado(testInfo);
    await requierePedido(ped, COD_BORRAR);
    await ped.eliminar(COD_BORRAR, false);
    await ped.cerrarDialogos();
    await ped.abrirListado(testInfo);
    await ped.buscar(COD_BORRAR);
    await expect(ped.fila(COD_BORRAR)).toHaveCount(1);
  });

  test('TAR-CP-004-05 aislamiento: desde la empresa 2 no se puede eliminar un pedido de la empresa 1 (HIP-TAR-02)', async ({ browser }, testInfo) => {
    await ped.abrirListado(testInfo);
    await requierePedido(ped, COD_BORRAR);
    await ped.buscar(COD_BORRAR);
    const fila = await ped.datosFila(COD_BORRAR);
    const petr = String(fila?.petr_id ?? '');
    expect(petr, 'no se pudo leer el número del pedido').toMatch(/^\d+$/);

    const ctx2 = await contextoDeRol(browser, 'empresa2');
    try {
      const base = requerirUrlDeApp('tools').replace(/\/$/, '');
      await ctx2.request.get(`${base}/index.php/traz-comp-bpm/Pedidotrabajo/eliminarPedidoTrabajo/?petr_id=${petr}&case_id=`);
    } finally {
      await ctx2.close();
    }
    await ped.abrirListado(testInfo);
    await ped.buscar(COD_BORRAR);
    await expect(ped.fila(COD_BORRAR), 'la empresa 2 eliminó un pedido de la empresa 1').toHaveCount(1);
  });

  test('TAR-CP-004-01 eliminar un pedido sin hitos: desaparece del listado con mensaje de éxito', async ({}, testInfo) => {
    await ped.abrirListado(testInfo);
    await ped.buscar(COD_BORRAR);
    test.skip((await ped.fila(COD_BORRAR).count()) === 0, 'el pedido ya no existe (lo borró la prueba de aislamiento)');
    await ped.eliminar(COD_BORRAR, true);
    const aviso = await ped.dialogoSiAparece(15_000);
    await ped.cerrarDialogos();
    await ped.abrirListado(testInfo);
    await ped.buscar(COD_BORRAR);
    await expect(ped.fila(COD_BORRAR)).toHaveCount(0);
    expect(aviso?.texto ?? '').toMatch(/Se Elimino Pedido Correctamente/i);
  });
});
