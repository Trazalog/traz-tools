/**
 * Datos base de TAR que crea `preparar-datos-tar.ts` y que usan los specs. Viven aparte porque
 * importar el seed lo ejecutaría.
 */

export const CLIENTES_TAR = ['DT Cliente Norte', 'DT Cliente Sur'] as const;
export const LISTA_TIPOS = 'tipos_pedidos_trabajo';
export const TIPOS_TAR = ['DT Mantenimiento', 'DT Montaje'] as const;
