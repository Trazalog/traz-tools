<?php
// Arnés de DocTest: imprime el HTML del panel de los agentes (traz-comp-agente/views/panel.php)
// sin CodeIgniter, para probarlo en el navegador con la API simulada (specs/age/).
// Mismo truco que tests/agente/render_vista.php (raíz del repo), pero devuelve la página entera.
// Uso: php render-panel-agentes.php <raiz-del-repo>
define('BASEPATH', 1);
define('AGE', 'traz-comp-agente/');
function base_url() { return 'http://tools.local/'; }
class Cargador {
    public $dir;
    public function view($v) { include $this->dir . '/' . substr($v, strlen(AGE)) . '.php'; }
}
class Pagina {
    public $load;
    public function __construct($dir) { $this->load = new Cargador; $this->load->dir = $dir; }
    public function render($vista) { ob_start(); include $this->load->dir . '/' . $vista . '.php'; return ob_get_clean(); }
}
$dir = rtrim($argv[1], '/') . '/application/modules/traz-comp-agente/views';
echo (new Pagina($dir))->render('panel');
