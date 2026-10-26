/**
 * CICLO-UC-001 — Alta de una empresa nueva + ciclo de vida de la OT con herramientas y pañol.
 * Catálogo: catalogo/ciclo/CICLO-UC-001.yaml (encadena DNATO-UC-001..005 + MAN-UC-002/007/009/010 + maqueta F3-F6)
 *
 * Es el recorrido que pidió el PM: registrar una empresa LIMPIA por la registración de
 * tools y, en esa misma empresa, sembrar los maestros (equipo, pañol+herramientas,
 * almacén+artículos) y recorrer el ciclo de la OT viendo su interrelación con
 * herramientas y pañol (F3 texto libre, F4 entregas, F5 herramientas usadas, F6 el
 * pañolero asocia la OT). Cada paso deja una captura con `--capturas`.
 *
 * Se corre con capturas así:
 *   DOCTEST_ENV=demo node scripts/pw.mjs --grep @ciclo --capturas
 *
 * ⚠️ Crea datos reales en el entorno (una empresa nueva por corrida). Nunca producción.
 */

import { test } from '@playwright/test';

import { crearCapturador } from '../../fixtures/capturas.ts';
import { registrarEmpresa } from '../../flows/registrar-empresa.ts';

test.describe('@ciclo @CICLO-UC-001 @alta-empresa Ciclo: alta de empresa + OT con herramientas y pañol', () => {
  test.describe.configure({ mode: 'serial', timeout: 900_000 });

  test('registra una empresa nueva por la registración de tools', async ({ page }) => {
    const cap = crearCapturador('01-registracion');
    const empresa = await registrarEmpresa(page, cap);
    console.log('\n[ciclo] ✓ empresa registrada:');
    console.log(`  razón social : ${empresa.razonSocial}`);
    console.log(`  CUIT         : ${empresa.cuit}`);
    console.log(`  admin (login): ${empresa.admin.email}  pass: ${empresa.admin.password}`);
    console.log(`  dominio rol  : ${empresa.dominio}`);
    console.log(`  usuarios rol : ${Object.values(empresa.usuariosRol).join(' · ')}`);
    // Las fases siguientes (seed de maestros y ciclo de OT) se encadenan acá, reutilizando
    // `empresa` y el mismo `cap`. Se van sumando a medida que se construyen y verifican.
  });
});
