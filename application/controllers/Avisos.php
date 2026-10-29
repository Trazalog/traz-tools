<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * La campanita de Tools y el registro del navegador para push (ADR-015).
 * Todo responde JSON. Lo usan lib/props/avisos.js y lib/props/firebase_config.js.
 *
 * NO llama a validarInactividad(): la campanita consulta sola cada minuto y,
 * si renovara el tiempo de sesión, nadie saldría nunca por inactividad. Acá
 * solo se mira si la sesión venció (sin renovarla) y se responde 401.
 */
class Avisos extends CI_Controller
{
    /** Igual que validarInactividad() en sesion_helper (40 min). */
    const INACTIVIDAD_MAX = 4000;

    public function __construct()
    {
        parent::__construct();
        $this->load->helper('sesion_helper');
        $this->load->model('Avisos_model');

        if (!$this->_sesionVigente()) {
            // Desde el constructor CI no llega a mandar la salida: se manda acá.
            $this->_json(array('error' => 'sesion_expirada'), 401);
            $this->output->_display();
            exit;
        }
    }

    /** GET Avisos/mios — {avisos:[...], no_leidos:N} */
    public function mios()
    {
        $avisos = $this->Avisos_model->mios();
        $no_leidos = 0;
        foreach ($avisos as $a) {
            $no_leidos += $a['leido'] ? 0 : 1;
        }
        $this->_json(array('avisos' => $avisos, 'no_leidos' => $no_leidos));
    }

    /** GET Avisos/noLeidos — {no_leidos:N} (lo que consulta cada minuto). */
    public function noLeidos()
    {
        $this->_json(array('no_leidos' => $this->Avisos_model->noLeidos()));
    }

    /** POST Avisos/leido/{aviso_id} */
    public function leido($aviso_id = null)
    {
        if (!$this->_esPost() || !ctype_digit((string) $aviso_id)) {
            $this->_json(array('error' => 'pedido_invalido'), 400);
            return;
        }
        $this->_json(array('marcados' => $this->Avisos_model->marcarLeido($aviso_id)));
    }

    /** POST Avisos/leidos — marca todos los propios. */
    public function leidos()
    {
        if (!$this->_esPost()) {
            $this->_json(array('error' => 'pedido_invalido'), 400);
            return;
        }
        $this->_json(array('marcados' => $this->Avisos_model->marcarLeido('')));
    }

    /** POST Avisos/dispositivo — token=<FCM> */
    public function dispositivo()
    {
        $token = trim((string) $this->input->post('token'));
        if (!$this->_esPost() || strlen($token) < 20 || strlen($token) > 4096) {
            $this->_json(array('error' => 'token_invalido'), 400);
            return;
        }
        log_message('DEBUG', '#TRAZA | CORE | Avisos | dispositivo() >> registra navegador de ' . userNick());
        $this->_json(array('ok' => $this->Avisos_model->registrarDispositivo($token, 'web')));
    }

    /** POST Avisos/bajaDispositivo — token=<FCM> (al salir; llega por sendBeacon). */
    public function bajaDispositivo()
    {
        $token = trim((string) $this->input->post('token'));
        if (!$this->_esPost() || $token === '') {
            $this->_json(array('error' => 'token_invalido'), 400);
            return;
        }
        $this->_json(array('bajas' => $this->Avisos_model->bajaDispositivo($token)));
    }

    private function _sesionVigente()
    {
        if (!$this->session->userdata('empr_id') || !$this->session->userdata('usernick')) {
            return false;
        }
        if (isset($_SESSION['tiempo']) && (time() - $_SESSION['tiempo']) > self::INACTIVIDAD_MAX) {
            return false;
        }
        return true;
    }

    private function _esPost()
    {
        return strtoupper($this->input->method()) === 'POST';
    }

    private function _json($data, $status = 200)
    {
        $this->output
            ->set_status_header($status)
            ->set_content_type('application/json', 'utf-8')
            ->set_output(json_encode($data, JSON_UNESCAPED_UNICODE));
    }
}
