<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Chat del Agente Minero dentro de Trazalog Tools.
 *
 * El navegador NUNCA habla directo con el orquestador: todo pasa por este
 * controller, que le agrega el Bearer del usuario. Asi el JWT no queda expuesto
 * al JavaScript, y el orquestador puede seguir sin estar publicado.
 *
 * Identidad — por que hay un flujo OAuth aca:
 *
 *   El orquestador necesita el JWT del usuario con el claim empr_id (ADR-009):
 *   es el token que reenvia al MCP Gateway para consultar los datos del
 *   cliente. Tools no tenia ese token — se autentica contra WSO2 con
 *   TOKEN_API_MANAGER, que es de APLICACION, y pasa el empr_id a mano en cada
 *   URL. Como Dnato ya expone OAuth 2.1 y comparte la sesion PHP con Tools, el
 *   usuario obtiene su JWT sin que le pidan nada: el authorize reconoce la
 *   sesion y vuelve con el code de una.
 *
 * @autor Claude Code (E3 del Agente Minero)
 */
class Agente extends CI_Controller
{
    /** Margen antes de que venza el token, para no usar uno a punto de expirar. */
    const MARGEN_VENCIMIENTO = 60;

    public function __construct()
    {
        parent::__construct();
        $this->load->model(AGE . 'Agentes');
        $this->load->helper('sesion');

        $data = $this->session->userdata();
        if (empty($data['email'])) {
            log_message('DEBUG', '#TRAZA | AGENTE | Agente | __construct() >> Sesion expirada');
            redirect(DNATO . 'main/login');
        }
    }

    // ---------------------------------------------------------------- vistas
    public function index()
    {
        log_message('DEBUG', '#TRAZA | AGENTE | Agente | index()');

        if (!$this->_tieneTokenVigente()) {
            redirect(base_url() . AGE . 'agente/conectar');
        }

        $this->load->view('layout/Admin');
        $this->load->view(AGE . 'chat');
    }

    /**
     * Feedback negativo agrupado, para el ciclo de mejora.
     * Ver doc/agente/feedback.md.
     */
    public function admin()
    {
        log_message('DEBUG', '#TRAZA | AGENTE | Agente | admin()');

        if (!$this->_tieneTokenVigente()) {
            redirect(base_url() . AGE . 'agente/conectar');
        }

        $data['feedback'] = $this->Agentes->feedbackNegativo($this->_token());
        $this->load->view('layout/Admin');
        $this->load->view(AGE . 'feedback_admin', $data);
    }

    // ----------------------------------------------------------- OAuth 2.1
    /**
     * Paso 1: manda al usuario a Dnato a autorizar.
     *
     * PKCE con S256 es obligatorio del lado de Dnato. El verifier queda en la
     * sesion del servidor, nunca viaja al navegador.
     */
    public function conectar()
    {
        $verifier  = $this->_base64url(random_bytes(48));
        $challenge = $this->_base64url(hash('sha256', $verifier, true));
        $state     = $this->_base64url(random_bytes(16));

        $this->session->set_userdata([
            'agente_pkce_verifier' => $verifier,
            'agente_oauth_state'   => $state,
        ]);

        $params = [
            'client_id'             => AGENTE_OAUTH_CLIENT_ID,
            'redirect_uri'          => $this->_redirectUri(),
            'response_type'         => 'code',
            'code_challenge'        => $challenge,
            'code_challenge_method' => 'S256',
            'state'                 => $state,
        ];

        log_message('DEBUG', '#TRAZA | AGENTE | Agente | conectar() >> pidiendo code a Dnato');
        redirect(DNATO . 'oauth/authorize?' . http_build_query($params));
    }

    /**
     * Paso 2: vuelve de Dnato con el code y se canjea por el JWT.
     */
    public function callback()
    {
        $code  = $this->input->get('code');
        $state = $this->input->get('state');

        // El state evita que alguien nos haga canjear un code ajeno.
        if (empty($state) || $state !== $this->session->userdata('agente_oauth_state')) {
            log_message('ERROR', '#TRAZA | AGENTE | Agente | callback() >> state invalido');
            $this->_error('No se pudo validar la vuelta del login. Probá de nuevo.');
            return;
        }

        $verifier = $this->session->userdata('agente_pkce_verifier');
        $this->session->unset_userdata(['agente_pkce_verifier', 'agente_oauth_state']);

        if (empty($code) || empty($verifier)) {
            $this->_error('Faltan datos para completar la conexión con el agente.');
            return;
        }

        $rsp = $this->Agentes->canjearCode($code, $verifier, $this->_redirectUri());
        if (!$rsp['ok']) {
            log_message('ERROR', '#TRAZA | AGENTE | Agente | callback() >> ' . $rsp['error']);
            $this->_error('No se pudo obtener la autorización del agente: ' . $rsp['error']);
            return;
        }

        $this->session->set_userdata([
            'agente_jwt'     => $rsp['access_token'],
            'agente_jwt_exp' => time() + (int) $rsp['expires_in'],
        ]);

        log_message('DEBUG', '#TRAZA | AGENTE | Agente | callback() >> token obtenido');
        redirect(base_url() . AGE . 'agente');
    }

    // -------------------------------------------------------------- API AJAX
    public function consultar()
    {
        $pregunta = trim((string) $this->input->post('pregunta'));
        if ($pregunta === '') {
            $this->_json(['error' => 'La pregunta no puede estar vacía'], 400);
            return;
        }

        if (!$this->_tieneTokenVigente()) {
            // El JS lo interpreta y manda a reconectar sin perder lo escrito.
            $this->_json(['error' => 'sesion_vencida'], 401);
            return;
        }

        log_message('DEBUG', '#TRAZA | AGENTE | Agente | consultar() >> ' . substr($pregunta, 0, 80));
        $this->_json($this->Agentes->consultar($this->_token(), $pregunta));
    }

    public function feedback()
    {
        $interaccion = (string) $this->input->post('interaccion_id');
        $util        = $this->input->post('util');

        if ($interaccion === '' || $util === null) {
            $this->_json(['error' => 'Faltan datos del feedback'], 400);
            return;
        }
        if (!$this->_tieneTokenVigente()) {
            $this->_json(['error' => 'sesion_vencida'], 401);
            return;
        }

        $rsp = $this->Agentes->feedback(
            $this->_token(),
            $interaccion,
            filter_var($util, FILTER_VALIDATE_BOOLEAN),
            $this->input->post('comentario'),
            $this->input->post('motivo')
        );
        $this->_json($rsp);
    }

    /** Estado del orquestador, para diagnosticar desde la UI. */
    public function salud()
    {
        $this->_json($this->Agentes->salud());
    }

    // ------------------------------------------------------------- internos
    private function _token()
    {
        return (string) $this->session->userdata('agente_jwt');
    }

    private function _tieneTokenVigente()
    {
        $exp = (int) $this->session->userdata('agente_jwt_exp');
        return $this->_token() !== '' && $exp > (time() + self::MARGEN_VENCIMIENTO);
    }

    private function _redirectUri()
    {
        return base_url() . AGE . 'agente/callback';
    }

    private function _base64url($bytes)
    {
        return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
    }

    private function _json($data, $code = 200)
    {
        $this->output
            ->set_status_header($code)
            ->set_content_type('application/json')
            ->set_output(json_encode($data, JSON_UNESCAPED_UNICODE));
    }

    private function _error($mensaje)
    {
        $this->load->view('layout/Admin');
        $this->load->view(AGE . 'error', ['mensaje' => $mensaje]);
    }
}
