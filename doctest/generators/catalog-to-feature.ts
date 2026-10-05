/**
 * catalog-to-feature.ts — deriva los `.feature` Gherkin desde el catálogo (Doc 3 §6).
 *
 * Es una transformación mecánica: cada paso del caso se convierte en un par
 * Cuando/Entonces, cada flujo alternativo en un escenario, y las precondiciones en
 * los antecedentes. **Los `.feature` no se editan a mano**: si algo está mal, se
 * corrige el YAML y se regenera.
 *
 * Gherkin acá es formato de documentación, no runtime: no hay Cucumber (DT-2 del
 * Doc 3 §9). Lo que se busca es que un tester lea el caso sin abrir el YAML.
 *
 * Solo se derivan los casos `validado` (RF-01.3). Un caso en `borrador` u
 * `obsoleto` no genera archivo, y si tenía uno, se borra.
 *
 * Uso (en una terminal, parado en `doctest/`):
 *   npm run features            # todos los módulos con casos validados
 *   npm run features -- dnato   # solo uno
 */

import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { parse as parseYaml } from 'yaml';

const HERE = dirname(fileURLToPath(import.meta.url));
const RAIZ = resolve(HERE, '..');

interface Paso {
  paso: string;
  resultado: string;
}

interface Caso {
  id: string;
  modulo: string;
  titulo: string;
  perfil: string;
  estado: string;
  version: string | number;
  fecha_validacion?: string;
  pantallas?: string[];
  precondiciones?: string[];
  flujo_principal?: Paso[];
  flujos_alternativos?: { nombre: string; pasos: Paso[] }[];
  validaciones?: string[];
  datos_prueba?: Record<string, unknown>;
  notas?: string[];
  derivados?: Record<string, string>;
}

/** Nombre del archivo: `<ID>.<titulo-en-kebab>.feature`, como pide el Doc 3 §3. */
function nombreArchivo(c: Caso): string {
  const kebab = c.titulo
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 48)
    .replace(/-$/, '');
  return `${c.id}.${kebab}.feature`;
}

function escenario(titulo: string, pasos: Paso[], sangria = '  '): string {
  const lineas: string[] = [`${sangria}Escenario: ${titulo}`];
  pasos.forEach((p, i) => {
    lineas.push(`${sangria}  ${i === 0 ? 'Cuando' : 'Y cuando'} ${p.paso}`);
    lineas.push(`${sangria}  Entonces ${p.resultado}`);
  });
  return lineas.join('\n');
}

function aFeature(c: Caso): string {
  const l: string[] = [];
  l.push('# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.');
  l.push(`# Fuente: catalogo/${c.modulo.toLowerCase()}/${c.id}.yaml (versión ${c.version}, validado ${c.fecha_validacion ?? '—'}).`);
  l.push('# Si algo está mal, se corrige el caso y se regenera con `npm run features`.');
  if (c.derivados?.test_e2e) l.push(`# Test que lo implementa: ${c.derivados.test_e2e}`);
  l.push('');
  l.push(`@${c.modulo.toLowerCase()} @${c.id}`);
  l.push(`Característica: ${c.titulo}`);
  l.push('');
  l.push(`  Quién lo hace: ${c.perfil}`);
  if (c.pantallas?.length) l.push(`  Dónde: ${c.pantallas.join(' · ')}`);
  l.push('');

  if (c.precondiciones?.length) {
    l.push('  Antecedentes:');
    c.precondiciones.forEach((p, i) => l.push(`    ${i === 0 ? 'Dado' : 'Y'} ${p}`));
    l.push('');
  }

  if (c.flujo_principal?.length) {
    l.push(escenario('Camino principal', c.flujo_principal));
    l.push('');
  }

  for (const alt of c.flujos_alternativos ?? []) {
    l.push(escenario(alt.nombre, alt.pasos));
    l.push('');
  }

  if (c.validaciones?.length) {
    l.push('  # Reglas que este caso verifica:');
    c.validaciones.forEach((v) => l.push(`  #   - ${v}`));
    l.push('');
  }

  if (c.datos_prueba && Object.keys(c.datos_prueba).length) {
    l.push('  # Datos de prueba:');
    Object.entries(c.datos_prueba).forEach(([k, v]) =>
      l.push(`  #   ${k}: ${typeof v === 'object' ? JSON.stringify(v) : String(v)}`),
    );
    l.push('');
  }

  const avisos = (c.notas ?? []).filter((n) => /comportamiento esperado|no lo cumple|hallazgo H-|issue #/i.test(n));
  if (avisos.length) {
    l.push('  # ⚠️ Atención al ejecutarlo:');
    avisos.forEach((n) => l.push(`  #   ${n}`));
    l.push('');
  }

  return l.join('\n').replace(/\n{3,}/g, '\n\n').trimEnd() + '\n';
}

// ─────────────────────────────────────────────────────────────────────────────

/** `--dry-run` informa qué haría sin tocar un solo archivo: es como corre en CI. */
const DRY_RUN = process.argv.includes('--dry-run');
const soloModulo = (process.argv.find((a) => !a.startsWith('--') && !a.endsWith('.ts') && !a.includes('/')) ?? '').toLowerCase();
const dirCatalogo = join(RAIZ, 'catalogo');
const modulos = readdirSync(dirCatalogo, { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .map((d) => d.name)
  .filter((m) => !soloModulo || m === soloModulo);

let generados = 0;
let borrados = 0;

for (const modulo of modulos) {
  const casos = readdirSync(join(dirCatalogo, modulo))
    .filter((f) => /\.ya?ml$/i.test(f))
    .sort()
    .map((f) => parseYaml(readFileSync(join(dirCatalogo, modulo, f), 'utf8')) as Caso);
  if (!casos.length) continue;

  const destino = join(RAIZ, 'features', modulo);
  if (!DRY_RUN) mkdirSync(destino, { recursive: true });
  if (!existsSync(destino)) continue;

  const esperados = new Set<string>();
  for (const c of casos) {
    if (c.estado !== 'validado') continue;
    const archivo = nombreArchivo(c);
    esperados.add(archivo);
    const contenido = aFeature(c);
    const ruta = join(destino, archivo);
    const igual = existsSync(ruta) && readFileSync(ruta, 'utf8') === contenido;
    if (DRY_RUN) {
      if (!igual) console.log(`  · ${modulo}/${archivo} ${existsSync(ruta) ? 'quedaría actualizado' : 'se crearía'}`);
    } else if (!igual) {
      writeFileSync(ruta, contenido, 'utf8');
    }
    generados += 1;
  }

  // Un caso que dejó de estar validado no puede conservar su .feature (regla R3).
  for (const f of readdirSync(destino)) {
    if (f.endsWith('.feature') && !esperados.has(f)) {
      if (!DRY_RUN) rmSync(join(destino, f));
      borrados += 1;
      console.log(`  · ${modulo}/${f} ${DRY_RUN ? 'sobra' : 'eliminado'}: su caso ya no está validado`);
    }
  }
  console.log(`✓ ${modulo.toUpperCase()}: ${esperados.size} feature(s)`);
}

if (!generados && !borrados) console.log('No hay casos validados: no se generó ningún .feature.');
console.log(
  DRY_RUN
    ? `\n${generados} feature(s) al día, ${borrados} sobrante(s). No se escribió nada (--dry-run).\n`
    : `\n${generados} archivo(s) generados, ${borrados} eliminado(s).\n`,
);
if (DRY_RUN && borrados) process.exit(1);
if (!existsSync(join(RAIZ, 'features'))) process.exit(1);
