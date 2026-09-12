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
 * ESTADO AL 2026-09-12 — BLOQUEADO AGUAS ARRIBA POR H-070.
 *
 * Todo este tramo se ejecuta desde la Bandeja de Tareas del Responsable
 * (`traz-comp-bpm/Proceso`), que se llena con las humanTasks que Bonita crea al lanzar el
 * proceso del pedido. Pero HOY el proceso no arranca: `pedidoNormal` devuelve
 * `{"status":false}` (H-070 / issue #508), así que **no llega ninguna tarea a la bandeja**
 * y no hay nada que aprobar ni entregar. Verificado en vivo el 2026-09-12: se creó un
 * pedido y la bandeja del Responsable quedó vacía.
 *
 * Por eso el caso está partido en dos:
 *   · `puertaDeEntrada` verifica lo único ejecutable hoy —que la tarea llegue a la
 *     bandeja— y **falla a propósito** (`test.fail()`) mientras H-070 siga abierto, igual
 *     que hace ALM-UC-006-007 con el lanzamiento del proceso. El día que se arregle,
 *     Playwright avisa "unexpectedly passed" y hay que habilitar el resto.
 *   · Los pasos de aprobación y entrega van con `test.fixme()`: están escritos desde el
 *     BPMN y el mapa de código (controladores, vistas y funciones JS reales), pero **sin
 *     verificación en vivo**, porque no hay tarea contra la cual correrlos. Sus selectores
 *     son los que declara el código; hay que confirmarlos en la primera corrida real una
 *     vez que H-070 esté resuelto. No se marcan como verdes para no afirmar como probado
 *     algo que no se pudo ejecutar.
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
   * PUERTA DE ENTRADA — lo único ejecutable hoy, y la razón por la que el resto no corre.
   *
   * El circuito de entrega arranca cuando la tarea "Aprueba pedido…" aparece en la
   * bandeja del Responsable. Se crea un pedido y se comprueba que la tarea llegue. HOY
   * NO LLEGA (H-070), así que el test **falla a propósito**. Cuando se arregle H-070 y
   * la tarea aparezca, este `test.fail()` va a "pasar inesperadamente" y avisa que se
   * pueden habilitar los pasos de abajo.
   */
  test('el pedido aprobado llega como tarea a la bandeja del Responsable', async ({ browser }) => {
    test.fail();

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
   * APROBAR — pendiente de verificación en vivo (bloqueado por H-070, ver cabecera).
   *
   * Flujo derivado del código: abrir la tarea en la bandeja → tomarla (#btnTomarTarea) →
   * en view_aprueba_pedido elegir establecimiento y depósito, marcar el radio
   * result=true, y confirmar con #btnHecho → cerrarTarea() hace POST a
   * Proceso/cerrarTarea/{taskId} con apruebaPedido=true → el pedido pasa a 'Aprobado' y
   * el gateway ¿Pedido aprobado? deriva a "Entrega pedido pendiente".
   */
  test.fixme('el Responsable aprueba el pedido y queda en estado Aprobado', async () => {
    // Requiere una tarea real en la bandeja (H-070). Selectores del código, sin verificar:
    //   input[name="result"][value="true"] · #establecimientos · #depositos · #btnHecho
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
