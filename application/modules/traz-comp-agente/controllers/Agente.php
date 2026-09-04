<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Chat del Agente Minero dentro de Trazalog Tools.
 *
 * COMO SE INTEGRA (igual que el resto de los modulos)
 *
 *   Este controller devuelve SOLO FRAGMENTOS. Nunca carga 'layout/Admin'.
 *
 *   Dos motivos. El primero es la convencion: en Tools el menu inyecta el
 *   contenido de cada modulo en el #content del layout con linkTo(), que hace
 *   $("#content").load(url). El segundo es que el layout NO FUNCIONA fuera del
 *   Dash: referencia sus CSS con rutas relativas ('lib/bower_components/...'),
 *   asi que servido desde una URL de mas de un segmento el navegador los busca
 *   en el lugar equivocado y la pagina queda sin estilos.
 *
 * IDENTIDAD
 *
 *   El orquestador necesita el JWT del usuario con el claim empr_id (ADR-009):
 *   es el token que reenvia al MCP Gateway. Tools no lo tenia --se autentica
 *   con TOKEN_API_MANAGER, que es de aplicacion-- asi que se obtiene de Dnato
 *   por OAuth 2.1.
 *
 *   Y se obtiene DESDE EL SERVIDOR, no con redirects del navegador: Tools y
 *   Dnato comparten la sesion PHP, asi que el controller puede pedir el code
 *   reenviando la cookie del usuario. Sin eso, conectarse sacaria al usuario
 *   de la SPA cada vez que el token vence.
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
            $this->_json(array('error' => 'sesion_expirada'), 401);
            exit;
        }
    }

    // ------------------------------------------------------------- fragmentos
    /** El chat. Es lo que apunta el menu. */
    public function index()
    {
        log_message('DEBUG', '#TRAZA | AGENTE | Agente | index()');
        $this->load->view(AGE . 'chat');
    }

    /**
     * Feedback negativo agrupado, para el ciclo de mejora.
     * Ver doc/agente/feedback.md.
     */
    public function admin()
    {
        log_message('DEBUG', '#TRAZA | AGENTE | Agente | admin()');

        if (!$this->_asegurarToken()) {
            $this->load->view(AGE . 'error', array(
                'mensaje' => 'No se pudo obtener la autorización para hablar con el agente.',
            ));
            return;
        }

        $data['feedback'] = $this->Agentes->feedbackNegativo($this->_token());
        $this->load->view(AGE . 'feedback_admin', $data);
    }

    // --------------------------------------------------------------- API AJAX
    public function consultar()
    {
        $pregunta = trim((string) $this->input->post('pregunta'));
        if ($pregunta === '') {
            $this->_json(array('error' => 'La pregunta no puede estar vacía'), 400);
            return;
        }

        if (!$this->_asegurarToken()) {
            $this->_json(array(
                'error'     => 'sin_autorizacion',
                'respuesta' => 'No se pudo obtener la autorización para hablar con el agente. '
                             . 'Probá recargando la página.',
            ));
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
            $this->_json(array('error' => 'Faltan datos del feedback'), 400);
            return;
        }
        if (!$this->_asegurarToken()) {
            $this->_json(array('error' => 'sin_autorizacion'));
            return;
        }

        $this->_json($this->Agentes->feedback(
            $this->_token(),
            $interaccion,
            filter_var($util, FILTER_VALIDATE_BOOLEAN),
            $this->input->post('comentario'),
            $this->input->post('motivo')
        ));
    }

    // ---------------------------------------------------------- entrevistador
    /** La pantalla de captura de conocimiento. Fragmento, como todo el modulo. */
    public function entrevista()
    {
        log_message('DEBUG', '#TRAZA | AGENTE | Agente | entrevista()');
        $this->load->view(AGE . 'entrevista');
    }

    /** Temas de la agenda, ordenados por lo que mas falta. */
    public function agenda()
    {
        if (!$this->_asegurarToken()) {
            $this->_json(array('error' => 'sin_autorizacion', 'temas' => array()));
            return;
        }
        $this->_json($this->Agentes->agenda($this->_token()));
    }

    public function expertos()
    {
        if (!$this->_asegurarToken()) {
            $this->_json(array('error' => 'sin_autorizacion', 'expertos' => array()));
            return;
        }
        $this->_json($this->Agentes->expertos($this->_token()));
    }

    public function entrevista_iniciar()
    {
        $this->_proxyEntrevista('/entrevista/iniciar', array(
            'experto_id' => (int) $this->input->post('experto_id'),
            'tema_id'    => (int) $this->input->post('tema_id'),
        ));
    }

    public function entrevista_responder()
    {
        $this->_proxyEntrevista('/entrevista/responder', array(
            'sesion_id' => (string) $this->input->post('sesion_id'),
            'respuesta' => (string) $this->input->post('respuesta'),
        ));
    }

    public function entrevista_estructurar()
    {
        $sesion = urlencode((string) $this->input->post('sesion_id'));
        $this->_proxyEntrevista('/entrevista/estructurar?sesion_id=' . $sesion, null);
    }

    public function entrevista_validar()
    {
        $contenido = (string) $this->input->post('contenido');
        $cuerpo = array(
            'hecho_id' => (int) $this->input->post('hecho_id'),
            'aprobado' => filter_var($this->input->post('aprobado'), FILTER_VALIDATE_BOOLEAN),
        );
        if ($contenido !== '') {
            $cuerpo['contenido'] = $contenido;
        }
        $this->_proxyEntrevista('/entrevista/validar', $cuerpo);
    }

    public function entrevista_cerrar()
    {
        $sesion = urlencode((string) $this->input->post('sesion_id'));
        $this->_proxyEntrevista('/entrevista/cerrar?sesion_id=' . $sesion, null);
    }

    /** Estado del orquestador, para diagnosticar desde la UI. */
    public function salud()
    {
        $this->_json($this->Agentes->salud());
    }

    // -------------------------------------------------------------- identidad
    /**
     * Deja un JWT vigente en la sesion. Devuelve false si no se pudo.
     *
     * Hace el flujo OAuth completo contra Dnato desde el servidor, reenviando
     * la cookie de sesion del usuario. Como Tools y Dnato comparten esa sesion,
     * Dnato lo reconoce y devuelve el code sin pedir credenciales.
     */
    private function _asegurarToken()
    {
        if ($this->_tieneTokenVigente()) {
            return true;
        }

        $verifier  = $this->_base64url(random_bytes(48));
        $challenge = $this->_base64url(hash('sha256', $verifier, true));

        // La sesion de CI usa archivos y queda bloqueada mientras dura el
        // request. Si no la cerramos, Dnato se queda esperando el mismo archivo
        // y el curl expira: hay que cerrarla antes y reabrirla despues.
        session_write_close();

        $rsp = $this->Agentes->obtenerToken($challenge, $verifier, $this->_cookieSesion());

        session_start();

        if (!$rsp['ok']) {
            log_message('ERROR', '#TRAZA | AGENTE | Agente | _asegurarToken() >> ' . $rsp['error']);
            return false;
        }

        $this->session->set_userdata(array(
            'agente_jwt'     => $rsp['access_token'],
            'agente_jwt_exp' => time() + (int) $rsp['expires_in'],
        ));
        log_message('DEBUG', '#TRAZA | AGENTE | Agente | _asegurarToken() >> token obtenido');
        return true;
    }

    /** Proxy generico a los endpoints del entrevistador. */
    private function _proxyEntrevista($ruta, $cuerpo)
    {
        if (!$this->_asegurarToken()) {
            $this->_json(array('error' => 'No se pudo obtener la autorización'));
            return;
        }
        $this->_json($this->Agentes->entrevista($this->_token(), $ruta, $cuerpo));
    }

    /** La cookie de sesion del usuario, para reenviarsela a Dnato. */
    private function _cookieSesion()
    {
        $nombre = $this->config->item('sess_cookie_name') ? $this->config->item('sess_cookie_name') : 'ci_session';
        return isset($_COOKIE[$nombre]) ? $nombre . '=' . $_COOKIE[$nombre] : '';
    }

    private function _token()
    {
        return (string) $this->session->userdata('agente_jwt');
    }

    private function _tieneTokenVigente()
    {
        $exp = (int) $this->session->userdata('agente_jwt_exp');
        return $this->_token() !== '' && $exp > (time() + self::MARGEN_VENCIMIENTO);
    }

    // --------------------------------------------------------------- internos
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
}
