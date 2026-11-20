/**
 * Caso de uso: ADM-UC-013 — Los enlaces de los correos llevan al módulo
 * Catálogo: catalogo/adm/ADM-UC-013.yaml
 *
 * El registro de la copia manda el correo de activación; el enlace tiene que apuntar
 * a la copia (traz-comp-adm/main/complete/token/...) y no a DNATO. Es el requisito de
 * "todo enlace que arma la copia apunta a la copia" (regla 5 del REQ).
 */

import { expect, test } from '@playwright/test';

import { RegistroPage } from '../../pages/dnato/RegistroPage.ts';
import { crearCasilla } from '../../fixtures/casilla-descartable.ts';

// El enlace tiene que incluir el módulo como raíz; uno apuntando a DNATO no matchea.
const ENLACE_ACTIVACION_COPIA =
  /https?:\/\/[^\s"'<>]*traz-comp-adm\/main\/complete\/token\/[A-Za-z0-9_-]+/;

test.describe('@adm @ADM-UC-013 Los enlaces de los correos llevan al módulo', () => {
  test('@smoke el enlace de activación apunta a la copia', async ({ page }) => {
    test.slow();
    const casilla = await crearCasilla('doctest-adm013');

    const registro = new RegistroPage(page);
    await registro.abrir();
    await registro.completar({
      nombre: 'DocTest',
      apellido: 'Adm013',
      email: casilla.direccion,
      razonSocial: `DocTest Adm013 ${Date.now()}`,
      telefono: '+54 92645123456',
      pais: 'Argentina',
    });
    await registro.enviar();
    await registro.esperarMensaje(/registro exitoso/i);

    const activacion = await casilla.esperarEnlace(/activar cuenta/i, ENLACE_ACTIVACION_COPIA, 150_000);

    expect(activacion).toContain('traz-comp-adm');
  });
});
