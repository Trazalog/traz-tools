/**
 * Casos de uso: AGE-UC-001 a AGE-UC-009 — el panel de los agentes (Quirqui y Kuntur)
 * Catálogo: catalogo/age/AGE-UC-00*.yaml (validados por el PM el 2026-11-22)
 * Gherkin:  features/age/AGE-UC-00*.feature
 *
 * Qué prueba: lo que el panel le muestra al usuario y lo que le manda a la API.
 * Qué NO prueba: lo que contesta el modelo ni la seguridad de la API. Eso lo cubren
 * tests/api-mcp/hurl/agentes/ (Kuntur solo para administradores, aislamiento) y las pruebas
 * automáticas del orquestador (guardián de cifras, reglas de propuestas).
 *
 * Cómo corre sin servidores: el panel es una vista PHP que se puede dibujar sola. El spec
 * la renderiza con `php` (fixtures/render-panel-agentes.php), la sirve en un origen falso
 * (http://tools.local/) y simula con `page.route` cada llamada a la API de los agentes.
 * No necesita Tools, ni Dnato, ni el orquestador, ni sesión: corre igual en cualquier
 * entorno. Si la máquina no tiene `php`, el spec se saltea (no falla).
 */

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { expect, test, type Page, type Route } from '@playwright/test';

const HERE = dirname(fileURLToPath(import.meta.url));
const RAIZ_REPO = resolve(HERE, '..', '..', '..', '..', '..');
const ARNES = resolve(HERE, '..', '..', 'fixtures', 'render-panel-agentes.php');
const JQUERY = resolve(RAIZ_REPO, 'lib', 'bower_components', 'jquery', 'dist', 'jquery.min.js');
const ORIGEN = 'http://tools.local';
const API = `${ORIGEN}/traz-comp-agente/agente/`;

function renderizarPanel(): string | null {
  try {
    return execFileSync('php', [ARNES, RAIZ_REPO], { encoding: 'utf8' });
  } catch {
    return null;
  }
}

const PANEL = renderizarPanel();
const SE_PUEDE = PANEL !== null && existsSync(JQUERY);

const QUIRQUI = { clave: 'quirqui', nombre: 'Quirqui', avatar: 'quirqui', rol: 'asistente' };
const KUNTUR = { clave: 'kuntur', nombre: 'Kuntur', avatar: 'kuntur', rol: 'coach' };

interface Opciones {
  agentes?: object[];
  respuesta?: object;
  propuestas?: object[];
  globitoVisto?: boolean;
}

/** Llamadas que el panel hizo a la API, para verificar qué mandó. */
type Llamadas = { ruta: string; cuerpo: string }[];

async function abrirTools(page: Page, op: Opciones = {}): Promise<Llamadas> {
  const llamadas: Llamadas = [];
  const json = (route: Route, cuerpo: unknown) =>
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(cuerpo) });

  await page.route(`${ORIGEN}/**`, async (route) => {
    const url = route.request().url();
    if (url === `${ORIGEN}/` || url === `${ORIGEN}/tools`) {
      return route.fulfill({
        contentType: 'text/html; charset=utf-8',
        body: `<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Tools</title>
          <script src="${ORIGEN}/jquery.js"></script>
          <script>
            // Lo que el layout de Tools define y el panel usa.
            window.site = 'traz-comp-almacenes/Articulo';
            window.__navegaciones = [];
            window.linkTo = function (r) { window.__navegaciones.push(r); };
          </script></head><body>${PANEL}</body></html>`,
      });
    }
    if (url === `${ORIGEN}/jquery.js`) {
      return route.fulfill({ contentType: 'application/javascript', body: readFileSync(JQUERY, 'utf8') });
    }
    if (url.startsWith(API)) {
      const ruta = url.slice(API.length).split('?')[0];
      llamadas.push({ ruta, cuerpo: route.request().postData() ?? '' });
      switch (ruta) {
        case 'agentes': return json(route, { agentes: op.agentes ?? [QUIRQUI] });
        case 'consultar': return json(route, op.respuesta ?? { respuesta: 'Hola', interaccion_id: '00000000-0000-0000-0000-000000000001' });
        case 'sugerencias': return json(route, { propuestas: op.propuestas ?? [] });
        case 'kuntur_configuracion': return json(route, {});
        case 'kuntur_avisos': return json(route, { avisos: [] });
        default: return json(route, {});
      }
    }
    if (url.includes('/Avisos/')) return json(route, { avisos: [], no_leidos: 0 });
    // Imágenes de los avatares u otros recursos: si no están, el componente usa la inicial.
    return route.fulfill({ status: 404, body: '' });
  });

  if (op.globitoVisto !== false) {
    await page.addInitScript(() => { try { localStorage.setItem('tzag-globito-visto', '1'); } catch { /* sin storage */ } });
  }
  await page.goto(`${ORIGEN}/`);
  await expect(page.locator('#agp-boton')).toBeVisible();
  return llamadas;
}

async function preguntar(page: Page, texto: string): Promise<void> {
  await page.locator('#agp-boton').click();
  await page.locator('#agp-pregunta').fill(texto);
  await page.locator('#agp-enviar').click();
}

test.describe('@age Panel de los agentes', () => {
  test.skip(!SE_PUEDE, 'Hace falta php (y el jQuery del repo) para dibujar el panel sin Tools');

  test('@AGE-UC-001 @smoke la primera vez aparece el globito y el panel no se abre solo', async ({ page }) => {
    await abrirTools(page, { globitoVisto: false });
    const globito = page.locator('#agp-globito');
    await expect(globito).toBeVisible();
    await expect(globito).toHaveText(/¿Te ayudo con esta pantalla\?/);
    await expect(page.locator('#agp-panel')).not.toHaveClass(/abierto/);

    await globito.click();
    await expect(page.locator('#agp-panel')).toHaveClass(/abierto/);
    await expect(globito).toBeHidden();
  });

  test('@AGE-UC-001 si ya lo vio, el globito no vuelve a aparecer', async ({ page }) => {
    await abrirTools(page);
    await expect(page.locator('#agp-globito')).toBeHidden();
  });

  test('@AGE-UC-001 la consulta lleva la pantalla donde está el usuario', async ({ page }) => {
    const llamadas = await abrirTools(page);
    await preguntar(page, '¿Qué se hace en esta pantalla?');
    await expect(page.locator('.agp-agente .agp-texto').last()).toHaveText('Hola');
    const consulta = llamadas.find((l) => l.ruta === 'consultar');
    expect(consulta?.cuerpo).toContain('pantalla=traz-comp-almacenes%2FArticulo');
  });

  test('@AGE-UC-002 @AGE-UC-005 @AGE-UC-006 el panel muestra el texto tal cual, sin interpretar HTML', async ({ page }) => {
    await abrirTools(page, {
      respuesta: {
        interaccion_id: '00000000-0000-0000-0000-000000000002',
        respuesta: 'No tengo ese dato confirmado. ¿Querés que lo busque en los datos de tu empresa o en internet? <img src=x onerror=alert(1)>',
      },
    });
    await preguntar(page, '¿Cuántas horas le quedan a la bomba?');
    const texto = page.locator('.agp-agente .agp-texto').last();
    await expect(texto).toContainText('No tengo ese dato confirmado.');
    await expect(texto).toContainText('<img src=x onerror=alert(1)>');
    await expect(texto.locator('img')).toHaveCount(0);
  });

  test('@AGE-UC-003 muestra las propuestas y permite descartarlas', async ({ page }) => {
    const llamadas = await abrirTools(page, {
      propuestas: [{ propuesta_id: 7, tipo: 'certificacion', titulo: 'Certificación por vencer', detalle: ' La amoladora A-12 vence en 10 días.', accion: { texto: 'Cargá la nueva certificación en Herramientas.' } }],
    });
    await page.locator('#agp-boton').click();
    const prop = page.locator('.agp-prop');
    await expect(prop).toContainText('Certificación por vencer');
    await prop.locator('.agp-descartar').click();
    await expect(prop).toHaveCount(0);
    await expect.poll(() => llamadas.find((l) => l.ruta === 'sugerencia_respuesta')?.cuerpo).toContain('estado=descartada');
  });

  test('@AGE-UC-004 el enlace directo navega a la pantalla con linkTo', async ({ page }) => {
    await abrirTools(page, {
      respuesta: {
        interaccion_id: '00000000-0000-0000-0000-000000000003',
        respuesta: 'Entrá a Artículos y tocá Agregar. [Abrir la pantalla](tools:traz-comp-almacenes/Articulo) [malo](tools:javascript:alert(1))',
      },
    });
    await preguntar(page, 'Dame de alta un artículo');
    const enlace = page.locator('.agp-ir');
    await expect(enlace).toHaveCount(1);
    await expect(enlace).toHaveText('Abrir la pantalla');
    await enlace.click();
    expect(await page.evaluate(() => (window as unknown as { __navegaciones: string[] }).__navegaciones)).toEqual(['traz-comp-almacenes/Articulo']);
  });

  test('@AGE-UC-007 con 👎 ofrece motivos rápidos y manda el elegido', async ({ page }) => {
    const llamadas = await abrirTools(page);
    await preguntar(page, '¿Qué stock hay?');
    const caja = page.locator('.agp-feedback').last();
    await expect(caja.locator('.agp-motivos')).toBeHidden();

    await caja.locator('> button[data-util="0"]').click();
    await expect(caja.locator('.agp-motivos')).toBeVisible();
    await caja.getByRole('button', { name: 'Dato equivocado' }).click();
    await caja.locator('textarea').fill('el stock no coincide');
    await caja.getByRole('button', { name: 'Enviar' }).click();
    await expect(caja).toContainText('Gracias, lo vamos a revisar.');

    const enviados = llamadas.filter((l) => l.ruta === 'feedback').map((l) => l.cuerpo);
    expect(enviados[0]).toContain('util=false');
    expect(enviados.at(-1)).toContain('motivo=respuesta_incorrecta');
    expect(enviados.at(-1)).toContain('comentario=el+stock+no+coincide');
  });

  test('@AGE-UC-007 con 👍 no pide motivos', async ({ page }) => {
    await abrirTools(page);
    await preguntar(page, 'Hola');
    const caja = page.locator('.agp-feedback').last();
    await caja.locator('> button[data-util="1"]').click();
    await expect(caja.locator('.agp-motivos')).toBeHidden();
  });

  test('@AGE-UC-008 @smoke un usuario común no ve la pestaña de Kuntur', async ({ page }) => {
    await abrirTools(page, { agentes: [QUIRQUI] });
    await page.locator('#agp-boton').click();
    await expect(page.locator('#agp-nombre')).toHaveText('Quirqui');
    await expect(page.locator('#agp-pestanias')).toBeHidden();
    await expect(page.getByRole('button', { name: 'Kuntur' })).toHaveCount(0);
  });

  test('@AGE-UC-008 un administrador ve las pestañas de Quirqui y Kuntur', async ({ page }) => {
    await abrirTools(page, { agentes: [QUIRQUI, KUNTUR] });
    await page.locator('#agp-boton').click();
    const pestanias = page.locator('#agp-pestanias');
    await expect(pestanias).toBeVisible();
    await pestanias.getByRole('button', { name: 'Kuntur' }).click();
    await expect(page.locator('#agp-nombre')).toHaveText('Kuntur');
    await expect(page.locator('#agp-aviso-coach')).toBeVisible();
  });

  test('@AGE-UC-009 el aviso de medición está siempre y explica qué se mide', async ({ page }) => {
    await abrirTools(page);
    await page.locator('#agp-boton').click();
    await expect(page.locator('#agp-aviso')).toContainText('se usa para medir indicadores de tu empresa');
    await page.locator('#agp-que-se-mide').click();
    await expect(page.locator('#agp-detalle-medicion')).toBeVisible();
    await expect(page.locator('#agp-detalle-medicion')).toContainText('no se le muestra');
  });
});
