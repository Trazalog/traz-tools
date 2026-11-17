#!/usr/bin/env node
/**
 * consola.mjs — muestra los informes de las corridas en el navegador: `npm run doctest:consola`.
 *
 * Lee `corridas/` y `corridas/.locales/` (ver tests/e2e/reporter/informe-corrida.ts) y sirve
 * `consola/index.html` solo a esta máquina. No escribe nada.
 */

import { createReadStream, existsSync, readdirSync, readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { parse } from 'yaml';

const DOCTEST_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const RAICES = [join(DOCTEST_ROOT, 'corridas'), join(DOCTEST_ROOT, 'corridas', '.locales')];
const PUERTO = Number(process.argv[2] ?? 9333);
const NOMBRE_VALIDO = /^[\w.-]+$/;

function carpetaDe(id) {
  if (!NOMBRE_VALIDO.test(id)) return null;
  return RAICES.map((r) => join(r, id)).find((c) => existsSync(join(c, 'corrida.yaml'))) ?? null;
}

function listar() {
  return RAICES.flatMap((raiz) =>
    existsSync(raiz) ? readdirSync(raiz).filter((d) => existsSync(join(raiz, d, 'corrida.yaml'))) : [],
  )
    .sort()
    .reverse()
    .map((id) => {
      const { corrida, resumen } = parse(readFileSync(join(carpetaDe(id), 'corrida.yaml'), 'utf8'));
      return { ...corrida, resumen };
    });
}

function responder(res, codigo, tipo, cuerpo) {
  res.writeHead(codigo, { 'content-type': tipo });
  res.end(cuerpo);
}

const servidor = createServer((req, res) => {
  const partes = decodeURIComponent(new URL(req.url, 'http://x').pathname).split('/').filter(Boolean);
  if (!partes.length) {
    return responder(res, 200, 'text/html; charset=utf-8', readFileSync(join(DOCTEST_ROOT, 'consola', 'index.html')));
  }
  if (partes[0] === 'api' && partes[1] === 'corridas') {
    if (!partes[2]) return responder(res, 200, 'application/json', JSON.stringify(listar()));
    const c = carpetaDe(partes[2]);
    if (!c) return responder(res, 404, 'text/plain', 'No existe esa corrida');
    return responder(res, 200, 'application/json', JSON.stringify(parse(readFileSync(join(c, 'corrida.yaml'), 'utf8'))));
  }
  const resto = partes.slice(2);
  if (partes[0] === 'captura' && resto.length && resto.length <= 2 && resto.every((p) => NOMBRE_VALIDO.test(p))) {
    const c = carpetaDe(partes[1]);
    const archivo = c && join(c, 'capturas', ...resto);
    if (archivo && existsSync(archivo)) {
      res.writeHead(200, { 'content-type': 'image/png' });
      return createReadStream(archivo).pipe(res);
    }
  }
  return responder(res, 404, 'text/plain', 'No encontrado');
});

servidor.listen(PUERTO, '127.0.0.1', () => {
  console.log(`Consola de DocTest: http://127.0.0.1:${PUERTO} (Ctrl+C para cerrarla)`);
});
