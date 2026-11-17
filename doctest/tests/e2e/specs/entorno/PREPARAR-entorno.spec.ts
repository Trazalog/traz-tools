/**
 * PREPARAR-entorno — deja un ambiente listo para probar, desde cero.
 *
 * No es un caso de uso del catálogo: es la preparación que corren los modos `casi-full` y
 * `full` de `npm run doctest`. Registra DOS empresas nuevas por la registración real
 * (los casos de aislamiento necesitan una segunda empresa), y en modo `full` le carga a la
 * primera los datos de Mantenimiento que una empresa recién registrada no trae (equipo, stock,
 * herramienta, plan y una orden con pedido, entrega y vale). Al terminar escribe `doctest/entornos/<entorno>.json`, el perfil
 * que el modo `regresion` usa después para saber con qué empresas probar.
 *
 * Reusa los flujos de `flows/registrar-empresa.ts` y `flows/seed-man.ts`.
 *
 * ⚠️ Crea datos reales en el ambiente (dos empresas por corrida). Nunca producción: lo
 * impide `config/apps.ts`. Necesita `DOCTEST_MAIL_IMAP_*` para leer el mail de activación.
 *
 * Etiqueta `@preparar-entorno`: está fuera de todas las demás corridas.
 */

import { test } from '@playwright/test';

import { entornoActual, escribirPerfil, type PerfilEntorno } from '../../config/perfil-entorno.ts';
import { crearCapturador } from '../../fixtures/capturas.ts';
import { registrarEmpresa } from '../../flows/registrar-empresa.ts';
import { sembrarMan } from '../../flows/seed-man.ts';
import { sesionTools } from '../../fixtures/roles-alm.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

/**
 * Contraseña con la que nacen los 5 usuarios de rol del alta (usuario@, almacen@, …).
 * Sale de `REGISTRACION_PASSWORD_DEFAULT` en el constants.php de dnato de cada ambiente;
 * en el DEMO es 12345 (verificado 2026-10-26). Si en otro ambiente es distinta, se pisa
 * con DOCTEST_PASSWORD_ROLES.
 */
const CLAVE_ROLES = process.env.DOCTEST_PASSWORD_ROLES || '12345';

test.describe('@preparar-entorno Preparar el ambiente: empresas de test desde cero', () => {
  // retries 0: cada intento registra empresas reales; un reintento crearía de más.
  test.describe.configure({ mode: 'serial', timeout: 1_800_000, retries: 0 });

  test('registrar dos empresas y dejar el perfil del ambiente', async ({ page, browser }) => {
    const sembrar = process.env.DOCTEST_PREPARAR_SEMBRAR === '1';
    const cap = crearCapturador('preparar-entorno');

    const empresa1 = await test.step('1. Registrar la empresa 1', () => registrarEmpresa(page, cap));
    console.log(`[preparar] ✓ empresa 1: ${empresa1.razonSocial} · admin ${empresa1.admin.email}`);

    // La segunda en un contexto limpio, para que la sesión de la primera no interfiera.
    const empresa2 = await test.step('2. Registrar la empresa 2', async () => {
      const contexto = await browser.newContext();
      try {
        return await registrarEmpresa(await contexto.newPage(), cap);
      } finally {
        await contexto.close();
      }
    });
    console.log(`[preparar] ✓ empresa 2: ${empresa2.razonSocial} · admin ${empresa2.admin.email}`);

    const perfil: PerfilEntorno = {
      entorno: entornoActual(),
      creado: new Date().toISOString(),
      modo: sembrar ? 'full' : 'casi-full',
      empresa1: {
        nombre: empresa1.razonSocial,
        dominio: empresa1.dominio,
        admin: { usuario: empresa1.admin.email, clave: empresa1.admin.password },
      },
      empresa2: {
        nombre: empresa2.razonSocial,
        dominio: empresa2.dominio,
        admin: { usuario: empresa2.admin.email, clave: empresa2.admin.password },
      },
      // El administrador entra a Tools y tiene el menú de Mantenimiento (lo carga el alta de la empresa).
      man: {
        usuario: empresa1.admin.email,
        clave: empresa1.admin.password,
        supervisor: { usuario: empresa1.usuariosRol.mantenimiento, clave: CLAVE_ROLES },
      },
      tar: {
        planificador: { usuario: empresa1.usuariosRol.produccion, clave: CLAVE_ROLES },
        responsable1: { usuario: empresa1.usuariosRol.mantenimiento, clave: CLAVE_ROLES },
        responsable2: { usuario: empresa1.usuariosRol.panol, clave: CLAVE_ROLES },
      },
      alm: {
        solicitante: { usuario: empresa1.usuariosRol.usuario, clave: CLAVE_ROLES },
        almacen: { usuario: empresa1.usuariosRol.almacen, clave: CLAVE_ROLES },
      },
    };

    if (sembrar) {
      await test.step('3. Cargar datos de Mantenimiento en la empresa 1', async () => {
        const admin = await sesionTools(browser, empresa1.admin.email, empresa1.admin.password, empresa1.razonSocial);
        const almacen = await sesionTools(browser, empresa1.usuariosRol.almacen, CLAVE_ROLES, empresa1.razonSocial);
        try {
          perfil.sembrado = await sembrarMan(new ShellMan(admin), almacen, empresa1.razonSocial);
        } finally {
          await admin.context().close();
          await almacen.context().close();
        }
        console.log(`[preparar] ✓ datos cargados: ${JSON.stringify(perfil.sembrado)}`);
      });
    }

    const ruta = escribirPerfil(perfil);
    console.log(`[preparar] ✓ perfil del ambiente escrito en ${ruta}`);
  });
});
