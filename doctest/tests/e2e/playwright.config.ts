/**
 * Configuración de la suite E2E de DocTest (Doc 3 §4.1).
 *
 * Projects:
 *   - `local`      → apps levantadas en la máquina del developer
 *   - `demo`       → entorno DEMO de v2 (demo.cloudtrazalog.com), el único desplegado hoy
 *   - `staging-v3` → entorno de staging de v3, pendiente de E7-CICD
 *
 * Selección: `DOCTEST_ENV=demo npm run test:smoke`, o `--project demo`.
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
  // El ingreso real se hace una sola vez acá y los tests reutilizan la sesión.
  globalSetup: resolve(HERE, 'global-setup.ts'),
  outputDir: resolve(HERE, '.test-results'),
  // RNF-02 pide una suite smoke corta, pero cada ingreso consulta el sistema de
  // procesos y contra el DEMO llega a tardar ~40 s: el timeout contempla eso.
  timeout: 90_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  forbidOnly: EN_CI,
  // El entorno de pruebas es una máquina chica y compartida: con tests en paralelo
  // las pantallas empiezan a tardar más que cualquier tiempo máximo razonable y
  // aparecen fallas que no son del sistema sino del banco de pruebas. Medido: en
  // serie la suite es estable y tarda ~2 min; con dos workers falla un test al azar
  // en cada corrida. RNF-03 pide tests deterministas, así que va en serie.
  // El día que exista un staging propio, esto se sube.
  workers: 1,
  // Un reintento en CI cubre el corte de red puntual, no la inestabilidad: si un
  // test falla siempre, el reintento no lo salva.
  retries: EN_CI ? 1 : 0,
  reporter: EN_CI
    ? [['github'], ['list'], ['html', { outputFolder: resolve(HERE, '.playwright-report'), open: 'never' }]]
    : [['list'], ['html', { outputFolder: resolve(HERE, '.playwright-report'), open: 'never' }]],
  use: {
    // RNF-03: nada de esperas fijas — auto-wait de Playwright + asserts explícitos.
    actionTimeout: 15_000,
    navigationTimeout: 60_000,
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
      // Entorno DEMO de v2 (demo.cloudtrazalog.com): el único desplegado hoy.
      name: 'demo',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: urlDeApp('tools', 'demo'),
      },
    },
    {
      // staging-v3 todavía no existe (lo entrega E7-CICD); queda declarado para
      // que la suite no necesite cambios el día que exista.
      name: 'staging-v3',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: urlDeApp('tools', 'staging-v3'),
      },
    },
  ],
});
