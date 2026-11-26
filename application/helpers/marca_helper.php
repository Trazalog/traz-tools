<?php
defined('BASEPATH') OR exit('No direct script access allowed');

/**
 * Marca por dominio (REQ-019, ADR-015).
 *
 * Decide qué marca se muestra según el dominio por el que entró el usuario
 * (HTTP_HOST), contra la lista cerrada de application/config/marcas.php.
 *
 * - Dominio que no está en la lista, o ejecución por consola: marca por defecto
 *   ("trazalog"). Con la marca por defecto TODAS las funciones devuelven el valor
 *   de respaldo que les pasa quien llama, es decir, lo que el sistema hace hoy.
 * - Nunca se usa el dominio crudo del pedido para armar nada si no está en la lista.
 *
 * No depende de CodeIgniter: se puede incluir desde constants.php (que se carga
 * antes que el framework) y se vuelve a cargar como helper sin problema.
 *
 * Este archivo es IGUAL en traz-tools y en traz-comp-dnato. Si se cambia en uno,
 * se cambia en el otro en el mismo pedido de cambio.
 *
 * Sintaxis PHP 5.6.
 */

if (!defined('MARCA_DEFECTO')) {
    define('MARCA_DEFECTO', 'trazalog');
}

if (!function_exists('marca_definiciones')) {
    /**
     * Lista de marcas leída de application/config/marcas.php (una sola vez).
     *
     * @return array
     */
    function marca_definiciones()
    {
        static $marcas = null;
        if ($marcas !== null) {
            return $marcas;
        }
        $marcas = array();
        $archivo = APPPATH . 'config/marcas.php';
        if (is_file($archivo)) {
            $config = array();
            include $archivo;
            if (isset($config['marcas']) && is_array($config['marcas'])) {
                $marcas = $config['marcas'];
            }
        }
        return $marcas;
    }
}

if (!function_exists('marca_host_pedido')) {
    /**
     * Dominio del pedido en minúsculas y sin puerto. Vacío si es consola.
     *
     * @return string
     */
    function marca_host_pedido()
    {
        if (empty($_SERVER['HTTP_HOST'])) {
            return '';
        }
        $host = strtolower(trim($_SERVER['HTTP_HOST']));
        $pos = strpos($host, ':');
        if ($pos !== false) {
            $host = substr($host, 0, $pos);
        }
        return $host;
    }
}

if (!function_exists('marca_id')) {
    /**
     * Identificador de la marca del pedido actual.
     *
     * @return string
     */
    function marca_id()
    {
        static $id = null;
        if ($id !== null) {
            return $id;
        }
        $id = MARCA_DEFECTO;
        $host = marca_host_pedido();
        if ($host === '') {
            return $id;
        }
        foreach (marca_definiciones() as $clave => $marca) {
            if (!empty($marca['hosts']) && in_array($host, $marca['hosts'], true)) {
                $id = $clave;
                break;
            }
        }
        return $id;
    }
}

if (!function_exists('marca_es_defecto')) {
    /**
     * @return bool TRUE si se está mostrando la marca de siempre (Trazalog).
     */
    function marca_es_defecto()
    {
        return marca_id() === MARCA_DEFECTO;
    }
}

if (!function_exists('marca')) {
    /**
     * Valor de la marca actual para una clave.
     *
     * Con la marca por defecto, o si la marca no define esa clave, devuelve
     * $defecto: así cada pantalla conserva su valor de hoy como respaldo.
     *
     * @param string $clave
     * @param mixed  $defecto
     * @return mixed
     */
    function marca($clave, $defecto = '')
    {
        if (marca_es_defecto()) {
            return $defecto;
        }
        $marcas = marca_definiciones();
        $actual = $marcas[marca_id()];
        return array_key_exists($clave, $actual) ? $actual[$clave] : $defecto;
    }
}

if (!function_exists('marca_constante')) {
    /**
     * Valor de una constante de imagen (REGISTER_IMG_*, LOGIN_IMG_*), reemplazado
     * por la marca si ésta lo define en su lista 'constantes'.
     *
     * @param string $nombre   nombre de la constante
     * @param string $respaldo valor si la constante no está definida
     * @return string
     */
    function marca_constante($nombre, $respaldo = '')
    {
        $valor = defined($nombre) ? constant($nombre) : $respaldo;
        $propias = marca('constantes', array());
        return isset($propias[$nombre]) ? $propias[$nombre] : $valor;
    }
}

if (!function_exists('marca_esquema_pedido')) {
    /**
     * "https" o "http" según cómo llegó el pedido, contemplando proxies.
     * Misma regla que usa traz-comp-dnato para armar su base_url.
     *
     * @return string
     */
    function marca_esquema_pedido()
    {
        if (!empty($_SERVER['HTTPS']) && strtolower($_SERVER['HTTPS']) !== 'off') {
            return 'https';
        }
        if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO'])) {
            $partes = explode(',', $_SERVER['HTTP_X_FORWARDED_PROTO']);
            return (strtolower(trim($partes[0])) === 'https') ? 'https' : 'http';
        }
        if (!empty($_SERVER['HTTP_X_FORWARDED_SSL']) && strtolower($_SERVER['HTTP_X_FORWARDED_SSL']) === 'on') {
            return 'https';
        }
        if (!empty($_SERVER['SERVER_PORT']) && (int) $_SERVER['SERVER_PORT'] === 443) {
            return 'https';
        }
        return 'http';
    }
}

if (!function_exists('marca_url_host')) {
    /**
     * Pasa una dirección absoluta fija (DNATO, DE, DS) al dominio por el que
     * entró el usuario, SOLO si ese dominio es de una marca distinta de la de
     * siempre. Con el dominio de Trazalog devuelve la dirección intacta.
     *
     * Ejemplo: entrando por app.pirkai.net,
     *   http://www.cloudtrazalog.com/traz-comp-dnato/main/login
     *   → https://app.pirkai.net/traz-comp-dnato/main/login
     *
     * @param string $url
     * @return string
     */
    function marca_url_host($url)
    {
        if (marca_es_defecto()) {
            return $url;
        }
        $partes = parse_url($url);
        if ($partes === false || empty($partes['host'])) {
            return $url;
        }
        // Mismo dominio y puerto por el que entró el usuario (sin :80 / :443).
        $host = strtolower(trim($_SERVER['HTTP_HOST']));
        $host = preg_replace('/:(80|443)$/', '', $host);
        $resto = isset($partes['path']) ? $partes['path'] : '/';
        if (isset($partes['query'])) {
            $resto .= '?' . $partes['query'];
        }
        if (isset($partes['fragment'])) {
            $resto .= '#' . $partes['fragment'];
        }
        return marca_esquema_pedido() . '://' . $host . $resto;
    }
}

if (!function_exists('marca_atributo_body')) {
    /**
     * Atributo para <body>: vacío con la marca por defecto (el HTML queda igual
     * que hoy), ' data-marca="<id>"' con cualquier otra.
     *
     * @return string
     */
    function marca_atributo_body()
    {
        if (marca_es_defecto()) {
            return '';
        }
        return ' data-marca="' . htmlspecialchars(marca_id(), ENT_QUOTES, 'UTF-8') . '"';
    }
}

if (!function_exists('marca_head')) {
    /**
     * Etiquetas extra para el <head>: ícono de pestaña y hoja de estilos de la
     * marca. Vacío con la marca por defecto.
     *
     * @param string $base prefijo de las rutas (base_url() de la aplicación)
     * @return string
     */
    function marca_head($base = '')
    {
        if (marca_es_defecto()) {
            return '';
        }
        $html = '';
        $favicon = marca('favicon', '');
        if ($favicon !== '') {
            $html .= '<link rel="icon" href="' . htmlspecialchars($base . $favicon, ENT_QUOTES, 'UTF-8') . '">' . "\n";
        }
        $css = marca('css', '');
        if ($css !== '') {
            $html .= '<link rel="stylesheet" href="' . htmlspecialchars($base . $css, ENT_QUOTES, 'UTF-8') . '">' . "\n";
        }
        return $html;
    }
}
