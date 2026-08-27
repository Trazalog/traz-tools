#!/usr/bin/env node
/**
 * pw.mjs — envoltorio de `playwright test` para DocTest.
 *
 * Existe por dos razones:
 *   1. Elegir el project (`local` / `staging-v3`) a partir de `DOCTEST_ENV`, que
 *      puede venir del `.env` — Playwright no lee el `.env` antes de resolver los args.
 *   2. Que los scripts npm funcionen igual en Linux, Mac y Windows (sin `VAR=x cmd`).
 *
 * Uso: node scripts/pw.mjs [args de playwright test]
 *      Un `--project` explícito en los argumentos gana sobre `DOCTEST_ENV`.
 */

import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { config as cargarEnv } from 'dotenv';

const HERE = dirname(fileURLToPath(import.meta.url));
const DOCTEST_ROOT = resolve(HERE, '..');

cargarEnv({ path: join(DOCTEST_ROOT, '.env'), quiet: true });

const ENTORNOS = ['local', 'demo', 'staging-v3'];
const entorno = (process.env.DOCTEST_ENV ?? 'local').trim();
if (!ENTORNOS.includes(entorno)) {
  console.error(`DOCTEST_ENV inválido: "${entorno}". Valores admitidos: ${ENTORNOS.join(' | ')}.`);
  process.exit(2);
}

const argsUsuario = process.argv.slice(2);
const yaEligeProject = argsUsuario.some((a) => a === '--project' || a.startsWith('--project='));

const args = [
  'test',
  '--config',
  join(DOCTEST_ROOT, 'tests', 'e2e', 'playwright.config.ts'),
  ...(yaEligeProject ? [] : ['--project', entorno]),
  ...argsUsuario,
];

const bin = join(DOCTEST_ROOT, 'node_modules', '.bin', process.platform === 'win32' ? 'playwright.cmd' : 'playwright');
const res = spawnSync(bin, args, { stdio: 'inherit', cwd: DOCTEST_ROOT, env: process.env });
process.exit(res.status ?? 1);
