#!/usr/bin/env node
/**
 * test-module.mjs — corre la suite de un módulo: `npm run test:module -- man`
 *
 * Los specs se etiquetan con `@<modulo>` (Doc 3 §4.1); acá solo se traduce el
 * nombre del módulo a un `--grep` y se excluye lo que esté en cuarentena.
 */

import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const MODULOS = ['dnato', 'man', 'alm', 'mcp', 'pan', 'prd', 'tar'];

const [modulo, ...resto] = process.argv.slice(2);
if (!modulo) {
  console.error(`Falta el módulo. Uso: npm run test:module -- <${MODULOS.join('|')}>`);
  process.exit(2);
}
if (!MODULOS.includes(modulo.toLowerCase())) {
  console.error(`Módulo desconocido: "${modulo}". Módulos: ${MODULOS.join(', ')}.`);
  process.exit(2);
}

const res = spawnSync(
  process.execPath,
  [
    join(HERE, 'pw.mjs'),
    '--grep',
    `@${modulo.toLowerCase()}`,
    '--grep-invert',
    '@quarantine',
    '--pass-with-no-tests',
    ...resto,
  ],
  { stdio: 'inherit', cwd: resolve(HERE, '..'), env: process.env },
);
process.exit(res.status ?? 1);
