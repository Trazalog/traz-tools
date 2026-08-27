/**
 * global-setup.ts — inicia sesión una sola vez, antes de toda la suite.
 *
 * Por qué existe: el ingreso real tarda entre 10 y 45 segundos contra el entorno
 * de pruebas, porque además de validar credenciales consulta el sistema de
 * procesos. Si eso ocurre dentro del primer test de cada worker, ese test paga el
 * costo y, con el banco de pruebas cargado, se pasa del tiempo máximo y falla por
 * ruido y no por el sistema — justo lo que RNF-03 no quiere.
 *
 * Acá se hace una vez, se guarda la sesión (`storageState`) y los tests solo la
 * reutilizan. Si una empresa no tiene credenciales configuradas, no se corta la
 * corrida: los tests que la necesiten van a fallar con un mensaje claro.
 */

import { chromium, type FullConfig } from '@playwright/test';
import { config as cargarEnv } from 'dotenv';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { guardarSesion, EMPRESAS, credencialesOpcionales } from './fixtures/auth.ts';

const HERE = dirname(fileURLToPath(import.meta.url));
cargarEnv({ path: resolve(HERE, '..', '..', '.env'), quiet: true });

export default async function globalSetup(_config: FullConfig): Promise<void> {
  const navegador = await chromium.launch();
  try {
    for (const empresa of EMPRESAS) {
      if (!credencialesOpcionales(empresa)) {
        console.log(`  · ${empresa}: sin credenciales configuradas, se omite el ingreso previo`);
        continue;
      }
      const desde = Date.now();
      await guardarSesion(navegador, empresa);
      console.log(`  · ${empresa}: sesión iniciada y guardada (${Math.round((Date.now() - desde) / 1000)} s)`);
    }
  } finally {
    await navegador.close();
  }
}
