/**
 * CICLO-UC-001 — Alta de una empresa nueva + ciclo de vida de la OT con herramientas y pañol.
 * Catálogo: catalogo/ciclo/CICLO-UC-001.yaml (encadena DNATO-UC-001..005 + MAN-UC-002/007/009/010 + maqueta F3-F6)
 *
 * Recorrido que pidió el PM: registrar una empresa LIMPIA por la registración de tools y,
 * en esa misma empresa, sembrar los maestros (equipo, pañol+herramientas, almacén+artículos)
 * y recorrer el ciclo de la OT viendo su interrelación con herramientas y pañol (F3 texto
 * libre, F4 entregas, F5 herramientas usadas, F6 el pañolero asocia la OT). Cada paso deja
 * una captura con `--capturas`. La guía para hacerlo a mano está en
 * doctest/doc/onboarding-empresa-nueva.md.
 *
 * Se corre con capturas así:
 *   DOCTEST_ENV=demo node scripts/pw.mjs --grep @CICLO-UC-001 --capturas
 *
 * Para iterar sin registrar una empresa nueva cada vez, se puede REUSAR una existente:
 *   DOCTEST_CICLO_ADMIN=<email> DOCTEST_CICLO_PASS=<pass> ... (salta la registración)
 *
 * ⚠️ Crea datos reales en el entorno (una empresa nueva por corrida). Nunca producción.
 */

import { test } from '@playwright/test';

import { crearCapturador } from '../../fixtures/capturas.ts';
import { registrarEmpresa, type EmpresaRegistrada } from '../../flows/registrar-empresa.ts';
import { loginAssetAdmin, seedEquipo } from '../../flows/seed-asset.ts';

test.describe('@ciclo @CICLO-UC-001 @alta-empresa Ciclo: alta de empresa + OT con herramientas y pañol', () => {
  // retries 0: cada corrida crea una empresa real; un reintento registraría otra de más.
  test.describe.configure({ mode: 'serial', timeout: 1_200_000, retries: 0 });

  test('empresa nueva: registración + siembra + ciclo de OT', async ({ page }) => {
    const cap = crearCapturador('ciclo-ot');

    // ── Fase 1: la empresa (registración nueva, o reusar una por env para iterar) ──
    let empresa: EmpresaRegistrada;
    const reuseAdmin = process.env.DOCTEST_CICLO_ADMIN;
    const reusePass = process.env.DOCTEST_CICLO_PASS;
    if (reuseAdmin && reusePass) {
      empresa = {
        razonSocial: process.env.DOCTEST_CICLO_RAZON ?? '(reusada)',
        cuit: '',
        dominio: reuseAdmin.split('@')[1],
        admin: { email: reuseAdmin, password: reusePass },
        usuariosRol: { usuario: '', almacen: '', panol: '', produccion: '', mantenimiento: '' },
      };
      console.log(`[ciclo] reusando empresa existente: admin ${reuseAdmin}`);
    } else {
      empresa = await test.step('1. Registrar empresa nueva (registración de tools)', async () => {
        const e = await registrarEmpresa(page, cap);
        console.log(`[ciclo] ✓ empresa: ${e.razonSocial} · admin ${e.admin.email} · dominio ${e.dominio}`);
        return e;
      });
    }

    // ── Fase 2: ingreso a AssetPlanner como admin y siembra de maestros ──
    await test.step('2. Ingresar a AssetPlanner y sembrar equipo', async () => {
      await loginAssetAdmin(page, empresa.admin.email, empresa.admin.password);
      await cap.shot(page, 'asset-landing');
      const eq = await seedEquipo(page, cap);
      console.log(`[ciclo] ✓ equipo sembrado: ${eq.equipoCodigo}`);
    });

    // ── Fase 3: pañol + almacén + ciclo de OT (F3-F6) — en construcción ──
    // Próximos pasos: herramienta + salida/vale (F5/F6), artículo+stock (F4),
    // solicitud de servicio → OT → informe de servicio con F3/F4/F5.
  });
});
