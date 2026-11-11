/**
 * Caso de uso: MAN-UC-007 — Pedir un servicio cuando algo falla
 * Catálogo: catalogo/man/MAN-UC-007.yaml
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

test.describe('@man @MAN-UC-007 Pedir un servicio', () => {
  test('@smoke el listado muestra los tiempos de servicio', async ({ paginaMan }, testInfo) => {
    const man = new ShellMan(paginaMan);
    await man.abrir('solicitudes', testInfo);
    const texto = await man.encabezados();
    for (const columna of ['Solicitante', 'Equipo', 'Sector']) {
      expect(texto).toContain(columna);
    }
    // Las tres columnas de tiempo son los indicadores de servicio del caso.
    expect(texto).toMatch(/T\.\s*de\s*ciclo/i);
    expect(texto).toMatch(/T\.\s*Asignaci/i);
    expect(texto).toMatch(/T\.\s*Generaci/i);
  });
});
