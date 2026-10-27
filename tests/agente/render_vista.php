<?php
// Arnes de test: renderiza una vista del modulo de agentes sin CodeIgniter y
// saca sus <script> a archivos. Uso: php render_vista.php <raiz> <vista> <prefijo-salida>
define('BASEPATH', 1); define('AGE', 'traz-comp-agente/');
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
$dir = $argv[1] . '/application/modules/traz-comp-agente/views';
$html = (new Pagina($dir))->render($argv[2]);
preg_match_all('#<script>(.*?)</script>#s', $html, $m);
foreach ($m[1] as $i => $js) { file_put_contents($argv[3] . $i . '.js', $js); }
echo count($m[1]);
