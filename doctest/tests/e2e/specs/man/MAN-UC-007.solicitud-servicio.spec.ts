/**
 * Caso de uso: MAN-UC-007 — Pedir un servicio cuando algo falla
 * Catálogo: catalogo/man/MAN-UC-007.yaml
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { requerirUrlDeApp } from '../../config/apps.ts';
import { encabezadosDeGrilla } from '../../pages/man/grilla.ts';

const MAN = () => requerirUrlDeApp('man');

test.describe('@man @MAN-UC-007 Pedir un servicio', () => {
  test('@smoke el listado muestra los tiempos de servicio', async ({ paginaMan }) => {
    await paginaMan.goto(`${MAN()}/Sservicio`, { waitUntil: 'domcontentloaded' });
    const texto = await encabezadosDeGrilla(paginaMan);
    for (const columna of ['Solicitante', 'Equipo', 'Sector']) {
      expect(texto).toContain(columna);
    }
    // Las tres columnas de tiempo son los indicadores de servicio del caso.
    expect(texto).toMatch(/T\.\s*de\s*ciclo/i);
    expect(texto).toMatch(/T\.\s*Asignaci/i);
    expect(texto).toMatch(/T\.\s*Generaci/i);
  });
});
