/**
 * casilla-descartable.ts — casilla de correo temporal para los casos que dependen
 * de un mail (activación de cuenta y recuperación de contraseña).
 *
 * Por qué existe: DNATO-UC-002 y DNATO-UC-008 no terminan en la pantalla, terminan
 * en un enlace que llega por correo. Si ese enlace lo pega una persona, el caso no
 * está automatizado. Con esto el test crea su propia casilla, se registra con ella
 * y lee el mail solo.
 *
 * Por qué una casilla descartable y no una cuenta fija: no hay credenciales que
 * guardar ni rotar (ni en `.env` ni en GitHub Secrets), cada corrida arranca con la
 * bandeja vacía —así que nunca lee el mail de la corrida anterior— y funciona igual
 * en la máquina de cualquiera y en CI. Google, además, ya no admite IMAP con
 * contraseña común y exige contraseña de aplicación, que esa cuenta no puede emitir.
 *
 * ⚠️ Límite conocido: el dominio de estas casillas es público, así que el enlace de
 * activación es legible por cualquiera que conozca la dirección. Es aceptable para
 * el entorno de pruebas y para datos de test; **nunca** para producción ni para
 * cuentas con datos reales.
 *
 * Servicio: https://mail.tm (gratuito, sin registro). Si algún día no responde,
 * la interfaz `Casilla` es lo único que hay que reimplementar.
 */

const API = process.env.DOCTEST_MAIL_API ?? 'https://api.mail.tm';

export interface Casilla {
  /** Dirección completa, para usar en el formulario de registro. */
  direccion: string;
  /** Espera un mail cuyo asunto matchee y devuelve el primer enlace que cumpla el patrón. */
  esperarEnlace(asunto: RegExp, enlace: RegExp, timeoutMs?: number): Promise<string>;
  /** Devuelve los asuntos recibidos, para diagnosticar cuando algo no llega. */
  asuntos(): Promise<string[]>;
}

interface Mensaje {
  id: string;
  subject: string;
}

async function pedir<T>(ruta: string, opciones: RequestInit = {}, token?: string): Promise<T> {
  const respuesta = await fetch(`${API}${ruta}`, {
    ...opciones,
    headers: {
      accept: 'application/json',
      ...(opciones.body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(opciones.headers ?? {}),
    },
  });
  if (!respuesta.ok) {
    throw new Error(`${API}${ruta} respondió ${respuesta.status}: ${(await respuesta.text()).slice(0, 200)}`);
  }
  return (await respuesta.json()) as T;
}

/** La API a veces devuelve un array y a veces la colección de Hydra. */
function comoLista<T>(cuerpo: unknown): T[] {
  if (Array.isArray(cuerpo)) return cuerpo as T[];
  const miembros = (cuerpo as { 'hydra:member'?: T[] })['hydra:member'];
  return miembros ?? [];
}

function aleatorio(largo = 10): string {
  const abc = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return Array.from({ length: largo }, () => abc[Math.floor(Math.random() * abc.length)]).join('');
}

const dormir = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Crea una casilla nueva y devuelve con qué leerla.
 * @param prefijo parte local de la dirección; se le agrega un sufijo aleatorio.
 */
export async function crearCasilla(prefijo = 'doctest'): Promise<Casilla> {
  const dominios = comoLista<{ domain: string; isActive: boolean }>(await pedir('/domains?page=1'));
  const dominio = dominios.find((d) => d.isActive)?.domain;
  if (!dominio) throw new Error('El servicio de casillas descartables no ofrece ningún dominio activo.');

  const direccion = `${prefijo}-${aleatorio()}@${dominio}`;
  const clave = `Dt-${aleatorio(14)}!`;

  await pedir('/accounts', { method: 'POST', body: JSON.stringify({ address: direccion, password: clave }) });
  const { token } = await pedir<{ token: string }>('/token', {
    method: 'POST',
    body: JSON.stringify({ address: direccion, password: clave }),
  });

  const listar = async (): Promise<Mensaje[]> =>
    comoLista<Mensaje>(await pedir('/messages?page=1', {}, token));

  return {
    direccion,
    async asuntos() {
      return (await listar()).map((m) => m.subject);
    },
    async esperarEnlace(asunto, enlace, timeoutMs = 180_000) {
      const hasta = Date.now() + timeoutMs;
      let vistos: string[] = [];
      while (Date.now() < hasta) {
        const mensajes = await listar();
        vistos = mensajes.map((m) => m.subject);
        const elegido = mensajes.find((m) => asunto.test(m.subject ?? ''));
        if (elegido) {
          const cuerpo = await pedir<{ text?: string; html?: string[] }>(`/messages/${elegido.id}`, {}, token);
          const html = (cuerpo.html ?? []).join('\n');
          const texto = `${cuerpo.text ?? ''}\n${html}`;
          // Primero se buscan los enlaces del HTML: en el cuerpo en texto plano el
          // enlace suele quedar pegado a la línea siguiente y se extrae de más.
          const hrefs = [...html.matchAll(/href="([^"]+)"/gi)].map((m) => m[1]);
          const desdeHref = hrefs.find((h) => enlace.test(h));
          const encontrado = desdeHref ?? enlace.exec(texto)?.[0];
          if (encontrado) return encontrado.replace(/&amp;/g, '&').trim();
          throw new Error(
            `Llegó el mail "${elegido.subject}" pero no tiene ningún enlace que cumpla ${enlace}.\n` +
              `Primeros 300 caracteres: ${texto.slice(0, 300)}`,
          );
        }
        await dormir(5_000);
      }
      throw new Error(
        `No llegó ningún mail con asunto ${asunto} en ${Math.round(timeoutMs / 1000)} s. ` +
          `Recibidos: ${vistos.length ? vistos.join(' | ') : '(ninguno)'}`,
      );
    },
  };
}
