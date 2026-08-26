/**
 * sitio-en-un-archivo.ts — arma todo el sitio de ayudas en un solo HTML navegable.
 *
 * El sitio real (`ayuda/` en la raíz del repo) son varios archivos que se enlazan entre sí, y así
 * es como se publica. Pero para **revisarlo antes de publicarlo** hace falta recorrerlo entero sin
 * desplegarlo: pasar del manual de Mantenimiento al de Almacenes como haría un usuario.
 *
 * **Cada página va en su propio Shadow DOM**, y ahí está el punto: las páginas no comparten CSS.
 * El índice y los manuales viejos traen su hoja de estilos adentro; los nuevos usan el `theme.css`
 * común. Los nombres de clase se repiten entre unas y otras (`.section`, `.card`, `.nav-item`), así
 * que juntarlas en un mismo documento hace que se pisen — que fue exactamente lo que pasó en el
 * primer intento, donde el índice quedó sin estilos. El Shadow DOM aísla cada página con los suyos.
 *
 * Como consecuencia, el comportamiento de los manuales tampoco puede venir de `manual.js`: ese
 * script busca con `document.querySelector` y no ve dentro de un shadow. Acá se reimplementa
 * recibiendo la raíz de cada página.
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

function entre(html: string, etiqueta: string): string {
  const m = new RegExp(`<${etiqueta}[^>]*>([\\s\\S]*?)</${etiqueta}>`, 'i').exec(html);
  return m ? m[1] : '';
}

function titulo(html: string): string {
  return /<title>([^<]*)<\/title>/i.exec(html)?.[1]?.replace(' · Trazalog Tools', '').trim() ?? '';
}

/**
 * Adapta un CSS pensado para un documento a vivir dentro de un shadow root.
 *
 * Hay dos selectores que ahí adentro no apuntan a nada:
 *
 *   · `:root` — es el `<html>` del documento, no la raíz del shadow. Las variables de color y
 *     tipografía se declaran ahí, así que sin esto **ningún color se aplica**: el fondo oscuro de
 *     la portada queda blanco y su texto blanco se vuelve ilegible.
 *   · `body` — dentro del shadow no existe: el contenido cuelga directo de la raíz.
 *
 * Los dos se mapean a `:host`, que es el elemento que contiene la página.
 */
function paraShadow(css: string): string {
  return css
    .replace(/(^|[,}\s])html\s*,\s*body(?=[\s,{])/g, '$1:host')
    .replace(/(^|[,}\s]):root(?=[\s,{:])/g, '$1:host')
    .replace(/(^|[,}\s])body(?=[\s,{:])/g, '$1:host');
}

/** Los estilos propios de la página: sus `<style>` y, si enlaza el theme, el theme. */
function estilos(html: string, theme: string): string {
  const propios = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)].map((m) => m[1]).join('\n');
  const usaTheme = /href="theme\.css"/i.test(html);
  return paraShadow((usaTheme ? theme : '') + '\n' + propios);
}

if (!existsSync(SITIO)) {
  console.error(`No está el sitio armado en ${SITIO}. Corré primero: npm run ayudas`);
  process.exit(1);
}

const theme = readFileSync(join(SITIO, 'theme.css'), 'utf8');

const paginas = ['index.html', ...readdirSync(SITIO)
  .filter((f) => f.endsWith('.html') && f !== 'index.html')
  .sort()];

const datos = paginas.map((archivo) => {
  const html = readFileSync(join(SITIO, archivo), 'utf8');
  return {
    archivo,
    titulo: titulo(html),
    css: estilos(html, theme),
    // Se sacan los <script> de la página: el comportamiento lo aporta este archivo.
    body: entre(html, 'body').replace(/<script[\s\S]*?<\/script>/gi, ''),
  };
});

const salida = `<title>Ayuda de Trazalog Tools</title>
<link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=DM+Sans:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
  html, body { margin: 0; padding: 0; background: #F7F8FC; }
  .pagina-sitio[hidden] { display: none; }
</style>

${datos.map((p) => `<div class="pagina-sitio" data-pagina="${p.archivo}" hidden></div>`).join('\n')}

<script id="paginas-del-sitio" type="application/json">${JSON.stringify(datos).replace(/</g, '\\u003c')}</script>

<script>
(function () {
  var datos = JSON.parse(document.getElementById('paginas-del-sitio').textContent);
  var hosts = {};

  // Cada página se monta en su propio shadow root, con sus estilos: así el CSS de una no le pisa
  // las clases a la otra.
  datos.forEach(function (p) {
    var host = document.querySelector('.pagina-sitio[data-pagina="' + p.archivo + '"]');
    var raiz = host.attachShadow({ mode: 'open' });
    raiz.innerHTML = '<style>' + p.css + '</style>' + p.body;
    hosts[p.archivo] = { host: host, raiz: raiz };
  });

  function activar(raiz) {
    // Las secciones arrancan ocultas por su animación de entrada; acá se muestran al aparecer.
    var secciones = raiz.querySelectorAll('.section');
    if (!secciones.length) return;
    if ('IntersectionObserver' in window) {
      var obs = new IntersectionObserver(function (entradas) {
        entradas.forEach(function (e) { if (e.isIntersecting) e.target.classList.add('visible'); });
      }, { threshold: 0.05 });
      secciones.forEach(function (s) { obs.observe(s); });
    }
    // La primera siempre visible, para que la página no abra en blanco.
    secciones[0].classList.add('visible');
    var portada = raiz.getElementById && raiz.getElementById('cover');
    if (portada) portada.classList.add('visible');
  }

  function mostrar(nombre) {
    if (!hosts[nombre]) nombre = 'index.html';
    Object.keys(hosts).forEach(function (k) { hosts[k].host.hidden = k !== nombre; });
    activar(hosts[nombre].raiz);
    window.scrollTo({ top: 0 });
  }

  // Los clics se escuchan en el documento: un evento nacido dentro de un shadow llega hasta acá,
  // y composedPath() deja ver el enlace real que se tocó.
  document.addEventListener('click', function (e) {
    var camino = e.composedPath ? e.composedPath() : [];
    var a = null;
    for (var i = 0; i < camino.length; i++) {
      if (camino[i].tagName === 'A') { a = camino[i]; break; }
    }
    if (!a) return;
    var href = a.getAttribute('href') || '';

    var otraPagina = /^([a-z0-9_.-]+\\.html)(#.*)?$/i.exec(href);
    if (otraPagina) {
      e.preventDefault();
      mostrar(otraPagina[1]);
      if (otraPagina[2]) irA(hosts[otraPagina[1]] ? otraPagina[1] : 'index.html', otraPagina[2]);
      return;
    }

    if (href.charAt(0) === '#' && href.length > 1) {
      var actual = Object.keys(hosts).filter(function (k) { return !hosts[k].host.hidden; })[0];
      if (actual) { e.preventDefault(); irA(actual, href); }
    }
  });

  function irA(pagina, ancla) {
    var raiz = hosts[pagina].raiz;
    var destino = raiz.querySelector(ancla);
    if (!destino) return;
    destino.classList.add('visible');
    destino.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // El menú lateral de los manuales usa toggleSidebar() en un onclick del propio HTML.
  window.toggleSidebar = function () {
    var actual = Object.keys(hosts).filter(function (k) { return !hosts[k].host.hidden; })[0];
    if (!actual) return;
    var lateral = hosts[actual].raiz.getElementById('sidebar');
    if (lateral) lateral.classList.toggle('open');
  };
  window.setActive = function () {};
  window.closeSidebar = function () {};

  mostrar('index.html');
})();
</script>
`;

mkdirSync(dirname(SALIDA), { recursive: true });
writeFileSync(SALIDA, salida, 'utf8');
console.log(`\n✓ Sitio completo en un archivo: ${SALIDA}`);
console.log(`  ${datos.length} páginas, cada una con sus propios estilos aislados:`);
for (const p of datos) console.log(`    · ${p.archivo.padEnd(42)} ${p.titulo}`);
