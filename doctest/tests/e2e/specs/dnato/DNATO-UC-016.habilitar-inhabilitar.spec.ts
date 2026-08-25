/**
 * Caso de uso: DNATO-UC-016 — Habilitar o inhabilitar un usuario
 * Catálogo: catalogo/dnato/DNATO-UC-016.yaml (v0.3, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-016.habilitar-o-inhabilitar-un-usuario.feature
 *
 * Es la baja lógica del sistema: la única forma de sacar a alguien de circulación
 * sin borrarlo (ver DNATO-UC-017 y el hallazgo H-002).
 */

import { expect, test } from '../../fixtures/auth.ts';
import { BanUsuarioPage } from '../../pages/dnato/BanUsuarioPage.ts';
import { credenciales } from '../../fixtures/auth.ts';

test.describe('@dnato @DNATO-UC-016 Habilitar o inhabilitar un usuario', () => {
  test('ofrece a los usuarios de la empresa para habilitar o inhabilitar', async ({ paginaEmpresa1 }) => {
    const pantalla = new BanUsuarioPage(paginaEmpresa1);
    await pantalla.abrir();

    expect(await pantalla.enPantalla()).toBe(true);
    const correos = await pantalla.correos();
    expect(correos.length).toBeGreaterThan(0);
    // Y solo de su empresa: el aislamiento vale también acá.
    expect(correos).not.toContain(credenciales('empresa2').email);
  });

  test('un administrador no puede inhabilitarse a sí mismo', async ({ paginaEmpresa1 }) => {
    // Regla del PM, verificada: la pantalla no ofrece al usuario conectado.
    // (El hallazgo H-018 nació de leer el controlador; este test lo desmintió.)
    const pantalla = new BanUsuarioPage(paginaEmpresa1);
    await pantalla.abrir();
    expect(await pantalla.correos()).not.toContain(credenciales('empresa1').email);
  });
});
