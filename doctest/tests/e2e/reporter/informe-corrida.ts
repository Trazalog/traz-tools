/**
 * informe-corrida.ts — deja un informe liviano de cada corrida: `corrida.yaml` y las capturas de lo
 * que falló. Se lee con `npm run doctest:consola`; el formato está en GUIA-PRUEBAS-Y-AYUDAS.md §1.3.
 *
 * Las corridas full y casi-full van a `corridas/` y se versionan, y el repositorio es público: nada
 * sale sin pasar por `limpiar()`, y de las empresas solo se copian los campos de `camposDeEmpresa()`.
 * Las demás van a `corridas/.locales/`, que no se versiona.
 */

import type { FullConfig, FullResult, Reporter, Suite, TestCase, TestResult, TestStep } from '@playwright/test/reporter';
import { execSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { parse, stringify } from 'yaml';

const HERE = dirname(fileURLToPath(import.meta.url));
const DOCTEST_ROOT = resolve(HERE, '..', '..', '..');
const REGISTRO = resolve(DOCTEST_ROOT, '..', 'doc', 'hallazgos', 'REGISTRO.md');
const ANSI = /\x1b\[[0-9;]*[A-Za-z]/g;
const MAX_ERROR = 900;
const MAX_CAPTURAS = 3;
const ANOTACIONES_PROPIAS = new Set(['fail', 'skip', 'slow', 'debe-fallar-con', 'menu-ausente']);

type Hallazgo = { severidad: string; resumen: string; issue?: number };
type Fila = Record<string, unknown> & { clave: string; estado: string };

function hallazgos(): Map<string, Hallazgo> {
  const mapa = new Map<string, Hallazgo>();
  if (!existsSync(REGISTRO)) return mapa;
  for (const linea of readFileSync(REGISTRO, 'utf8').split('\n')) {
    if (!/^\| H-\d+ /.test(linea)) continue;
    const c = linea.split('|').map((x) => x.trim());
    const estado = c[c.length - 2] ?? '';
    const issue = /en issue #(\d+)/.exec(estado)?.[1];
    mapa.set(c[1], {
      severidad: c[6],
      resumen: (c[7] ?? '').replace(/\*\*/g, '').slice(0, 220),
      issue: issue ? Number(issue) : undefined,
    });
  }
  return mapa;
}

function perfilDelAmbiente(entorno: string): Record<string, any> | null {
  const ruta = join(DOCTEST_ROOT, 'entornos', `${entorno}.json`);
  if (process.env.DOCTEST_SIN_PERFIL || !existsSync(ruta)) return null;
  try {
    return JSON.parse(readFileSync(ruta, 'utf8'));
  } catch {
    return null;
  }
}

function secretos(perfil: Record<string, any> | null): string[] {
  const salida = new Set<string>();
  for (const [k, v] of Object.entries(process.env)) {
    if (/PASS|CLAVE|SECRET|TOKEN/i.test(k) && v && v.length >= 4) salida.add(v);
  }
  const recorrer = (o: unknown): void => {
    if (!o || typeof o !== 'object') return;
    for (const [k, v] of Object.entries(o)) {
      if (typeof v === 'string' && /clave|pass/i.test(k) && v.length >= 4) salida.add(v);
      else recorrer(v);
    }
  };
  recorrer(perfil);
  return [...salida].sort((a, b) => b.length - a.length);
}

function camposDeEmpresa(p: Record<string, any> | null): Record<string, unknown> | undefined {
  if (!p) return undefined;
  const empresa = (e: any) => e && { nombre: e.nombre, dominio: e.dominio, administrador: e.admin?.usuario };
  return {
    empresa1: empresa(p.empresa1),
    empresa2: empresa(p.empresa2),
    usuarios: {
      mantenimiento: p.man?.usuario,
      supervisor: p.man?.supervisor?.usuario,
      planificador: p.tar?.planificador?.usuario,
      responsable1: p.tar?.responsable1?.usuario,
      responsable2: p.tar?.responsable2?.usuario,
      solicitante: p.alm?.solicitante?.usuario,
      almacen: p.alm?.almacen?.usuario,
    },
    datos_cargados: p.sembrado,
  };
}

function git(cmd: string): string {
  try {
    return execSync(`git ${cmd}`, { cwd: DOCTEST_ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    return '';
  }
}

function idPorDefecto(modo: string, entorno: string): string {
  const d = new Date();
  const dos = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${dos(d.getMonth() + 1)}-${dos(d.getDate())}_${dos(d.getHours())}${dos(d.getMinutes())}_${modo}_${entorno}`;
}

function resumir(pruebas: Fila[]): Record<string, number> {
  const contar = (e: string) => pruebas.filter((p) => p.estado === e).length;
  return {
    total: pruebas.length,
    pasan: contar('pasa'),
    errores_conocidos: contar('error-conocido'),
    sin_comprobar: contar('sin-comprobar'),
    otro_punto: contar('otro-punto'),
    fallas: contar('falla'),
    inestables: contar('inestable'),
    dejaron_de_fallar: contar('dejo-de-fallar'),
    salteadas: contar('salteada'),
  };
}

export default class InformeCorrida implements Reporter {
  private modo = process.env.DOCTEST_MODO ?? 'suelta';
  private entorno = (process.env.DOCTEST_ENV ?? 'local').trim();
  private id = process.env.DOCTEST_CORRIDA_ID ?? idPorDefecto(this.modo, this.entorno);
  private carpeta = resolve(
    DOCTEST_ROOT,
    'corridas',
    ['full', 'casi-full'].includes(this.modo) ? '' : '.locales',
    this.id,
  );
  private perfil = perfilDelAmbiente(this.entorno);
  private ocultar = secretos(this.perfil);
  private registro = hallazgos();
  private inicio = Date.now();
  private filas: Fila[] = [];

  private limpiar(texto: string): string {
    let t = texto.replace(ANSI, '').replace(/((?:pass(?:word)?|clave|contrase[nñ]a|token|secret)["']?\s*[:=]\s*)\S+/gi, '$1***').replace(/(\/token\/)[\w-]+/g, '$1***');
    for (const s of this.ocultar) t = t.split(s).join('***');
    return t;
  }

  onBegin(_config: FullConfig, _suite: Suite): void {
    this.inicio = Date.now();
  }

  onTestEnd(test: TestCase, result: TestResult): void {
    // Con reintento pasa dos veces: se pisa por clave y queda el último resultado.
    const fila = this.armarFila(test, result);
    this.filas = this.filas.filter((f) => f.clave !== fila.clave);
    this.filas.push(fila);
  }

  private estado(test: TestCase, result: TestResult, mensajes: string[]): string {
    const salida = test.outcome();
    const esperaFalla = test.expectedStatus === 'failed';
    if (salida === 'skipped') return 'salteada';
    if (salida === 'flaky') return 'inestable';
    if (salida === 'unexpected') return esperaFalla && result.status === 'passed' ? 'dejo-de-fallar' : 'falla';
    if (!esperaFalla) return 'pasa';
    const patron = [...test.annotations, ...result.annotations].find((a) => a.type === 'debe-fallar-con')?.description;
    if (!patron) return 'sin-comprobar';
    const re = new RegExp(patron, 'i');
    return mensajes.some((m) => re.test(m)) ? 'error-conocido' : 'otro-punto';
  }

  private armarFila(test: TestCase, result: TestResult): Fila {
    const archivo = relative(resolve(HERE, '..', 'specs'), test.location.file).replace(/\\/g, '/');
    const notas = [...test.annotations, ...result.annotations];
    const mensajes = result.errors.map((e) => (e.message ?? '').replace(ANSI, ''));
    const estado = this.estado(test, result, mensajes);
    const marca = notas.find((a) => a.type === 'fail')?.description ?? '';
    const hallazgo = /^(H-\d+|E\d+)/.exec(marca)?.[1];
    const delRegistro = hallazgo ? this.registro.get(hallazgo) : undefined;
    const issue = delRegistro?.issue ?? (/#(\d+)/.exec(marca)?.[1] ? Number(/#(\d+)/.exec(marca)?.[1]) : undefined);
    const clave = `${archivo}::${test.title}`;
    const fila: Fila = {
      clave,
      modulo: archivo.split('/')[0].toUpperCase(),
      caso: /[A-Z]+-UC-[\d-]*\d/.exec(archivo)?.[0] ?? '',
      titulo: test.title,
      estado,
      segundos: Math.round(result.duration / 1000),
    };
    if (result.retry > 0) fila.intentos = result.retry + 1;
    if (hallazgo) fila.hallazgo = hallazgo;
    if (issue) fila.issue = issue;
    if (delRegistro?.severidad) fila.severidad = delRegistro.severidad;
    if (marca) fila.error_anotado = this.limpiar(marca);
    const nota = notas.find((a) => a.type === 'skip')?.description;
    if (estado === 'salteada' && nota) fila.motivo = this.limpiar(nota);
    if (notas.some((a) => a.type === 'menu-ausente')) fila.sin_menu = true;
    const datos = notas.filter((a) => !ANOTACIONES_PROPIAS.has(a.type) && a.description);
    if (datos.length) fila.datos = Object.fromEntries(datos.map((a) => [a.type, this.limpiar(a.description ?? '').slice(0, 240)]));
    const pasos = this.pasos(result.steps, result.status !== 'passed');
    if (pasos.length) fila.pasos = pasos;
    if (mensajes.length && estado !== 'pasa') fila.error = this.limpiar(mensajes.join('\n---\n')).slice(0, MAX_ERROR);
    if (result.status !== 'passed' && estado !== 'salteada') {
      const capturas = this.copiarCapturas(result, clave, estado === 'error-conocido' ? 'conocidos' : '');
      if (capturas.length) fila.capturas = capturas;
    }
    return fila;
  }

  /** Los pasos con nombre siempre; si falló, además las últimas acciones antes de cortarse. */
  private pasos(steps: TestStep[], conAcciones: boolean): string[] {
    const salida: string[] = [];
    const acciones: string[] = [];
    const recorrer = (lista: TestStep[]): void => {
      for (const s of lista) {
        const marca = s.error ? '✗ ' : '';
        if (s.category === 'test.step') salida.push(marca + s.title);
        else if (['pw:api', 'expect'].includes(s.category)) acciones.push(marca + s.title);
        recorrer(s.steps);
      }
    };
    recorrer(steps);
    const finales = conAcciones ? acciones.slice(-10) : [];
    return [...salida, ...finales].map((t) => this.limpiar(t).slice(0, 160));
  }

  /** Los errores conocidos se repiten en cada corrida: sus capturas van a `conocidos/`, que no se versiona. */
  private copiarCapturas(result: TestResult, clave: string, subcarpeta: string): string[] {
    const fotos = result.attachments.filter((a) => a.name === 'screenshot' && a.path && existsSync(a.path));
    const nombre = clave.replace(/\.spec\.ts::/, '_').replace(/[^\w-]+/g, '-').slice(0, 90);
    const dir = join(this.carpeta, 'capturas', subcarpeta);
    return fotos.slice(0, MAX_CAPTURAS).map((f, i) => {
      mkdirSync(dir, { recursive: true });
      const archivo = `${nombre}-${i + 1}.png`;
      copyFileSync(f.path as string, join(dir, archivo));
      return subcarpeta ? `${subcarpeta}/${archivo}` : archivo;
    });
  }

  /** La corrida anterior del mismo ambiente, para decir qué cambió. */
  private anterior(): Fila[] {
    const raiz = dirname(this.carpeta);
    if (!existsSync(raiz)) return [];
    const previa = readdirSync(raiz)
      .filter((d) => d < this.id && d.endsWith(`_${this.entorno}`) && existsSync(join(raiz, d, 'corrida.yaml')))
      .sort()
      .pop();
    return previa ? (parse(readFileSync(join(raiz, previa, 'corrida.yaml'), 'utf8')).pruebas ?? []) : [];
  }

  private cambios(actuales: Fila[], previas: Fila[]): Record<string, string[]> | undefined {
    if (!previas.length) return undefined;
    const antes = new Map(previas.map((p) => [p.clave, p.estado]));
    const mal = (e?: string) => !!e && !['pasa', 'salteada'].includes(e);
    const titulo = (p: Fila) => String(p.titulo);
    return {
      nuevas: actuales.filter((p) => mal(p.estado) && !mal(antes.get(p.clave))).map(titulo),
      corregidas: actuales.filter((p) => (p.estado === 'pasa' || p.estado === 'dejo-de-fallar') && mal(antes.get(p.clave))).map(titulo),
    };
  }

  async onEnd(result: FullResult): Promise<{ status?: FullResult['status'] } | void> {
    mkdirSync(this.carpeta, { recursive: true });
    const ruta = join(this.carpeta, 'corrida.yaml');
    const previo = existsSync(ruta) ? parse(readFileSync(ruta, 'utf8')) : null;
    // doctest.mjs puede lanzar varias tandas en una corrida: se suman en el mismo informe.
    const claves = new Set(this.filas.map((f) => f.clave));
    const pruebas = [...(previo?.pruebas ?? []).filter((p: Fila) => !claves.has(p.clave)), ...this.filas].sort((a, b) =>
      a.clave.localeCompare(b.clave),
    );
    const minutos = (previo?.corrida?.minutos ?? 0) + Math.round((Date.now() - this.inicio) / 60_000);
    const informe = {
      corrida: {
        id: this.id,
        modo: this.modo,
        entorno: this.entorno,
        rama: git('rev-parse --abbrev-ref HEAD'),
        commit: git('rev-parse --short HEAD'),
        inicio: previo?.corrida?.inicio ?? new Date(this.inicio).toISOString(),
        minutos,
      },
      resumen: resumir(pruebas),
      empresas: camposDeEmpresa(this.perfil),
      cambios: this.cambios(pruebas, this.anterior()),
      pruebas,
    };
    writeFileSync(ruta, stringify(informe, { lineWidth: 0, aliasDuplicateObjects: false }));
    const cortadas = this.filas.filter((f) => f.estado === 'otro-punto');
    if (!cortadas.length) return;
    console.log(`\n❌ ${cortadas.length} prueba(s) marcadas se cortaron en otro punto: el error anotado no quedó confirmado.`);
    for (const f of cortadas) console.log(`   · ${f.hallazgo ?? '¿?'} ${f.titulo}`);
    return result.status === 'passed' ? { status: 'failed' } : undefined;
  }
}
