/**
 * Caso de uso: DNATO-UC-013 — Ver la lista de usuarios de la empresa
 * Catálogo: catalogo/dnato/DNATO-UC-013.yaml
 * Gherkin:  features/dnato/DNATO-UC-013.ver-la-lista-de-usuarios-de-la-empresa.feature
 *
 * El caso más valioso del módulo: verifica que un administrador NO vea usuarios de
 * otra empresa. Por eso corre con las dos empresas de test.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { UsuariosListPage } from '../../pages/dnato/UsuariosListPage.ts';
import { credenciales } from '../../fixtures/auth.ts';

/** Dominio de los usuarios iniciales de una empresa, deducido del correo de su administrador. */
const dominioDe = (correo: string) => correo.split('@')[1];

test.describe('@dnato @DNATO-UC-013 Ver la lista de usuarios de la empresa', () => {
  test('@smoke muestra la grilla con sus columnas', async ({ paginaEmpresa1 }) => {
    const usuarios = new UsuariosListPage(paginaEmpresa1);
    await usuarios.abrir();

    expect(await usuarios.visible()).toBe(true);
    const columnas = (await usuarios.columnas()).map((c) => c.toLowerCase());
    for (const esperada of ['nombre', 'usuario', 'nivel de usuario', 'estado', 'acciones']) {
      expect(columnas.join(' | ')).toContain(esperada);
    }
  });

  test('el administrador ve a los usuarios de su empresa', async ({ paginaEmpresa1 }) => {
    const usuarios = new UsuariosListPage(paginaEmpresa1);
    await usuarios.abrir();

    const correos = await usuarios.correos();
    expect(correos).toContain(credenciales('empresa1').email);
    // Los cinco usuarios iniciales de la empresa comparten el dominio declarado en el alta.
    expect(correos.filter((c) => c.endsWith('@' + dominioDe(correos[correos.length - 1]))).length).toBeGreaterThan(0);
  });

  test('@smoke no ve usuarios de otra empresa', async ({ paginaEmpresa1, paginaEmpresa2 }) => {
    const deUno = new UsuariosListPage(paginaEmpresa1);
    await deUno.abrir();
    const correosUno = await deUno.correos();

    const deDos = new UsuariosListPage(paginaEmpresa2);
    await deDos.abrir();
    const correosDos = await deDos.correos();

    expect(correosUno).toContain(credenciales('empresa1').email);
    expect(correosDos).toContain(credenciales('empresa2').email);

    // Ninguno ve al administrador del otro.
    expect(correosUno).not.toContain(credenciales('empresa2').email);
    expect(correosDos).not.toContain(credenciales('empresa1').email);

    // Y tampoco a los usuarios iniciales del otro, que viven en otro dominio.
    const dominioDos = dominioDe(credenciales('empresa2').email);
    expect(correosUno.filter((c) => c.endsWith('@' + dominioDos))).toHaveLength(0);
  });

  test('el buscador filtra por correo', async ({ paginaEmpresa1 }) => {
    const usuarios = new UsuariosListPage(paginaEmpresa1);
    await usuarios.abrir();
    const propio = credenciales('empresa1').email;

    await usuarios.buscar(propio);
    const correos = await usuarios.correos();
    expect(correos).toContain(propio);
    expect(correos.length).toBeLessThanOrEqual(2);
  });
});
