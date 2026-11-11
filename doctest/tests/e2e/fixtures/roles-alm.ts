/**
 * Sesiones por ROL para las pruebas de ciclo de vida de Almacenes.
 *
 * El circuito del pedido de materiales lo recorren dos personas distintas —quien pide y
 * quien entrega—, así que no alcanza con la sesión de administrador que usa el resto de
 * la suite: hace falta entrar con cada rol.
 *
 * Los usuarios son los que crea la registración de cada empresa (DNATO-UC-005), con los
 * roles que les asigna el alta. Como siempre, **nunca se hardcodean**: si falta uno, el
 * test falla diciendo exactamente qué variable completar.
 */

import { type Browser, type Page } from '@playwright/test';

import { requerirUrlDeApp } from '../config/apps.ts';
import { LoginPage } from '../pages/dnato/LoginPage.ts';

export type RolAlm = 'solicitante' | 'almacen';

const VARIABLES: Record<RolAlm, { usuario: string; clave: string; queHace: string }> = {
  solicitante: {
    usuario: 'DOCTEST_ALM_SOLICITANTE_USER',
    clave: 'DOCTEST_ALM_SOLICITANTE_PASS',
    queHace: 'pide materiales al almacén',
  },
  almacen: {
    usuario: 'DOCTEST_ALM_ALMACEN_USER',
    clave: 'DOCTEST_ALM_ALMACEN_PASS',
    queHace: 'recibe el pedido y entrega',
  },
};

/** Abre una sesión de Tools con el rol pedido. Quien la abre es responsable de cerrarla. */
export async function sesionDeRol(browser: Browser, rol: RolAlm): Promise<Page> {
  const { usuario, clave, queHace } = VARIABLES[rol];
  const email = process.env[usuario];
  const password = process.env[clave];
  const empresa = process.env.DOCTEST_EMPRESA1_NOMBRE;

  if (!email || !password || !empresa) {
    throw new Error(
      `Falta el usuario con rol "${rol}" (el que ${queHace}).\n` +
        `Completá ${usuario} y ${clave} en doctest/.env, y DOCTEST_EMPRESA1_NOMBRE.\n` +
        `Son los usuarios iniciales que crea la registración: se ven en la pantalla de bienvenida.`,
    );
  }

  return sesionTools(browser, email, password, empresa, `el rol "${rol}"`);
}

/** Abre una sesión de Tools con un usuario. Quien la abre es responsable de cerrarla. */
export async function sesionTools(browser: Browser, email: string, password: string, empresa: string, quien = 'el usuario'): Promise<Page> {
  const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await contexto.newPage();
  // Las pantallas avisan con alert()/confirm() nativos: un diálogo sin atender traba la página.
  page.on('dialog', (d) => void d.accept().catch(() => {}));
  const login = new LoginPage(page);
  await login.abrir(requerirUrlDeApp('dnato'));
  await login.ingresar({ email, password, empresa });

  // El ingreso redirige en el navegador: se espera a que salga del login antes de decidir.
  await page.waitForURL((u) => !/main\/login/i.test(u.href), { timeout: 60_000 }).catch(() => {});
  if (/main\/login/i.test(page.url())) {
    throw new Error(`No se pudo entrar a Tools con ${quien} (${email}).`);
  }
  return page;
}

/** URL de una pantalla de Almacenes dentro de Tools. */
export function urlModuloAlm(ruta: string): string {
  return `${requerirUrlDeApp('tools').replace(/\/$/, '')}/traz-comp-almacenes/${ruta}`;
}
