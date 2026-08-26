/**
 * sitio-en-un-archivo.ts — arma todo el sitio de ayudas en un solo HTML navegable.
 *
 * El sitio real (`ayuda/` en la raíz del repo) son varios archivos que se enlazan entre sí, y así
 * es como se publica. Pero para **revisarlo antes de publicarlo** hace falta poder recorrerlo
 * entero sin desplegarlo: pasar del manual de Mantenimiento al de Almacenes como haría un usuario.
 *
 * Este generador toma el sitio armado y lo empaqueta en un archivo único: el índice y todos los
 * manuales quedan como páginas dentro de la misma página, y los enlaces entre ellos funcionan sin
 * servidor. No reemplaza al sitio — es la copia para mirar.
 *
 * Uso (en una terminal, parado en `doctest/`):
 *   npm run ayudas          # primero, para tener el sitio al día
 *   npm run ayudas:unico    # deja .validacion/sitio-ayudas.html
 */

import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const RAIZ = resolve(HERE, '..');
const SITIO = resolve(RAIZ, '..', 'ayuda');
const SALIDA = join(RAIZ, '.validacion', 'sitio-ayudas.html');

/** El contenido de <body> de una página, sin sus scripts. */
function cuerpo(html: string): string {
  const m = /<body[^>]*>([\s\S]*?)<\/body>/i.exec(html);
  const dentro = m ? m[1] : html;
  return dentro.replace(/<script[\s\S]*?<\/script>/gi, '');
}

function titulo(html: string): string {
  return /<title>([^<]*)<\/title>/i.exec(html)?.[1]?.replace(' · Trazalog Tools', '').trim() ?? '';
}

if (!existsSync(SITIO)) {
  console.error(`No está el sitio armado en ${SITIO}. Corré primero: npm run ayudas`);
  process.exit(1);
}

const css = readFileSync(join(SITIO, 'theme.css'), 'utf8');
const js = readFileSync(join(SITIO, 'manual.js'), 'utf8');

// El índice va primero; los manuales, en orden alfabético detrás.
const paginas = ['index.html', ...readdirSync(SITIO)
  .filter((f) => f.endsWith('.html') && f !== 'index.html')
  .sort()];

const secciones = paginas.map((archivo) => {
  const html = readFileSync(join(SITIO, archivo), 'utf8');
  return `<div class="pagina-sitio" data-pagina="${archivo}" hidden>\n${cuerpo(html)}\n</div>`;
});

const nombres = paginas.map((a) => `${a} → ${titulo(readFileSync(join(SITIO, a), 'utf8'))}`);

const salida = `<title>Ayuda de Trazalog Tools</title>
<link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=DM+Sans:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
${css}
/* Cada página del sitio es una sección de este archivo; se muestra una por vez. */
.pagina-sitio[hidden] { display: none; }
</style>

${secciones.join('\n\n')}

<script>
${js}
</script>
<script>
// Navegación entre las páginas del sitio, sin servidor: los enlaces a otros manuales muestran
// la sección correspondiente en vez de pedir el archivo.
(function () {
  var paginas = Array.prototype.slice.call(document.querySelectorAll('.pagina-sitio'));

  function mostrar(nombre) {
    var encontrada = false;
    paginas.forEach(function (p) {
      var esta = p.getAttribute('data-pagina') === nombre;
      p.hidden = !esta;
      if (esta) encontrada = true;
    });
    if (!encontrada && paginas.length) paginas[0].hidden = false;
    window.scrollTo({ top: 0 });
    // Las secciones del manual arrancan ocultas por su animación de entrada: se reactiva.
    document.querySelectorAll('.pagina-sitio:not([hidden]) .section').forEach(function (s, i) {
      if (i === 0 || s.id === 'cover') s.classList.add('visible');
    });
    if (typeof updateActiveNav === 'function') { try { updateActiveNav(); } catch (e) {} }
  }

  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[href]');
    if (!a) return;
    var href = a.getAttribute('href') || '';
    var m = /^([a-z0-9_.-]+\\.html)(#.*)?$/i.exec(href);
    if (!m) return;
    e.preventDefault();
    mostrar(m[1]);
    if (m[2]) {
      var destino = document.querySelector('.pagina-sitio:not([hidden]) ' + m[2]);
      if (destino) { destino.classList.add('visible'); destino.scrollIntoView({ behavior: 'smooth' }); }
    }
  });

  mostrar('index.html');
})();
</script>
`;

mkdirSync(dirname(SALIDA), { recursive: true });
writeFileSync(SALIDA, salida, 'utf8');
console.log(`\n✓ Sitio completo en un archivo: ${SALIDA}`);
console.log(`  ${paginas.length} páginas navegables entre sí:`);
for (const n of nombres) console.log(`    · ${n}`);
