/**
 * mail-imap.ts — lee el enlace de activación de una casilla Gmail por IMAP, y arma
 * variantes irrepetibles de una dirección usando PUNTOS.
 *
 * Por qué Gmail y no una casilla descartable (mail.tm) para crear EMPRESAS: el alta
 * exige un dominio corporativo único por empresa. Si el correo es de un webmail
 * reconocido (Gmail), el sistema pide un dominio corporativo APARTE y editable, así
 * que cada corrida puede estrenar uno propio. Con una casilla descartable, en cambio,
 * el sistema toma el dominio del correo (compartido entre todas las direcciones del
 * servicio) como dominio corporativo y lo deja READONLY → "ese dominio ya está en uso".
 *
 * Extraído de `seeds/crear-empresa-test.ts`, donde este mecanismo está validado contra
 * el DEMO (incluye el rodeo de los puntos por el hallazgo H-084).
 */

import { connect as tlsConnect, type ConnectionOptions as TlsConnectionOptions } from 'node:tls';

const IMAP = {
  host: process.env.DOCTEST_MAIL_IMAP_HOST ?? '',
  port: Number(process.env.DOCTEST_MAIL_IMAP_PORT ?? 993),
  user: process.env.DOCTEST_MAIL_IMAP_USER ?? '',
  pass: process.env.DOCTEST_MAIL_IMAP_PASS ?? '',
};

/** `true` si hay con qué leer la casilla (host + pass). */
export function hayImap(): boolean {
  return !!(IMAP.host && IMAP.pass);
}

/** La casilla base configurada (p. ej. admindoctest@gmail.com). */
export function casillaBase(): string {
  return IMAP.user;
}

/**
 * Variante irrepetible de una dirección de Gmail usando PUNTOS.
 * Gmail ignora los puntos de la parte local (misma bandeja), pero Trazalog ve cada
 * variante como un usuario distinto, así que cada corrida estrena administrador sin
 * crear cuentas nuevas. NO se usa `+` porque toolsbpmAPI lo mete sin escapar en un
 * query string y el `+` se decodifica como espacio (H-084), y el alta se revierte.
 */
export function variantePorPuntos(casilla: string, n: number): string {
  const [local, dominio] = casilla.split('@');
  let salida = local[0];
  for (let i = 1; i < local.length; i++) {
    if ((n >> (i - 1)) & 1) salida += '.';
    salida += local[i];
  }
  return `${salida}@${dominio}`;
}

/** Cliente IMAP mínimo (LOGIN → SELECT → SEARCH → FETCH) sin dependencias. */
function imapBuscarEnlace(asunto: string, destinatario: string, minutos = 30): Promise<string | null> {
  return new Promise((resolveP, rejectP) => {
    const socket = tlsConnect({ host: IMAP.host, port: IMAP.port, servername: IMAP.host, family: 4 } as TlsConnectionOptions & { family: number });
    let buffer = '';
    let paso = 0;
    const enviar = (cmd: string) => socket.write(`a${++paso} ${cmd}\r\n`);
    const desde = new Date(Date.now() - minutos * 60_000)
      .toUTCString()
      .replace(/^\w+, (\d+) (\w+) (\d+).*$/, '$1-$2-$3');

    socket.setEncoding('utf8');
    socket.on('error', rejectP);
    socket.on('data', (chunk: string) => {
      buffer += chunk;
      if (paso === 0 && buffer.includes('* OK')) {
        enviar(`LOGIN "${IMAP.user}" "${IMAP.pass}"`);
      } else if (paso === 1 && /a1 OK/.test(buffer)) {
        buffer = '';
        enviar('SELECT INBOX');
      } else if (paso === 2 && /a2 OK/.test(buffer)) {
        buffer = '';
        enviar(`SEARCH SINCE ${desde} TO "${destinatario}" SUBJECT "${asunto}"`);
      } else if (paso === 3 && /a3 OK/.test(buffer)) {
        const ids = (/\* SEARCH([^\r\n]*)/.exec(buffer)?.[1] ?? '').trim().split(/\s+/).filter(Boolean);
        if (ids.length === 0) {
          socket.end();
          resolveP(null);
          return;
        }
        buffer = '';
        enviar(`FETCH ${ids[ids.length - 1]} BODY[TEXT]`);
      } else if (paso === 4 && /a4 OK/.test(buffer)) {
        const cuerpo = buffer.replace(/=\r\n/g, '').replace(/=3D/g, '=');
        const enlace = /https?:\/\/[^\s"'<>]*main\/complete\/token\/[A-Za-z0-9_-]+/.exec(cuerpo)?.[0] ?? null;
        socket.end();
        resolveP(enlace);
      } else if (/a\d+ (NO|BAD)/.test(buffer)) {
        const err = buffer.trim().split('\n').pop();
        socket.end();
        rejectP(new Error(`IMAP rechazó el comando: ${err}`));
      }
    });
  });
}

/**
 * Espera el mail de activación dirigido a `destinatario` y devuelve su enlace.
 * Reintenta porque el mail puede tardar unos segundos en llegar.
 */
export async function esperarEnlaceActivacion(destinatario: string, intentos = 12, intervaloMs = 15_000): Promise<string> {
  for (let i = 1; i <= intentos; i++) {
    const enlace = await imapBuscarEnlace('Activar cuenta', destinatario);
    if (enlace) return enlace;
    if (i < intentos) await new Promise((r) => setTimeout(r, intervaloMs));
  }
  throw new Error(
    `No llegó el mail de activación para ${destinatario} en ${Math.round((intentos * intervaloMs) / 1000)} s ` +
      `(casilla ${IMAP.user} en ${IMAP.host}).`,
  );
}
