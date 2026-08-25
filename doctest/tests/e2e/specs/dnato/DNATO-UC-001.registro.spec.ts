/**
 * Caso de uso: DNATO-UC-001 — Registrar una empresa nueva (paso 1: datos de contacto)
 * Catálogo: catalogo/dnato/DNATO-UC-001.yaml (v0.4, validado 2026-08-24)
 * Gherkin:  features/dnato/DNATO-UC-001.registrar-una-empresa-nueva-paso-1-datos-de-cont.feature
 *
 * El camino feliz crea una cuenta real (sin activar) usando una casilla descartable:
 * es la decisión del PM de automatizar contra datos descartables y depurar después.
 * Los caminos de error no escriben nada.
 */

import { expect, test } from '@playwright/test';

import { RegistroPage, type DatosRegistro } from '../../pages/dnato/RegistroPage.ts';
import { crearCasilla } from '../../fixtures/casilla-descartable.ts';
import { credenciales } from '../../fixtures/auth.ts';

const base = (): DatosRegistro => ({
  nombre: 'DocTest',
  apellido: 'Registro',
  email: `doctest-${Date.now()}@ejemplo.test`,
  razonSocial: `DocTest Registro ${Date.now()}`,
  telefono: '+54 92645123456',
  pais: 'Argentina',
});

test.describe('@dnato @DNATO-UC-001 Registrar una empresa nueva', () => {
  test('@smoke muestra el formulario con los seis datos que pide', async ({ page }) => {
    const registro = new RegistroPage(page);
    await registro.abrir();

    for (const campo of [registro.nombre, registro.apellido, registro.email, registro.razonSocial, registro.telefono, registro.pais]) {
      await expect(campo).toBeVisible();
    }
    await expect(registro.pais.locator('option')).not.toHaveCount(1); // la lista de países se cargó
  });

  test('rechaza un correo ya registrado', async ({ page }) => {
    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.completar({ ...base(), email: credenciales('empresa1').email });
    await registro.enviar();

    expect(await registro.mensaje()).toMatch(/ya existe/i);
  });

  test('rechaza una razón social ya usada en el mismo país', async ({ page }) => {
    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.completar({ ...base(), razonSocial: credenciales('empresa1').empresa });
    await registro.enviar();

    expect(await registro.mensaje()).toMatch(/razón social ingresada ya existe/i);
  });

  test('rechaza un teléfono que no cumple el formato del país', async ({ page }) => {
    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.completar({ ...base(), telefono: '123' });

    // El teléfono se valida en el navegador antes de enviar: la pantalla corta con un
    // aviso emergente y no manda nada al servidor. Se verifica el aviso y que no viaje
    // el formulario. (Playwright descarta los avisos por defecto: si no se escucha el
    // evento, este caso parece pasar sin probar nada.)
    let aviso = '';
    page.on('dialog', async (d) => {
      aviso = d.message();
      await d.dismiss();
    });
    let hubopost = false;
    page.on('request', (r) => {
      if (r.method() === 'POST' && r.url().includes('main/register')) hubopost = true;
    });
    await registro.enviar();
    await page.waitForTimeout(1000);

    expect(aviso).toMatch(/tel[ée]fono inv[áa]lido/i);
    expect(hubopost).toBe(false);
    await expect(registro.razonSocial).toBeVisible(); // sigue en el formulario
  });

  test('no registra si faltan campos obligatorios', async ({ page }) => {
    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.email.fill(base().email); // solo el correo
    await registro.enviar();

    const mensaje = await registro.mensaje();
    expect(mensaje).not.toMatch(/registro exitoso/i);
    await expect(registro.razonSocial).toBeVisible(); // sigue en el formulario
  });

  test('registra la cuenta y manda el correo de activación', async ({ page }) => {
    test.slow(); // depende de que llegue un mail
    const casilla = await crearCasilla('doctest-uc001');
    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.completar({ ...base(), email: casilla.direccion });
    await registro.enviar();

    expect(await registro.mensaje()).toMatch(/registro exitoso/i);

    const enlace = await casilla.esperarEnlace(
      /activar cuenta/i,
      /https?:\/\/[^\s"'<>]*main\/complete\/token\/[A-Za-z0-9_-]+/,
      120_000,
    );
    expect(enlace).toContain('main/complete/token/');
  });
});
