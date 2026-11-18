/**
 * Casos de uso: MAN-UC-038 (herramientas, insumos y pedido en cada paso de la OT) y
 *               MAN-UC-039 (asociar a la OT los vales del pañol)
 * Catálogo: catalogo/man/MAN-UC-038.yaml, MAN-UC-039.yaml
 *
 * La pestaña "Herramientas e Insumos" (`views/ot/materiales.php` de traz-tools-man) se arma con
 * cuatro consultas de `Ordenservicio`. Acá se verifican esas consultas y las reglas de los vales
 * contra una OT del ambiente que ya tiene pedido, entregas y vales:
 *
 *   DOCTEST_<AMBIENTE>_MAN_OT_MATERIALES   (en DEV, la OT 935: pedido 13/8/5, entregas 290 y 291,
 *                                          vale del mantenedor y vale del pañolero)
 *
 * La pestaña dentro de cada tarea de la bandeja la recorre el circuito largo (MAN-UC-030, @ciclo).
 *
 * Regla del PM (2026-11-03): desde la OT **nunca** se genera un vale; los hace el pañol. El
 * mantenedor solo asocia los suyos (por DNI) y el supervisor busca sin DNI y puede quitar también los
 * del pañolero. Ninguna prueba de acá crea vales.
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { entornoActual } from '../../config/apps.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

const PREFIJO: Record<string, string> = { local: 'LOCAL', demo: 'DEMO', 'staging-v3': 'STAGING' };
const OT = Number(process.env[`DOCTEST_${PREFIJO[entornoActual()]}_MAN_OT_MATERIALES`] ?? 0);

type Fila = Record<string, unknown>;
const RUTA = 'traz-tools-man/Ordenservicio/';

test.describe('@man @MAN-UC-038 @MAN-UC-039 Herramientas e insumos de la OT', () => {
  test.skip(!OT, 'Falta DOCTEST_<AMBIENTE>_MAN_OT_MATERIALES: una OT con pedido, entregas y vales');

  test('el pedido muestra lo pedido, lo entregado y lo pendiente de cada artículo', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const insumos = (await man.pedir(`${RUTA}getInsumosPorOT`, { id_ot: OT })) as Fila[];
    expect(Array.isArray(insumos) && insumos.length, 'la OT tiene pedido de materiales').toBeTruthy();
    for (const i of insumos) {
      const pedido = Number(i.cant_pedida ?? i.pedido ?? i.cantidad ?? NaN);
      const entregado = Number(i.cant_entregada ?? i.entregado ?? NaN);
      const pendiente = Number(i.pendiente ?? i.resto ?? NaN);
      if (![pedido, entregado, pendiente].some(Number.isNaN)) {
        expect(pendiente, `pendiente = pedido − entregado (${JSON.stringify(i)})`).toBeCloseTo(pedido - entregado);
      }
    }
  });

  test('las entregas del almacén traen su detalle', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const pedidos = (await man.pedir(`${RUTA}getEntregasPorOT`, { id_ot: OT })) as Array<{ entregas?: Fila[] }>;
    const entregas = (pedidos ?? []).flatMap((p) => p.entregas ?? []);
    expect(entregas.length, 'la OT tiene al menos una entrega').toBeGreaterThan(0);
  });

  test('las herramientas usadas salen de los vales asociados, con su origen', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const usadas = (await man.pedir(`${RUTA}getHerramientasUsadas`, { id_ot: OT })) as Fila[];
    expect(usadas.length, 'la OT tiene herramientas usadas').toBeGreaterThan(0);
    for (const h of usadas) {
      expect(['MANTENEDOR', 'SUPERVISOR', 'PANOLERO']).toContain(h.origen);
      expect(Number(h.sapa_id)).toBeGreaterThan(0);
    }
  });

  test('el mantenedor no puede buscar vales sin DNI', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const r = (await man.pedir(`${RUTA}buscarVales`, { rol: 'MANTENEDOR', dni: '' })) as Fila;
    expect(r.ok).toBe(false);
    expect(String(r.msg)).toMatch(/Sin DNI/i);
  });

  test('el supervisor busca vales sin DNI', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const r = (await man.pedir(`${RUTA}buscarVales`, { rol: 'SUPERVISOR' })) as Fila;
    expect(r.ok).toBe(true);
    expect(Array.isArray(r.vales)).toBe(true);
  });

  test('un vale ya asociado no se asocia dos veces', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const usadas = (await man.pedir(`${RUTA}getHerramientasUsadas`, { id_ot: OT })) as Fila[];
    const sapa = usadas[0]?.sapa_id;
    const r = (await man.pedir(`${RUTA}asociarVale`, { id_ot: OT, sapa_id: sapa, origen: 'MANTENEDOR' })) as Fila;
    expect(r.ok).toBe(false);
    expect(String(r.msg)).toMatch(/ya est[aá] asociado/i);
  });

  test('el mantenedor no puede quitar un vale que asoció el pañolero', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const usadas = (await man.pedir(`${RUTA}getHerramientasUsadas`, { id_ot: OT })) as Fila[];
    const delPanol = usadas.find((h) => h.origen === 'PANOLERO');
    test.skip(!delPanol, 'La OT configurada no tiene un vale del pañolero');
    const r = (await man.pedir(`${RUTA}quitarVale`, { id_ot: OT, sapa_id: delPanol!.sapa_id, rol: 'MANTENEDOR' })) as Fila;
    expect(r.ok).toBe(false);
    expect(String(r.msg)).toMatch(/No tiene permiso/i);
  });
});
