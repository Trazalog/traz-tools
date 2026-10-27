/**
 * Casos de uso: TAR-UC-005 (Trabajo Terminado), 006/007 (hitos), 009 (agregar tareas),
 *               010 (planificar), 011 (asignar), 014 (eliminar tarea), 016/017/018 (bandeja,
 *               iniciar y finalizar) y el aislamiento por URL de HIP-TAR-02.
 * Catálogo: catalogo/tar/TAR-UC-005..018.yaml (en borrador)
 * Casos de prueba del spec: doc/specs/TAR-spec-modulo-tareas.md §7.7 a §7.18
 *
 * Es el circuito completo de una tarea, recorrido por tres personas: el planificador arma el
 * pedido, el hito y las tareas, las planifica y las asigna; el responsable la ve en su bandeja,
 * la toma, la inicia y la finaliza; el planificador ve el resultado. Los tests van en orden y
 * comparten los datos de la corrida, pero **cada uno los busca en la pantalla** en vez de
 * heredarlos en memoria: si uno falla, los siguientes siguen pudiendo correr.
 *
 * Requisitos de datos: `npm run seed:tar` (clientes y tipos de trabajo) y `PROCESO-STANDAR` en
 * `pro.procesos` de la empresa (seeds/tar/pro-procesos-empresas-test.sql). Sin ese proceso el alta
 * del pedido falla y todo lo demás queda sin datos.
 */

import { expect, test, type Browser } from '@playwright/test';
import { writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { requerirUrlDeApp } from '../../config/apps.ts';
import { contextoDeRol, paginaDeRol, usuarioDeRol } from '../../fixtures/roles-tar.ts';
import { BandejaTareaPage } from '../../pages/tar/BandejaTareaPage.ts';
import { codigoPedido, PedidosTrabajoPage } from '../../pages/tar/PedidosTrabajoPage.ts';
import { ddmmyyyy, enDias, PlanificacionPage, type TareaPlanificada } from '../../pages/tar/PlanificacionPage.ts';
import { sufijoDeCorrida, type PantallaTar } from '../../pages/tar/ShellTar.ts';
import { TareasEstandarPage } from '../../pages/tar/TareasEstandarPage.ts';
import { CLIENTES_TAR, TIPOS_TAR } from '../../seeds/tar/datos-tar.ts';

const SUF = sufijoDeCorrida();
const PEDIDO = codigoPedido(SUF, 'C');
const HITO = `H${SUF}`.slice(0, 10);
const HITO_BORRAR = `E${SUF}`.slice(0, 10);
const STD_INSP = `DT Insp C${SUF}`;
const STD_LIMP = `DT Limp C${SUF}`;
const PLANTILLA = `DT PL C${SUF}`;
const LIBRE = `Revisar bomba ${SUF}`;

/** Hora (0-23) de un `fec_inicio` como lo devuelve el DataService: `DD-MM-YYYY+HH12:MI:SS`. */
function horaDe(fec?: string): number | null {
  const m = /[+ T](\d{2}):(\d{2})/.exec(fec ?? '');
  return m ? Number(m[1]) : null;
}

function minutoDe(fec?: string): number | null {
  const m = /[+ T](\d{2}):(\d{2})/.exec(fec ?? '');
  return m ? Number(m[2]) : null;
}

async function planificador(browser: Browser): Promise<PlanificacionPage> {
  return new PlanificacionPage(await paginaDeRol(browser, 'planificador'));
}

/**
 * Origen sintético para el ciclo de la tarea cuando la empresa no puede crear pedidos.
 *
 * Decisión documentada en doc/specs/TAR-bugs-detectados.md (2026-10-27): la empresa de test no
 * tiene `PROCESO-STANDAR` en `pro.procesos`, no hay API ni pantalla para crearlo y la base del DEMO
 * no es alcanzable. Sin pedido no hay hito, y sin hito no se puede probar nada del ciclo. Como el
 * componente de planificación es el mismo para cualquier origen, se abre sobre un `hito_id` que no
 * existe —sin ceros, para no caer en HIP-TAR-01— y todo lo que se crea queda en la empresa de test.
 * Los tests que necesitan el pedido real se saltean diciendo por qué.
 */
const ORIGEN_SINTETICO = '987654321';
let hayPedido: boolean | null = null;

async function pedidoDisponible(pl: PlanificacionPage): Promise<boolean> {
  if (hayPedido === null) {
    await pl.abrirPlanificacion();
    hayPedido = (await pl.page.locator('#tbl-pedidos tbody td[data-json]').filter({ hasText: PEDIDO }).count()) > 0;
  }
  return hayPedido;
}

function requierePedido(): void {
  test.skip(hayPedido === false, 'bloqueado: la empresa no puede crear pedidos de trabajo (sin PROCESO-STANDAR, TAR-CP-002-01)');
}

/** Abre la planificación del hito de la corrida, o la del origen sintético si no hay pedido. */
async function enElHito(pl: PlanificacionPage, hito = HITO): Promise<void> {
  if (!(await pedidoDisponible(pl))) {
    await pl.abrirPlanificacionDeOrigen(ORIGEN_SINTETICO, test.info());
    return;
  }
  await pl.abrirPlanificacion();
  await pl.elegirPedido(PEDIDO);
  await pl.elegirHito(hito);
}

/**
 * Los casos de bandeja necesitan que la tarea tenga caso de Bonita. Si no lo tiene (hoy en el DEMO
 * ninguna tarea lo consigue: TAR-CP-009-10 y TAR-CP-011-01), se saltean diciendo por qué.
 */
async function requiereCaso(browser: Browser, nombre: string): Promise<void> {
  const pl = await planificador(browser);
  let caso = '';
  try {
    caso = String((await tareaRecargada(pl, nombre))?.case_id ?? '');
  } finally {
    await pl.page.context().close();
  }
  test.skip(!/^\d+$/.test(caso), `bloqueado: "${nombre}" no tiene caso de Bonita, no puede llegar a ninguna bandeja (TAR-CP-011-01)`);
}

async function tareaRecargada(pl: PlanificacionPage, nombre: string, hito = HITO): Promise<TareaPlanificada | null> {
  await enElHito(pl, hito);
  return pl.datosTarea(nombre);
}

test.describe('@tar @TAR-UC-005 @TAR-UC-006 @TAR-UC-009 @TAR-UC-010 @TAR-UC-011 @TAR-UC-014 @TAR-UC-016 @TAR-UC-017 @TAR-UC-018 Ciclo de una tarea', () => {
  test('@TAR-menu el planificador ve los menús del módulo de Tareas', async ({ browser }) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-101 #588 (B-11): la asignación del rol Planificador de Tareas falla en DNATO');
    const pl = await planificador(browser);
    try {
      const faltan: string[] = [];
      for (const p of ['pedidos', 'planificacion', 'tareasEstandar', 'indicadores'] as PantallaTar[]) {
        if (!(await pl.tieneMenu(p))) faltan.push(p);
      }
      expect(faltan, `al planificador (${usuarioDeRol('planificador')}) le faltan menús`).toEqual([]);
    } finally {
      await pl.page.context().close();
    }
  });

  test('prepara los datos de la corrida: pedido, tareas estándar y plantilla', async ({ browser }, testInfo) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-091 #578 (B-01): no se puede crear el pedido de la corrida');
    const tst = new TareasEstandarPage(await paginaDeRol(browser, 'planificador'));
    try {
      await tst.abrir('tareasEstandar', testInfo);
      if (!(await tst.filaTarea(STD_INSP).count())) {
        await tst.crearTareaOk({ nombre: STD_INSP, descripcion: 'Inspección (DocTest)', duracion: '02:00' });
        await tst.abrirSubtareas(STD_INSP);
        for (const n of ['Aislar', 'Revisar']) {
          await tst.agregarSubtarea(`${n} ${SUF}`);
          await tst.esperarCarga();
          await tst.cerrarDialogos();
        }
        await tst.cerrarSubtareas();
      }
      if (!(await tst.filaTarea(STD_LIMP).count())) await tst.crearTareaOk({ nombre: STD_LIMP, descripcion: 'Limpieza (DocTest)', duracion: '01:00' });
      await tst.abrir('tareasEstandar', testInfo);
      await tst.irAPlantillas();
      if (!(await tst.filaPlantilla(PLANTILLA).count())) {
        await tst.crearPlantilla(PLANTILLA);
        await tst.verTareasDePlantilla(PLANTILLA);
        await tst.asociarTarea(STD_INSP);
        await tst.asociarTarea(STD_LIMP);
        await tst.cerrarTareasDePlantilla();
      }
    } finally {
      await tst.page.context().close();
    }

    const ped = new PedidosTrabajoPage(await paginaDeRol(browser, 'planificador'));
    try {
      await ped.abrirListado(testInfo);
      await ped.buscar(PEDIDO);
      if (!(await ped.fila(PEDIDO).count())) {
        await ped.crearPedido({ codigo: PEDIDO, objetivo: '10', unidad: 'Dias', cliente: CLIENTES_TAR[0], tipo: TIPOS_TAR[0], descripcion: `Ciclo DocTest ${SUF}` });
        await ped.cerrarDialogos();
        await ped.abrirListado(testInfo);
        await ped.buscar(PEDIDO);
      }
      await expect(ped.fila(PEDIDO), 'no se pudo crear el pedido de la corrida: ¿la empresa tiene PROCESO-STANDAR?').toHaveCount(1);
    } finally {
      await ped.page.context().close();
    }
  });

  test('TAR-CP-006-01 crear un hito con todos los campos y un PDF: aparece en el pedido', async ({ browser }, testInfo) => {
    hayPedido ??= await (async () => { const p = await planificador(browser); try { return await pedidoDisponible(p); } finally { await p.page.context().close(); } })();
    requierePedido();
    const pl = await planificador(browser);
    try {
      await pl.abrirPlanificacion(testInfo);
      await pl.elegirPedido(PEDIDO);
      if (!(await pl.filaHito(HITO).count())) {
        const pdf = join(tmpdir(), `doctest-hito-${SUF}.pdf`);
        writeFileSync(pdf, '%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n');
        const r = await pl.nuevoHito({ codigo: HITO, descripcion: `Hito DocTest ${SUF}`, fechaInicio: ddmmyyyy(enDias(1)), objetivo: '3', documento: pdf });
        expect.soft(r.texto, 'el alta del hito no devolvió status true').toMatch(/"status":\s*true/);
        await pl.cerrarDialogos();
      }
      await expect(pl.filaHito(HITO)).toHaveCount(1, { timeout: 30_000 });
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-006-02 hito sin código o con código de 3 caracteres: no se guarda', async ({ browser }, testInfo) => {
    hayPedido ??= await (async () => { const p = await planificador(browser); try { return await pedidoDisponible(p); } finally { await p.page.context().close(); } })();
    requierePedido();
    const pl = await planificador(browser);
    try {
      await pl.abrirPlanificacion(testInfo);
      await pl.elegirPedido(PEDIDO);
      const antes = await pl.page.locator('#tbl-hitos tbody tr').count();
      for (const codigo of ['', 'H12']) {
        await pl.nuevoHito({ codigo, descripcion: 'no va', fechaInicio: ddmmyyyy(enDias(1)), objetivo: '1' });
        await pl.cerrarModales();
      }
      await pl.abrirPlanificacion(testInfo);
      await pl.elegirPedido(PEDIDO);
      await expect(pl.page.locator('#tbl-hitos tbody tr')).toHaveCount(antes);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-006-03 ver el detalle del hito: muestra lo cargado, en solo lectura', async ({ browser }, testInfo) => {
    hayPedido ??= await (async () => { const p = await planificador(browser); try { return await pedidoDisponible(p); } finally { await p.page.context().close(); } })();
    requierePedido();
    const pl = await planificador(browser);
    try {
      await pl.abrirPlanificacion(testInfo);
      await pl.elegirPedido(PEDIDO);
      await pl.verDetalleHito(HITO);
      const panel = pl.page.locator('#mdl-hito #pnl-hito');
      await expect(panel.locator('[name="numero"]')).toHaveValue(HITO);
      await expect(panel.locator('[name="descripcion"]')).toHaveValue(`Hito DocTest ${SUF}`);
      await expect(panel.locator('[name="numero"]')).toBeDisabled();
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-009-01 agregar una tarea libre: aparece con "Se planificó la tarea correctamente!"', async ({ browser }, testInfo) => {
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      void testInfo;
      if (!(await pl.filaTarea(LIBRE).count())) {
        const r = await pl.agregarTareaLibre(LIBRE);
        expect.soft(r.texto).toMatch(/"status":\s*true/);
        expect((await pl.dialogo()).texto).toMatch(/Se planificó la tarea correctamente/i);
        await pl.cerrarDialogos();
      }
      const t = await tareaRecargada(pl, LIBRE);
      expect(t?.tapl_id, 'la tarea libre no quedó guardada en el hito').toBeTruthy();
      expect(t?.estado).toBe('creada');
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-009-09 volver a pulsar la pestaña Calendario no borra las tareas de la vista', async ({ browser }) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-099 #586 (B-09): copiarTareas() vacía la lista');
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      const antes = await pl.filasCalendario.count();
      expect(antes, 'el hito no tiene tareas para la prueba').toBeGreaterThan(0);
      await pl.clicPestanaCalendarioActiva();
      await expect(pl.filasCalendario, 'las tareas desaparecieron de la vista').toHaveCount(antes);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-009-10 una tarea libre toma el proceso TST001', async ({ browser }) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-092 #579 (B-02): TAREAS_DEFAULT_PROC no está definida en el DEMO');
    const pl = await planificador(browser);
    try {
      const t = await tareaRecargada(pl, LIBRE);
      expect(t?.proc_id, `la tarea libre quedó con proc_id "${t?.proc_id}"`).toBe('TST001');
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-009-05 "Nueva Tarea" con nombre vacío: no agrega nada', async ({ browser }, testInfo) => {
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      let pedidos = 0;
      pl.page.on('request', (r) => {
        if (/guardarTareaPlanificada/.test(r.url())) pedidos++;
      });
      await pl.pestanaPlanificacionTareas();
      const antes = await pl.filasPlanificadas.count();
      await pl.page.locator('#tab_22 button[onclick*="agregarTareaPlanificada"]').click();
      await expect(pl.filasPlanificadas).toHaveCount(antes);
      expect(pedidos).toBe(0);
      void testInfo;
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-009-03 agregar una tarea del catálogo: copia duración, y queda una sola vez', async ({ browser }) => {
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      if (!(await pl.filaTarea(STD_INSP).count())) {
        const r = await pl.agregarTareaEstandar(STD_INSP);
        expect.soft(r.texto).toMatch(/"status":\s*true/);
        await pl.cerrarDialogos();
      }
      const t = await tareaRecargada(pl, STD_INSP);
      expect(t?.hora_duracion ?? t?.duracion).toBe('02:00');
      await expect(pl.filasCalendario.filter({ hasText: STD_INSP })).toHaveCount(1);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-009-04 "Agregar Todas" de una plantilla: agrega cada tarea una sola vez y sin errores', async ({ browser }) => {
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      const respuestas = await pl.agregarPlantilla(PLANTILLA, 2);
      const errores = await pl.dialogoSiAparece(3_000);
      await pl.cerrarDialogos();
      await enElHito(pl);
      const conteo = await pl.filasCalendario.filter({ hasText: STD_LIMP }).count();
      expect.soft(respuestas.map((r) => r.texto.slice(0, 120)), 'alguna respuesta no es JSON').toEqual(
        respuestas.map((r) => {
          try {
            JSON.parse(r.texto);
            return r.texto.slice(0, 120);
          } catch {
            return 'NO-JSON';
          }
        }),
      );
      expect.soft(errores, `la pantalla mostró un error: ${JSON.stringify(errores)}`).toBeNull();
      expect(conteo, `"${STD_LIMP}" quedó ${conteo} veces en el hito`).toBe(1);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-009-06 hito cuyo id contiene un 0: la tarea queda en ESE hito (HIP-TAR-01)', async ({ browser }, testInfo) => {
    hayPedido ??= await (async () => { const p = await planificador(browser); try { return await pedidoDisponible(p); } finally { await p.page.context().close(); } })();
    requierePedido();
    test.setTimeout(10 * 60_000);
    const pl = await planificador(browser);
    try {
      await pl.abrirPlanificacion(testInfo);
      await pl.elegirPedido(PEDIDO);
      // Se crean hitos hasta que uno tenga un 0 en su id (los ids son globales, del 10 en adelante
      // uno de cada diez lo tiene). Corta a los 12 intentos.
      let codigo = '';
      let hitoId = '';
      for (let i = 0; i < 12; i++) {
        const c = `Z${SUF.slice(-6)}${i}`.slice(0, 10);
        if (!(await pl.filaHito(c).count())) {
          await pl.nuevoHito({ codigo: c, descripcion: `Hito cero ${i}`, fechaInicio: ddmmyyyy(enDias(1)), objetivo: '1' });
          await pl.cerrarDialogos();
          await pl.abrirPlanificacion(testInfo);
          await pl.elegirPedido(PEDIDO);
        }
        const id = await pl.idHito(c);
        if (id.includes('0')) {
          codigo = c;
          hitoId = id;
          break;
        }
      }
      expect(hitoId, 'no se consiguió un hito con 0 en el id en 12 intentos').toContain('0');
      testInfo.annotations.push({ type: 'hito', description: `${codigo} = hito_id ${hitoId}` });

      await pl.elegirHito(codigo);
      const origen = await pl.origenActual();
      const nombre = `Tarea cero ${SUF}`;
      if (!(await pl.filaTarea(nombre).count())) {
        await pl.agregarTareaLibre(nombre);
        await pl.cerrarDialogos();
      }
      await pl.elegirHito(codigo);
      const vuelve = await pl.filaTarea(nombre).count();
      expect.soft(origen?.orta_id, `la planificación del hito ${hitoId} se abrió con orta_id=${origen?.orta_id}`).toBe(hitoId);
      expect(vuelve, `la tarea agregada al hito ${hitoId} no aparece al volver a abrirlo`).toBe(1);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-010-02 elegir un día anterior a hoy: "No se puede seleccionar fechas anteriores a la actual!"', async ({ browser }) => {
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      await pl.pestanaCalendario();
      await pl.filaTarea(STD_INSP).locator('.btn-planificar').click();
      await pl.clickDia(enDias(-1));
      expect((await pl.dialogo()).texto).toMatch(/No se puede seleccionar fechas anteriores a la actual/i);
      await pl.cerrarDialogos();
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-010-01/010-06 planificar mañana 10:00: queda la fecha y la hora, sigue "creada" sin responsable', async ({ browser }) => {
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      const r = await pl.planificar(STD_INSP, enDias(1), '10:00');
      expect.soft(() => JSON.parse(r.texto), `respuesta no JSON: ${r.texto.slice(0, 300)}`).not.toThrow();
      const t = await tareaRecargada(pl, STD_INSP);
      expect(t?.fecha).toBe(ddmmyyyy(enDias(1)));
      expect(horaDe(t?.fec_inicio)).toBe(10);
      expect(t?.estado).toBe('creada');
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-011-01/011-03 asignar responsable a una tarea planificada: lanza el caso', async ({ browser }) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-093 #580 (B-03): la tarea estándar no puede tener proceso TST001 y no lanza caso');
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      await pl.asignar(STD_INSP, usuarioDeRol('responsable1'));
      const pregunta = await pl.dialogo(30_000);
      expect(pregunta.titulo).toMatch(/Desea asignar la tarea a/i);
      const r = await pl.confirmarAsignacion();
      expect.soft(() => JSON.parse(r.texto), `respuesta no JSON: ${r.texto.slice(0, 300)}`).not.toThrow();
      const t = await tareaRecargada(pl, STD_INSP);
      expect(t?.user_id).toBe(usuarioDeRol('responsable1'));
      expect(t?.case_id, 'la tarea no guardó el caso de Bonita').toMatch(/^\d+$/);
      expect.soft(t?.estado, 'la tarea no pasó a "planificada"').toBe('planificada');
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-010-04 planificar a las 15:00 y después asignar: sigue a las 15:00 (HIP-TAR-18)', async ({ browser }) => {
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      await pl.planificar(STD_LIMP, enDias(2), '15:00');
      const antes = await tareaRecargada(pl, STD_LIMP);
      await pl.asignar(STD_LIMP, usuarioDeRol('responsable1'));
      await pl.dialogo(30_000);
      await pl.confirmarAsignacion();
      const despues = await tareaRecargada(pl, STD_LIMP);
      testInfo().annotations.push({ type: 'fec_inicio', description: `antes ${antes?.fec_inicio} · después ${despues?.fec_inicio}` });
      expect(despues?.fecha).toBe(ddmmyyyy(enDias(2)));
      // El DataService devuelve HH12 sin AM/PM: un 15:00 se lee "03". Se mira el evento del
      // calendario, que es lo que ve el usuario, y la fecha fin calculada.
      expect(horaDe(despues?.fec_inicio) === 15 || horaDe(despues?.fec_inicio) === 3, `fec_inicio=${despues?.fec_inicio}`).toBe(true);
      const ev = pl.eventos.find((e) => String(e.titulo) === STD_LIMP);
      expect(ev?.dia_inicio ?? '', `evento del calendario: ${JSON.stringify(ev)}`).toMatch(/[+ T]15:00/);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-011-05 asignar responsable a una tarea sin fecha: se guarda, sin caso y sin errores (HIP-TAR-06)', async ({ browser }) => {
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      await pl.asignar(LIBRE, usuarioDeRol('responsable1'));
      await pl.dialogo(30_000);
      const r = await pl.confirmarAsignacion();
      const t = await tareaRecargada(pl, LIBRE);
      expect.soft(t?.user_id).toBe(usuarioDeRol('responsable1'));
      expect.soft(t?.case_id ?? '').toBe('');
      expect(() => JSON.parse(r.texto), `la respuesta trae basura además del JSON: ${r.texto.slice(0, 400)}`).not.toThrow();
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-011-09 aislamiento: para asignar solo se ofrecen usuarios de la empresa', async ({ browser }) => {
    const pl = await planificador(browser);
    try {
      await enElHito(pl);
      await pl.pestanaCalendario();
      await pl.filaTarea(LIBRE).locator('.btn-asignar').click();
      const usuarios = await pl.usuariosAsignables();
      expect(usuarios).toContain(usuarioDeRol('responsable1'));
      expect(usuarios).not.toContain(usuarioDeRol('empresa2'));
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-006-07 aislamiento: la empresa 2 no puede ver un hito de la empresa 1 por URL (HIP-TAR-02)', async ({ browser }) => {
    hayPedido ??= await (async () => { const p = await planificador(browser); try { return await pedidoDisponible(p); } finally { await p.page.context().close(); } })();
    requierePedido();
    const pl = await planificador(browser);
    let hitoId = '';
    try {
      await pl.abrirPlanificacion();
      await pl.elegirPedido(PEDIDO);
      hitoId = await pl.idHito(HITO);
    } finally {
      await pl.page.context().close();
    }
    expect(hitoId).toMatch(/^\d+$/);
    const ctx2 = await contextoDeRol(browser, 'empresa2');
    try {
      const base = requerirUrlDeApp('tools').replace(/\/$/, '');
      const html = await (await ctx2.request.get(`${base}/index.php/traz-comp-bpm/Pedidotrabajo/hito/${hitoId}`)).text();
      expect(html, 'la empresa 2 ve el detalle del hito de la empresa 1').not.toContain(`Hito DocTest ${SUF}`);
    } finally {
      await ctx2.close();
    }
  });

  test('TAR-CP-X-01 aislamiento: la empresa 2 no ve por URL las tareas planificadas de la empresa 1 (HIP-TAR-02)', async ({ browser }) => {
    // Bug conocido: hoy tiene que fallar. Cuando se corrija, la corrida avisa y se saca esta marca.
    test.fail(true, 'H-094 #581 (B-04): getTareasPlanificadas no filtra empresa');
    const pl = await planificador(browser);
    let origen = ORIGEN_SINTETICO;
    try {
      await enElHito(pl);
      origen = (await pl.origenActual())?.orta_id ?? ORIGEN_SINTETICO;
    } finally {
      await pl.page.context().close();
    }
    const ctx2 = await contextoDeRol(browser, 'empresa2');
    try {
      const base = requerirUrlDeApp('tools').replace(/\/$/, '');
      const html = await (await ctx2.request.get(`${base}/index.php/traz-comp-tareasestandar/tarea/planificar/PETR/${origen}`)).text();
      expect(html, 'la empresa 2 recibe las tareas planificadas de la empresa 1').not.toContain(LIBRE);
    } finally {
      await ctx2.close();
    }
  });

  test('TAR-CP-014-05 aislamiento: la empresa 2 no puede eliminar una tarea de la empresa 1 por URL (HIP-TAR-02)', async ({ browser }) => {
    const pl = await planificador(browser);
    let tapl = '';
    try {
      tapl = String((await tareaRecargada(pl, LIBRE))?.tapl_id ?? '');
    } finally {
      await pl.page.context().close();
    }
    expect(tapl).toMatch(/^\d+$/);
    const ctx2 = await contextoDeRol(browser, 'empresa2');
    try {
      const base = requerirUrlDeApp('tools').replace(/\/$/, '');
      await ctx2.request.delete(`${base}/index.php/traz-comp-tareasestandar/Tarea/eliminarPlanificada/${tapl}`);
    } finally {
      await ctx2.close();
    }
    const pl2 = await planificador(browser);
    try {
      expect(await tareaRecargada(pl2, LIBRE), 'la empresa 2 eliminó una tarea de la empresa 1').not.toBeNull();
    } finally {
      await pl2.page.context().close();
    }
  });

  test('TAR-CP-016-01/016-02 el responsable ve la tarea en su bandeja con el pedido correcto (HIP-TAR-12)', async ({ browser }, testInfo) => {
    await requiereCaso(browser, STD_INSP);
    const pl = await planificador(browser);
    let petr = '';
    try {
      await pl.abrirPlanificacion();
      if (await pedidoDisponible(pl)) petr = String((await pl.datosPedido(PEDIDO))?.petr_id ?? '');
    } finally {
      await pl.page.context().close();
    }
    const b = new BandejaTareaPage(await paginaDeRol(browser, 'responsable1'));
    try {
      await b.abrirBandeja(testInfo);
      await expect(b.item(STD_INSP), 'la tarea asignada no está en la bandeja del responsable').toHaveCount(1, { timeout: 60_000 });
      const etiquetas = await b.etiquetas(STD_INSP);
      testInfo.annotations.push({ type: 'etiquetas', description: etiquetas.join(' · ') });
      expect.soft(etiquetas.join(' · ')).toContain('Origen: Pedido de trabajo');
      expect.soft(etiquetas, 'falta "Nro Pedido: <código>" con su etiqueta').toContain(`Nro Pedido: ${PEDIDO}`);
      if (petr) expect(etiquetas, `"Id Ped.Trabajo" no es el número del pedido (${petr})`).toContain(`Id Ped.Trabajo: ${petr}`);
    } finally {
      await b.page.context().close();
    }
  });

  test('TAR-CP-016-06 aislamiento: la empresa 2 no ve la tarea en su bandeja', async ({ browser }, testInfo) => {
    const b = new BandejaTareaPage(await paginaDeRol(browser, 'empresa2'));
    try {
      await b.abrirBandeja(testInfo);
      await expect(b.item(STD_INSP)).toHaveCount(0);
    } finally {
      await b.page.context().close();
    }
  });

  test('TAR-CP-011-04 reasignar: pasa a la bandeja del nuevo responsable, sale de la del anterior y no crea otro caso', async ({ browser }, testInfo) => {
    await requiereCaso(browser, STD_LIMP);
    const pl = await planificador(browser);
    let casoAntes = '';
    let casoDespues = '';
    try {
      casoAntes = String((await tareaRecargada(pl, STD_LIMP))?.case_id ?? '');
      await pl.asignar(STD_LIMP, usuarioDeRol('responsable2'));
      await pl.dialogo(30_000);
      await pl.confirmarAsignacion();
      casoDespues = String((await tareaRecargada(pl, STD_LIMP))?.case_id ?? '');
    } finally {
      await pl.page.context().close();
    }
    const b2 = new BandejaTareaPage(await paginaDeRol(browser, 'responsable2'));
    const b1 = new BandejaTareaPage(await paginaDeRol(browser, 'responsable1'));
    try {
      await b2.abrirBandeja(testInfo);
      await b1.abrirBandeja(testInfo);
      expect.soft(casoDespues, 'la reasignación cambió el caso').toBe(casoAntes);
      await expect.soft(b1.item(STD_LIMP), 'la tarea sigue en la bandeja del responsable anterior').toHaveCount(0);
      await expect(b2.item(STD_LIMP), 'la tarea no llegó a la bandeja del nuevo responsable').toHaveCount(1);
    } finally {
      await b1.page.context().close();
      await b2.page.context().close();
    }
  });

  test('TAR-CP-016-03/017-01/017-02 tomar e iniciar: pide "Inicializar tarea" y registra la hora real del clic (HIP-TAR-04, HIP-TAR-13)', async ({ browser }, testInfo) => {
    await requiereCaso(browser, STD_INSP);
    const b = new BandejaTareaPage(await paginaDeRol(browser, 'responsable1'));
    let clic = new Date();
    try {
      await b.abrirBandeja(testInfo);
      await b.abrirTarea(STD_INSP);
      const cabecera = await b.cabecera();
      testInfo.annotations.push({ type: 'cabecera', description: cabecera.slice(0, 400) });
      expect.soft(cabecera, 'la cabecera de la tarea no muestra el pedido de trabajo').toContain(PEDIDO);
      if (await b.tomar.isVisible()) {
        await b.tomar.click();
        await b.esperarCarga();
        await b.cerrarDialogos();
      }
      await expect(b.iniciar, '"Inicializar tarea" no está disponible después de tomarla').toBeEnabled({ timeout: 15_000 });
      clic = new Date();
      await b.iniciar.click();
      expect((await b.dialogo()).texto).toMatch(/Se inici[oó] la tarea correctamente/i);
      await b.cerrarDialogos();
    } finally {
      await b.page.context().close();
    }
    const pl = await planificador(browser);
    try {
      const t = await tareaRecargada(pl, STD_INSP);
      testInfo.annotations.push({ type: 'fec_inicio', description: `${t?.fec_inicio} (clic ${clic.toTimeString().slice(0, 5)})` });
      expect.soft(t?.estado).toBe('iniciada');
      expect(minutoDe(t?.fec_inicio), `fec_inicio=${t?.fec_inicio}, clic a las ${clic.toTimeString().slice(0, 5)}`).toBe(clic.getMinutes());
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-018-02 finalizar con una subtarea sin tildar: "No se marcaron como finalizadas todas las subtareas!"', async ({ browser }, testInfo) => {
    await requiereCaso(browser, STD_INSP);
    const b = new BandejaTareaPage(await paginaDeRol(browser, 'responsable1'));
    try {
      await b.abrirBandeja(testInfo);
      await b.abrirTarea(STD_INSP);
      await expect(b.subtareas).toHaveCount(2);
      await b.tildarSubtareas(1);
      await b.pulsarHecho();
      expect((await b.dialogo()).texto).toMatch(/No se marcaron como finalizadas todas las subtareas/i);
      await b.cerrarDialogos();
    } finally {
      await b.page.context().close();
    }
  });

  test('TAR-CP-018-01/018-03 finalizar: sale de la bandeja y queda "finalizada" con la hora real de fin (HIP-TAR-05)', async ({ browser }, testInfo) => {
    await requiereCaso(browser, STD_INSP);
    const b = new BandejaTareaPage(await paginaDeRol(browser, 'responsable1'));
    let planificada: TareaPlanificada | null = null;
    const pl0 = await planificador(browser);
    try {
      planificada = await tareaRecargada(pl0, STD_INSP);
    } finally {
      await pl0.page.context().close();
    }
    try {
      await b.abrirBandeja(testInfo);
      await b.abrirTarea(STD_INSP);
      await b.tildarSubtareas();
      await b.pulsarHecho();
      expect((await b.dialogo(60_000)).texto).toMatch(/Se finaliz[oó] la tarea correctamente/i);
      await b.aceptarDialogo();
      await b.abrirBandeja(testInfo);
      await expect(b.item(STD_INSP)).toHaveCount(0, { timeout: 60_000 });
    } finally {
      await b.page.context().close();
    }
    const pl = await planificador(browser);
    try {
      const t = await tareaRecargada(pl, STD_INSP);
      testInfo.annotations.push({ type: 'fec_fin', description: `planificada ${planificada?.fec_fin} · final ${t?.fec_fin}` });
      expect.soft(t?.estado).toBe('finalizada');
      expect(t?.fec_fin, 'fec_fin sigue siendo la planificada: no se registró la hora real de cierre').not.toBe(planificada?.fec_fin);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-014-01/014-03 eliminar la única tarea de un hito: desaparece y vuelve "No hay Tareas Planificadas" (HIP-TAR-20)', async ({ browser }, testInfo) => {
    hayPedido ??= await (async () => { const p = await planificador(browser); try { return await pedidoDisponible(p); } finally { await p.page.context().close(); } })();
    requierePedido();
    const pl = await planificador(browser);
    try {
      await pl.abrirPlanificacion(testInfo);
      await pl.elegirPedido(PEDIDO);
      if (!(await pl.filaHito(HITO_BORRAR).count())) {
        await pl.nuevoHito({ codigo: HITO_BORRAR, descripcion: 'Hito para borrar', fechaInicio: ddmmyyyy(enDias(1)), objetivo: '1' });
        await pl.cerrarDialogos();
        await pl.abrirPlanificacion(testInfo);
        await pl.elegirPedido(PEDIDO);
      }
      await pl.elegirHito(HITO_BORRAR);
      const nombre = `Borrar ${SUF}`;
      await pl.agregarTareaLibre(nombre);
      await pl.cerrarDialogos();
      await pl.elegirHito(HITO_BORRAR);
      const r = await pl.eliminarTarea(nombre);
      expect.soft(r?.texto ?? '').toMatch(/"status":\s*true/);
      await pl.cerrarDialogos();
      await pl.pestanaCalendario();
      await expect(pl.filasCalendario.filter({ hasText: nombre })).toHaveCount(0);
      await pl.pestanaPlanificacionTareas();
      await expect(pl.page.locator('#tareas-planificadas tfoot'), 'no vuelve el "No hay Tareas Planificadas"').toBeVisible();
      await pl.elegirHito(HITO_BORRAR);
      await expect(pl.filasCalendario.filter({ hasText: nombre }), 'la tarea eliminada vuelve al recargar').toHaveCount(0);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-005-01/005-02 "Trabajo Terminado": lo marca o explica por qué no', async ({ browser }, testInfo) => {
    hayPedido ??= await (async () => { const p = await planificador(browser); try { return await pedidoDisponible(p); } finally { await p.page.context().close(); } })();
    requierePedido();
    const pl = await planificador(browser);
    try {
      await pl.abrirPlanificacion(testInfo);
      const r = await pl.marcarTrabajoTerminado(PEDIDO);
      const aviso = await pl.dialogoSiAparece(5_000);
      testInfo.annotations.push({ type: 'respuesta', description: r.texto.slice(0, 300) });
      if (/"status":\s*false/.test(r.texto)) {
        expect(aviso?.texto ?? '', 'el sistema rechazó el cambio y no le dijo nada al usuario').toMatch(/TAREA IT|no se encuentra/i);
      } else {
        await pl.abrirPlanificacion(testInfo);
        await expect(pl.celdaPedido(PEDIDO)).toContainText(/Finalizado/i);
      }
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-004-04 eliminar un pedido con tareas asignadas: las tareas no quedan en la bandeja (HIP-TAR-08)', async ({ browser }, testInfo) => {
    hayPedido ??= await (async () => { const p = await planificador(browser); try { return await pedidoDisponible(p); } finally { await p.page.context().close(); } })();
    requierePedido();
    const ped = new PedidosTrabajoPage(await paginaDeRol(browser, 'planificador'));
    try {
      await ped.abrirListado(testInfo);
      await ped.buscar(PEDIDO);
      test.skip((await ped.fila(PEDIDO).count()) === 0, 'el pedido de la corrida no existe');
      await ped.eliminar(PEDIDO, true);
      await ped.dialogoSiAparece(15_000);
      await ped.cerrarDialogos();
    } finally {
      await ped.page.context().close();
    }
    const b2 = new BandejaTareaPage(await paginaDeRol(browser, 'responsable2'));
    try {
      await b2.abrirBandeja(testInfo);
      await expect(b2.item(STD_LIMP), 'la tarea del pedido eliminado sigue en la bandeja').toHaveCount(0);
    } finally {
      await b2.page.context().close();
    }
  });
});

function testInfo() {
  return test.info();
}
