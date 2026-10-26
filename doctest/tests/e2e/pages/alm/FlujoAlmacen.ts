/**
 * Bloques reutilizables del circuito de Almacenes, para las pruebas de ciclo (`@ciclo`).
 *
 * El circuito de entrega no se puede probar en el aire: para entregar tiene que haber
 * stock, y el stock nace en una recepción (ALM-UC-009, "la fuente de toda existencia"),
 * que a su vez necesita un artículo y un proveedor. En vez de asumir que la empresa ya
 * los tiene —que es lo que hacía que la entrega quedara en `test.fixme()`—, estos helpers
 * **generan el dato ellos mismos**, para que el caso corra siempre como regresión.
 *
 * Todo lo opera el **Responsable de Almacén**: es el dueño del maestro de artículos
 * (ALM-UC-002), de la recepción (ALM-UC-009) y de la entrega (ALM-UC-010). El pedido lo
 * crea el Solicitante (ALM-UC-006); esa parte queda en el spec, con su propia sesión.
 *
 * Los selectores salen del código de las vistas, no de adivinar:
 *   · alta de artículo:  views/articulo/list.php            (#frm-articulo, #es_loteado)
 *   · componente artículo: views/articulo/componente.php    (#inputarti onchange=getItem)
 *   · recepción:         views/remito/view_.php             (guardar → Remito/guardar_mejor)
 *   · pedido:            views/notapedido/...               (guardar_pedido / lanzarPedido)
 */

import { expect, type Page } from '@playwright/test';

import { AlmacenesPage } from './AlmacenesPage.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';

/** ¿La grilla tiene filas de verdad, o solo el relleno "Ningún dato disponible"? */
async function grillaConDatos(page: Page): Promise<boolean> {
  return !/Ning[úu]n dato disponible/i.test(await page.locator('#content').innerText());
}

/**
 * Cierra cualquier SweetAlert que haya quedado abierto.
 *
 * Es imprescindible entre pasos: los avisos "Hecho!" del alta usan SweetAlert (Swal), y
 * como `linkTo` sólo recarga `#content` —no toda la página—, el overlay del Swal sobrevive
 * al cambio de pantalla e **intercepta los clics** de la pantalla siguiente. Se acepta con
 * su botón (o Escape) hasta que el contenedor desaparece.
 */
/**
 * Elige una opción real de un `<select>` (select2) por evaluate y dispara su `change`.
 *
 * Se hace por evaluate y no con `selectOption` porque select2 deja el `<select>` nativo
 * oculto (`select2-hidden-accessible`) y Playwright lo ve "no visible". Setear el value y
 * disparar `change` también corre el `onchange` inline (seleccionPais/seleccionEstado) que
 * encadena el AJAX, y deja el value correcto para el FormData que postea el alta.
 */
async function elegirOpcion(page: Page, selector: string, preferir?: RegExp): Promise<void> {
  await page.locator(selector).evaluate((el, pref) => {
    const s = el as HTMLSelectElement;
    const reales = Array.from(s.options).filter((o) => o.value !== '' && !o.disabled);
    const re = pref ? new RegExp(pref, 'i') : null;
    const opt = (re && reales.find((o) => re.test(o.text))) || reales[0];
    if (!opt) return;
    s.value = opt.value;
    s.dispatchEvent(new Event('change', { bubbles: true }));
  }, preferir ? preferir.source : null);
}

/** Espera a que un `<select>` tenga al menos una opción real (poblado por el AJAX). */
async function esperarOpciones(page: Page, selector: string): Promise<void> {
  await page.waitForFunction(
    (s) => {
      const el = document.querySelector(s);
      return el instanceof HTMLSelectElement && Array.from(el.options).some((o) => o.value !== '' && !o.disabled);
    },
    selector,
    { timeout: 15_000 },
  );
}

export async function cerrarSweetAlerts(page: Page): Promise<void> {
  for (let i = 0; i < 4; i++) {
    const contenedor = page.locator('.swal2-container');
    if (!(await contenedor.first().isVisible().catch(() => false))) return;
    const confirmar = page.locator('.swal2-confirm');
    if (await confirmar.first().isVisible().catch(() => false)) {
      await confirmar.first().click().catch(() => {});
    } else {
      await page.keyboard.press('Escape').catch(() => {});
    }
    await page.waitForTimeout(700);
  }
}

/**
 * Da de alta un artículo **no loteado**, si no existe ya uno con ese código.
 *
 * No loteado a propósito: así la recepción no dispara la verificación de existencia de
 * lote (`Lote/verificarExistencia`) ni el modal de acumulación, y la entrega sale de un
 * único lote `S/L`. Es el camino determinista, que es lo que una regresión necesita.
 */
export async function asegurarArticulo(
  page: Page,
  { codigo, descripcion }: { codigo: string; descripcion: string },
): Promise<void> {
  await new AlmacenesPage(page).abrir('articulos');
  await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

  if ((await grillaConDatos(page)) && (await page.locator('#content').innerText()).includes(codigo)) {
    return;
  }

  await page.getByRole('button', { name: /Agregar/i }).first().click();
  await expect(page.locator('#artBarCode')).toBeVisible({ timeout: 15_000 });
  await page.locator('#artBarCode').fill(codigo);
  await page.locator('#artDescription').fill(descripcion);
  await page.locator('#tipo').selectOption({ index: 1 });
  await page.locator('#unidmed').selectOption({ index: 1 });
  // #es_loteado es un checkbox: se deja SIN marcar (artículo no loteado, ver arriba).
  for (const campo of ['#puntped', '#cant_caja']) {
    const input = page.locator(campo);
    if (await input.isEnabled()) await input.fill('1');
  }

  // La validación es de navegador (validarArticulo): un faltante sale por un alert, no por
  // un mensaje en la página. Se captura para no dejar pasar un alta que rebotó.
  let aviso = '';
  const onDialog = async (d: import('@playwright/test').Dialog) => {
    aviso = d.message();
    await d.dismiss();
  };
  page.on('dialog', onDialog);
  await page.locator('#btn-accion').click();
  await page.waitForTimeout(3000);
  page.off('dialog', onDialog);
  expect(aviso, 'el alta de artículo no tendría que rebotar por validación').toBe('');

  // El alta exitosa muestra un Swal "Hecho!" que hay que cerrar, o queda tapando la
  // pantalla siguiente (linkTo sólo recarga #content, no la página entera).
  await cerrarSweetAlerts(page);
  await new AlmacenesPage(page).abrir('articulos');
  // A veces el fragmento de #content vuelve vacío en el primer linkTo (carrera del shell
  // contra el DEMO cargado): si pasó, se reintenta una vez antes de dar por perdido el alta.
  if (!/\S/.test(await page.locator('#content').innerText().catch(() => ''))) {
    await new AlmacenesPage(page).abrir('articulos');
  }
  await expect(page.locator('#content'), 'el artículo recién creado tiene que aparecer').toContainText(codigo, {
    timeout: 30_000,
  });
}

/**
 * Garantiza que la empresa tenga al menos un proveedor. Si no tiene ninguno, crea uno.
 *
 * La pantalla de proveedores es **de core**, no del módulo de Almacenes, así que se abre
 * por `linkTo('core/Proveedor')` desde el shell. El alta valida sólo los campos
 * `.requerido` (nombre, cuit, domicilio, teléfono, email); país/provincia/localidad son
 * select2 opcionales y se dejan en su valor por defecto.
 */
export async function asegurarProveedor(
  page: Page,
  { nombre, cuit }: { nombre: string; cuit: string },
): Promise<void> {
  await abrirEnShell(page, 'core/Proveedor');
  await cerrarSweetAlerts(page); // por si arrastra un aviso del alta de artículo
  await page.waitForTimeout(2500);

  // Si la empresa YA tiene un proveedor de verdad, no se crea otro. El chequeo pregunta por
  // un CUIT en la lista —dato que sólo tiene una fila real—, no por "hay filas": así no se
  // confunde con la fila de relleno ("Ningún dato disponible") ni con un "Cargando…".
  const tieneProveedor = async () =>
    /\d{2}-?\d{6,8}-?\d/.test(await page.locator('#cargar_tabla').innerText().catch(() => ''));
  if (await tieneProveedor()) return;

  await page.locator('#botonProveedor').click();
  await expect(page.locator('#formProveedor #nombre')).toBeVisible({ timeout: 15_000 });
  await page.locator('#formProveedor #nombre').fill(nombre);
  await page.locator('#formProveedor #cuit').fill(cuit);
  await page.locator('#formProveedor #domicilio').fill('Calle Falsa 123');
  await page.locator('#formProveedor #telefono').fill('2644000000');
  await page.locator('#formProveedor #email').fill('proveedor@doctest.local');

  // País → provincia → localidad: cascada AJAX. El insert del server las necesita (con las
  // tres vacías el alta se rechaza en silencio), aunque la validación de navegador no las
  // pida. Se recorre como un usuario: elegir país dispara los estados; elegir estado, las
  // localidades.
  await elegirOpcion(page, '#formProveedor #pais', /argentina/i);
  await esperarOpciones(page, '#formProveedor #estado');
  await elegirOpcion(page, '#formProveedor #estado');
  await esperarOpciones(page, '#formProveedor #localidad');
  await elegirOpcion(page, '#formProveedor #localidad');
  await page.waitForTimeout(500);

  // El botón Guardar está en el footer del modal (hermano del <form>, no dentro), y su id
  // `btnsave_edit` se repite en los tres modales de la pantalla; se acota por el modal.
  await page.locator('#modalProveedor #btnsave_edit').click();
  await cerrarSweetAlerts(page);
  await page.waitForTimeout(3000);

  // Verificar el EFECTO, no asumirlo: se recarga la lista y tiene que aparecer el proveedor.
  // Si no aparece, el alta falló en silencio y hay que saberlo acá, no en la recepción.
  await abrirEnShell(page, 'core/Proveedor');
  await cerrarSweetAlerts(page);
  await expect(page.locator('#cargar_tabla'), 'el proveedor recién creado tiene que quedar en la lista').toContainText(
    nombre,
    { timeout: 20_000 },
  );
}

/**
 * Registra una recepción del artículo indicado → **crea stock** en el depósito.
 *
 * Es ALM-UC-009. Deja `cant_disponible > 0` para ese artículo, que es la precondición que
 * destraba la entrega (el '+' de la tarea de entrega está `hidden` con stock en cero).
 */
export async function recepcionar(
  page: Page,
  { codigo, cantidad, comprobante }: { codigo: string; cantidad: number; comprobante: string },
): Promise<void> {
  const alm = new AlmacenesPage(page);
  await abrirEnShell(page, 'traz-comp-almacenes/Remito');
  await cerrarSweetAlerts(page);
  await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

  await page.getByRole('button', { name: /Agregar/i }).first().click();
  await expect(page.locator('#comprobante')).toBeVisible({ timeout: 15_000 });

  // Cabecera. #fecha lo lee guardar() como texto plano (get_info_remito), así que alcanza
  // con una fecha válida; se setea por evaluate porque es un datetimepicker.
  await page.locator('#comprobante').fill(comprobante);
  const hoy = new Date().toISOString().slice(0, 10);
  await page.locator('#fecha').evaluate((el, v) => {
    (el as HTMLInputElement).value = v;
  }, `${hoy} 08:00`);
  await page.locator('#proveedor').selectOption({ index: 1 });

  // Artículo: se elige del datalist. #inputarti tiene onchange=getItem(this), que setea la
  // variable global `selectItem` (arti_id, es_loteado, ...) de la que depende Agregar.
  await page.locator('#inputarti').fill(codigo);
  await page.locator('#inputarti').dispatchEvent('change');
  await page.waitForTimeout(500);

  // #lote es obligatorio para validar_campos() aun en no loteados; el convenio es 'S/L'.
  await page.locator('#lote').fill('S/L');
  await page.locator('#cantidad').fill(String(cantidad));

  // Establecimiento dispara seleccionesta() → AJAX que puebla #deposito y le saca el
  // readonly. Se espera a que tenga una opción real antes de elegirla.
  await page.locator('#establecimiento').selectOption({ index: 1 });
  await page.waitForFunction(
    () => {
      const el = document.querySelector('#deposito');
      return el instanceof HTMLSelectElement && el.options.length > 0 && el.value !== '' && el.value !== 'false';
    },
    undefined,
    { timeout: 15_000 },
  );

  // "Agregar" (verificarExistenciaLote): con artículo no loteado suma la fila directo.
  await page.locator('button[onclick*="verificarExistenciaLote"]').click();
  await expect(page.locator('#tablainsumo tbody tr'), 'la línea de recepción tiene que sumarse al detalle').toHaveCount(
    1,
    { timeout: 10_000 },
  );

  // "Guardar" (guardar → Remito/guardar_mejor). El éxito hace linkTo(Remito), así que se
  // espera a volver al listado.
  await page.locator('button[onclick*="guardar()"]').click();
  await page.waitForTimeout(4000);
  await alm.abrir('pedidos'); // vuelve a un estado conocido para el paso siguiente
}

/**
 * Crea un pedido del artículo indicado, dirigido al primer depósito del establecimiento.
 *
 * A diferencia del helper del spec ALM-UC-006 —que toma el primer artículo del datalist—,
 * acá el código se pasa explícito: el pedido tiene que ser del MISMO artículo al que se le
 * cargó stock, o no habría nada que entregar.
 */
export async function crearPedidoDe(
  page: Page,
  { codigo, cantidad, justificacion }: { codigo: string; cantidad: number; justificacion: string },
): Promise<void> {
  await new AlmacenesPage(page).abrir('pedidos');
  await cerrarSweetAlerts(page);
  await expect(page.locator('table thead th').first()).toBeVisible({ timeout: 60_000 });

  await page.getByRole('button', { name: /Agregar/i }).first().click();
  await expect(page.locator('#just')).toBeVisible({ timeout: 15_000 });
  await page.locator('#just').fill(justificacion);

  await page.locator('#inputarti').fill(codigo);
  await page.locator('#inputarti').dispatchEvent('change');
  await page.locator('#add_cantidad').fill(String(cantidad));
  await page.locator('button[onclick*="guardar_pedido"]').click();
  await page.waitForTimeout(2000);

  await page.locator('#establecimiento').selectOption({ index: 1 });
  await page.waitForTimeout(1500);
  await page.locator('#deposito').selectOption({ index: 0 });
  await page.locator('button[onclick*="lanzarPedido"]').click();
  await page.waitForTimeout(5000);
}

/** Abre una ruta cualquiera por el shell de Tools (mismo mecanismo que AlmacenesPage). */
export async function abrirEnShell(page: Page, ruta: string): Promise<void> {
  const enElShell = async () =>
    page.evaluate(() => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function');
  if (!(await enElShell().catch(() => false))) {
    // No estaba en el shell: se navega a la base de Tools, que es la que trae `linkTo`.
    await page.goto(requerirUrlDeApp('tools'), { waitUntil: 'domcontentloaded' });
    if (!(await enElShell().catch(() => false))) {
      await page.reload({ waitUntil: 'domcontentloaded' });
    }
  }
  await page.waitForFunction(
    () => typeof (window as unknown as { linkTo?: unknown }).linkTo === 'function',
    undefined,
    { timeout: 60_000 },
  );
  await page.evaluate((r) => {
    (window as unknown as { linkTo: (x: string) => void }).linkTo(r);
  }, ruta);
  await page.waitForTimeout(1800);
}
