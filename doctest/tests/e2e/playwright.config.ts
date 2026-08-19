/**
 * Configuración de la suite E2E de DocTest (Doc 3 §4.1).
 *
 * Projects:
 *   - `local`      → apps levantadas en la máquina del developer
 *   - `staging-v3` → entorno de staging (default en CI)
 *
 * Selección: `DOCTEST_ENV=staging-v3 npm run test:smoke`, o `--project staging-v3`.
 * Las URLs salen de `doctest/.env` (plantilla en `.env.example`); nunca se hardcodean.
 */

import { defineConfig, devices } from '@playwright/test';
import { config as cargarEnv } from 'dotenv';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { urlDeApp } from './config/apps.ts';

const HERE = dirname(fileURLToPath(import.meta.url));
const DOCTEST_ROOT = resolve(HERE, '..', '..');

// `.env` es local y no se commitea; en CI las variables vienen del workflow.
cargarEnv({ path: resolve(DOCTEST_ROOT, '.env'), quiet: true });

const EN_CI = !!process.env.CI;

export default defineConfig({
  testDir: resolve(HERE, 'specs'),
  outputDir: resolve(HERE, '.test-results'),
  // RNF-02: la suite smoke tiene que quedar bajo 2 minutos; los tests, cortos.
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  forbidOnly: EN_CI,
  retries: EN_CI ? 1 : 0,
  workers: EN_CI ? 2 : undefined,
  reporter: EN_CI
    ? [['github'], ['list'], ['html', { outputFolder: resolve(HERE, '.playwright-report'), open: 'never' }]]
    : [['list'], ['html', { outputFolder: resolve(HERE, '.playwright-report'), open: 'never' }]],
  use: {
    // RNF-03: nada de esperas fijas — auto-wait de Playwright + asserts explícitos.
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    locale: 'es-AR',
    timezoneId: 'America/Argentina/San_Juan',
    ignoreHTTPSErrors: true,
  },
  projects: [
    {
      name: 'local',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: urlDeApp('tools', 'local'),
      },
    },
    {
      name: 'staging-v3',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: urlDeApp('tools', 'staging-v3'),
      },
    },
  ],
});
