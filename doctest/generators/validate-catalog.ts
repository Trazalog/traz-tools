/**
 * validate-catalog.ts — validador del Catálogo Funcional de DocTest.
 *
 * Verifica todos los YAML de `doctest/catalogo/<modulo>/` contra el JSON Schema
 * (`catalogo/catalogo.schema.json`) y contra las reglas duras del
 * Doc 3 §3 que un schema no puede expresar.
 *
 * Uso:
 *   npm run validate:catalog                       # valida el catálogo completo
 *   npm run validate:catalog -- --diff-base origin/develop-v3   # + regla R6 (bump de versión)
 *   npm run validate:catalog:selftest              # valida el validador contra sus fixtures
 *
 * Códigos de regla:
 *   SCHEMA  el YAML no cumple el JSON Schema
 *   YAML    el archivo no parsea como YAML
 *   R1      estado: borrador ⇒ `dudas` no vacío y `derivados` vacío
 *   R2      estado: validado ⇒ `dudas` vacío, `fecha_validacion` presente y los derivados existen en disco
 *   R3      estado: obsoleto ⇒ `derivados` vacío y sus archivos derivados eliminados
 *   R4      coherencia de identidad: id ↔ nombre de archivo ↔ prefijo de módulo ↔ directorio
 *   R5      id duplicado en el catálogo
 *   R6      cambio de flujo/validaciones en un caso `validado` sin bump de `version`
 */

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { basename, dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { Ajv2020, type ErrorObject } from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { parse as parseYaml } from 'yaml';

const HERE = dirname(fileURLToPath(import.meta.url));
const DOCTEST_ROOT = resolve(HERE, '..');
const CATALOG_DIR = join(DOCTEST_ROOT, 'catalogo');
const SCHEMA_PATH = join(CATALOG_DIR, 'catalogo.schema.json');

const MODULOS = ['DNATO', 'MAN', 'ALM', 'MCP', 'PAN', 'PRD', 'TAR'] as const;

interface Issue {
  file: string;
  code: string;
  message: string;
}

interface Caso {
  id?: string;
  modulo?: string;
  estado?: string;
  version?: string | number;
  fecha_validacion?: string;
  dudas?: string[];
  derivados?: Record<string, string>;
  flujo_principal?: unknown;
  flujos_alternativos?: unknown;
  validaciones?: unknown;
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilidades
// ─────────────────────────────────────────────────────────────────────────────

function yamlFilesIn(dir: string): string[] {
  if (!existsSync(dir)) return [];
  const out: string[] = [];
  for (const entry of readdirSync(dir, { recursive: true, encoding: 'utf8' })) {
    const full = join(dir, entry);
    if (!/\.ya?ml$/i.test(entry)) continue;
    if (!statSync(full).isFile()) continue;
    out.push(full);
  }
  return out.sort();
}

function rel(file: string): string {
  return relative(DOCTEST_ROOT, file).split('\\').join('/');
}

function isEmptyDerivados(derivados: unknown): boolean {
  return derivados === undefined || derivados === null || Object.keys(derivados as object).length === 0;
}

function formatSchemaError(err: ErrorObject): string {
  const donde = err.instancePath === '' ? '(raíz)' : err.instancePath;
  const extra = err.params && Object.keys(err.params).length ? ` ${JSON.stringify(err.params)}` : '';
  return `${donde} ${err.message ?? ''}${extra}`.trim();
}

function buildValidator() {
  const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats.default(ajv);
  return ajv.compile(schema);
}

// ─────────────────────────────────────────────────────────────────────────────
// Reglas duras
// ─────────────────────────────────────────────────────────────────────────────

function reglasDeIdentidad(file: string, caso: Caso, verificarDirectorio: boolean): Issue[] {
  const issues: Issue[] = [];
  const nombre = basename(file).replace(/\.ya?ml$/i, '');

  if (caso.id && caso.id !== nombre) {
    issues.push({
      file,
      code: 'R4',
      message: `el id "${caso.id}" no coincide con el nombre del archivo "${nombre}.yaml"`,
    });
  }

  const prefijo = (caso.id ?? '').split('-')[0];
  if (caso.id && caso.modulo && prefijo !== caso.modulo) {
    issues.push({
      file,
      code: 'R4',
      message: `el módulo "${caso.modulo}" no coincide con el prefijo del id ("${prefijo}")`,
    });
  }

  const dirModulo = basename(dirname(file));
  const dirEsperado = (caso.modulo ?? '').toLowerCase();
  if (verificarDirectorio && caso.modulo && dirModulo !== dirEsperado) {
    issues.push({
      file,
      code: 'R4',
      message: `el archivo está en "catalogo/${dirModulo}/" pero el módulo es "${caso.modulo}" (esperado "catalogo/${dirEsperado}/")`,
    });
  }

  if (caso.modulo && !MODULOS.includes(caso.modulo as (typeof MODULOS)[number])) {
    issues.push({ file, code: 'R4', message: `módulo desconocido "${caso.modulo}"` });
  }

  return issues;
}

function reglasDeEstado(file: string, caso: Caso): Issue[] {
  const issues: Issue[] = [];
  const dudas = caso.dudas ?? [];
  const derivados = caso.derivados ?? {};

  if (caso.estado === 'borrador') {
    if (dudas.length === 0) {
      issues.push({
        file,
        code: 'R1',
        message: 'estado "borrador" exige al menos una entrada en `dudas` (modo conservador, RF-02.3)',
      });
    }
    if (!isEmptyDerivados(caso.derivados)) {
      issues.push({
        file,
        code: 'R1',
        message: 'un caso en "borrador" no puede tener derivados — ningún artefacto se genera desde un borrador (RF-01.3)',
      });
    }
  }

  if (caso.estado === 'validado') {
    if (dudas.length > 0) {
      issues.push({
        file,
        code: 'R2',
        message: 'estado "validado" exige `dudas` vacío — si quedan dudas de intención, el caso sigue en "borrador"',
      });
    }
    if (!caso.fecha_validacion) {
      issues.push({ file, code: 'R2', message: 'estado "validado" exige `fecha_validacion`' });
    }
    for (const [tipo, path] of Object.entries(derivados)) {
      const limpio = String(path).split('#')[0];
      if (!existsSync(join(DOCTEST_ROOT, limpio))) {
        issues.push({
          file,
          code: 'R2',
          message: `el derivado ${tipo} declarado ("${limpio}") no existe en el repo`,
        });
      }
    }
  }

  if (caso.estado === 'obsoleto') {
    if (!isEmptyDerivados(caso.derivados)) {
      issues.push({
        file,
        code: 'R3',
        message: 'un caso "obsoleto" conserva su historia pero no sus derivados: vaciar `derivados` y borrar los archivos',
      });
    }
  }

  return issues;
}

/** R6 — bump de versión obligatorio si cambió el comportamiento de un caso validado. */
function reglaBumpDeVersion(files: string[], base: string): Issue[] {
  const issues: Issue[] = [];
  const CAMPOS = ['flujo_principal', 'flujos_alternativos', 'validaciones'] as const;

  for (const file of files) {
    const rutaRepo = relative(resolve(DOCTEST_ROOT, '..'), file).split('\\').join('/');
    let anterior: string;
    try {
      anterior = execFileSync('git', ['show', `${base}:${rutaRepo}`], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
        cwd: resolve(DOCTEST_ROOT, '..'),
      });
    } catch {
      continue; // archivo nuevo en esta rama, o base inaccesible: nada que comparar
    }

    let casoAnterior: Caso;
    let casoActual: Caso;
    try {
      casoAnterior = parseYaml(anterior) as Caso;
      casoActual = parseYaml(readFileSync(file, 'utf8')) as Caso;
    } catch {
      continue; // el error de parseo lo reporta la validación normal
    }
    if (casoAnterior?.estado !== 'validado') continue;

    const cambio = CAMPOS.some(
      (campo) => JSON.stringify(casoAnterior[campo] ?? null) !== JSON.stringify(casoActual[campo] ?? null),
    );
    if (cambio && String(casoAnterior.version) === String(casoActual.version)) {
      issues.push({
        file,
        code: 'R6',
        message: `cambió el comportamiento de un caso validado sin bump de \`version\` (sigue en ${casoActual.version}); regenerar además sus derivados en el mismo PR`,
      });
    }
  }
  return issues;
}

// ─────────────────────────────────────────────────────────────────────────────
// Validación de un conjunto de archivos
// ─────────────────────────────────────────────────────────────────────────────

function validarArchivos(files: string[], verificarDirectorio: boolean): Issue[] {
  const validate = buildValidator();
  const issues: Issue[] = [];
  const vistos = new Map<string, string>();

  for (const file of files) {
    let caso: Caso;
    try {
      caso = parseYaml(readFileSync(file, 'utf8')) as Caso;
    } catch (e) {
      issues.push({ file, code: 'YAML', message: (e as Error).message.split('\n')[0] });
      continue;
    }
    if (caso === null || typeof caso !== 'object') {
      issues.push({ file, code: 'YAML', message: 'el archivo está vacío o no contiene un mapa YAML' });
      continue;
    }

    if (!validate(caso)) {
      for (const err of validate.errors ?? []) {
        issues.push({ file, code: 'SCHEMA', message: formatSchemaError(err) });
      }
    }

    issues.push(...reglasDeIdentidad(file, caso, verificarDirectorio));
    issues.push(...reglasDeEstado(file, caso));

    if (caso.id) {
      const previo = vistos.get(caso.id);
      if (previo) {
        issues.push({ file, code: 'R5', message: `id duplicado: ya lo usa ${rel(previo)}` });
      } else {
        vistos.set(caso.id, file);
      }
    }
  }

  return issues;
}

function imprimir(issues: Issue[], files: string[]): void {
  const porArchivo = new Map<string, Issue[]>();
  for (const i of issues) {
    const arr = porArchivo.get(i.file) ?? [];
    arr.push(i);
    porArchivo.set(i.file, arr);
  }
  for (const [file, arr] of porArchivo) {
    console.log(`\n  ✖ ${rel(file)}`);
    for (const i of arr) console.log(`      [${i.code}] ${i.message}`);
  }
  console.log(
    `\n${issues.length === 0 ? '✓' : '✖'} ${files.length} caso(s) revisado(s), ${issues.length} problema(s).\n`,
  );
}

function resumenPorEstado(files: string[]): void {
  const conteo: Record<string, number> = { borrador: 0, validado: 0, obsoleto: 0 };
  for (const file of files) {
    try {
      const caso = parseYaml(readFileSync(file, 'utf8')) as Caso;
      if (caso?.estado && caso.estado in conteo) conteo[caso.estado] += 1;
    } catch {
      /* ya reportado */
    }
  }
  console.log(
    `  estado: ${conteo.validado} validado(s) · ${conteo.borrador} borrador(es) · ${conteo.obsoleto} obsoleto(s)`,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Selftest: el validador se prueba a sí mismo contra generators/fixtures/
// ─────────────────────────────────────────────────────────────────────────────

function selftest(): number {
  const dirValidos = join(HERE, 'fixtures', 'validos');
  const dirInvalidos = join(HERE, 'fixtures', 'invalidos');
  let fallas = 0;

  const validos = yamlFilesIn(dirValidos);
  const issuesValidos = validarArchivos(validos, false);
  if (issuesValidos.length > 0) {
    console.log('✖ fixtures válidas que el validador rechaza:');
    imprimir(issuesValidos, validos);
    fallas += issuesValidos.length;
  } else {
    console.log(`✓ ${validos.length} fixture(s) válida(s) aceptada(s)`);
  }

  for (const file of yamlFilesIn(dirInvalidos)) {
    const primeraLinea = readFileSync(file, 'utf8').split('\n')[0];
    const esperado = /#\s*expect-error:\s*([A-Z0-9]+)/.exec(primeraLinea)?.[1];
    if (!esperado) {
      console.log(`✖ ${rel(file)}: falta la cabecera "# expect-error: <CODIGO>"`);
      fallas += 1;
      continue;
    }
    const issues = validarArchivos([file], false);
    const codigos = new Set(issues.map((i) => i.code));
    if (codigos.has(esperado)) {
      console.log(`✓ ${rel(file)}: detectado ${esperado}`);
    } else {
      console.log(
        `✖ ${rel(file)}: se esperaba ${esperado} y se obtuvo [${[...codigos].join(', ') || 'ningún error'}]`,
      );
      fallas += 1;
    }
  }

  console.log(fallas === 0 ? '\n✓ selftest del validador OK\n' : `\n✖ selftest con ${fallas} falla(s)\n`);
  return fallas === 0 ? 0 : 1;
}

// ─────────────────────────────────────────────────────────────────────────────
// Entrada
// ─────────────────────────────────────────────────────────────────────────────

function main(): number {
  const argv = process.argv.slice(2);
  if (argv.includes('--selftest')) return selftest();

  const idxBase = argv.indexOf('--diff-base');
  const diffBase = idxBase >= 0 ? argv[idxBase + 1] : undefined;

  const files = yamlFilesIn(CATALOG_DIR);
  console.log(`\nDocTest · validando catálogo en ${rel(CATALOG_DIR)}/`);

  const issues = validarArchivos(files, true);
  if (diffBase) issues.push(...reglaBumpDeVersion(files, diffBase));

  resumenPorEstado(files);
  imprimir(issues, files);
  return issues.length === 0 ? 0 : 1;
}

process.exit(main());
