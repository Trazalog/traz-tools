<?php
defined('BASEPATH') OR exit('No direct script access allowed');

/*
|--------------------------------------------------------------------------
| Marcas por dominio (REQ-019, ADR-015)
|--------------------------------------------------------------------------
|
| Lista CERRADA de dominios que muestran una marca distinta de Trazalog.
| Cualquier dominio que no figure acá muestra Trazalog, exactamente como hoy.
|
| La marca por defecto (Trazalog) NO se define acá a propósito: sus valores
| siguen saliendo de donde salen hoy (core.tablas, constantes, vistas).
|
| Para sumar un dominio a una marca: agregarlo a 'hosts' (en minúsculas, sin
| puerto). Para sumar una marca nueva: copiar el bloque 'pirkai'.
| Ver doc/infra/pirkai-06-operacion.md.
|
| Claves (todas optativas; la que falte usa el valor de Trazalog):
|   hosts             dominios que muestran esta marca
|   nombre            nombre corto en textos ("pirkai.net")
|   titulo            <title> de la pestaña del navegador
|   titulo_impresion  título de las impresiones (reemplaza "TRAZALOG TOOLS")
|   skin              clase de AdminLTE para el <body>
|   css               hoja de estilos propia (se carga al final del <head>)
|   js                código propio (títulos de impresión, logos por defecto)
|   favicon           ícono de la pestaña
|   manifest          manifest de la aplicación web
|   logo_navbar       logo de la barra superior
|   estilo_logo_navbar estilo en línea del logo de la barra
|   texto_logo_navbar texto al lado del logo
|   logo_impresos     reemplaza el logo por defecto de remitos y vales
|   url_sitio         link del pie de página
|   razon_social      titular de los derechos en el texto legal
|
| ⚠ Los valores de pirkai son PROVISORIOS (logo de texto y colores elegidos
|   sin definición del dueño del producto). Reemplazar los archivos en
|   lib/marcas/pirkai/ cuando lleguen los definitivos; no hace falta tocar
|   este archivo si se mantienen los nombres.
*/

$config['marcas'] = array(

    'pirkai' => array(
        'hosts' => array(
            'app.pirkai.net',
            'demo.pirkai.net',
            'pirkai.local',
        ),
        'nombre'             => 'pirkai.net',
        'titulo'             => 'PIRKAI.NET',
        'titulo_impresion'   => 'PIRKAI.NET',
        'skin'               => 'skin-blue',
        'css'                => 'lib/marcas/pirkai/marca.css',
        'js'                 => 'lib/marcas/marca.js',
        'favicon'            => 'lib/marcas/pirkai/favicon.svg',
        'manifest'           => 'lib/marcas/pirkai/manifest.json',
        'logo_navbar'        => 'lib/marcas/pirkai/logo.svg',
        'estilo_logo_navbar' => 'height: 34px; width: auto; border-radius: 0;',
        'texto_logo_navbar'  => '',
        'logo_impresos'      => 'lib/marcas/pirkai/logo-impresos.svg',
        'url_sitio'          => 'https://pirkai.net/',
        'razon_social'       => 'pirkai.net',
    ),

);
