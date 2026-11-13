/**
 * Caso de uso: TAR-UC-025 — Metas del pedido y de sus hitos sobre los KPI de la empresa (TAR-METAS)
 * Diseño y análisis de impacto: doc/specs/TAR-metas-pedido-hito.md
 *
 * Quien planifica el pedido carga, en el recuadro "Metas del pedido" de la planificación, el valor
 * a alcanzar y la fecha; el sistema guarda el valor de hoy del indicador como punto de partida.
 * Decisiones del PM (2026-11-12): meta en el pedido y opcional en cada hito; varias metas por
 * indicador si son de pedidos o hitos distintos.
 *
 * Datos: un pedido y un hito propios de la corrida (letra M), creados acá. El indicador es
 * `alm_reorder` (motor de KPIs de Tools): existe en toda empresa aunque valga 0.
 */

import { expect, test } from '@playwright/test';

import { contextoDeRol, paginaDeRol } from '../../fixtures/roles-tar.ts';
import { CLIENTES_TAR, TIPOS_TAR } from '../../seeds/tar/datos-tar.ts';
import { codigoPedido, PedidosTrabajoPage } from '../../pages/tar/PedidosTrabajoPage.ts';
import { ddmmyyyy, enDias, iso, PlanificacionPage } from '../../pages/tar/PlanificacionPage.ts';
import { sufijoDeCorrida } from '../../pages/tar/ShellTar.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';

const SUF = sufijoDeCorrida();
const PEDIDO = codigoPedido(SUF, 'M');
const HITO = `HM${SUF}`.slice(0, 12);
const KPI = 'alm_reorder';

test.describe.configure({ mode: 'serial' });

test.describe('@tar @TAR-UC-025 Metas del pedido y de sus hitos', () => {
  let petrId = '';

  async function planificacion(browser: import('@playwright/test').Browser, testInfo: import('@playwright/test').TestInfo): Promise<PlanificacionPage> {
    const pl = new PlanificacionPage(await paginaDeRol(browser, 'planificador'));
    await pl.abrirPlanificacion(testInfo);
    await pl.elegirPedido(PEDIDO);
    await pl.esperarMetas();
    return pl;
  }

  test('TAR-CP-025-00 prepara un pedido y un hito propios', async ({ browser }, testInfo) => {
    const ped = new PedidosTrabajoPage(await paginaDeRol(browser, 'planificador'));
    try {
      await ped.abrirListado(testInfo);
      await ped.buscar(PEDIDO);
      if ((await ped.fila(PEDIDO).count()) === 0) {
        await ped.crearPedido({ codigo: PEDIDO, objetivo: '10', unidad: 'Dias', cliente: CLIENTES_TAR[0], tipo: TIPOS_TAR[0], descripcion: `Metas DocTest ${SUF}` });
        await ped.cerrarDialogos();
      }
    } finally {
      await ped.page.context().close();
    }
    const pl = new PlanificacionPage(await paginaDeRol(browser, 'planificador'));
    try {
      await pl.abrirPlanificacion(testInfo);
      await expect(pl.celdaPedido(PEDIDO), 'el pedido de la corrida no está en la planificación').toHaveCount(1, { timeout: 30_000 });
      petrId = String((await pl.datosPedido(PEDIDO))?.petr_id ?? '');
      await pl.elegirPedido(PEDIDO);
      if (!(await pl.filaHito(HITO).count())) {
        await pl.nuevoHito({ codigo: HITO, descripcion: `Hito metas ${SUF}`, fechaInicio: ddmmyyyy(enDias(1)), objetivo: '2' });
        await pl.cerrarDialogos();
      }
      await expect(pl.filaHito(HITO)).toHaveCount(1, { timeout: 30_000 });
    } finally {
      await pl.page.context().close();
    }
    expect(petrId).toMatch(/^\d+$/);
  });

  test('TAR-CP-025-01 al elegir el pedido aparece el recuadro de metas, vacío', async ({ browser }, testInfo) => {
    const pl = await planificacion(browser, testInfo);
    try {
      await expect(pl.page.locator('#frm-meta'), 'no aparece el formulario para cargar metas').toBeVisible();
      await expect(pl.page.locator('#frm-meta [name="kpi"] option[value="' + KPI + '"]'), 'el indicador no se ofrece').toHaveCount(1);
      await expect(pl.page.locator('#frm-meta [name="hito_id"] option').filter({ hasText: HITO }), 'el hito del pedido no se ofrece').toHaveCount(1);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-025-02 meta para todo el pedido: queda con su punto de partida, la meta y estado vigente', async ({ browser }, testInfo) => {
    const pl = await planificacion(browser, testInfo);
    try {
      const antes = await pl.filasMeta.count();
      const r = await pl.agregarMeta({ kpi: KPI, operador: '<=', meta: '3', hasta: iso(enDias(60)), responsable: 'Jefe de almacén' });
      expect(r.texto, `guardarMeta no respondió ok: ${r.texto.slice(0, 300)}`).toMatch(/"ok":\s*true/);
      await pl.cerrarDialogos();
      await expect(pl.filasMeta).toHaveCount(antes + 1, { timeout: 30_000 });
      const fila = pl.filasMeta.filter({ hasText: 'Todo el pedido' }).first();
      await expect(fila.locator('.valor-meta')).toHaveText('3');
      await expect(fila.locator('.estado')).toHaveText(/Vigente|Cumplida/);
      // El punto de partida es el valor del indicador hoy (número); "—" solo si el motor no lo calculó.
      await expect(fila.locator('.partida')).toHaveText(/^(\d[\d.,]*|—)$/);
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-025-03 meta de un hito, sobre el mismo indicador: se permite y se ve con su hito', async ({ browser }, testInfo) => {
    const pl = await planificacion(browser, testInfo);
    try {
      const etiqueta = await pl.page.locator('#frm-meta [name="hito_id"] option').filter({ hasText: HITO }).first().textContent();
      const r = await pl.agregarMeta({ kpi: KPI, operador: '<=', meta: '5', hasta: iso(enDias(30)), hito: (etiqueta ?? '').trim() });
      expect(r.texto, `guardarMeta no respondió ok: ${r.texto.slice(0, 300)}`).toMatch(/"ok":\s*true/);
      await pl.cerrarDialogos();
      await expect(pl.filasMeta.filter({ hasText: HITO }), 'la meta del hito no aparece').toHaveCount(1, { timeout: 30_000 });
    } finally {
      await pl.page.context().close();
    }
  });

  test('TAR-CP-025-04 datos inválidos (fecha vencida, meta no numérica, indicador inexistente): no se guarda', async ({ browser }) => {
    const ctx = await contextoDeRol(browser, 'planificador');
    try {
      const base = requerirUrlDeApp('tools').replace(/\/$/, '');
      const url = `${base}/index.php/traz-comp-bpm/Pedidotrabajo/guardarMeta/${petrId}`;
      const casos: Array<[string, Record<string, string>, RegExp]> = [
        ['fecha vencida', { kpi: KPI, operador: '>=', meta: '10', hasta: '2020-01-01' }, /fecha/i],
        ['meta no numérica', { kpi: KPI, operador: '>=', meta: 'mucho', hasta: iso(enDias(10)) }, /número/i],
        ['indicador inexistente', { kpi: 'no_existe', operador: '>=', meta: '10', hasta: iso(enDias(10)) }, /indicador/i],
      ];
      for (const [nombre, form, motivo] of casos) {
        const texto = await (await ctx.request.post(url, { form })).text();
        const r = JSON.parse(texto) as { ok: boolean; error?: string };
        expect(r.ok, `${nombre}: se aceptó`).toBe(false);
        expect(r.error ?? '', `${nombre}: el error no explica el motivo`).toMatch(motivo);
      }
    } finally {
      await ctx.close();
    }
  });

  test('TAR-CP-025-05 aislamiento: otra empresa no ve las metas del pedido ni puede cargarle una', async ({ browser }) => {
    expect(petrId).toMatch(/^\d+$/);
    const ctx2 = await contextoDeRol(browser, 'empresa2');
    try {
      const base = requerirUrlDeApp('tools').replace(/\/$/, '');
      const html = await (await ctx2.request.get(`${base}/index.php/traz-comp-bpm/Pedidotrabajo/metas/${petrId}`)).text();
      expect(html, 'la empresa 2 ve metas del pedido de la empresa 1').not.toContain('Jefe de almacén');
      expect((html.match(/<tr class="meta"/g) ?? []).length, 'la empresa 2 ve filas de metas del pedido de la empresa 1').toBe(0);
      const texto = await (await ctx2.request.post(`${base}/index.php/traz-comp-bpm/Pedidotrabajo/guardarMeta/${petrId}`, {
        form: { kpi: KPI, operador: '>=', meta: '1', hasta: iso(enDias(10)) },
      })).text();
      expect((JSON.parse(texto) as { ok: boolean }).ok, 'la empresa 2 pudo cargar una meta en un pedido ajeno').toBe(false);
    } finally {
      await ctx2.close();
    }
  });

  test('TAR-CP-025-06 cancelar una meta: deja de verse en el pedido', async ({ browser }, testInfo) => {
    const pl = await planificacion(browser, testInfo);
    try {
      const fila = pl.filasMeta.filter({ hasText: HITO }).first();
      await expect(fila).toHaveCount(1);
      const antes = await pl.filasMeta.count();
      await fila.locator('i[title="Cancelar meta"]').click();
      await pl.dialogo();
      const resp = pl.page.waitForResponse((r) => /Pedidotrabajo\/cancelarMeta\//.test(r.url()), { timeout: 30_000 });
      await pl.aceptarDialogo();
      expect(await (await resp).text()).toMatch(/"ok":\s*true/);
      await expect(pl.filasMeta).toHaveCount(antes - 1, { timeout: 30_000 });
    } finally {
      await pl.page.context().close();
    }
  });
});
