/**
 * Caso de uso: MAN-UC-024 — Registrar una lectura desde el equipo y reportar una falla
 * Catálogo: catalogo/man/MAN-UC-024.yaml
 */

import { test, expect } from '../../fixtures/auth-man.ts';
import { buscarSolicitud, crearEquipo, sufijo } from '../../pages/man/datos.ts';
import { ShellMan } from '../../pages/man/ShellMan.ts';

const EQUIPO = 'traz-tools-man/Equipo';

test.describe('@man @MAN-UC-024 Lectura desde el equipo', () => {
  test('sin falla queda solo la lectura', async ({ paginaMan }) => {
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const equipo = await crearEquipo(man);
    await man.pedir(`${EQUIPO}/estado_alta`, { idequipo: equipo.id });
    const r = await man.pedir(`${EQUIPO}/setLectura`, {
      id_equipo: equipo.id, lectura: 50, operario: 'DocTest', turno: 'Mañana', observacion: 'Sin novedad', estado: 'AC',
    });
    expect(r, 'la lectura se registró').toBeTruthy();
    const historia = (await man.pedir(`${EQUIPO}/getHistoriaLect`, { idequipo: equipo.id, id_equipo: equipo.id })) as unknown[];
    expect(historia.length).toBeGreaterThan(0);
  });

  test('con falla registra la lectura y crea la solicitud de servicio', async ({ paginaMan }) => {
    // Falla conocida, decisión E14: el mantenimiento autónomo está apagado hasta portarlo con su motor;
    // hoy `Equipo::setLectura` rechaza la lectura con falla. Cuando se porte, esta prueba avisa.
    test.fail();
    const man = new ShellMan(paginaMan);
    await man.enElShell();
    const equipo = await crearEquipo(man);
    const falla = `Falla DocTest ${sufijo()}`;
    const r = (await man.pedir(`${EQUIPO}/setLectura`, {
      id_equipo: equipo.id, lectura: 60, operario: 'DocTest', turno: 'Mañana', observacion: 'Con falla', estado: 'AC', falla,
    })) as { status?: boolean; msj?: string };
    expect(r.status, r.msj).toBe(true);
    expect(await buscarSolicitud(man, equipo, falla), 'se creó la solicitud').toBeTruthy();
  });
});
