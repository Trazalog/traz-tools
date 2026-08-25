/**
 * hoja-validacion.ts — arma la hoja de validación de un módulo.
 *
 * El gate de DocTest es humano: el PM tiene que decir, caso por caso, si lo
 * relevado es lo que el negocio espera (RF-01.4). Hacerlo leyendo 25 archivos YAML
 * en el diff de un PR es incómodo y se presta a validar por cansancio, así que este
 * generador arma una página con los mismos casos en prosa, con las dudas al frente
 * y un control para marcar la decisión de cada uno.
 *
 * NO es un artefacto derivado: no genera tests, ni Gherkin, ni ayudas. Es una vista
 * de lectura del catálogo, y por eso puede correrse sobre casos en `borrador`.
 *
 * Uso (en una terminal, parado en `doctest/`):
 *   npm run hoja:validacion -- dnato
 *
 * Sale en `.validacion/<modulo>.html`, que no se commitea: se regenera cuando el
 * catálogo cambia.
 */

import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
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
  pantallas?: string[];
  precondiciones?: string[];
  flujo_principal?: Paso[];
  flujos_alternativos?: { nombre: string; pasos: Paso[] }[];
  validaciones?: string[];
  datos_prueba?: Record<string, unknown>;
  dudas?: string[];
  notas?: string[];
  referencias_codigo?: { repo: string; path: string; detalle?: string }[];
}

const esc = (t: unknown): string =>
  String(t ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

function leerCasos(modulo: string): Caso[] {
  const dir = join(RAIZ, 'catalogo', modulo);
  return readdirSync(dir)
    .filter((f) => /\.ya?ml$/i.test(f))
    .sort()
    .map((f) => parseYaml(readFileSync(join(dir, f), 'utf8')) as Caso);
}

// ─────────────────────────────────────────────────────────────────────────────
// Render
// ─────────────────────────────────────────────────────────────────────────────

function lista(titulo: string, items: string[] | undefined, clase = ''): string {
  if (!items?.length) return '';
  return `<div class="bloque ${clase}">
      <h4>${esc(titulo)}</h4>
      <ul>${items.map((i) => `<li>${esc(i)}</li>`).join('')}</ul>
    </div>`;
}

function pasos(items: Paso[] | undefined): string {
  if (!items?.length) return '';
  return `<ol class="pasos">${items
    .map(
      (p) => `<li>
        <span class="accion">${esc(p.paso)}</span>
        <span class="resultado">${esc(p.resultado)}</span>
      </li>`,
    )
    .join('')}</ol>`;
}

function tarjeta(c: Caso): string {
  const alternativos = (c.flujos_alternativos ?? [])
    .map((f) => `<div class="alternativo"><h5>${esc(f.nombre)}</h5>${pasos(f.pasos)}</div>`)
    .join('');
  const referencias = (c.referencias_codigo ?? [])
    .map((r) => `<li><span class="repo">${esc(r.repo)}</span> <code>${esc(r.path)}</code>${r.detalle ? ` — ${esc(r.detalle)}` : ''}</li>`)
    .join('');
  const datos = Object.entries(c.datos_prueba ?? {})
    .map(([k, v]) => `<li><code>${esc(k)}</code>: ${esc(typeof v === 'object' ? JSON.stringify(v) : v)}</li>`)
    .join('');

  return `<article class="caso" id="${esc(c.id)}" data-id="${esc(c.id)}" data-dudas="${(c.dudas ?? []).length}">
    <header>
      <div class="titulo">
        <span class="id">${esc(c.id)}</span>
        <h3>${esc(c.titulo)}</h3>
      </div>
      <div class="meta">
        <span class="chip perfil">${esc(c.perfil)}</span>
        <span class="chip version">v${esc(c.version)}</span>
        ${(c.dudas ?? []).length ? `<span class="chip dudas">${(c.dudas ?? []).length} duda${(c.dudas ?? []).length > 1 ? 's' : ''}</span>` : ''}
      </div>
    </header>

    ${c.pantallas?.length ? `<p class="pantallas">${c.pantallas.map((p) => esc(p)).join(' &nbsp;·&nbsp; ')}</p>` : ''}
    ${lista('Antes de empezar', c.precondiciones)}

    <div class="bloque">
      <h4>Cómo se hace</h4>
      ${pasos(c.flujo_principal)}
    </div>

    ${alternativos ? `<div class="bloque"><h4>Qué pasa si…</h4>${alternativos}</div>` : ''}
    ${lista('Reglas que el caso verifica', c.validaciones)}
    ${lista('Dudas para vos', c.dudas, 'dudas')}
    ${lista('Notas', c.notas, 'notas')}
    ${datos ? `<div class="bloque tecnico"><h4>Datos de prueba</h4><ul>${datos}</ul></div>` : ''}
    ${referencias ? `<details class="tecnico"><summary>De dónde salió (código relevado)</summary><ul>${referencias}</ul></details>` : ''}

    <footer class="decision">
      <div class="opciones" role="group" aria-label="Decisión sobre ${esc(c.id)}">
        <button type="button" data-valor="validado">Validado</button>
        <button type="button" data-valor="obsoleto">Obsoleto</button>
        <button type="button" data-valor="borrador">Sigue en borrador</button>
      </div>
      <input type="text" class="comentario" placeholder="Corrección o comentario (opcional)" aria-label="Comentario sobre ${esc(c.id)}">
    </footer>
  </article>`;
}

function pagina(modulo: string, casos: Caso[], resumenHtml: string): string {
  const total = casos.length;
  const conDudas = casos.filter((c) => (c.dudas ?? []).length).length;
  const perfiles = [...new Set(casos.map((c) => c.perfil))];

  return `<title>Validación DNATO</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=DM+Sans:wght@400;500;700&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
  :root {
    --tinta: #0F1923;
    --papel: #F7F8FC;
    --superficie: #FFFFFF;
    --borde: #DCE3ED;
    --suave: #5B6b7D;
    --rojo: #CC1F1A;
    --teal: #0D7377;
    --ambar: #B26A00;
    --ambar-fondo: #FFF6E5;
    --sombra: 0 1px 2px rgba(15,25,35,.06), 0 8px 24px rgba(15,25,35,.06);
  }
  :root:not([data-theme="light"]) { }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --tinta: #E8EDF5;
      --papel: #0F1923;
      --superficie: #16202D;
      --borde: #2A3646;
      --suave: #9AA8BA;
      --rojo: #FF6B63;
      --teal: #4FC3C7;
      --ambar: #F5B942;
      --ambar-fondo: #2A2314;
      --sombra: 0 1px 2px rgba(0,0,0,.4), 0 8px 24px rgba(0,0,0,.3);
    }
  }
  :root[data-theme="dark"] {
    --tinta: #E8EDF5;
    --papel: #0F1923;
    --superficie: #16202D;
    --borde: #2A3646;
    --suave: #9AA8BA;
    --rojo: #FF6B63;
    --teal: #4FC3C7;
    --ambar: #F5B942;
    --ambar-fondo: #2A2314;
    --sombra: 0 1px 2px rgba(0,0,0,.4), 0 8px 24px rgba(0,0,0,.3);
  }

  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--papel); color: var(--tinta);
    font-family: 'DM Sans', system-ui, sans-serif; line-height: 1.6;
    -webkit-font-smoothing: antialiased;
  }
  .envoltorio { max-width: 1180px; margin: 0 auto; padding: 0 24px 140px; }

  header.portada { padding: 56px 0 28px; border-bottom: 2px solid var(--tinta); margin-bottom: 32px; }
  .eyebrow { font-size: 12px; letter-spacing: .14em; text-transform: uppercase; color: var(--rojo); font-weight: 700; }
  h1 { font-family: 'DM Serif Display', Georgia, serif; font-weight: 400; font-size: clamp(34px, 5vw, 52px);
       line-height: 1.08; margin: 10px 0 12px; text-wrap: balance; }
  .bajada { max-width: 62ch; color: var(--suave); font-size: 17px; margin: 0; }

  .tablero { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 26px; }
  .dato { background: var(--superficie); border: 1px solid var(--borde); border-radius: 10px; padding: 10px 14px; box-shadow: var(--sombra); }
  .dato b { font-family: 'JetBrains Mono', monospace; font-size: 19px; font-variant-numeric: tabular-nums; display: block; }
  .dato span { font-size: 12px; color: var(--suave); text-transform: uppercase; letter-spacing: .07em; }

  .instrucciones { background: var(--superficie); border: 1px solid var(--borde); border-left: 4px solid var(--rojo);
                   border-radius: 10px; padding: 18px 22px; margin: 28px 0 8px; box-shadow: var(--sombra); }
  .instrucciones h2 { font-family: 'DM Sans', sans-serif; font-size: 15px; text-transform: uppercase; letter-spacing: .08em; margin: 0 0 8px; }
  .instrucciones p { margin: 0 0 8px; max-width: 70ch; }
  .instrucciones p:last-child { margin-bottom: 0; }

  .filtros { position: sticky; top: 0; z-index: 5; background: var(--papel); padding: 14px 0 12px;
             border-bottom: 1px solid var(--borde); display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-bottom: 24px; }
  .filtros label { font-size: 13px; color: var(--suave); margin-right: 4px; }
  .filtros button { font: inherit; font-size: 13px; padding: 6px 12px; border-radius: 999px; cursor: pointer;
                    border: 1px solid var(--borde); background: var(--superficie); color: var(--tinta); }
  .filtros button[aria-pressed="true"] { background: var(--tinta); color: var(--papel); border-color: var(--tinta); }

  .caso { background: var(--superficie); border: 1px solid var(--borde); border-radius: 14px; padding: 24px 26px;
          margin-bottom: 18px; box-shadow: var(--sombra); scroll-margin-top: 90px; }
  .caso[data-decision="validado"] { border-left: 5px solid var(--teal); }
  .caso[data-decision="obsoleto"] { border-left: 5px solid var(--suave); opacity: .72; }
  .caso[data-decision="borrador"] { border-left: 5px solid var(--ambar); }
  .caso header { display: flex; flex-wrap: wrap; gap: 12px; justify-content: space-between; align-items: flex-start; }
  .caso .id { font-family: 'JetBrains Mono', monospace; font-size: 12px; color: var(--rojo); font-weight: 500; letter-spacing: .02em; }
  .caso h3 { font-family: 'DM Serif Display', Georgia, serif; font-weight: 400; font-size: 25px; line-height: 1.2; margin: 4px 0 0; text-wrap: balance; }
  .meta { display: flex; gap: 6px; flex-wrap: wrap; }
  .chip { font-size: 11.5px; padding: 4px 10px; border-radius: 999px; border: 1px solid var(--borde); color: var(--suave); white-space: nowrap; }
  .chip.perfil { border-color: var(--teal); color: var(--teal); }
  .chip.dudas { border-color: var(--ambar); color: var(--ambar); background: var(--ambar-fondo); font-weight: 500; }
  .pantallas { font-size: 14px; color: var(--suave); margin: 14px 0 0; font-family: 'JetBrains Mono', monospace; }

  .bloque { margin-top: 20px; }
  .bloque h4 { font-size: 12px; text-transform: uppercase; letter-spacing: .09em; color: var(--suave); margin: 0 0 8px; font-weight: 700; }
  .bloque ul { margin: 0; padding-left: 20px; }
  .bloque li { margin-bottom: 4px; }
  .bloque.dudas { background: var(--ambar-fondo); border-radius: 10px; padding: 14px 18px; }
  .bloque.dudas h4 { color: var(--ambar); }
  .bloque.notas { border-top: 1px dashed var(--borde); padding-top: 14px; }
  .bloque.notas li, .tecnico li { color: var(--suave); font-size: 14px; }

  ol.pasos { list-style: none; counter-reset: paso; margin: 0; padding: 0; }
  ol.pasos li { counter-increment: paso; display: grid; grid-template-columns: 26px 1fr; gap: 4px 12px; margin-bottom: 10px; }
  ol.pasos li::before { content: counter(paso); font-family: 'JetBrains Mono', monospace; font-size: 12px; color: var(--suave);
                        border: 1px solid var(--borde); border-radius: 50%; width: 24px; height: 24px; display: grid; place-items: center; margin-top: 2px; }
  ol.pasos .accion { grid-column: 2; font-weight: 500; }
  ol.pasos .resultado { grid-column: 2; color: var(--suave); }
  ol.pasos .resultado::before { content: "→ "; color: var(--teal); font-weight: 700; }
  .alternativo { margin-bottom: 14px; }
  .alternativo h5 { margin: 0 0 6px; font-size: 14px; font-weight: 700; }

  details.tecnico { margin-top: 16px; border-top: 1px dashed var(--borde); padding-top: 12px; }
  details.tecnico summary { cursor: pointer; font-size: 12px; text-transform: uppercase; letter-spacing: .09em; color: var(--suave); }
  details.tecnico ul { margin: 10px 0 0; padding-left: 20px; }
  code { font-family: 'JetBrains Mono', monospace; font-size: 12.5px; background: var(--papel); padding: 1px 5px; border-radius: 4px; }
  .repo { font-size: 11px; text-transform: uppercase; letter-spacing: .06em; color: var(--rojo); }

  footer.decision { margin-top: 22px; padding-top: 18px; border-top: 1px solid var(--borde);
                    display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }
  .opciones { display: flex; gap: 6px; flex-wrap: wrap; }
  .opciones button { font: inherit; font-size: 13.5px; padding: 8px 16px; border-radius: 8px; cursor: pointer;
                     border: 1px solid var(--borde); background: transparent; color: var(--tinta); transition: background .12s, color .12s, border-color .12s; }
  .opciones button:hover { border-color: var(--suave); }
  .opciones button[aria-pressed="true"][data-valor="validado"] { background: var(--teal); border-color: var(--teal); color: #fff; }
  .opciones button[aria-pressed="true"][data-valor="obsoleto"] { background: var(--suave); border-color: var(--suave); color: var(--papel); }
  .opciones button[aria-pressed="true"][data-valor="borrador"] { background: var(--ambar); border-color: var(--ambar); color: #1A1204; }
  .comentario { flex: 1; min-width: 240px; font: inherit; font-size: 14px; padding: 8px 12px;
                border: 1px solid var(--borde); border-radius: 8px; background: var(--papel); color: var(--tinta); }
  :focus-visible { outline: 2px solid var(--rojo); outline-offset: 2px; }

  .barra { position: fixed; left: 0; right: 0; bottom: 0; z-index: 10; background: var(--superficie);
           border-top: 1px solid var(--borde); box-shadow: 0 -6px 24px rgba(15,25,35,.10); }
  .barra .envoltorio { padding: 12px 24px; display: flex; flex-wrap: wrap; gap: 12px; align-items: center; justify-content: space-between; }
  .progreso { font-size: 14px; color: var(--suave); font-variant-numeric: tabular-nums; }
  .progreso b { color: var(--tinta); }
  .acciones { display: flex; gap: 8px; }
  .acciones button { font: inherit; font-size: 14px; padding: 9px 18px; border-radius: 8px; cursor: pointer; border: 1px solid var(--tinta);
                     background: var(--tinta); color: var(--papel); font-weight: 500; }
  .acciones button.secundario { background: transparent; color: var(--tinta); }
  dialog { border: 1px solid var(--borde); border-radius: 14px; padding: 0; max-width: 760px; width: calc(100% - 32px); background: var(--superficie); color: var(--tinta); }
  dialog::backdrop { background: rgba(15,25,35,.55); }
  dialog .cuerpo { padding: 22px 24px; }
  dialog h2 { font-family: 'DM Serif Display', Georgia, serif; font-weight: 400; margin: 0 0 6px; font-size: 26px; }
  dialog p { color: var(--suave); margin: 0 0 14px; }
  dialog textarea { width: 100%; height: 320px; font-family: 'JetBrains Mono', monospace; font-size: 12.5px; line-height: 1.5;
                    border: 1px solid var(--borde); border-radius: 10px; padding: 12px; background: var(--papel); color: var(--tinta); resize: vertical; }
  .oculto { display: none !important; }
  @media (prefers-reduced-motion: reduce) { * { transition: none !important; scroll-behavior: auto !important; } }
</style>

<div class="envoltorio">
  <header class="portada">
    <div class="eyebrow">DocTest · Fase F1 · Issue #438</div>
    <h1>Hoja de validación del catálogo de DNATO</h1>
    <p class="bajada">Los ${total} casos de uso relevados de registración y administración de cuenta, en el mismo orden en que los va a leer un tester. Nada de esto genera todavía un test, una ayuda ni un documento Gherkin: eso arranca cuando cada caso queda validado.</p>
    <div class="tablero">
      <div class="dato"><b>${total}</b><span>casos relevados</span></div>
      <div class="dato"><b>${conDudas}</b><span>con dudas abiertas</span></div>
      <div class="dato"><b>${perfiles.length}</b><span>perfiles involucrados</span></div>
      <div class="dato"><b id="contador-decididos">0</b><span>decididos por vos</span></div>
    </div>
  </header>

  <section class="instrucciones">
    <h2>Qué se espera de esta lectura</h2>
    <p>Para cada caso hace falta una de tres respuestas: <b>validado</b> (es lo que el negocio espera, con las correcciones de texto que quieras), <b>obsoleto</b> (ese flujo ya no existe o no se sostiene) o <b>sigue en borrador</b> (falta definir algo). Lo que marques queda guardado en este navegador.</p>
    <p>Al terminar, <b>Copiar decisiones</b> arma un texto listo para pegarme. Las <span style="color:var(--ambar);font-weight:700">dudas</span> son las preguntas concretas que necesito respondidas: si contestás ahí mismo en el comentario, mejor.</p>
  </section>

  ${resumenHtml}

  <nav class="filtros">
    <label>Mostrar:</label>
    <button type="button" data-filtro="todos" aria-pressed="true">Todos</button>
    <button type="button" data-filtro="dudas" aria-pressed="false">Solo con dudas</button>
    <button type="button" data-filtro="pendientes" aria-pressed="false">Sin decidir</button>
  </nav>

  <main>${casos.map(tarjeta).join('')}</main>
</div>

<div class="barra">
  <div class="envoltorio">
    <div class="progreso"><b id="progreso-n">0</b> de ${total} casos decididos · <span id="progreso-detalle">—</span></div>
    <div class="acciones">
      <button type="button" class="secundario" id="limpiar">Empezar de nuevo</button>
      <button type="button" id="copiar">Copiar decisiones</button>
    </div>
  </div>
</div>

<dialog id="salida">
  <div class="cuerpo">
    <h2>Decisiones</h2>
    <p>Copiá este texto y pegámelo en el chat. Si preferís, también sirve como comentario del PR.</p>
    <textarea id="texto-salida" readonly></textarea>
    <div class="acciones" style="margin-top:14px; justify-content:flex-end">
      <button type="button" class="secundario" id="cerrar">Cerrar</button>
      <button type="button" id="copiar-texto">Copiar al portapapeles</button>
    </div>
  </div>
</dialog>

<script>
  const CLAVE = 'doctest-validacion-${modulo}';
  const casos = Array.from(document.querySelectorAll('.caso'));

  function leerGuardado() {
    try { return JSON.parse(localStorage.getItem(CLAVE) || '{}'); } catch { return {}; }
  }
  function guardar(datos) {
    try { localStorage.setItem(CLAVE, JSON.stringify(datos)); } catch { /* modo privado: se pierde al cerrar */ }
  }

  let decisiones = leerGuardado();

  function pintar() {
    let decididos = 0, validados = 0, obsoletos = 0, borradores = 0;
    for (const caso of casos) {
      const id = caso.dataset.id;
      const d = decisiones[id];
      caso.dataset.decision = d?.valor || '';
      caso.querySelectorAll('.opciones button').forEach((b) => {
        b.setAttribute('aria-pressed', String(b.dataset.valor === d?.valor));
      });
      const comentario = caso.querySelector('.comentario');
      if (d?.comentario && comentario.value !== d.comentario) comentario.value = d.comentario;
      if (d?.valor) {
        decididos++;
        if (d.valor === 'validado') validados++;
        else if (d.valor === 'obsoleto') obsoletos++;
        else borradores++;
      }
    }
    document.getElementById('progreso-n').textContent = decididos;
    document.getElementById('contador-decididos').textContent = decididos;
    document.getElementById('progreso-detalle').textContent =
      decididos ? validados + ' validados · ' + obsoletos + ' obsoletos · ' + borradores + ' en borrador' : 'todavía no marcaste ninguno';
    aplicarFiltro();
  }

  let filtroActual = 'todos';
  function aplicarFiltro() {
    for (const caso of casos) {
      const conDudas = caso.dataset.dudas !== '0';
      const decidido = !!decisiones[caso.dataset.id]?.valor;
      const visible =
        filtroActual === 'todos' ? true : filtroActual === 'dudas' ? conDudas : !decidido;
      caso.classList.toggle('oculto', !visible);
    }
  }

  document.querySelectorAll('.filtros button').forEach((b) => {
    b.addEventListener('click', () => {
      filtroActual = b.dataset.filtro;
      document.querySelectorAll('.filtros button').forEach((o) => o.setAttribute('aria-pressed', String(o === b)));
      aplicarFiltro();
    });
  });

  for (const caso of casos) {
    const id = caso.dataset.id;
    caso.querySelectorAll('.opciones button').forEach((b) => {
      b.addEventListener('click', () => {
        const actual = decisiones[id]?.valor;
        decisiones[id] = { ...(decisiones[id] || {}), valor: actual === b.dataset.valor ? '' : b.dataset.valor };
        guardar(decisiones); pintar();
      });
    });
    caso.querySelector('.comentario').addEventListener('input', (e) => {
      decisiones[id] = { ...(decisiones[id] || {}), comentario: e.target.value };
      guardar(decisiones);
    });
  }

  document.getElementById('limpiar').addEventListener('click', () => {
    decisiones = {}; guardar(decisiones);
    casos.forEach((c) => { c.querySelector('.comentario').value = ''; });
    pintar();
  });

  document.getElementById('copiar').addEventListener('click', () => {
    const lineas = ['Validación del catálogo de ${modulo.toUpperCase()} (${total} casos):', ''];
    for (const caso of casos) {
      const id = caso.dataset.id;
      const d = decisiones[id];
      if (!d?.valor && !d?.comentario) continue;
      const titulo = caso.querySelector('h3').textContent.trim();
      lineas.push('- ' + id + ' [' + (d.valor || 'sin decidir').toUpperCase() + '] ' + titulo + (d.comentario ? ' — ' + d.comentario : ''));
    }
    const sinDecidir = casos.filter((c) => !decisiones[c.dataset.id]?.valor).map((c) => c.dataset.id);
    if (sinDecidir.length) { lineas.push('', 'Sin decidir: ' + sinDecidir.join(', ')); }
    document.getElementById('texto-salida').value = lineas.join('\\n');
    document.getElementById('salida').showModal();
  });
  document.getElementById('cerrar').addEventListener('click', () => document.getElementById('salida').close());
  document.getElementById('copiar-texto').addEventListener('click', async () => {
    const area = document.getElementById('texto-salida');
    area.select();
    try { await navigator.clipboard.writeText(area.value); document.getElementById('copiar-texto').textContent = 'Copiado'; }
    catch { document.execCommand('copy'); }
  });

  pintar();
</script>`;
}

// ─────────────────────────────────────────────────────────────────────────────

const modulo = (process.argv[2] ?? '').toLowerCase();
if (!modulo) {
  console.error('Falta el módulo. Uso: npm run hoja:validacion -- dnato');
  process.exit(2);
}

const casos = leerCasos(modulo);
if (!casos.length) {
  console.error(`No hay casos en catalogo/${modulo}/`);
  process.exit(2);
}

/** El resumen del relevamiento se enlaza, no se duplica: la fuente sigue siendo el .md. */
const resumenHtml = `<section class="instrucciones" style="border-left-color: var(--teal)">
    <h2>Contexto</h2>
    <p>El detalle de qué se relevó, qué decisiones ya están tomadas y los hallazgos del código está en <code>doctest/catalogo/${esc(modulo)}/RESUMEN-RELEVAMIENTO-${esc(modulo.toUpperCase())}.md</code>. Esta hoja es solo para decidir caso por caso.</p>
  </section>`;

const destino = join(RAIZ, '.validacion');
mkdirSync(destino, { recursive: true });
const archivo = join(destino, `${modulo}.html`);
writeFileSync(archivo, pagina(modulo, casos, resumenHtml), 'utf8');

console.log(`✓ Hoja de validación de ${modulo.toUpperCase()}: ${casos.length} casos → ${archivo}`);
