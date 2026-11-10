/**
 * Datos base de TAR que crea `preparar-datos-tar.ts` y que usan los specs. Viven aparte porque
 * importar el seed lo ejecutaría.
 */

export const CLIENTES_TAR = ['DT Cliente Norte', 'DT Cliente Sur'] as const;
export const LISTA_TIPOS = 'tipos_pedidos_trabajo';
export const TIPOS_TAR = ['DT Mantenimiento', 'DT Montaje'] as const;

/**
 * Proceso de Bonita de la tarea planificada, para el selector "Proceso Asociado" del alta de tarea
 * estándar. La pantalla Lista de Valores lo guarda como lista propia de la empresa de test (no lo
 * ven otras empresas). Hoy el selector lee solo la lista general, así que no lo ofrece (H-093): el
 * dato queda listo para cuando se corrija.
 */
export const LISTA_PROCESOS = 'procesos';
export const PROCESO_TAREAS = { valor: 'TST001', descripcion: 'Tarea Planificada (TST001)' } as const;
