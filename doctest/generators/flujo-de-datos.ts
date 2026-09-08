/**
 * flujo-de-datos.ts — el mapa de qué produce cada caso y qué necesita.
 *
 * POR QUÉ EXISTE: un catálogo puede describir bien cada pantalla y aun así no decir
 * nada de cómo se encadenan. Eso se paga al escribir las pruebas —una precondición
 * como "hay existencias" no dice de dónde salen— y se paga al usar el sistema: una
 * empresa recién creada no tiene artículos, y nada le dice por dónde empezar.
 *
 * El mapa sale de los campos `produce` y `depende_de` de cada caso, así que no se
 * desactualiza: si alguien agrega un caso y declara su dependencia, aparece acá.
 *
 * Uso:  npm run flujo -- alm
 */

import { readdirSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'yaml';

const AQUI = dirname(fileURLToPath(import.meta.url));
const RAIZ = resolve(AQUI, '..');

interface Caso {
  id: string;
  titulo: string;
  estado: string;
  perfil?: string;
  produce?: string[];
  depende_de?: string[];
}

function leer(modulo: string): Caso[] {
  const dir = join(RAIZ, 'catalogo', modulo);
  return readdirSync(dir)
    .filter((f) => f.endsWith('.yaml'))
    .map((f) => parse(readFileSync(join(dir, f), 'utf8')) as Caso)
    .filter((c) => c?.id)
    .sort((a, b) => a.id.localeCompare(b.id));
}

/**
 * La puerta de entrada del módulo: los casos que no dependen de ningún otro caso
 * DEL MISMO módulo. Puede que dependan de algo de afuera —el alta de la empresa,
 * típicamente— y eso es justamente lo que conviene ver: de qué depende el módulo
 * para poder arrancar.
 */
function raices(casos: Caso[], modulo: string): Caso[] {
  const prefijo = modulo.toUpperCase() + '-UC-';
  return casos.filter(
    (c) => c.estado !== 'obsoleto' && !(c.depende_de ?? []).some((d) => d.startsWith(prefijo)),
  );
}

/** Dependencias que apuntan fuera del módulo, con quién las necesita. */
function externas(casos: Caso[], modulo: string): { de: string; caso: Caso }[] {
  const prefijo = modulo.toUpperCase() + '-UC-';
  const out: { de: string; caso: Caso }[] = [];
  for (const c of casos) {
    for (const d of c.depende_de ?? []) if (!d.startsWith(prefijo)) out.push({ de: d, caso: c });
  }
  return out;
}

function diagrama(casos: Caso[]): string {
  const vivos = casos.filter((c) => c.estado !== 'obsoleto');
  const nombre = (c: Caso) => `${c.id}["${c.id}<br/>${c.titulo.replace(/"/g, "'")}"]`;
  const lineas: string[] = ['```mermaid', 'flowchart TD'];
  for (const c of vivos) {
    if ((c.produce ?? []).length) lineas.push(`    ${nombre(c)}:::produce`);
    else lineas.push(`    ${nombre(c)}`);
  }
  for (const c of vivos) {
    for (const d of c.depende_de ?? []) lineas.push(`    ${d} --> ${c.id}`);
  }
  lineas.push('    classDef produce fill:#fff3cd,stroke:#856404');
  lineas.push('```');
  return lineas.join('\n');
}

function pagina(modulo: string, casos: Caso[]): string {
  const M = modulo.toUpperCase();
  const productores = casos.filter((c) => (c.produce ?? []).length && c.estado !== 'obsoleto');
  let md = `# Flujo de datos de ${M}\n\n## Objetivo\n\n`;
  md += `Qué produce cada caso de uso y qué necesita para poder ejecutarse. Sirve para dos cosas: `;
  md += `escribir pruebas que **generen sus propios datos** en vez de asumir que ya están, y entender `;
  md += `en qué orden se usa el módulo cuando la empresa es nueva y todo está vacío.\n\n`;
  md += `**No** cubre qué hace cada pantalla —eso está en cada caso, en \`doctest/catalogo/${modulo}/\`— `;
  md += `ni cómo se corren las pruebas, que está en la [guía](../../doctest/GUIA-PRUEBAS-Y-AYUDAS.md).\n\n`;
  md += `> Generado por \`doctest/generators/flujo-de-datos.ts\` desde los campos \`produce\` y \`depende_de\` `;
  md += `del catálogo. No editar a mano.\n\n---\n\n## Por dónde se empieza\n\n`;
  md += `Estos casos no dependen de ningún otro del módulo: son la puerta de entrada.\n\n`;
  for (const c of raices(casos, modulo)) md += `- **${c.id}** — ${c.titulo}${c.perfil ? ` · *${c.perfil}*` : ''}\n`;
  const fuera = externas(casos, modulo);
  if (fuera.length) {
    md += `\n### De qué depende el módulo para poder arrancar\n\n`;
    md += `Lo que ${M} necesita y no produce: si esto no está, no se puede empezar.\n\n`;
    for (const { de, caso } of fuera) md += `- **${de}** → lo necesita ${caso.id} (${caso.titulo})\n`;
  }
  md += `\n## Qué deja cada caso\n\n`;
  md += `Solo los que producen algo que otros necesitan.\n\n| Caso | Qué deja en el sistema |\n|---|---|\n`;
  for (const c of productores) md += `| **${c.id}** ${c.titulo} | ${(c.produce ?? []).join(' · ')} |\n`;
  md += `\n## El mapa completo\n\n`;
  md += `Las cajas resaltadas son las que producen datos; las flechas van del que produce al que necesita.\n\n`;
  md += diagrama(casos);
  md += `\n\n## Casos sin dependencias declaradas\n\n`;
  const huerfanos = casos.filter((c) => c.estado !== 'obsoleto' && !(c.depende_de ?? []).length && !(c.produce ?? []).length);
  md += huerfanos.length
    ? huerfanos.map((c) => `- ${c.id} — ${c.titulo}`).join('\n') + '\n\nSi alguno necesita datos que no produce, le falta declarar su `depende_de`.\n'
    : 'Ninguno: todos los casos vivos declaran de dónde salen sus datos o qué producen.\n';
  return md;
}

const modulo = (process.argv.slice(2).find((a) => !a.startsWith('--')) ?? '').toLowerCase();
if (!modulo) {
  console.error('Falta el módulo. Uso: npm run flujo -- alm');
  process.exit(2);
}
const casos = leer(modulo);
const destino = join(RAIZ, '..', 'doc', modulo, 'flujo-de-datos.md');
mkdirSync(dirname(destino), { recursive: true });
writeFileSync(destino, pagina(modulo, casos), 'utf8');
console.log(`\n✓ Flujo de datos de ${modulo.toUpperCase()}: ${casos.length} casos → ${destino}\n`);
