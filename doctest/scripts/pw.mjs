#!/usr/bin/env node
/**
 * pw.mjs — envoltorio de `playwright test` para DocTest.
 *
 * Existe por dos razones:
 *   1. Elegir el project (`local` / `staging-v3`) a partir de `DOCTEST_ENV`, que
 *      puede venir del `.env` — Playwright no lee el `.env` antes de resolver los args.
 *   2. Que los scripts npm funcionen igual en Linux, Mac y Windows (sin `VAR=x cmd`).
 *
 * Uso: node scripts/pw.mjs [args de playwright test] [--capturas]
 *      Un `--project` explícito en los argumentos gana sobre `DOCTEST_ENV`.
 *      `--capturas` enciende las capturas a pedido (ver fixtures/capturas.ts): no es
 *      un flag de Playwright, así que se saca de los args y se pasa por entorno.
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

// `--capturas` no es un flag de Playwright: se saca de los args y se expresa por
// entorno, para que fixtures/capturas.ts saque capturas aunque los tests pasen.
const argsCrudos = process.argv.slice(2);
const capturas = argsCrudos.includes('--capturas');
const argsUsuario = argsCrudos.filter((a) => a !== '--capturas');
if (capturas) {
  process.env.DOCTEST_CAPTURAS = '1';
  // Un identificador de corrida compartido por todos los specs de esta ejecución,
  // para que todas sus capturas caigan bajo la misma carpeta.
  if (!process.env.DOCTEST_CAPTURAS_RUN) {
    const ahora = new Date();
    const p = (n) => String(n).padStart(2, '0');
    process.env.DOCTEST_CAPTURAS_RUN =
      `${ahora.getFullYear()}${p(ahora.getMonth() + 1)}${p(ahora.getDate())}-` +
      `${p(ahora.getHours())}${p(ahora.getMinutes())}${p(ahora.getSeconds())}`;
  }
  console.log(`📸 Capturas ENCENDIDAS → doctest/.capturas/${process.env.DOCTEST_CAPTURAS_RUN}/`);
}

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
