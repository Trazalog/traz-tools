/**
 * Casos de uso: ALM-UC-009 — Registrar la recepción de materiales de un proveedor
 *               ALM-UC-010 — Entregar materiales contra un pedido
 *
 * EL CIRCUITO COMPLETO DE ENTREGA, CON SU PROPIO STOCK. No depende de que la empresa
 * tenga datos cargados: se los crea. Recorre, en orden, todo el BPMN "Pedido de Recursos
 * Materiales" del lado del almacén:
 *
 *     Recepción (crea stock) ─► Pedido ─► Aprueba ─► Entrega parcial ─► Entrega del resto
 *          ALM-UC-009            UC-006    (BPM)         UC-010              UC-010
 *
 * ⚠️ Etiquetado `@ciclo` y fuera de `test:all`: opera sobre datos reales —da de alta un
 * artículo y un proveedor, RECIBE mercadería (crea stock), crea un pedido, lo aprueba y
 * ENTREGA (descuenta stock)—. Se corre a demanda con `npm run test:ciclo`.
 *
 * ── Por qué esta preparación existe ──────────────────────────────────────────────────
 * La entrega no se puede probar en el aire: el '+' que abre la carga de una entrega está
 * `hidden` cuando `cant_disponible == 0` (view_entrega_pedido_pendiente.php:53). Una
 * empresa freemium nace SIN stock, así que antes había que dejar la entrega en
 * `test.fixme()`. La única fuente de stock del módulo es la recepción (ALM-UC-009), y ésa
 * necesita un artículo (ALM-UC-002) y un proveedor. El caso genera las tres cosas —ver
 * `pages/alm/FlujoAlmacen.ts`— para que la entrega tenga de dónde salir y el circuito
 * corra siempre como regresión, contemplando el flujo de datos de punta a punta.
 *
 * ── Estado ───────────────────────────────────────────────────────────────────────────
 * H-070 resuelto (el proceso de Bonita arranca; clave alineada a BPM_USER_PASS, PR #42 de
 * dnato) y verificado en vivo el 2026-09-12: el pedido pasa Solicitado → Aprobado y la
 * tarea se convierte en "Entrega pedido pendiente".
 *
 * Referencias de código:
 *   · Recepción:        traz-comp-almacenes/controllers/Remito.php (guardar_mejor)
 *   · Entrega:          traz-comp-almacenes/controllers/new/Entrega_Material.php
 *   · Vista entregar:   views/proceso/tareas/pedido_materiales/view_entrega_pedido_pendiente.php
 *                       #realizarEntrega → a.btnEntrega(ver_info) abre #modal_view con la
 *                       tabla de lotes (Articulo/getLotes); input .cantidad + #btn-extraccion
 *                       (guardar_entrega, sólo apila en el data-json de la fila);
 *                       #btncerrarTarea=parcial (cerrarTareaParcial) / #btnHecho=total
 *                       (cerrarTarea). Ambos confirman con un modal SweetAlert (.swal2-*),
 *                       que NO es un diálogo nativo del navegador.
 *   · Botones wrapper:  traz-comp-bpm/views/notificacion_estandar.php
 *   · Descuento stock:  Ordeninsumos::actualizar_lote() (alm.alm_lotes)
 *   · Estados:          admin_helper.php::estadoPedido()
 */
import { expect, test, type Page } from '@playwright/test';

import { AlmacenesPage } from '../../pages/alm/AlmacenesPage.ts';
import { asegurarArticulo, asegurarProveedor, recepcionar, crearPedidoDe } from '../../pages/alm/FlujoAlmacen.ts';
import { sesionDeRol } from '../../fixtures/roles-alm.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';

/** Datos de esta corrida, únicos, para reconocer lo que crea y no confundirlo con otro. */
const SELLO = new Date().toISOString().slice(2, 16).replace(/[-:T]/g, '');
const CODIGO = `DT-ENT-${Date.now().toString().slice(-8)}`;
const MARCA = `DocTest entrega ${SELLO}`;

/** Números del circuito: se recibe de más, se pide una parte, y se entrega en dos tramos. */
const CANT_RECEPCION = 20;
const CANT_PEDIDA = 6;
const CANT_PARCIAL = 2; // primera entrega (parcial): deja saldo
const CANT_RESTO = CANT_PEDIDA - CANT_PARCIAL; // segunda entrega (completa)

/** Abre la Bandeja de Tareas del Responsable por el shell de Tools (vive en traz-comp-bpm). */
async function abrirBandeja(page: Page): Promise<void> {
  const base = requerirUrlDeApp('tools');
  await page.goto(base, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(
    () => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function',
    undefined,
    { timeout: 60_000 },
  );
  await page.evaluate(() => {
    (window as unknown as { linkTo: (r: string) => void }).linkTo('traz-comp-bpm/Proceso');
  });
  await page.waitForTimeout(2500);
}

/**
 * Abre la tarea "Entrega pedido pendiente" de ESTA corrida, la toma, y entrega `cantidad`
 * del artículo desde su lote. `finalizar` decide con qué botón se cierra: `parcial` deja
 * saldo (el circuito vuelve a "Entrega pendiente"); `total` completa el pedido.
 */
async function entregar(page: Page, cantidad: number, finalizar: 'parcial' | 'total'): Promise<void> {
  await abrirBandeja(page);
  const tarea = page
    .locator('#tareas tbody tr')
    .filter({ hasText: MARCA })
    .filter({ hasText: /Entrega pedido pendiente/i });
  await expect(tarea.first(), 'la tarea de entrega de esta corrida tiene que estar en la bandeja').toBeVisible({
    timeout: 30_000,
  });
  await tarea.first().click();

  await page.locator('.btn-tomar').first().click().catch(() => {});
  await page.waitForTimeout(2500);

  // Realizar Entrega: muestra los '+' de cada ítem y el botón de finalizar parcial.
  await page.locator('#realizarEntrega').click();
  await page.waitForTimeout(1200);

  // '+' del primer ítem (el único de este pedido) → modal con la tabla de lotes.
  await page.locator('a.btnEntrega').first().click();
  const filaLote = page.locator('#modal_view #lotes_depositos tr').first();
  await expect(filaLote, 'el modal tiene que listar el lote que dejó la recepción').toBeVisible({ timeout: 15_000 });

  // Cantidad a extraer del lote. verificar_cantidad() corre en keyup y recién ahí habilita
  // el botón de guardar del modal.
  const inputCant = filaLote.locator('input.cantidad');
  await inputCant.fill(String(cantidad));
  await inputCant.dispatchEvent('keyup');
  await expect(page.locator('#btn-extraccion'), 'el modal habilita Guardar cuando la cantidad es válida').toBeEnabled({
    timeout: 8_000,
  });
  await page.locator('#btn-extraccion').click(); // guardar_entrega(): apila en la fila y cierra el modal
  await page.waitForTimeout(1500);

  // Finalizar. El POST real (Proceso/cerrarTarea) va dentro del confirm de SweetAlert.
  await page.locator(finalizar === 'parcial' ? '#btncerrarTarea' : '#btnHecho').click();
  await page.locator('.swal2-confirm').first().click({ timeout: 15_000 });
  await page.waitForTimeout(4000);
  // El aviso de éxito es otro SweetAlert: se acepta si aparece.
  await page.locator('.swal2-confirm').first().click({ timeout: 8_000 }).catch(() => {});
  await page.waitForTimeout(3000);
}

/** Estado del pedido de esta corrida, buscándolo por su marca en la grilla de pedidos. */
async function estadoDelPedido(page: Page): Promise<string> {
  await new AlmacenesPage(page).abrir('pedidos');
  await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });
  const buscador = page.locator('#content input[type="search"]').first();
  await expect(buscador).toBeVisible({ timeout: 30_000 });
  await buscador.fill(MARCA);
  await page.waitForTimeout(1500);
  const fila = page.locator('#content table tbody tr').filter({ hasText: MARCA }).first();
  await expect(fila, 'el pedido de esta corrida tiene que aparecer al buscarlo').toBeVisible({ timeout: 30_000 });
  return (await fila.innerText()).replace(/\s+/g, ' ');
}

test.describe.serial('@alm @ciclo @ALM-UC-009 @ALM-UC-010 El circuito de entrega, con su propio stock', () => {
  /**
   * PREPARACIÓN (ALM-UC-009). El Responsable de Almacén crea lo que el circuito necesita
   * y que una empresa freemium no trae: un artículo, un proveedor y —lo esencial— una
   * recepción que deja stock de ese artículo en un depósito. Sin este paso no hay entrega
   * posible: es la precondición del caso, cumplida en vez de asumida.
   */
  test('preparación: el almacén recibe materiales y deja stock (ALM-UC-009)', async ({ browser }) => {
    const alm = await sesionDeRol(browser, 'almacen');
    try {
      await asegurarArticulo(alm, { codigo: CODIGO, descripcion: `Artículo de ${MARCA}` });
      await asegurarProveedor(alm, { nombre: `Proveedor ${SELLO}`, cuit: `30-${SELLO.slice(0, 8)}-9` });
      await recepcionar(alm, { codigo: CODIGO, cantidad: CANT_RECEPCION, comprobante: `REM-${SELLO}` });

      // Se comprueba que la recepción dejó existencias: el artículo aparece en Stock.
      await new AlmacenesPage(alm).abrir('stock');
      await expect(alm.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });
      const buscador = alm.locator('#content input[type="search"]').first();
      if (await buscador.isVisible().catch(() => false)) {
        await buscador.fill(CODIGO);
        await alm.waitForTimeout(1500);
      }
      await expect(alm.locator('#content'), 'tras la recepción el artículo tiene que tener stock').toContainText(
        CODIGO,
        { timeout: 30_000 },
      );
    } finally {
      await alm.context().close();
    }
  });

  /**
   * PEDIDO (ALM-UC-006). El Solicitante pide el MISMO artículo que se acaba de recibir
   * —no cualquiera del catálogo—, porque es el único con stock del que se podrá entregar.
   */
  test('el Solicitante pide el artículo que tiene stock', async ({ browser }) => {
    const sol = await sesionDeRol(browser, 'solicitante');
    try {
      await crearPedidoDe(sol, { codigo: CODIGO, cantidad: CANT_PEDIDA, justificacion: MARCA });

      const estado = await estadoDelPedido(sol);
      expect(estado).toMatch(/Solicitado|Creada|Aprobado/i);
    } finally {
      await sol.context().close();
    }
  });

  /**
   * APROBACIÓN (Bonita). El Responsable toma la tarea "Aprueba pedido", aprueba, y el
   * pedido pasa a Aprobado: la tarea se convierte en "Entrega pedido pendiente".
   * Verificado en vivo el 2026-09-12.
   */
  test('el Responsable aprueba el pedido y pasa a Entrega pendiente', async ({ browser }) => {
    const rep = await sesionDeRol(browser, 'almacen');
    try {
      await abrirBandeja(rep);
      const tarea = rep
        .locator('#tareas tbody tr')
        .filter({ hasText: MARCA })
        .filter({ hasText: /Aprueba pedido/i });
      await expect(tarea.first(), 'la tarea de aprobación de esta corrida tiene que estar en la bandeja').toBeVisible({
        timeout: 30_000,
      });
      await tarea.first().click();

      await rep.locator('.btn-tomar').first().click().catch(() => {});
      await rep.waitForTimeout(2500);

      // Establecimiento y depósito ya vienen pre-seleccionados con los del pedido; sólo se
      // fuerzan si por algún motivo el depósito llegara vacío (cambiarlo dispara un AJAX).
      const depoTieneValor = async () =>
        rep
          .locator('#depositos')
          .evaluate((el) => el instanceof HTMLSelectElement && !el.disabled && !!el.value && el.value !== '0')
          .catch(() => false);
      if (!(await depoTieneValor())) {
        await rep.locator('#establecimientos').selectOption({ index: 1 });
        await rep.waitForFunction(
          () => {
            const el = document.querySelector('#depositos');
            return el instanceof HTMLSelectElement && !el.disabled && el.options.length > 1;
          },
          undefined,
          { timeout: 15_000 },
        );
        await rep.locator('#depositos').selectOption({ index: 1 });
      }

      await rep.locator('input[name="result"][value="true"]').check();
      await rep.locator('#btnHecho').click();
      await rep.waitForTimeout(6000);

      await abrirBandeja(rep);
      const entrega = rep
        .locator('#tareas tbody tr')
        .filter({ hasText: MARCA })
        .filter({ hasText: /Entrega pedido pendiente/i });
      await expect(entrega.first(), 'aprobado el pedido, tiene que aparecer la tarea de entrega').toBeVisible({
        timeout: 30_000,
      });
      await expect(entrega.first()).toContainText(/Aprobado/i);
    } finally {
      await rep.context().close();
    }
  });

  /**
   * ENTREGA PARCIAL (ALM-UC-010, flujo alternativo). Se entrega MENOS de lo pedido
   * (CANT_PARCIAL de CANT_PEDIDA). El pedido queda con saldo: pasa a "Ent. Parcial" y el
   * circuito —por el gateway ¿Entrega completa?=N— vuelve a dejar una tarea de entrega
   * pendiente para el resto.
   */
  test('una entrega parcial deja el pedido en Ent. Parcial con saldo pendiente', async ({ browser }) => {
    const rep = await sesionDeRol(browser, 'almacen');
    try {
      await entregar(rep, CANT_PARCIAL, 'parcial');

      const estado = await estadoDelPedido(rep);
      expect(estado, 'una entrega parcial tiene que dejar el pedido en estado parcial').toMatch(/Parcial/i);
    } finally {
      await rep.context().close();
    }
  });

  /**
   * ENTREGA DEL RESTO (ALM-UC-010, flujo principal). Se entrega el saldo restante y se
   * finaliza con "Hecho": el gateway ¿Entrega completa?=sí cierra el circuito y el pedido
   * queda Entregado. La tarea desaparece de la bandeja.
   */
  test('la entrega del resto completa el pedido y lo deja Entregado', async ({ browser }) => {
    const rep = await sesionDeRol(browser, 'almacen');
    try {
      await entregar(rep, CANT_RESTO, 'total');

      const estado = await estadoDelPedido(rep);
      expect(estado, 'entregado el saldo, el pedido tiene que quedar Entregado/Finalizado').toMatch(
        /Entregado|Finalizado/i,
      );
    } finally {
      await rep.context().close();
    }
  });
});
