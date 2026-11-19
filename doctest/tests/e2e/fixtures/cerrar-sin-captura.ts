/**
 * Cierra una ventana auxiliar (la del ingreso que guarda la sesión) sin que entre en el informe.
 *
 * Con `screenshot: 'on'`, Playwright saca una foto de cada página de un contexto que se cierra
 * durante una prueba y la suma a sus capturas. Las sesiones se inician dentro de la primera prueba
 * que las pide (y de nuevo en cada reintento), así que la foto del inicio de Tools recién ingresado
 * se colaba entre las capturas de la falla. Cerrando antes las páginas, el contexto se cierra vacío
 * y Playwright no tiene qué fotografiar.
 */

import type { BrowserContext } from '@playwright/test';

export async function cerrarSinCaptura(contexto: BrowserContext): Promise<void> {
  await Promise.all(contexto.pages().map((p) => p.close().catch(() => {})));
  await contexto.close();
}
