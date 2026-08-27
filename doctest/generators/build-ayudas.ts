/**
 * build-ayudas.ts — arma el sitio de ayudas publicable (Doc 1 RF-05, Doc 3 §6).
 *
 * **Dónde sale:** en `ayuda/`, en la raíz del repo del frontend. Esa carpeta se sirve
 * como `<base_url>ayuda/` sin pasar por CodeIgniter (el `.htaccess` rutea a `index.php`
 * solo lo que no existe en disco), y va **versionada**: el frontend no tiene build step,
 * así que el deploy es el mismo de siempre y no necesita Node. Decisión del PM
 * (2026-08-25): las ayudas son parte de traz-tools, no un sitio aparte.
 *
 * Qué hace:
 *   1. Copia el sitio actual (`ayudas/legacy/`) tal cual al destino. Los
 *      manuales publicados se respetan como están, **incluidos los nombres de
 *      archivo con typo** (`correrctivo`, `mantenimeinto`): son URLs que la gente ya
 *      tiene guardadas y linkeadas.
 *   2. Ensambla los manuales nuevos de `ayudas/src/<modulo>/*.html` con la plantilla
 *      (`ayudas/plantilla/`), que aporta portada, menú lateral y pie, y con el
 *      `theme.css` compartido — las variables de color y tipografía dejan de estar
 *      duplicadas en cada archivo.
 *   3. **Regenera el índice del buscador del inicio recorriendo TODOS los manuales**,
 *      los viejos y los nuevos. Ese índice hoy está escrito a mano y solo cubre dos
 *      manuales: es la deuda que el RF-05.3 pide resolver, y se resuelve acá.
 *
 * Los archivos de `ayudas/src/` llevan solo las secciones (`<section id="sNN">…`) y
 * su metadata en un comentario al principio (`meta:titulo=…`). Todo lo demás lo pone
 * la plantilla.
 *
 * Uso (en una terminal, parado en `doctest/`):
 *   npm run ayudas             # arma <repo>/ayuda/
 *   npm run ayudas -- --dry-run
 */

import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const RAIZ = resolve(HERE, '..');
const LEGACY = join(RAIZ, 'ayudas', 'legacy');
const PLANTILLA = join(RAIZ, 'ayudas', 'plantilla');
const SRC = join(RAIZ, 'ayudas', 'src');
// El sitio armado vive en el frontend, no dentro de doctest/: es lo que se publica.
const BUILD = resolve(RAIZ, '..', 'ayuda');

const DRY_RUN = process.argv.includes('--dry-run');

/** Una entrada del buscador del inicio. */
interface EntradaBusqueda {
  title: string;
  desc: string;
  keywords: string[];
  url: string;
  icon: string;
  manual: string;
}

const ICONOS: Record<string, string> = {
  correctivo: '🔧',
  preventivo: '🗓️',
  equipos: '⚙️',
  almacen: '📦',
  configuracion: '🛠️',
  registracion: '🔑',
};

function sinEtiquetas(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&[a-z]+;/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Palabras significativas de un texto, para que el buscador encuentre por contenido. */
function palabrasClave(texto: string, tope = 14): string[] {
  const vacias = new Set(
    'para con los las una uno del que por como sobre este esta esto sus más son ser hay muy cada donde cuando desde entre todo toda todos todas puede pueden tiene tienen hacer hace acá aca vos tu tus'.split(' '),
  );
  const cuenta = new Map<string, number>();
  for (const p of texto.toLowerCase().match(/[a-záéíóúñ]{4,}/g) ?? []) {
    if (vacias.has(p)) continue;
    cuenta.set(p, (cuenta.get(p) ?? 0) + 1);
  }
  return [...cuenta.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, tope)
    .map(([p]) => p);
}

function claveManual(archivo: string): string {
  const n = basename(archivo, '.html').toLowerCase();
  if (n.includes('correrctivo') || n.includes('correctivo')) return 'correctivo';
  if (n.includes('preventivo') || n.includes('mantenimeinto')) return 'preventivo';
  if (n.includes('equipos')) return 'equipos';
  if (n.includes('almacen')) return 'almacen';
  if (n.includes('configuracion')) return 'configuracion';
  if (n.includes('registracion')) return 'registracion';
  return 'manual';
}

/** Extrae una entrada de búsqueda por cada sección `sNN` de un manual ya armado. */
function entradasDeManual(archivo: string, html: string): EntradaBusqueda[] {
  const manual = claveManual(archivo);
  const icono = ICONOS[manual] ?? '📄';
  const entradas: EntradaBusqueda[] = [];

  const secciones = html.matchAll(/<section id="(s\d+)"[\s\S]*?(?=<section id="|<\/div><!-- \/content -->|$)/g);
  for (const s of secciones) {
    const bloque = s[0];
    const ancla = s[1];
    const titulo = /<h2[^>]*>([\s\S]*?)<\/h2>/.exec(bloque)?.[1];
    if (!titulo) continue;
    const texto = sinEtiquetas(bloque);
    const limpio = sinEtiquetas(titulo);
    entradas.push({
      title: limpio,
      desc: texto.slice(limpio.length).trim().slice(0, 150).replace(/\s\S*$/, '') + '…',
      keywords: palabrasClave(texto),
      url: `${basename(archivo)}#${ancla}`,
      icon: icono,
      manual,
    });
  }
  return entradas;
}

/** Metadata declarada en el comentario de cabecera del archivo de contenido. */
function metadata(html: string): Record<string, string> {
  const meta: Record<string, string> = {};
  for (const m of html.matchAll(/meta:([a-z_]+)=(.*)/g)) meta[m[1]] = m[2].trim();
  return meta;
}

function navDeSecciones(html: string): string {
  const items: string[] = [];
  for (const s of html.matchAll(/<section id="(s\d+)"[\s\S]*?<h2[^>]*>([\s\S]*?)<\/h2>/g)) {
    const num = s[1].replace('s', '');
    items.push(
      `<a class="nav-item" href="#${s[1]}"><span class="nav-num">${num}</span> ${sinEtiquetas(s[2])}</a>`,
    );
  }
  return items.join('\n      ');
}

function copiarLegacy(): string[] {
  const copiados: string[] = [];
  for (const archivo of readdirSync(LEGACY)) {
    const origen = join(LEGACY, archivo);
    if (!statSync(origen).isFile() || !archivo.endsWith('.html')) continue;
    if (!DRY_RUN) copyFileSync(origen, join(BUILD, archivo));
    copiados.push(archivo);
  }
  return copiados;
}

function armarManuales(): { archivo: string; casos: string }[] {
  if (!existsSync(SRC)) return [];
  const plantilla = readFileSync(join(PLANTILLA, 'manual.html'), 'utf8');
  const armados: { archivo: string; casos: string }[] = [];
  const hoy = new Date().toISOString().slice(0, 10);

  for (const modulo of readdirSync(SRC, { withFileTypes: true }).filter((d) => d.isDirectory())) {
    for (const archivo of readdirSync(join(SRC, modulo.name)).filter((f) => f.endsWith('.html'))) {
      const contenido = readFileSync(join(SRC, modulo.name, archivo), 'utf8');
      const meta = metadata(contenido);
      const secciones = contenido.replace(/^<!--[\s\S]*?-->\s*/, '');

      const html = plantilla
        .replace(/\{\{TITULO\}\}/g, meta.titulo ?? basename(archivo, '.html'))
        .replace(/\{\{PORTADA\}\}/g, meta.portada ?? meta.titulo ?? '')
        .replace(/\{\{SUBTITULO\}\}/g, meta.subtitulo ?? '')
        .replace(/\{\{MODULO\}\}/g, meta.modulo ?? modulo.name.toUpperCase())
        .replace(/\{\{CODIGO\}\}/g, meta.codigo ?? '—')
        .replace(/\{\{VERSION\}\}/g, meta.version ?? '1.0')
        .replace(/\{\{FECHA\}\}/g, hoy)
        .replace(/\{\{CASOS\}\}/g, meta.casos ?? '—')
        .replace(/\{\{FUENTE\}\}/g, `ayudas/src/${modulo.name}/${archivo}`)
        .replace(/\{\{NAV\}\}/g, navDeSecciones(secciones))
        .replace(/\{\{OTROS\}\}/g, otrosManuales(archivo))
        .replace(/\{\{SECCIONES\}\}/g, secciones.trim());

      if (!DRY_RUN) {
        writeFileSync(join(BUILD, archivo), html, 'utf8');
        const indice = join(BUILD, 'index.html');
        if (existsSync(indice)) {
          writeFileSync(indice, agregarTarjeta(readFileSync(indice, 'utf8'), archivo, meta), 'utf8');
        }
      }
      armados.push({ archivo, casos: meta.casos ?? '—' });
    }
  }
  return armados;
}

/** Enlaces a los otros manuales publicados, para el menú lateral. */
function otrosManuales(propio: string): string {
  const nombres: Record<string, string> = {
    'manual_configuracion_inicial.html': 'Configuración inicial',
    'manual_alta_equipos_componentes.html': 'Alta de equipos',
    'manual_mantenimiento_correrctivo.html': 'Mantenimiento correctivo',
    'manual_mantenimeinto_preventivo.html': 'Mantenimiento preventivo',
    'manual_almacen_mantenimiento.html': 'Almacén',
  };
  return Object.entries(nombres)
    .filter(([archivo]) => archivo !== propio)
    .map(
      ([archivo, nombre]) =>
        `<a class="nav-item" href="${archivo}" style="color:var(--teal)"><span class="nav-num" style="background:rgba(13,115,119,.15);color:var(--teal)">›</span> ${nombre}</a>`,
    )
    .join('\n      ');
}

/** Agrega al inicio la tarjeta de un manual nuevo, con el mismo formato que las demás. */
function agregarTarjeta(html: string, archivo: string, meta: Record<string, string>): string {
  if (html.includes(`href="${archivo}"`)) return html;
  const tarjeta = `      <a href="${archivo}" class="card">
        <div class="card-header">
          <div class="card-icon amber">&#128273;</div>
          <div class="card-meta">
            <h3>${meta.titulo ?? archivo}</h3>
            <p>${meta.modulo ?? ''}</p>
          </div>
        </div>
        <div class="card-body">
          <p class="card-desc">${meta.subtitulo ?? ''}</p>
          <div class="card-arrow">
            Ver manual
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
        </div>
      </a>
`;
  return html.replace('<div class="cards-grid">', `<div class="cards-grid">\n${tarjeta}`);
}

/**
 * Reescribe el índice del buscador del inicio con TODAS las secciones de TODOS los
 * manuales. Antes se mantenía a mano y cubría dos: esa era la deuda del RF-05.3.
 */
function regenerarBuscador(): number {
  const indice = join(BUILD, 'index.html');
  if (!existsSync(indice)) return 0;

  const entradas: EntradaBusqueda[] = [];
  for (const archivo of readdirSync(BUILD).filter((f) => f.endsWith('.html') && f !== 'index.html')) {
    entradas.push(...entradasDeManual(archivo, readFileSync(join(BUILD, archivo), 'utf8')));
  }

  const html = readFileSync(indice, 'utf8');
  const json = JSON.stringify(entradas, null, 2).replace(/\n/g, '\n  ');
  const reemplazado = html.replace(
    /const INDEX = \[[\s\S]*?\n\];/,
    `const INDEX = ${json};\n// Generado por doctest/generators/build-ayudas.ts desde el contenido de todos los manuales.`,
  );
  if (reemplazado === html) {
    console.log('  ⚠️  No se encontró el índice del buscador en index.html: quedó como estaba.');
    return 0;
  }
  if (!DRY_RUN) writeFileSync(indice, reemplazado, 'utf8');
  return entradas.length;
}

// ─────────────────────────────────────────────────────────────────────────────

console.log('\nDocTest · armado de las ayudas\n');

if (!DRY_RUN) {
  rmSync(BUILD, { recursive: true, force: true });
  mkdirSync(BUILD, { recursive: true });
  for (const compartido of ['theme.css', 'manual.js']) {
    copyFileSync(join(PLANTILLA, compartido), join(BUILD, compartido));
  }
}

const legacy = copiarLegacy();
console.log(`  · ${legacy.length} archivo(s) del sitio actual copiados tal cual`);

const armados = armarManuales();
for (const m of armados) console.log(`  · ${m.archivo} armado con la plantilla (cubre ${m.casos})`);

const entradas = regenerarBuscador();
console.log(`  · buscador del inicio: ${entradas} secciones indexadas de todos los manuales`);

console.log(
  DRY_RUN
    ? '\n(--dry-run: no se escribió nada)\n'
    : `\n✓ Sitio armado en ayuda/ (raíz del repo) — ${legacy.length + armados.length} manuales\n`,
);
