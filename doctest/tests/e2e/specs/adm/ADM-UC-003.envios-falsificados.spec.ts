/**
 * Caso de uso: ADM-UC-003 — Rechazar envíos falsificados en el módulo
 * Catálogo: catalogo/adm/ADM-UC-003.yaml
 *
 * El esqueleto todavía no tiene acciones que guarden, así que la protección se prueba
 * contra la pantalla de inicio del Portal: el envío con el código de la sesión se acepta y
 * los envíos sin código, o con el de otra sesión, se rechazan.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { PortalPage, urlPortal } from '../../pages/adm/PortalPage.ts';

test.describe('@adm @ADM-UC-003 Rechazar envíos falsificados en el módulo', () => {
  test('el envío con el código de la sesión se acepta', async ({ paginaEmpresa1 }) => {
    const portal = new PortalPage(paginaEmpresa1);
    await portal.abrir();

    const token = await portal.token();
    expect(token, 'la página tiene que publicar el código de seguridad').not.toBe('');

    const respuesta = await portal.enviar({ adm_token: token });
    expect(respuesta.status()).toBe(200);
  });

  test('el código dura toda la sesión: sirve en dos pestañas', async ({ paginaEmpresa1 }) => {
    const portal = new PortalPage(paginaEmpresa1);
    await portal.abrir();

    const token = await portal.token();
    const primero = await portal.enviar({ adm_token: token });
    const segundo = await portal.enviar({ adm_token: token });

    expect(primero.status()).toBe(200);
    expect(segundo.status()).toBe(200);
  });

  test('el envío sin código se rechaza', async ({ paginaEmpresa1 }) => {
    const portal = new PortalPage(paginaEmpresa1);
    await portal.abrir();

    const respuesta = await portal.enviar({});

    expect(respuesta.status()).toBe(403);
  });

  test('el código de otra sesión no sirve', async ({ paginaEmpresa1, paginaEmpresa2 }) => {
    const deUno = new PortalPage(paginaEmpresa1);
    await deUno.abrir();

    const deDos = new PortalPage(paginaEmpresa2);
    await deDos.abrir();
    const tokenAjeno = await deDos.token();
    expect(tokenAjeno, 'la segunda sesión también tiene que tener código').not.toBe('');

    const respuesta = await deUno.enviar({ adm_token: tokenAjeno });

    expect(respuesta.status()).toBe(403);
  });

  test('el envío sin sesión se rechaza con 401', async ({ browser }) => {
    const contexto = await browser.newContext({ ignoreHTTPSErrors: true });
    const pagina = await contexto.newPage();

    // Como AJAX: así el módulo responde 401 en vez de redirigir al ingreso.
    const respuesta = await pagina.request.post(urlPortal(), {
      form: { adm_token: 'cualquiera' },
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
    });

    expect(respuesta.status()).toBe(401);
    await contexto.close();
  });
});
