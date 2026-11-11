#!/usr/bin/env node
/**
 * publicar-corrida.mjs — arma el resumen de una corrida para el issue fijo "Estado de DocTest".
 *
 *   npm run doctest:publicar                 muestra el resumen de la última corrida versionada
 *   npm run doctest:publicar -- --enviar     además lo agrega como comentario del issue
 *   npm run doctest:publicar -- <id>         usa esa corrida
 *
 * Requiere `gh` con sesión iniciada. El repositorio es público: un error sin issue abierto se lista
 * solo por su número, para no adelantar el detalle de una falla de seguridad.
 */

import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { parse } from 'yaml';

const DOCTEST_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const REPO = 'Trazalog/traz-tools';
const TITULO = 'Estado de DocTest';
const raiz = join(DOCTEST_ROOT, 'corridas');
const args = process.argv.slice(2);
const enviar = args.includes('--enviar');
const id =
  args.find((a) => !a.startsWith('--')) ??
  readdirSync(raiz).filter((d) => existsSync(join(raiz, d, 'corrida.yaml'))).sort().pop();
if (!id) {
  console.error('No hay corridas versionadas en corridas/.');
  process.exit(2);
}

const { corrida, resumen, cambios, pruebas } = parse(readFileSync(join(raiz, id, 'corrida.yaml'), 'utf8'));
const r = resumen;
const conEnlace = (p) => (p.issue ? `#${p.issue}` : `${p.hallazgo ?? 'sin número'} (${p.privado ? 'aviso privado' : 'sin issue'})`);
const lista = (titulo, filas) => (filas.length ? [`### ${titulo}`, ...filas.map((f) => `- ${f}`), ''] : []);
const atencion = pruebas.filter((p) => ['falla', 'otro-punto', 'dejo-de-fallar', 'inestable'].includes(p.estado));
const conocidos = [...new Set(pruebas.filter((p) => ['error-conocido', 'sin-comprobar'].includes(p.estado)).map(conEnlace))];

const cuerpo = [
  `## Corrida ${corrida.id}`,
  '',
  `Rama \`${corrida.rama}\`, commit \`${corrida.commit}\`, ${corrida.minutos} minutos.`,
  '',
  '| Total | Pasan | Errores conocidos | Sin comprobar | Otro punto | Fallas | Inestables | Dejaron de fallar | Salteadas |',
  '|---:|---:|---:|---:|---:|---:|---:|---:|---:|',
  `| ${r.total} | ${r.pasan} | ${r.errores_conocidos} | ${r.sin_comprobar} | ${r.otro_punto} | ${r.fallas} | ${r.inestables} | ${r.dejaron_de_fallar} | ${r.salteadas} |`,
  '',
  ...lista('Para revisar', atencion.map((p) => `${p.estado}: ${p.caso} ${p.titulo} (${conEnlace(p)})`)),
  ...lista('Nuevas respecto de la corrida anterior', cambios?.nuevas ?? []),
  ...lista('Corregidas', cambios?.corregidas ?? []),
  ...lista('Errores conocidos', conocidos),
  `Informe completo: \`doctest/corridas/${corrida.id}/corrida.yaml\`. Se ve con \`npm run doctest:consola\`.`,
].join('\n');

console.log(cuerpo);
if (!enviar) {
  console.log('\nNo se envió nada. Para agregarlo al issue: npm run doctest:publicar -- --enviar');
  process.exit(0);
}

const gh = (a) => {
  const s = spawnSync('gh', a, { encoding: 'utf8' });
  if (s.status !== 0) throw new Error(s.stderr);
  return s.stdout.trim();
};
const existentes = JSON.parse(gh(['issue', 'list', '-R', REPO, '--state', 'open', '--search', `"${TITULO}" in:title`, '--json', 'number,title']));
let numero = existentes.find((i) => i.title === TITULO)?.number;
if (!numero) {
  const url = gh(['issue', 'create', '-R', REPO, '--title', TITULO, '--label', 'doctest', '--body', 'Resumen de cada corrida completa de DocTest. Lo agrega `npm run doctest:publicar`.']);
  numero = url.split('/').pop();
}
console.log(gh(['issue', 'comment', String(numero), '-R', REPO, '--body', cuerpo]));
