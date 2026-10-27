/**
 * Circuito completo: alta de usuario en Dnato → rol de AssetPlanner → ingreso a Tools y a Asset.
 * Catálogo: catalogo/dnato/DNATO-UC-014.yaml + DNATO-UC-018.yaml (este spec los encadena)
 *
 * Los casos sueltos no alcanzan para detectar que el alta está rota: UC-014 termina en
 * "usuario creado" y UC-018 solo lee roles existentes. Lo que el PM necesita saber es si
 * un usuario nuevo **termina pudiendo trabajar**, así que se recorre el camino entero.
 *
 * Cada tramo es un `test.step` con aserciones `soft`: si un tramo falla, los siguientes
 * corren igual y el reporte dice cuáles fallan y dónde, no solo el primero.
 *
 * - La asignación de rol se hace entrando directo a `main/changeleveluser/<id>`, porque
 *   la Lista de Usuarios no muestra al recién creado (H-032, #464). El id sale del
 *   redirect que hace el alta (`main/users/<id>`).
 * - El correo NO lleva '+': rompe la asignación de roles en Bonita (H-084).
 */

import { expect, test, credenciales } from '../../fixtures/auth.ts';
import { requerirUrlDeApp, urlDnato } from '../../config/apps.ts';
import { AltaUsuarioPage } from '../../pages/dnato/AltaUsuarioPage.ts';
import { LoginPage } from '../../pages/dnato/LoginPage.ts';
import { UsuariosListPage } from '../../pages/dnato/UsuariosListPage.ts';
import { LoginManPage } from '../../pages/man/LoginManPage.ts';

const ROL_ASSET = /mantenedor/i;

test.describe('@dnato @DNATO-UC-014 @DNATO-UC-018 Circuito: alta de usuario con rol de Asset', () => {
  test.describe.configure({ mode: 'serial', timeout: 600_000 });

  test('un usuario nuevo con rol Mantenedor puede entrar a Tools y a Asset', async ({ paginaEmpresa1: page, browser }) => {
    const empresa = credenciales('empresa1').empresa;
    const marca = Date.now();
    const datos = {
      nombre: 'DocTest',
      apellido: `Circuito ${marca}`,
      email: `doctest-circuito-${marca}@doctest-empresa.com`,
      empresa,
      password: 'Doctest2026!',
    };
    let userId = '';
    console.log(`[circuito] usuario de prueba: ${datos.email} / empresa ${empresa}`);

    await test.step('1. Alta del usuario en Dnato', async () => {
      const alta = new AltaUsuarioPage(page);
      await alta.abrir();
      await alta.completar(datos);
      await alta.enviar();
      await alta.esperarMensaje(/creado exitosamente|error|ya existe/i, 60_000);
      const id = /main\/users\/(\d+)/.exec(page.url())?.[1];
      console.log(`[circuito] 1. URL tras el alta: ${page.url()}`);
      expect(id, 'el alta debe redirigir a main/users/<id>').toBeTruthy();
      userId = id ?? '';
    });

    await test.step('2. El recién creado aparece en la Lista de Usuarios (H-032)', async () => {
      const lista = new UsuariosListPage(page);
      await lista.abrir();
      await lista.buscar(datos.email);
      const visto = (await lista.correos()).includes(datos.email);
      console.log(`[circuito] 2. aparece en la lista sin roles: ${visto}`);
      // FALLA CONOCIDA — H-032, #464. La aserción vive en DNATO-UC-014 con test.fail();
      // acá solo se registra, para que el circuito no quede rojo por un bug ya abierto.
      // Cuando se arregle #464, este tramo pasa a dar `true` y la anotación lo muestra.
      test.info().annotations.push({ type: 'H-032', description: `usuario sin roles visible en la lista: ${visto}` });
    });

    await test.step('3. Asignar el rol Mantenedor desde Asignar Rol', async () => {
      test.skip(!userId, 'sin id de usuario no se puede asignar rol');
      await page.goto(urlDnato(`main/changeleveluser/${userId}`), { waitUntil: 'domcontentloaded' });
      await page.getByRole('button', { name: 'Agregar Rol' }).click();

      const grupos = page.locator('#groups');
      const opcionesGrupo = (await grupos.locator('option').allInnerTexts()).map((t) => t.trim());
      console.log(`[circuito] 3. empresas ofrecidas: ${JSON.stringify(opcionesGrupo)}`);
      const grupo = opcionesGrupo.find((t) => t.includes(empresa));
      expect(grupo, `la empresa "${empresa}" debe estar en el combo`).toBeTruthy();
      await grupos.selectOption({ label: grupo! });

      const roles = page.locator('#roles');
      const opcionesRol = (await roles.locator('option').allInnerTexts()).map((t) => t.trim());
      console.log(`[circuito] 3. roles ofrecidos: ${JSON.stringify(opcionesRol)}`);
      const rol = opcionesRol.find((t) => ROL_ASSET.test(t));
      expect(rol, 'debe ofrecerse un rol Mantenedor').toBeTruthy();
      await roles.selectOption({ label: rol! });

      await page.locator('.roleIdClass').click();
      await page.locator('#mdlRolEmpresa').getByRole('button', { name: 'Finalizar' }).click();

      const respuesta = page.waitForResponse((r) => r.url().includes('changeLevelRolUserObject'), { timeout: 180_000 });
      await page.getByRole('button', { name: 'Guardar' }).click();
      const r = await respuesta;
      const cuerpo = await r.text();
      console.log(`[circuito] 3. changeLevelRolUserObject → HTTP ${r.status()} ${cuerpo.slice(0, 500)}`);
      expect.soft(r.status(), `asignar rol respondió: ${cuerpo.slice(0, 300)}`).toBe(200);
    });

    await test.step('4. Con el rol asignado, aparece en la Lista de Usuarios', async () => {
      const lista = new UsuariosListPage(page);
      await lista.abrir();
      await lista.buscar(datos.email);
      const visto = (await lista.correos()).includes(datos.email);
      console.log(`[circuito] 4. aparece en la lista con rol: ${visto}`);
      expect.soft(visto).toBe(true);
    });

    await test.step('5. El usuario nuevo entra a Tools', async () => {
      const ctx = await browser.newContext({ ignoreHTTPSErrors: true });
      const p = await ctx.newPage();
      p.setDefaultNavigationTimeout(120_000);
      const login = new LoginPage(p);
      await login.abrir(requerirUrlDeApp('dnato'));
      await login.ingresar({ empresa, email: datos.email, password: datos.password });
      const error = await login.mensajeDeError();
      const ok = await login.sesionIniciada();
      console.log(`[circuito] 5. Tools: sesión=${ok} error=${error ?? '-'} url=${p.url()}`);
      expect.soft(error, 'el login no debe mostrar error').toBeNull();
      expect.soft(ok, 'debe quedar con sesión iniciada en Tools').toBe(true);
      await ctx.close();
    });

    await test.step('6. El usuario nuevo entra a AssetPlanner', async () => {
      const ctx = await browser.newContext({ ignoreHTTPSErrors: true });
      const p = await ctx.newPage();
      const login = new LoginManPage(p);
      await login.abrir(requerirUrlDeApp('man'));
      await login.ingresar({ usuario: datos.email, password: datos.password });
      const sigue = await login.sigueEnElIngreso();
      const texto = (await p.locator('body').innerText()).replace(/\s+/g, ' ').slice(0, 300);
      console.log(`[circuito] 6. Asset: sigue en el ingreso=${sigue} url=${p.url()} texto="${texto}"`);
      expect.soft(sigue, `no debe quedar en el formulario de ingreso de Asset: ${texto}`).toBe(false);
      await ctx.close();
    });
  });
});
