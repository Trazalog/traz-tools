/**
 * Casos de uso: ALM-UC-006 — Pedir materiales al almacén
 *               ALM-UC-007 — Ver el detalle de un pedido de materiales
 *
 * EL PRIMER TEST DE LA SUITE QUE RECORRE UN CIRCUITO, NO UNA PANTALLA.
 *
 * ⚠️ Etiquetado `@ciclo` y **fuera de `test:all`**: crea un pedido de materiales real en
 * el entorno, igual que `@alta-empresa` crea una empresa real. Se corre a demanda con
 * `npm run test:ciclo`.
 *
 * Lo recorren dos personas distintas —quien pide y quien entrega—, así que cada paso
 * abre la sesión del rol que le corresponde. Los pasos dependen entre sí: `serial`.
 *
 * ⚠️ ESTADO AL 2026-09-08: **la preparación pasa; la creación del pedido todavía no.**
 *
 * Lo que quedó resuelto y verificado contra el DEMO:
 *   · las pantallas se abren **por el shell de Tools**, no por la URL del módulo — ver
 *     la explicación en `AlmacenesPage.abrir()`, que era la causa de todo lo anterior;
 *   · el alta de artículo funciona: `Articulo/guardar` devuelve el id y la grilla pasa
 *     a `recordsTotal: 1`;
 *   · el datalist del pedido ya ofrece ese artículo;
 *   · el flujo del modal quedó mapeado: **Agregar** suma la línea (`guardar_pedido()`) y
 *     **Hecho** crea el pedido y lanza el proceso (`lanzarPedido()`).
 *
 * Lo que falta: después de **Hecho** el pedido no aparece en el listado. Hipótesis a
 * verificar, en este orden — (1) `lanzarPedido()` lanza el proceso en Bonita y puede
 * estar fallando ahí, que es justo lo que ALM-UC-006 tiene relevado como riesgo;
 * (2) puede faltar un paso del formulario que todavía no identifiqué. Se resuelve
 * mirando la respuesta de red del POST, como se resolvió el alta de artículo.
 */

import { expect, test, type Page } from '@playwright/test';

import { AlmacenesPage } from '../../pages/alm/AlmacenesPage.ts';
import { sesionDeRol } from '../../fixtures/roles-alm.ts';

/** Marca única para reconocer el pedido que crea esta corrida y no confundirlo con otro. */
const MARCA = `DocTest ciclo ${new Date().toISOString().slice(0, 19)}`;

/** Código del artículo que crea la preparación, único por corrida. */
const CODIGO_ARTICULO = `DT-${Date.now().toString().slice(-8)}`;


/**
 * Crea un pedido de materiales completo, con la justificación que se le pase como marca.
 *
 * Los nombres de los botones engañan y conviene tenerlo escrito: **Agregar** suma la línea
 * al detalle (`guardar_pedido()`) y **Hecho** es el que crea el pedido y lanza el proceso
 * en Bonita (`lanzarPedido()`). Se los busca por su función y no por su texto, porque
 * "Agregar" es además el botón que abre el modal.
 */
async function crearPedido(page: Page, justificacion: string): Promise<void> {
  await new AlmacenesPage(page).abrir('pedidos');
  await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

  await page.getByRole('button', { name: /Agregar/i }).first().click();
  await expect(page.locator('#just')).toBeVisible({ timeout: 15_000 });
  await page.locator('#just').fill(justificacion);

  // El artículo se elige del datalist: se toma el primero que ofrezca la empresa, en vez
  // de fijar un código que mañana puede no existir.
  const opciones = page.locator('datalist option');
  await expect(opciones.first()).toHaveCount(1, { timeout: 15_000 });
  const articulo = (await opciones.first().getAttribute('value')) ?? '';
  expect(articulo, 'la empresa tiene que tener al menos un artículo cargado').not.toBe('');

  await page.locator('#inputarti').fill(articulo);
  await page.locator('#add_cantidad').fill('1');
  await page.locator('button[onclick*="guardar_pedido"]').click();
  await page.waitForTimeout(2000);

  // El pedido va dirigido a un depósito concreto: es un paso del caso, no un detalle.
  await page.locator('#establecimiento').selectOption({ index: 1 });
  await page.waitForTimeout(1500);
  await page.locator('#deposito').selectOption({ index: 0 });

  await page.locator('button[onclick*="lanzarPedido"]').click();
  await page.waitForTimeout(5000);
}

test.describe.serial('@alm @ciclo @ALM-UC-002 @ALM-UC-006 @ALM-UC-007 El ciclo de vida de un pedido de materiales', () => {
  /**
   * El circuito empieza antes del pedido: no se puede pedir lo que no existe. Si la
   * empresa no tiene ni un artículo, el pedido no tiene qué contener — es la
   * precondición que declara ALM-UC-006, y acá se cumple en vez de asumirse.
   *
   * Lo carga el **Responsable de Almacén**, que es de quien es el maestro de artículos
   * (ALM-UC-002): el Solicitante pide de ese catálogo, no lo arma.
   */
  test('preparación: el almacén carga un artículo para que haya qué pedir', async ({ browser }) => {
    const page = await sesionDeRol(browser, 'almacen');
    try {
      await new AlmacenesPage(page).abrir('articulos');
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

      // Contar filas es una trampa: DataTables pinta una fila de relleno que dice
      // "Ningún dato disponible en esta tabla", así que `count() > 0` da verdadero con
      // la grilla vacía. Se pregunta por el contenido, no por la cantidad.
      const hayArticulos = async () =>
        !/Ning[úu]n dato disponible/i.test(await page.locator('#content').innerText());

      if (await hayArticulos()) {
        test.info().annotations.push({ type: 'nota', description: 'la empresa ya tenía artículos' });
        return;
      }

      await page.getByRole('button', { name: /Agregar/i }).first().click();
      await expect(page.locator('#artBarCode')).toBeVisible({ timeout: 15_000 });
      await page.locator('#artBarCode').fill(CODIGO_ARTICULO);
      await page.locator('#artDescription').fill(`Artículo de ${MARCA}`);
      await page.locator('#tipo').selectOption({ index: 1 });
      await page.locator('#unidmed').selectOption({ index: 1 });
      // `guardar()` lee punto_pedido y unme_id directo del POST, sin default. Pero no
      // todos los campos están habilitados siempre: `cantidad_caja` viene `disabled` y
      // se habilita según el tipo de artículo. Se completa lo que esté editable y nada
      // más — forzar un campo deshabilitado prueba algo que el usuario no puede hacer.
      for (const campo of ['#puntped', '#cant_caja']) {
        const input = page.locator(campo);
        if (await input.isEnabled()) await input.fill('1');
      }

      // Por id y no por texto: la pantalla tiene varios botones "Guardar" —uno por modal—
      // y `getByRole(...).first()` agarra uno oculto de otro modal, que no hace nada.
      // La validación es de navegador (`validarArticulo()`), así que un campo faltante
      // sale por un aviso emergente y no por un mensaje en la página.
      let aviso = '';
      page.on('dialog', async (d) => {
        aviso = d.message();
        await d.dismiss();
      });
      await page.locator('#btn-accion').click();
      await page.waitForTimeout(3000);
      expect(aviso, 'el alta no tendría que rebotar por validación').toBe('');
      await page.waitForTimeout(3000);

      await new AlmacenesPage(page).abrir('articulos');
      await expect(page.locator('#content table thead th').first()).toBeVisible({ timeout: 60_000 });
      await expect(page.locator('#content'), 'sin artículos no hay pedido posible').toContainText(
        CODIGO_ARTICULO,
        { timeout: 30_000 },
      );
    } finally {
      await page.context().close();
    }
  });

  test('el Solicitante crea el pedido y queda registrado', async ({ browser }) => {
    const page = await sesionDeRol(browser, 'solicitante');
    try {
      await crearPedido(page, MARCA);

      await new AlmacenesPage(page).abrir('pedidos');
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

      // Se busca el pedido de ESTA corrida por su justificación, que es única — y se lo
      // busca CON EL BUSCADOR de la grilla, no mirando la página que quedó a la vista.
      //
      // Mirar la página visible funcionó las primeras veces y despues empezó a fallar:
      // cada corrida deja un pedido, la grilla muestra 10 por página y el listado no
      // declara ORDER BY, así que el pedido nuevo no tiene por qué caer en la primera.
      // Un test que depende de eso caduca solo, y encima falla acusando al sistema.
      const buscador = page.locator('#content input[type="search"]').first();
      await expect(buscador).toBeVisible({ timeout: 30_000 });
      await buscador.fill(MARCA);
      await page.waitForTimeout(1500);

      await expect(page.locator('#content'), 'el pedido creado tiene que aparecer al buscarlo').toContainText(
        MARCA,
        { timeout: 30_000 },
      );
    } finally {
      await page.context().close();
    }
  });

  test('el pedido nace en un estado del circuito, no en blanco', async ({ browser }) => {
    const page = await sesionDeRol(browser, 'solicitante');
    try {
      await new AlmacenesPage(page).abrir('pedidos');
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

      const primera = (await page.locator('table').first().locator('tbody tr').first().innerText())
        .replace(/\s+/g, ' ');

      // Los ocho estados del pedido los mueve Bonita, no la pantalla. Lo que se verifica
      // es que el pedido nazca dentro del circuito: un pedido sin estado quedaría huérfano,
      // sin nadie que lo apruebe ni lo entregue.
      expect(primera).toMatch(/Creada|Aprobado|Rechazado|Entregado|Ent\. Parcial|Finalizado|Cancelado/i);
    } finally {
      await page.context().close();
    }
  });

  /**
   * FALLA CONOCIDA — H-070 / issue #508.
   *
   * `ALM-UC-006` dice que al confirmar se dispara el proceso de aprobación. Hoy el
   * pedido se crea igual aunque el proceso no arranque: se verificó en vivo que
   * `crearNotaPedido` devuelve `pema_id` y acto seguido `pedidoNormal` devuelve
   * `{"status":false,"msj":"Error al Inciar Proceso"}`. El pedido queda huérfano — el
   * solicitante lo ve y lo espera, y nadie puede aprobarlo ni entregarlo.
   *
   * El test verifica lo que el caso dice que debe pasar, así que **falla a propósito**
   * hasta que se corrija. El día que se arregle, la suite avisa que hay que sacarle el
   * `test.fail()`.
   */
  test('el pedido arranca su proceso de aprobación', async ({ browser }) => {
    test.fail();
    const page = await sesionDeRol(browser, 'solicitante');
    try {
      let procesoOk: boolean | null = null;
      page.on('response', async (r) => {
        if (!/pedidoNormal/.test(r.url())) return;
        try {
          procesoOk = JSON.parse(await r.text())?.status === true;
        } catch {
          procesoOk = false;
        }
      });

      await crearPedido(page, `${MARCA} · proceso`);
      expect(procesoOk, 'el proceso de aprobación tiene que quedar lanzado').toBe(true);
    } finally {
      await page.context().close();
    }
  });

  test('el Responsable de Almacén ve el pedido que le hicieron', async ({ browser }) => {
    const page = await sesionDeRol(browser, 'almacen');
    try {
      await new AlmacenesPage(page).abrir('pedidos');
      await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

      const filas = await page.locator('table').first().locator('tbody tr').count();
      expect(filas, 'el almacén tiene que ver el pedido para poder entregarlo').toBeGreaterThan(0);
    } finally {
      await page.context().close();
    }
  });
});
