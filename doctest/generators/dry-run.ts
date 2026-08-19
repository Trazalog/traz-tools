/**
 * dry-run.ts — corrida en seco de los generadores de DocTest (Doc 3 §6).
 *
 * Lo ejecuta `doctest-validate.yml` en cada PR que toca `doctest/`: verifica que
 * los generadores implementados corran sin escribir nada, y deja explícito cuáles
 * faltan todavía y en qué fase llegan. Falla si un generador declarado como
 * implementado no existe o termina con error.
 */

import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
/** Los generadores son TypeScript: se ejecutan con el tsx del propio proyecto. */
const TSX = join(HERE, '..', 'node_modules', '.bin', process.platform === 'win32' ? 'tsx.cmd' : 'tsx');

interface Generador {
  archivo: string;
  descripcion: string;
  /** Fase del plan de implementación en la que llega. */
  fase: string;
  implementado: boolean;
  /** Argumentos con los que corre en seco (solo lectura). Vacío = no se ejecuta. */
  dryRunArgs?: string[];
}

const GENERADORES: Generador[] = [
  {
    archivo: 'validate-catalog.ts',
    descripcion: 'Valida los YAML del catálogo contra el JSON Schema y las reglas duras (Doc 3 §3)',
    fase: 'F0',
    implementado: true,
    dryRunArgs: ['--selftest'],
  },
  {
    archivo: 'catalog-to-feature.ts',
    descripcion: 'Deriva los .feature Gherkin desde los casos validados',
    fase: 'F5',
    implementado: false,
  },
  {
    archivo: 'scaffold-spec.ts',
    descripcion: 'Genera el esqueleto del spec Playwright desde el YAML',
    fase: 'F5',
    implementado: false,
  },
  {
    archivo: 'build-ayudas.ts',
    descripcion:
      'Ensambla ayudas/build/ desde ayudas/src/ + plantilla: searchData de index.html generado desde TODOS los manuales, theme.css compartido, nombres de archivo y anclas sNN del sitio publicado intactos (Doc 3 §6)',
    fase: 'F2 (plantilla) / F5 (completo)',
    implementado: false,
  },
  {
    archivo: 'coverage-report.ts',
    descripcion: 'Cruza catálogo vs specs: casos validados sin test y tests sin caso',
    fase: 'F5',
    implementado: false,
  },
];

let fallas = 0;
console.log('\nDocTest · dry-run de generators\n');

for (const gen of GENERADORES) {
  const ruta = join(HERE, gen.archivo);
  const existe = existsSync(ruta);

  if (!gen.implementado) {
    console.log(`  ⏳ ${gen.archivo} — pendiente (${gen.fase}): ${gen.descripcion}`);
    if (existe) {
      console.log('      ⚠️  el archivo ya existe: marcarlo como implementado en dry-run.ts');
    }
    continue;
  }

  if (!existe) {
    console.log(`  ✖ ${gen.archivo} — declarado implementado pero no existe`);
    fallas += 1;
    continue;
  }

  const res = spawnSync(TSX, [ruta, ...(gen.dryRunArgs ?? [])], { stdio: 'inherit', env: process.env });
  if (res.status !== 0) {
    console.log(`  ✖ ${gen.archivo} — terminó con código ${res.status}`);
    fallas += 1;
  } else {
    console.log(`  ✓ ${gen.archivo} — dry-run OK`);
  }
}

console.log(fallas === 0 ? '\n✓ dry-run de generators OK\n' : `\n✖ dry-run con ${fallas} falla(s)\n`);
process.exit(fallas === 0 ? 0 : 1);
