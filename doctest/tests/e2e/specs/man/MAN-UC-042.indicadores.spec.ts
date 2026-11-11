/**
 * Caso de uso: MAN-UC-042 — Ver los indicadores de mantenimiento en el tablero de Tools
 * Catálogo: catalogo/man/MAN-UC-042.yaml
 *
 * Los cuatro indicadores (MTTR, MTTF, MTBF y confiabilidad, decisión E61) se calculan por mes en la
 * caché de KPIs con `scripts/assetplanner/kpi-mantenimiento.sql`, que corre el cron. La prueba
 * verifica que el tablero los ofrece; el valor depende de los datos del ambiente.
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

const CAJAS = [
  'Tiempo medio de reparación (MTTR)',
  'Tiempo medio hasta la falla (MTTF)',
  'Tiempo medio entre fallas (MTBF)',
  'Confiabilidad de equipos',
];

test.describe('@man @MAN-UC-042 Indicadores de mantenimiento', () => {
  test('el tablero muestra las cuatro cajas de mantenimiento', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrirRuta('Dash/dashboard', testInfo);
    // Los indicadores aparecen al tocar "Comenzar" en el saludo del tablero.
    const comenzar = paginaMan.getByText(/Comenzar/).first();
    if (await comenzar.isVisible().catch(() => false)) await comenzar.click();
    await expect(paginaMan.locator('#tz-kpis-wrap')).toBeVisible({ timeout: 30_000 });
    const texto = (await paginaMan.locator('#tz-kpis-wrap').innerText()).replace(/\s+/g, ' ');
    for (const caja of CAJAS) {
      expect(texto, `falta la caja "${caja}"`).toContain(caja);
    }
  });
});
