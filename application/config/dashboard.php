<?php defined('BASEPATH') OR exit('No direct script access allowed');

/**
 * Configuración por defecto del Dashboard / Landing del Administrador (v2.5).
 *
 * IMPORTANTE (supuesto A8, ver doc/analisis/dashboard-administrador-landing.md):
 * en v2.5 esta config es un DEFAULT en código. Todavía NO hay pantalla de administración
 * (refresco/posición/tamaño/colores). La estructura ya contempla esos campos para que una
 * versión futura los tome de core.tablas o de una pantalla, sin tocar la vista.
 *
 * Cada caja se declara con:
 *   id          clave interna
 *   sector      'suscripcion' | 'kpi'
 *   titulo      encabezado visible
 *   orden       posición (asc)
 *   ancho       columnas bootstrap (col-lg-N, N de 1 a 12)
 *   alto        alto del cuerpo en px
 *   refresh_seg refresco del dato (0 = no refresca; sólo aplica a KPIs en Fase 2)
 *   color       color de acento de la caja
 *   kpi_nombre  clave del KPI en la caché (Fase 2)
 *   chart       tipo de gráfico: 'bar' | 'doughnut' | 'line' (Fase 2)
 *   modulo      etiqueta de módulo para el KPI
 */

/* Saludo configurable del sector Suscripción (supuesto A2). */
$config['dashboard_welcome_msg'] = 'Bienvenido a tu panel de control. Acá tenés el pulso de tu operación de un vistazo.';

/* Umbral de suscripción (supuesto A5): alta de empresa >= esta fecha => Freemium; anterior => Full. */
$config['dashboard_freemium_desde'] = '2026-09-01';

/* Módulos habilitados (supuesto A6): fijo en v2.5. */
$config['dashboard_modulos'] = array(
    array('cod' => 'MAN', 'nombre' => 'Mantenimiento', 'color' => '#2b6cb0', 'estado' => 'Operativo'),
    array('cod' => 'ALM', 'nombre' => 'Almacenes',     'color' => '#2f855a', 'estado' => 'Operativo'),
    array('cod' => 'HER', 'nombre' => 'Herramientas',  'color' => '#c05621', 'estado' => 'Operativo'),
);

/* Timeline corto por módulo (supuesto A7): estático en Fase 1, estructura lista para dato real. */
$config['dashboard_actividad'] = array(
    'MAN' => array(array('fecha' => 'hoy', 'texto' => 'Sin órdenes vencidas')),
    'ALM' => array(array('fecha' => 'hoy', 'texto' => 'Movimientos al día')),
    'HER' => array(array('fecha' => 'hoy', 'texto' => 'Sin herramientas demoradas')),
);

/* Cajas de KPI (Sector B). En Fase 1 se muestran como scaffolding; el dato llega en Fase 2. */
// fuente: 'tools' => caché Postgres via ToolsKPIDataService (Dash/kpi). 'man' => caché de
// AssetPlanner via MANKPIDataService (pendiente de wiring — supuesto A10).
$config['dashboard_kpis'] = array(
    array(
        'id' => 'alm_reorder', 'sector' => 'kpi', 'modulo' => 'ALM', 'fuente' => 'tools',
        'titulo' => 'Artículos bajo punto de pedido',
        'orden' => 10, 'ancho' => 6, 'alto' => 260, 'refresh_seg' => 300,
        'color' => '#2f855a', 'kpi_nombre' => 'alm_reorder', 'chart' => 'bar',
    ),
    array(
        'id' => 'alm_mov_sin_entregar', 'sector' => 'kpi', 'modulo' => 'ALM', 'fuente' => 'tools',
        'titulo' => 'Movimientos internos sin entregar',
        'orden' => 20, 'ancho' => 6, 'alto' => 260, 'refresh_seg' => 300,
        'color' => '#2f855a', 'kpi_nombre' => 'alm_mov_sin_entregar', 'chart' => 'doughnut',
    ),
    array(
        'id' => 'her_transito', 'sector' => 'kpi', 'modulo' => 'HER', 'fuente' => 'tools',
        'titulo' => 'Herramientas en tránsito vs total',
        'orden' => 30, 'ancho' => 6, 'alto' => 260, 'refresh_seg' => 600,
        'color' => '#c05621', 'kpi_nombre' => 'her_transito', 'chart' => 'doughnut',
    ),
    array(
        'id' => 'man_disponibilidad', 'sector' => 'kpi', 'modulo' => 'MAN', 'fuente' => 'man',
        'titulo' => 'Disponibilidad de equipos',
        'orden' => 40, 'ancho' => 6, 'alto' => 260, 'refresh_seg' => 600,
        'color' => '#2b6cb0', 'kpi_nombre' => 'man_disponibilidad', 'chart' => 'line',
    ),
);
