/**
 * Caso de uso: MAN-UC-036 — Editar o quitar la asociación de un componente
 * Catálogo: catalogo/man/MAN-UC-036.yaml
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { crearComponente, crearEquipo, sistema, sufijo } from '../../pages/man/datos.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

const COMP = 'traz-tools-man/Componente';

async function asociacion(man: ShellMan, idEquipo: string, codigo: string): Promise<{ id: string; componente: string } | undefined> {
  const html = String(await man.pedir(`${COMP}/asigna/Add-Edit-Del`));
  const fila = html.split('<tr ').find((t) => t.includes(`data-equipo="${idEquipo}"`) && t.includes(codigo));
  if (!fila) return undefined;
  return {
    id: fila.match(/data-componenteequipo="(\d+)"/)?.[1] ?? '',
    componente: fila.match(/data-componente="(\d+)"/)?.[1] ?? '',
  };
}

test.describe('@man @MAN-UC-036 Asociación de un componente', () => {
  test('se cambia el código trazable y al quitarla el componente sigue en el catálogo', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const equipo = await crearEquipo(man);
    const componente = await crearComponente(man);
    const codigo = `TR-${sufijo()}`;
    await man.pedir(`${COMP}/guardar_componente`, {
      idequipo: equipo.id, x: 1, comp: { 1: componente }, codigo: { 1: codigo }, sistemaid: { 1: await sistema(man) },
    });
    const a = await asociacion(man, equipo.id, codigo);
    expect(a?.id, 'la asociación aparece en la lista').toBeTruthy();

    const nuevo = `${codigo}-B`;
    const r = await man.pedir(`${COMP}/editarCompEq`, {
      idCompEq: a!.id, data: { id_equipo: equipo.id, id_componente: componente, codigo: nuevo },
    });
    expect(r, 'la edición se guardó').toBeTruthy();
    expect(await asociacion(man, equipo.id, nuevo), 'la lista muestra el código nuevo').toBeTruthy();

    await man.pedir(`${COMP}/baja_comp`, { idequipo: equipo.id, datos: componente });
    expect(await asociacion(man, equipo.id, nuevo), 'la asociación ya no figura').toBeUndefined();
    const catalogo = (await man.pedir(`${COMP}/getcomponente`, {})) as Array<{ value: string }>;
    expect(catalogo.map((c) => c.value), 'el componente sigue en el catálogo').toContain(componente);
  });
});
