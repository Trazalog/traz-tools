#!/usr/bin/env node
/**
 * doctest.mjs — el comando único de DocTest: `npm run doctest -- <modo> [opciones]`.
 *
 * Modos:
 *   regresion  (el de todos los días) lo NUEVO de tu rama + el SET DE REGRESIÓN, contra
 *              las empresas del perfil del ambiente. Es el que se corre antes de cada
 *              commit/push (contra tu máquina) y después de desplegar (contra el ambiente).
 *   nuevos     solo lo nuevo de tu rama.
 *   casi-full  crea dos empresas desde cero, las deja en el perfil del ambiente y corre
 *              el set de regresión contra ellas.
 *   full       crea dos empresas, le carga datos a la primera (AssetPlanner: maestros,
 *              equipo, herramienta), las deja en el perfil y corre TODO: regresión +
 *              circuitos largos (@ciclo).
 *
 * Opciones:
 *   --entorno <local|demo|staging-v3>  contra qué ambiente (si no, DOCTEST_ENV del .env)
 *   --base <rama o tag>                contra qué se calcula "lo nuevo" (default: origin/develop).
 *                                      Después de desplegar, el tag de la versión ANTERIOR.
 *   --sin-perfil                       ignora entornos/<entorno>.json y usa las credenciales del .env
 *   --plan                             muestra qué correría y sale, sin ejecutar nada
 *
 * Qué es cada cosa:
 *   - LO NUEVO: las pruebas que cambiaron en tu rama respecto de --base (los .spec.ts
 *     tocados y las pruebas declaradas en `derivados.test_e2e` de los casos .yaml tocados),
 *     incluido lo que todavía no commiteaste.
 *   - SET DE REGRESIÓN: toda la suite estable — todo menos @quarantine (inestables),
 *     @alta-empresa (crea una empresa), @ciclo (circuitos largos) y @preparar-entorno. Las
 *     pruebas con `test.fail()` quedan adentro: son las que avisan cuando se arregla un bug.
 *   - PERFIL DEL AMBIENTE: `entornos/<entorno>.json`, con qué empresas probar. Lo escriben
 *     casi-full y full; si no existe, se usan las variables del .env.
 */

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { config as cargarEnv } from 'dotenv';
import { parse as parseYaml } from 'yaml';

const HERE = dirname(fileURLToPath(import.meta.url));
const DOCTEST_ROOT = resolve(HERE, '..');
const REPO_ROOT = resolve(DOCTEST_ROOT, '..');

cargarEnv({ path: join(DOCTEST_ROOT, '.env'), quiet: true });

const MODOS = ['regresion', 'nuevos', 'casi-full', 'full'];
const FUERA_DE_REGRESION = ['@quarantine', '@alta-empresa', '@ciclo', '@preparar-entorno'];
const FUERA_DE_FULL = ['@quarantine', '@alta-empresa', '@preparar-entorno'];

// ── argumentos ──────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const opcion = (nombre) => {
  const i = args.indexOf(nombre);
  return i >= 0 ? args[i + 1] : undefined;
};
const modo = (args.find((a) => !a.startsWith('--') && MODOS.includes(a)) ?? 'regresion').toLowerCase();
const desconocido = args.find(
  (a, i) => !a.startsWith('--') && !MODOS.includes(a) && !['--entorno', '--base'].includes(args[i - 1]),
);
if (desconocido) {
  console.error(`Modo desconocido: "${desconocido}". Modos: ${MODOS.join(', ')}.`);
  process.exit(2);
}
if (opcion('--entorno')) process.env.DOCTEST_ENV = opcion('--entorno');
const entorno = (process.env.DOCTEST_ENV ?? 'local').trim();
const base = opcion('--base') ?? 'origin/develop';
const soloPlan = args.includes('--plan');
const sinPerfil = args.includes('--sin-perfil');

// ── perfil del ambiente ─────────────────────────────────────────────────────
const rutaPerfil = join(DOCTEST_ROOT, 'entornos', `${entorno}.json`);

/** Pasa las credenciales del perfil a las variables que lee la suite (pisan las del .env). */
function aplicarPerfil() {
  if (sinPerfil) {
    console.log(`👤 Perfil: --sin-perfil → credenciales del .env`);
    return;
  }
  if (!existsSync(rutaPerfil)) {
    console.log(`👤 Perfil: no hay entornos/${entorno}.json → credenciales del .env`);
    return;
  }
  const p = JSON.parse(readFileSync(rutaPerfil, 'utf8'));
  const set = (k, v) => {
    if (v) process.env[k] = v;
  };
  set('DOCTEST_EMPRESA1_NOMBRE', p.empresa1?.nombre);
  set('DOCTEST_EMPRESA1_USER', p.empresa1?.admin?.usuario);
  set('DOCTEST_EMPRESA1_PASS', p.empresa1?.admin?.clave);
  set('DOCTEST_EMPRESA2_NOMBRE', p.empresa2?.nombre);
  set('DOCTEST_EMPRESA2_USER', p.empresa2?.admin?.usuario);
  set('DOCTEST_EMPRESA2_PASS', p.empresa2?.admin?.clave);
  set('DOCTEST_MAN_USER', p.man?.usuario);
  set('DOCTEST_MAN_PASS', p.man?.clave);
  // Mantenimiento corre dentro de Tools con la empresa 1 recién creada, no con un usuario fijo:
  // el perfil pisa las variables por ambiente, y lo que cargó el modo full es de esa empresa.
  const pre = { local: 'LOCAL', demo: 'DEMO', 'staging-v3': 'STAGING' }[entorno];
  set(`DOCTEST_${pre}_MAN_USER`, p.man?.usuario);
  set(`DOCTEST_${pre}_MAN_PASS`, p.man?.clave);
  set(`DOCTEST_${pre}_MAN_EMPRESA`, p.empresa1?.nombre);
  set(`DOCTEST_${pre}_MAN_PREVENTIVO`, p.sembrado?.preventivo);
  set(`DOCTEST_${pre}_MAN_RESPONSABLE`, p.sembrado?.responsable);
  set(`DOCTEST_${pre}_MAN_OT_MATERIALES`, p.sembrado?.otMateriales);
  set('DOCTEST_ALM_SOLICITANTE_USER', p.alm?.solicitante?.usuario);
  set('DOCTEST_ALM_SOLICITANTE_PASS', p.alm?.solicitante?.clave);
  set('DOCTEST_ALM_ALMACEN_USER', p.alm?.almacen?.usuario);
  set('DOCTEST_ALM_ALMACEN_PASS', p.alm?.almacen?.clave);
  // Los circuitos largos (@ciclo) reusan la empresa 1 en vez de registrar otra.
  set('DOCTEST_CICLO_ADMIN', p.empresa1?.admin?.usuario);
  set('DOCTEST_CICLO_PASS', p.empresa1?.admin?.clave);
  set('DOCTEST_CICLO_RAZON', p.empresa1?.nombre);
  console.log(
    `👤 Perfil: entornos/${entorno}.json (${p.modo}, ${p.creado?.slice(0, 16)}) → ` +
      `empresa 1 "${p.empresa1?.nombre}", empresa 2 "${p.empresa2?.nombre}"`,
  );
}

// ── lo nuevo de la rama ─────────────────────────────────────────────────────
function git(...a) {
  const r = spawnSync('git', a, { cwd: REPO_ROOT, encoding: 'utf8' });
  if (r.status !== 0) throw new Error(`git ${a.join(' ')}: ${(r.stderr || '').trim()}`);
  return r.stdout.split('\n').map((l) => l.trim()).filter(Boolean);
}

function calcularNuevos() {
  try {
    git('rev-parse', '--verify', '--quiet', `${base}^{commit}`);
  } catch {
    console.error(`No encuentro "${base}" para calcular lo nuevo. Pasá --base <rama o tag> (y hacé git fetch).`);
    process.exit(2);
  }
  const cambiados = new Set([
    ...git('diff', '--name-only', `${base}...HEAD`, '--', 'doctest/'),
    ...git('diff', '--name-only', 'HEAD', '--', 'doctest/'),
    ...git('ls-files', '--others', '--exclude-standard', '--', 'doctest/'),
  ]);
  const pruebas = new Set();
  for (const f of cambiados) {
    const abs = join(REPO_ROOT, f);
    if (!existsSync(abs)) continue; // borrado
    if (/^doctest\/tests\/e2e\/specs\/.+\.spec\.ts$/.test(f)) {
      if (!f.includes('/specs/entorno/')) pruebas.add(relative(DOCTEST_ROOT, abs));
    } else if (/^doctest\/catalogo\/.+\.ya?ml$/.test(f)) {
      const caso = parseYaml(readFileSync(abs, 'utf8')) ?? {};
      const derivadas = [caso?.derivados?.test_e2e].flat().filter(Boolean);
      for (const d of derivadas) if (existsSync(join(DOCTEST_ROOT, d))) pruebas.add(d);
    }
  }
  return [...pruebas].sort();
}

/** Etiquetas de caso (@DNATO-UC-006, @ALM-UC-006-007…) declaradas en un spec. */
function etiquetasDe(archivo) {
  const texto = readFileSync(join(DOCTEST_ROOT, archivo), 'utf8');
  return [...new Set(texto.match(/@[A-Z]+-UC-\d+(?:-\d+)*/g) ?? [])];
}

const escaparRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// ── ejecución ───────────────────────────────────────────────────────────────
const pasos = [];

function correr(nombre, argsPw, envExtra = {}) {
  console.log(`\n━━━ ${nombre} ━━━`);
  if (soloPlan) {
    console.log(`   (plan) node scripts/pw.mjs ${argsPw.join(' ')}`);
    pasos.push({ nombre, ok: true, plan: true });
    return true;
  }
  const desde = Date.now();
  const r = spawnSync(process.execPath, [join(HERE, 'pw.mjs'), ...argsPw], {
    stdio: 'inherit',
    cwd: DOCTEST_ROOT,
    env: { ...process.env, ...envExtra },
  });
  const ok = r.status === 0;
  pasos.push({ nombre, ok, segundos: Math.round((Date.now() - desde) / 1000) });
  return ok;
}

function regresion(excluirEtiquetas = []) {
  const fuera = [...FUERA_DE_REGRESION, ...excluirEtiquetas.map(escaparRegex)].join('|');
  return correr('Set de regresión', ['--grep-invert', fuera, '--pass-with-no-tests']);
}

function nuevos() {
  const lista = calcularNuevos();
  console.log(`\n🆕 Lo nuevo respecto de ${base}: ${lista.length ? '' : 'nada'}`);
  for (const f of lista) console.log(`   · ${f}`);
  if (!lista.length) return { ok: true, etiquetas: [] };
  // Los archivos van al final: pw.mjs pone `--project <entorno>` adelante, y esa opción de
  // Playwright acepta varios valores, así que un archivo pegado a ella se toma por proyecto.
  const ok = correr('Pruebas nuevas', ['--grep-invert', '@quarantine', ...lista]);
  return { ok, etiquetas: lista.flatMap(etiquetasDe) };
}

function preparar(sembrar) {
  console.log(
    `\n⚠️  Se van a registrar DOS empresas nuevas en "${entorno}"${sembrar ? ' y cargar datos en la primera' : ''}. ` +
      'Quedan en el ambiente.',
  );
  return correr(
    sembrar ? 'Preparar el ambiente (empresas + datos)' : 'Preparar el ambiente (empresas)',
    ['--grep', '@preparar-entorno'],
    { DOCTEST_SALTAR_SESIONES: '1', ...(sembrar ? { DOCTEST_PREPARAR_SEMBRAR: '1' } : {}) },
  );
}

console.log(`DocTest · modo ${modo} · ambiente ${entorno}${soloPlan ? ' · solo plan' : ''}`);
const inicio = Date.now();

if (modo === 'regresion' || modo === 'nuevos') {
  aplicarPerfil();
  const n = nuevos();
  if (modo === 'regresion' && (n.ok || soloPlan)) regresion(n.etiquetas);
} else {
  const sembrar = modo === 'full';
  if (preparar(sembrar) || soloPlan) {
    aplicarPerfil(); // ahora sí, el perfil recién escrito
    if (sembrar) {
      correr('Todas las pruebas (regresión + circuitos largos)', [
        '--grep-invert',
        FUERA_DE_FULL.join('|'),
        '--pass-with-no-tests',
      ]);
    } else {
      regresion();
    }
  }
}

// ── resumen ─────────────────────────────────────────────────────────────────
console.log('\n━━━ Resumen ━━━');
for (const p of pasos) {
  console.log(`${p.plan ? '•' : p.ok ? '✅' : '❌'} ${p.nombre}${p.segundos != null ? ` (${p.segundos} s)` : ''}`);
}
const todoOk = pasos.every((p) => p.ok);
if (soloPlan) {
  console.log('Plan mostrado, no se ejecutó nada.');
} else if (todoOk) {
  console.log(`Todo verde en ${Math.round((Date.now() - inicio) / 60000)} min.` +
    (modo === 'regresion' ? ' Listo para commit y push.' : ''));
} else {
  console.log('Hay pruebas en rojo: el reporte se abre con `npm run test:report`.');
}
process.exit(todoOk ? 0 : 1);
