/**
 * Caso de uso: TAR-UC-022 — Consultar indicadores de tareas
 * Catálogo: catalogo/tar/TAR-UC-022.yaml (en borrador; perfil pendiente, duda D-02)
 * Casos de prueba del spec: doc/specs/TAR-spec-modulo-tareas.md §7.20
 *
 * El reporte (`traz-comp-tareasestandar/Reportes/indicadores`) muestra dos totales —tareas
 * planificadas y finalizadas— y una tabla con una fila por tarea y su estado. La prueba no
 * depende de cuántas tareas haya en la empresa: compara los totales contra la propia tabla.
 * Si el total de finalizadas cuenta tareas cuya fila dice otro estado, el KPI está mal
 * (HIP-TAR-03). Conviene correrla después del ciclo (TAR-UC-005-018), que deja tareas en
 * distintos estados.
 */

import { expect, test } from '@playwright/test';

import { paginaDeRol } from '../../fixtures/roles-tar.ts';
import { iso, enDias } from '../../pages/tar/PlanificacionPage.ts';
import { ShellTar } from '../../pages/tar/ShellTar.ts';

test.describe('@tar @TAR-UC-022 Indicadores de tareas', () => {
  test('TAR-CP-022-01/022-02 "finalizadas" cuenta solo las tareas finalizadas (HIP-TAR-03)', async ({ browser }, testInfo) => {
    const sh = new ShellTar(await paginaDeRol(browser, 'planificador'));
    try {
      await sh.abrir('indicadores', testInfo);
      await sh.page.locator('#datepickerDesde').fill(iso(enDias(-30)));
      await sh.page.locator('#datepickerHasta').fill(iso(enDias(60)));
      await sh.page.locator('#masFiltros button[onclick*="filtrar"], button[onclick="filtrar()"]').first().evaluate((b: HTMLElement) => b.click());
      await sh.esperarCarga();

      const finalizadas = Number((await sh.page.locator('#cantidad_finalizadas').innerText()).trim());
      const planificadas = Number((await sh.page.locator('#cantidad_planificadas').innerText()).trim());
      // La grilla vacía tiene una sola fila de "sin datos": se cuentan solo las que traen estado.
      const filas = (await sh.page.locator('#reportContent table tbody tr').allInnerTexts()).filter((f) => /creada|planificada|iniciada|finalizada/i.test(f));
      const conEstado = (re: RegExp) => filas.filter((f) => re.test(f)).length;
      const finalizadasEnTabla = conEstado(/finalizada/i);
      testInfo.annotations.push({
        type: 'kpi',
        description: `planificadas=${planificadas} finalizadas=${finalizadas} · filas=${filas.length} (finalizada=${finalizadasEnTabla}, iniciada=${conEstado(/iniciada/i)}, planificada=${conEstado(/planificada/i)}, creada=${conEstado(/creada/i)})`,
      });

      test.skip(filas.length === 0, 'bloqueado: no hay tareas de pedidos de trabajo en el período (H-091: la empresa no puede crear pedidos)');
      expect(finalizadas, 'el total de finalizadas no coincide con las filas en estado "finalizada"').toBe(finalizadasEnTabla);
    } finally {
      await sh.page.context().close();
    }
  });
});
