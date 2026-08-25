/**
 * Caso de uso: DNATO-UC-014 — Dar de alta un usuario de la empresa
 * Catálogo: catalogo/dnato/DNATO-UC-014.yaml (v0.3, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-014.dar-de-alta-un-usuario-de-la-empresa.feature
 *
 * El alta crea un usuario real con prefijo `doctest+`, según la decisión del PM de
 * trabajar contra datos descartables y depurarlos después.
 */

import { expect, test } from '../../fixtures/auth.ts';
import { AltaUsuarioPage } from '../../pages/dnato/AltaUsuarioPage.ts';
import { UsuariosListPage } from '../../pages/dnato/UsuariosListPage.ts';
import { credenciales } from '../../fixtures/auth.ts';

const nuevo = () => ({
  nombre: 'DocTest',
  apellido: `Alta ${Date.now()}`,
  email: `doctest+alta-${Date.now()}@doctest-empresa.com`,
  empresa: credenciales('empresa1').empresa,
  password: 'Doctest2026!',
});

test.describe('@dnato @DNATO-UC-014 Dar de alta un usuario de la empresa', () => {
  test('muestra el formulario con sus campos obligatorios', async ({ paginaEmpresa1 }) => {
    const alta = new AltaUsuarioPage(paginaEmpresa1);
    await alta.abrir();

    for (const campo of [alta.nombre, alta.apellido, alta.email, alta.empresa, alta.perfil, alta.password, alta.passconf]) {
      await expect(campo).toBeVisible();
    }
  });

  test('rechaza un correo que ya existe', async ({ paginaEmpresa1 }) => {
    const alta = new AltaUsuarioPage(paginaEmpresa1);
    await alta.abrir();
    await alta.completar({ ...nuevo(), email: credenciales('empresa1').email });
    await alta.enviar();

    expect(await alta.mensaje()).toMatch(/ya existe un usuario asociado a ese email/i);
  });

  test('no deja guardar con una contraseña que no cumple la política', async ({ paginaEmpresa1 }) => {
    const alta = new AltaUsuarioPage(paginaEmpresa1);
    await alta.abrir();
    await alta.completar({ ...nuevo(), password: 'doctest2026' }); // sin mayúscula ni símbolo

    // La pantalla tiene un medidor de fortaleza que mantiene el botón fuera de juego
    // hasta que la contraseña cumple: no hace falta enviar el formulario para verlo.
    await expect(alta.guardar.first()).toBeDisabled();
  });

  test('crea el usuario y avisa que hay que asignarle roles', async ({ paginaEmpresa1 }) => {
    const datos = nuevo();
    const alta = new AltaUsuarioPage(paginaEmpresa1);
    await alta.abrir();
    await alta.completar(datos);
    await alta.enviar();
    await paginaEmpresa1.waitForTimeout(2000);

    const mensaje = await alta.mensaje();
    expect(mensaje).toMatch(/creado exitosamente/i);
    // La pantalla avisa que sin roles el usuario todavía no puede entrar.
    expect(mensaje).toMatch(/asignarle roles/i);

  });

  test('el usuario recién creado aparece en la lista para poder asignarle roles', async ({ paginaEmpresa1 }) => {
    // FALLA CONOCIDA — hallazgo H-032, issue #464: la Lista de Usuarios hace INNER JOIN
    // contra las membresías, así que un usuario sin roles no aparece… que es justo lo
    // que la pantalla de alta pide ir a hacer ahí. Callejón sin salida.
    test.fail();

    const datos = nuevo();
    const alta = new AltaUsuarioPage(paginaEmpresa1);
    await alta.abrir();
    await alta.completar(datos);
    await alta.enviar();
    await paginaEmpresa1.waitForTimeout(2000);

    const usuarios = new UsuariosListPage(paginaEmpresa1);
    await usuarios.abrir();
    await usuarios.buscar(datos.email);
    expect(await usuarios.correos()).toContain(datos.email);
  });

  test('el desplegable de empresas ofrece solo las empresas del administrador', async ({ paginaEmpresa1 }) => {
    // Regla del PM, verificada: la vista arma el combo con las empresas del conectado.
    // (El hallazgo H-019 nació de leer el controlador; este test lo desmintió.)
    const alta = new AltaUsuarioPage(paginaEmpresa1);
    await alta.abrir();
    const empresas = await alta.empresasOfrecidas();

    expect(empresas).toContain(credenciales('empresa1').empresa);
    expect(empresas).not.toContain(credenciales('empresa2').empresa);
  });
});
