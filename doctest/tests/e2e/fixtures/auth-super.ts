/**
 * Sesión del superusuario del ambiente.
 *
 * Es el correo de `TOOLS_ADMIN_USER` (distinto por ambiente) y lo que separa a la Consola
 * del Portal: a la Consola entra solo el superusuario. Las credenciales nunca se
 * hardcodean: salen del `.env`, con un nombre por entorno
 * (`DOCTEST_LOCAL_SUPER_USER` / `DOCTEST_DEMO_SUPER_USER`).
 */

import { type Browser, type Page } from '@playwright/test';

import { entornoActual, requerirUrlDeApp } from '../config/apps.ts';
import { LoginPage } from '../pages/dnato/LoginPage.ts';

/** Nombres de las variables de este entorno. */
function variables(): { usuario: string; clave: string } {
  const entorno = entornoActual().toUpperCase().replace(/-/g, '_');

  return {
    usuario: `DOCTEST_${entorno}_SUPER_USER`,
    clave: `DOCTEST_${entorno}_SUPER_PASS`,
  };
}

/**
 * Abre una sesión de Tools con el superusuario del ambiente.
 *
 * Entra por el Portal de la empresa 1: el superusuario puede no ser administrador de
 * ninguna empresa, y para llegar a la Consola desde el Portal necesita serlo.
 */
export async function sesionSuperusuario(browser: Browser): Promise<Page> {
  const { usuario, clave } = variables();
  const email = process.env[usuario]?.trim();
  const password = process.env[clave]?.trim();
  const empresa = process.env.DOCTEST_EMPRESA1_NOMBRE;

  if (!email || !password || !empresa) {
    throw new Error(
      `Falta el superusuario del ambiente: completá ${usuario} y ${clave} en doctest/.env ` +
        `(y DOCTEST_EMPRESA1_NOMBRE). Es el correo que está en TOOLS_ADMIN_USER; ` +
        `la contraseña nunca se commitea.`,
    );
  }

  const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
  const pagina = await contexto.newPage();
  const login = new LoginPage(pagina);

  await login.abrir(requerirUrlDeApp('dnato'));
  await login.completar({ empresa, email, password });
  await login.enviar();

  if (await login.enSeleccionDeEmpresa()) {
    await login.elegirEmpresa(empresa);
    await pagina
      .waitForURL((u) => !/seleccionar_empresa/i.test(u.toString()), { timeout: 120_000 })
      .catch(() => {});
  }

  if (/main\/(login|seleccionar_empresa)/i.test(pagina.url())) {
    throw new Error(`No se pudo entrar como superusuario (${email}).`);
  }

  return pagina;
}
