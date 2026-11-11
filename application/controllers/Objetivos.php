<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Metas sobre los KPIs de la empresa (KPI-OBJ, ADR-A9). Las ve y las carga solo el
 * administrador de la empresa, desde el Tablero (dashboard/admin_dashboard ->
 * dashboard/objetivos). Kuntur las propone y las lee por MCP; no las graba (ADR-A8).
 *
 * Todo responde JSON. Lo usa lib/props/objetivos.js.
 */
class Objetivos extends CI_Controller
{
    public function __construct()
    {
        parent::__construct();
        $this->load->helper('sesion_helper');
        $this->load->model('Dashs');
        $this->load->model('Objetivos_model');

        // Como el resto de Tools: 40 minutos sin uso cierran la sesión.
        validarInactividad();

        if (!$this->session->userdata('empr_id') || !$this->session->userdata('usernick')) {
            $this->_json(array('error' => 'sesion_expirada'), 401);
            $this->output->_display();
            exit;
        }
        if (!$this->_esAdmin()) {
            log_message('DEBUG', '#TRAZA | CORE | Objetivos | __construct() >> no es administrador: ' . userNick());
            $this->_json(array('error' => 'solo_administrador'), 403);
            $this->output->_display();
            exit;
        }
    }

    /** GET Objetivos/lista[?todas=1] — {metas:[...], kpis:[...]} */
    public function lista()
    {
        $this->_json(array(
            'metas' => $this->Objetivos_model->lista($this->input->get('todas') === '1'),
            'kpis'  => array_values($this->_kpis()),
        ));
    }

    /** POST Objetivos/guardar — kpi, operador, meta, hasta, responsable[, propuesto_por] */
    public function guardar()
    {
        if (strtoupper($this->input->method()) !== 'POST') {
            $this->_json(array('error' => 'pedido_invalido'), 400);
            return;
        }
        $kpis = $this->_kpis();
        $kpi = (string) $this->input->post('kpi');
        $operador = (string) $this->input->post('operador');
        $meta = str_replace(',', '.', trim((string) $this->input->post('meta')));
        $hasta = (string) $this->input->post('hasta');
        $responsable = trim((string) $this->input->post('responsable'));

        $error = '';
        if (!isset($kpis[$kpi])) {
            $error = 'Elegí un indicador de la lista.';
        } elseif ($operador !== '>=' && $operador !== '<=') {
            $error = 'Elegí si el indicador tiene que quedar por encima o por debajo de la meta.';
        } elseif (!is_numeric($meta)) {
            $error = 'La meta tiene que ser un número.';
        } elseif (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $hasta) || $hasta < date('Y-m-d')) {
            $error = 'La fecha límite tiene que ser hoy o más adelante.';
        } elseif (strlen($responsable) > 255) {
            $error = 'El responsable es demasiado largo.';
        }
        if ($error !== '') {
            $this->_json(array('ok' => false, 'error' => $error), 400);
            return;
        }

        log_message('DEBUG', '#TRAZA | CORE | Objetivos | guardar() >> ' . $kpi . ' ' . $operador . ' ' . $meta . ' hasta ' . $hasta);
        $r = $this->Objetivos_model->guardar(array(
            'kpi'           => $kpi,
            'fuente'        => $kpis[$kpi]['fuente'],
            'operador'      => $operador,
            'meta'          => $meta,
            'hasta'         => $hasta,
            'responsable'   => $responsable,
            'propuesto_por' => $this->input->post('propuesto_por') === 'kuntur' ? 'kuntur' : 'usuario',
        ));
        $this->_json($r, $r['ok'] ? 200 : 400);
    }

    /** POST Objetivos/cancelar/{objetivo_id} */
    public function cancelar($objetivo_id = null)
    {
        if (strtoupper($this->input->method()) !== 'POST' || !ctype_digit((string) $objetivo_id)) {
            $this->_json(array('error' => 'pedido_invalido'), 400);
            return;
        }
        $this->_json(array('cancelados' => $this->Objetivos_model->cancelar($objetivo_id)));
    }

    /**
     * Los KPIs sobre los que se puede fijar una meta: los del Tablero
     * (config/dashboard.php). Los de Mantenimiento quedan con fuente 'man': los
     * evalúa el job de Kuntur hasta que Mantenimiento migre al motor de KPIs.
     */
    private function _kpis()
    {
        $this->config->load('dashboard', true);
        $cfg = $this->config->item('dashboard');
        $kpis = array();
        foreach ($cfg['dashboard_kpis'] as $k) {
            $nombre = $k['fuente'] === 'man' ? $k['id'] : $k['kpi_nombre'];
            $kpis[$nombre] = array('nombre' => $nombre, 'titulo' => $k['titulo'], 'fuente' => $k['fuente']);
        }
        return $kpis;
    }

    /** El resultado se guarda en la sesión: no hace falta preguntarlo en cada pedido. */
    private function _esAdmin()
    {
        $clave = 'objetivos_es_admin_' . empresa();
        $guardado = $this->session->userdata($clave);
        if ($guardado !== null) {
            return $guardado === 'si';
        }
        $es = $this->Dashs->esAdminEmpresa();
        $this->session->set_userdata($clave, $es ? 'si' : 'no');
        return $es;
    }

    private function _json($data, $status = 200)
    {
        $this->output
            ->set_status_header($status)
            ->set_content_type('application/json', 'utf-8')
            ->set_output(json_encode($data, JSON_UNESCAPED_UNICODE));
    }
}
