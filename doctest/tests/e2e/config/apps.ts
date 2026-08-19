/**
 * apps.ts — resolución de las URLs de las tres apps bajo prueba (Doc 3 §4.1).
 *
 * Asset Planner (MAN), Trazalog Tools (ALM/PAN/PRD/TAR) y Dnato son aplicaciones
 * distintas, con URL propia por entorno. Ninguna URL está hardcodeada acá: salen
 * de variables de entorno (`doctest/.env` en local, secrets/vars en CI).
 *
 * ⚠️ Regla: los tests nunca apuntan a producción (RNF-04 del Doc 1). El único
 * workflow autorizado a tocar producción es `doctest-smoke-prod.yml`, que usa
 * su propio set de variables y solo lecturas.
 */

export type App = 'tools' | 'man' | 'dnato';
export type Entorno = 'local' | 'staging-v3';

const VARIABLES: Record<Entorno, Record<App, string>> = {
  local: {
    tools: 'DOCTEST_LOCAL_URL_TOOLS',
    man: 'DOCTEST_LOCAL_URL_MAN',
    dnato: 'DOCTEST_LOCAL_URL_DNATO',
  },
  'staging-v3': {
    tools: 'DOCTEST_STAGING_URL_TOOLS',
    man: 'DOCTEST_STAGING_URL_MAN',
    dnato: 'DOCTEST_STAGING_URL_DNATO',
  },
};

/**
 * Hosts de producción de v2 (CLAUDE.md: "v2 corre en producción en cloudtrazalog.com").
 * Los subdominios NO se bloquean: `demo.` y `mcp.` son entornos de trabajo válidos.
 */
const HOSTS_PRODUCTIVOS = ['cloudtrazalog.com', 'www.cloudtrazalog.com'];

function safeHost(url: string): string | undefined {
  try {
    return new URL(url).host.toLowerCase();
  } catch {
    return undefined;
  }
}

export function entornoActual(): Entorno {
  const env = (process.env.DOCTEST_ENV ?? 'local').trim();
  if (env !== 'local' && env !== 'staging-v3') {
    throw new Error(`DOCTEST_ENV inválido: "${env}". Valores admitidos: local | staging-v3.`);
  }
  return env;
}

/** URL de una app, o `undefined` si el entorno todavía no la tiene configurada. */
export function urlDeApp(app: App, entorno: Entorno = entornoActual()): string | undefined {
  const override = process.env.DOCTEST_BASE_URL?.trim();
  if (override) return override;
  const valor = process.env[VARIABLES[entorno][app]]?.trim();
  return valor ? valor : undefined;
}

/**
 * Igual que `urlDeApp`, pero falla con un mensaje accionable en vez de dejar que
 * el test reviente con una URL vacía. Es la que usan los page objects.
 */
export function requerirUrlDeApp(app: App, entorno: Entorno = entornoActual()): string {
  const url = urlDeApp(app, entorno);
  if (!url) {
    throw new Error(
      `Falta la URL de la app "${app}" para el entorno "${entorno}": seteá ${VARIABLES[entorno][app]} ` +
        `en doctest/.env (plantilla en doctest/.env.example) o en las variables del workflow. ` +
        `Las URLs reales de staging-v3 las provee el PM — no inventarlas.`,
    );
  }
  const host = safeHost(url);
  if (host && HOSTS_PRODUCTIVOS.includes(host)) {
    // Guarda explícita contra RNF-04: los hosts productivos no se prueban desde acá.
    throw new Error(
      `La URL configurada para "${app}" apunta a un host productivo (${host}). ` +
        `DocTest solo corre contra staging-v3 o el entorno local (RNF-04).`,
    );
  }
  return url;
}
