/**
 * Caso de uso: ALM-UC-008 — Aprobar y entregar un pedido de materiales
 *
 * Continúa donde termina ALM-UC-006-007 (el pedido llega a la bandeja del Responsable).
 * Cubre el tramo del Responsable de Almacén en el proceso BPMN "Pedido de Recursos
 * Materiales":
 *
 *     Aprueba pedido ──► ¿aprobado? ──sí──► Entrega pedido pendiente ──► ¿completa?
 *          │                  │                        ▲                     │  │
 *          │                  no                       └────── N (parcial) ──┘  sí
 *          │                  ▼                                                 ▼
 *          └──────────►  Comunica Rechazo ─► Pedido Rechazado          Entrega completa
 *
 * ⚠️ Etiquetado `@ciclo` y fuera de `test:all`: opera sobre datos reales (aprueba, entrega
 * y DESCUENTA STOCK). Se corre a demanda con `npm run test:ciclo`.
 *
 * ════════════════════════════════════════════════════════════════════════════════════
 * ESTADO AL 2026-09-12 — H-070 RESUELTO. La aprobación funciona y está verificada en vivo.
 *
 * El proceso de Bonita ya arranca (PR #42 de dnato: la clave de Bonita del alta freemium
 * quedó alineada a BPM_USER_PASS), así que la tarea llega a la bandeja del Responsable y
 * se puede aprobar. Verificado el 2026-09-12: el pedido pasa Solicitado → Aprobado y la
 * tarea se convierte en 'Entrega pedido pendiente'.
 *
 * Pasos:
 *   · `puertaDeEntrada` (la tarea llega a la bandeja) y `aprueba` están VERIFICADOS.
 *   · La ENTREGA (total y parcial) queda en `test.fixme()`. Reconocido en vivo el
 *     2026-09-12: la tabla de ítems muestra el '+' de lote SOLO si el artículo tiene
 *     stock en el depósito (`view_entrega_pedido_pendiente.php:53`: la clase es `hidden`
 *     cuando `cant_disponible == 0`). Una empresa freemium nace SIN stock (H-068), así
 *     que no hay nada que entregar hasta cargarlo. Para probar la entrega total/parcial
 *     de verdad falta una PRECONDICIÓN: crear stock (recepción de materiales o ajuste),
 *     que es un flujo aparte a automatizar. No es un bloqueo del circuito de entrega en
 *     sí —que ya funciona hasta la aprobación— sino la falta del dato de stock.
 * ════════════════════════════════════════════════════════════════════════════════════
 *
 * Referencias de código (para la verificación en vivo pendiente):
 *   · Bandeja:            traz-comp-bpm/controllers/Proceso.php (index, paginarServerSide)
 *   · Detalle de tarea:   traz-comp-bpm/Proceso/detalleTarea/{taskId}
 *   · Cerrar tarea:       POST traz-comp-bpm/Proceso/cerrarTarea/{taskId}
 *   · Vista aprobar:      views/proceso/tareas/pedido_materiales/view_aprueba_pedido.php
 *                         radios input[name="result"] (true=aprobar / false=rechazar)
 *   · Vista entregar:     views/proceso/tareas/pedido_materiales/view_entrega_pedido_pendiente.php
 *                         cerrarTarea()=total, cerrarTareaParcial()=parcial
 *   · Botones (wrapper):  traz-comp-bpm/views/notificacion_estandar.php
 *                         #btnHecho (total) / #btncerrarTarea (parcial) / #btnTomarTarea
 *   · Descuento de stock: Ordeninsumos::actualizar_lote() (alm.alm_lotes)
 *   · Estados:            admin_helper.php::estadoPedido()
 *                         Solicitado → Aprobado → Ent. Parcial (loop) → Entregado
 */
import { expect, test, type Page } from '@playwright/test';

import { AlmacenesPage } from '../../pages/alm/AlmacenesPage.ts';
import { sesionDeRol } from '../../fixtures/roles-alm.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';

const MARCA = `DocTest entrega ${new Date().toISOString().slice(2, 16).replace(/[-:T]/g, '')}`;

/** Abre la Bandeja de Tareas del Responsable por el shell de Tools (no por URL directa;
 *  ver la explicación en AlmacenesPage.abrir()). La bandeja vive en OTRO módulo
 *  (traz-comp-bpm), con un prefijo de ruta distinto al de Almacenes, así que se invoca
 *  `linkTo` directamente en vez de por el page object de Almacenes. */
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

/** Crea un pedido como Solicitante y devuelve su justificación (única, para reconocerlo). */
async function crearPedido(page: Page, justificacion: string): Promise<void> {
  await new AlmacenesPage(page).abrir('pedidos');
  await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });
  await page.getByRole('button', { name: /Agregar/i }).first().click();
  await expect(page.locator('#just')).toBeVisible({ timeout: 15_000 });
  await page.locator('#just').fill(justificacion);
  const opciones = page.locator('datalist option');
  await expect(opciones.first()).toHaveCount(1, { timeout: 15_000 });
  const articulo = (await opciones.first().getAttribute('value')) ?? '';
  await page.locator('#inputarti').fill(articulo);
  await page.locator('#add_cantidad').fill('2');
  await page.locator('button[onclick*="guardar_pedido"]').click();
  await page.waitForTimeout(2000);
  await page.locator('#establecimiento').selectOption({ index: 1 });
  await page.waitForTimeout(1500);
  await page.locator('#deposito').selectOption({ index: 0 });
  await page.locator('button[onclick*="lanzarPedido"]').click();
  await page.waitForTimeout(5000);
}

test.describe.serial('@alm @ciclo @ALM-UC-008 Aprobar y entregar un pedido de materiales', () => {
  /**
   * El pedido que crea el Solicitante llega como tarea "Aprueba pedido…" a la bandeja del
   * Responsable. Es el arranque del circuito de entrega. Fue H-070 (el proceso no
   * arrancaba); resuelto y verificado el 2026-09-12.
   */
  test('el pedido aprobado llega como tarea a la bandeja del Responsable', async ({ browser }) => {
    const sol = await sesionDeRol(browser, 'solicitante');
    try {
      await crearPedido(sol, MARCA);
    } finally {
      await sol.context().close();
    }

    const rep = await sesionDeRol(browser, 'almacen');
    try {
      await abrirBandeja(rep);
      // La bandeja NO tiene buscador (bandeja_entrada.php: searching:false), así que se
      // reconoce la tarea por el contenido de las filas, no por un input de búsqueda.
      const filasReales = rep
        .locator('#tareas tbody tr')
        .filter({ hasNotText: /Ning[úu]n dato disponible/i });
      await expect(
        filasReales.first(),
        'la tarea de aprobación tiene que llegar a la bandeja del Responsable para poder aprobar y entregar',
      ).toBeVisible({ timeout: 30_000 });
    } finally {
      await rep.context().close();
    }
  });

  /**
   * El Responsable toma la tarea de aprobación, aprueba, y el pedido pasa a 'Aprobado':
   * la tarea se convierte en "Entrega pedido pendiente". Selectores verificados en vivo
   * (2026-09-12): Tomar tarea → establecimiento + depósito (obligatorios) → radio
   * result=true → #btnHecho (cerrarTarea → apruebaPedido=true).
   */
  test('el Responsable aprueba el pedido y pasa a Entrega pendiente', async ({ browser }) => {
    const rep = await sesionDeRol(browser, 'almacen');
    try {
      await abrirBandeja(rep);
      const tarea = rep
        .locator('#tareas tbody tr')
        .filter({ hasText: MARCA })
        .filter({ hasText: /Aprueba pedido/i });
      await expect(tarea.first(), 'la tarea de aprobación del pedido de esta corrida tiene que estar en la bandeja').toBeVisible({ timeout: 30_000 });
      await tarea.first().click();

      // Tomar la tarea antes de operarla (la asigna al usuario en Bonita).
      await rep.locator('button[onclick*="tomarTarea"]').first().click().catch(() => {});
      await rep.waitForTimeout(2500);

      // Establecimiento y depósito son obligatorios, pero la vista los PRE-SELECCIONA con
      // los del pedido. No hay que forzarlos —cambiar el establecimiento dispara un AJAX
      // que repuebla los depósitos y genera una carrera—: solo se espera a que el depósito
      // tenga un valor real. Si por algún motivo llegara vacío, ahí sí se elige.
      const depoTieneValor = async () =>
        rep.locator('#depositos').evaluate(
          (el) => el instanceof HTMLSelectElement && !el.disabled && !!el.value && el.value !== '0',
        ).catch(() => false);
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

      // Aprobar (result=true) y confirmar.
      await rep.locator('input[name="result"][value="true"]').check();
      await rep.locator('#btnHecho').click();
      await rep.waitForTimeout(6000);

      // Verificación: en la bandeja, la tarea del pedido pasa a "Entrega pedido pendiente"
      // con estado Aprobado. Es el efecto de haber aprobado, no solo que el click no falló.
      await abrirBandeja(rep);
      const entrega = rep
        .locator('#tareas tbody tr')
        .filter({ hasText: MARCA })
        .filter({ hasText: /Entrega pedido pendiente/i });
      await expect(entrega.first(), 'aprobado el pedido, tiene que aparecer la tarea de entrega').toBeVisible({ timeout: 30_000 });
      await expect(entrega.first()).toContainText(/Aprobado/i);
    } finally {
      await rep.context().close();
    }
  });

  /**
   * ENTREGA PARCIAL — pendiente de verificación en vivo (bloqueado por H-070).
   *
   * En "Entrega pedido pendiente" se entrega MENOS de lo pedido: por cada ítem, el botón
   * `.btnEntrega` (ver_info) abre el modal de lote/cantidad; se carga una cantidad menor
   * a la pedida y se finaliza con #btncerrarTarea ("Finalizar Pedido con Entrega
   * Parcial", cerrarTareaParcial()). El pedido pasa a 'Ent. Parcial' y —por el loop del
   * gateway ¿Entrega completa?=N— vuelve a quedar como tarea pendiente de entrega.
   * Verificación dura esperada: el stock del lote BAJA en la cantidad entregada
   * (Ordeninsumos::actualizar_lote), y el pedido NO queda cerrado.
   */
  // PRECONDICIÓN FALTANTE: el artículo necesita stock en el depósito para que aparezca el
  // '+' de lote (hoy oculto por cant_disponible==0, H-068). Falta automatizar una recepción
  // que cree stock antes de este paso. Selectores de entrega ya reconocidos:
  //   tabla de ítems (7 columnas, sin id) · '+' = a.btnEntrega[onclick=ver_info] ·
  //   #realizarEntrega · #btncerrarTarea (parcial) · #btnHecho (total).
  test.fixme('una entrega parcial descuenta stock y deja el pedido pendiente', async () => {
    // Selectores del código, sin verificar: .btnEntrega / ver_info(modal lote) /
    //   #btncerrarTarea. Estado esperado: 'Ent. Parcial'.
  });

  /**
   * ENTREGA DEL RESTO (total) — pendiente de verificación en vivo (bloqueado por H-070).
   *
   * Se entrega el saldo restante y se confirma con #btnHecho (cerrarTarea(), completa).
   * El gateway ¿Entrega completa?=sí cierra el circuito: el pedido pasa a 'Entregado' y
   * la tarea desaparece de la bandeja. Verificación dura: el stock refleja el total
   * entregado y el pedido queda 'Entregado'.
   */
  test.fixme('la entrega del resto completa el pedido y lo deja Entregado', async () => {
    // Selectores del código, sin verificar: #btnHecho. Estado esperado: 'Entregado'.
  });

  /**
   * RECHAZO — pendiente de verificación en vivo (bloqueado por H-070).
   *
   * Rama alternativa del gateway ¿Pedido aprobado?=no: en view_aprueba_pedido se marca el
   * radio result=false y se completa el motivo_rechazo. El proceso va a "Comunica
   * Rechazo" y el pedido queda 'Rechazado'. No se entrega nada ni se toca el stock.
   */
  test.fixme('un pedido rechazado queda en estado Rechazado y no toca el stock', async () => {
    // Selectores del código, sin verificar:
    //   input[name="result"][value="false"] · textarea[name="motivo_rechazo"] · #btnHecho
  });
});
