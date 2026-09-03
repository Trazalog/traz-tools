<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Puente entre Tools y el orquestador del Agente Minero.
 *
 * Todo lo que sale de aca lleva el JWT del usuario en el header Authorization.
 * El orquestador deriva el empr_id de ese token: no se manda por separado, ni
 * se acepta que el cliente lo elija.
 *
 * @autor Claude Code (E3 del Agente Minero)
 */
class Agentes extends CI_Model
{
    /** Una consulta puede tardar: el modelo razona y quizas consulta tools. */
    const TIMEOUT_CONSULTA = 120;

    public function __construct()
    {
        parent::__construct();
        log_message('DEBUG', '#TRAZA | AGENTE | Agentes | cargado');
    }

    /**
     * Hace el flujo OAuth completo contra Dnato, desde el servidor.
     *
     * Reenvia la cookie de sesion del usuario: como Tools y Dnato la comparten,
     * el authorize lo reconoce y devuelve el code sin pedir credenciales, y sin
     * sacar al usuario de la SPA.
     *
     * @param string $challenge   code_challenge S256
     * @param string $verifier    code_verifier que lo genero
     * @param string $cookie      "ci_session=..." del usuario
     * @return array ['ok' => bool, 'access_token' => string, 'expires_in' => int, 'error' => string]
     */
    public function obtenerToken($challenge, $verifier, $cookie)
    {
        if ($cookie === '') {
            return array('ok' => false, 'error' => 'no hay cookie de sesion para reenviar');
        }

        $redirectUri = base_url() . AGE . 'agente';
        $url = rtrim(AGENTE_DNATO_OAUTH, '/') . '/oauth/authorize?' . http_build_query(array(
            'client_id'             => AGENTE_OAUTH_CLIENT_ID,
            'redirect_uri'          => $redirectUri,
            'response_type'         => 'code',
            'code_challenge'        => $challenge,
            'code_challenge_method' => 'S256',
            'state'                 => 'server-side',
        ));

        // No seguimos el redirect: lo que interesa es el 'code' del Location.
        $curl = curl_init($url);
        curl_setopt_array($curl, array(
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_HEADER         => true,
            CURLOPT_TIMEOUT        => 20,
            CURLOPT_COOKIE         => $cookie,
        ));
        $rsp     = curl_exec($curl);
        $status  = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $errCurl = curl_error($curl);
        curl_close($curl);

        if ($rsp === false) {
            return array('ok' => false, 'error' => 'no se pudo contactar a Dnato: ' . $errCurl);
        }
        if ($status < 300 || $status >= 400) {
            // 200 = Dnato devolvio la pantalla de login: no reconocio la sesion.
            return array('ok' => false, 'error' => "authorize respondio $status (¿la sesion no viajo?)");
        }
        if (!preg_match('/^Location:\s*(\S+)/mi', $rsp, $m)) {
            return array('ok' => false, 'error' => 'authorize redirigio sin Location');
        }

        parse_str((string) parse_url(trim($m[1]), PHP_URL_QUERY), $params);
        if (empty($params['code'])) {
            $destino = trim($m[1]);
            return array('ok' => false, 'error' => 'el redirect no trae code: ' . substr($destino, 0, 120));
        }

        return $this->canjearCode($params['code'], $verifier, $redirectUri);
    }

    /**
     * Canjea el authorization code por el JWT del usuario (OAuth 2.1 + PKCE).
     *
     * @return array ['ok' => bool, 'access_token' => string, 'expires_in' => int, 'error' => string]
     */
    public function canjearCode($code, $verifier, $redirectUri)
    {
        $post = http_build_query([
            'grant_type'    => 'authorization_code',
            'code'          => $code,
            'code_verifier' => $verifier,
            'client_id'     => AGENTE_OAUTH_CLIENT_ID,
            'redirect_uri'  => $redirectUri,
        ]);

        // Form-urlencoded, no JSON: es lo que pide el estandar de OAuth y lo
        // que lee el endpoint de Dnato con $this->input->post().
        $curl = curl_init(rtrim(AGENTE_DNATO_OAUTH, '/') . '/oauth/token');
        curl_setopt_array($curl, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $post,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 30,
            CURLOPT_HTTPHEADER     => ['Content-Type: application/x-www-form-urlencoded'],
        ]);
        $body = curl_exec($curl);
        $code_http = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $errCurl = curl_error($curl);
        curl_close($curl);

        if ($body === false) {
            return ['ok' => false, 'error' => 'no se pudo contactar a Dnato: ' . $errCurl];
        }

        $json = json_decode($body, true);
        if ($code_http >= 300 || !isset($json['access_token'])) {
            $detalle = isset($json['error_description']) ? $json['error_description']
                     : (isset($json['error']) ? $json['error'] : substr((string) $body, 0, 200));
            return ['ok' => false, 'error' => "HTTP $code_http — $detalle"];
        }

        return [
            'ok'           => true,
            'access_token' => $json['access_token'],
            'expires_in'   => isset($json['expires_in']) ? (int) $json['expires_in'] : 3600,
        ];
    }

    /**
     * Le hace una consulta al agente.
     *
     * Devuelve el cuerpo del orquestador tal cual, que incluye el
     * interaccion_id necesario para calificar la respuesta despues.
     */
    public function consultar($jwt, $pregunta)
    {
        $rsp = $this->_llamar('POST', '/consulta', [
            'pregunta' => $pregunta,
            'canal'    => 'chat_tools',
        ], $jwt, self::TIMEOUT_CONSULTA);

        if (!$rsp['ok']) {
            log_message('ERROR', '#TRAZA | AGENTE | Agentes | consultar() >> ' . $rsp['error']);
            return [
                'error'     => 'no_disponible',
                'respuesta' => 'El agente no está disponible en este momento. Probá de nuevo en un rato.',
                'detalle'   => $rsp['error'],
            ];
        }
        return $rsp['data'];
    }

    public function feedback($jwt, $interaccionId, $util, $comentario = null, $motivo = null)
    {
        $cuerpo = ['interaccion_id' => $interaccionId, 'util' => (bool) $util];
        if (!empty($comentario)) {
            $cuerpo['comentario'] = $comentario;
        }
        if (!empty($motivo)) {
            $cuerpo['motivo'] = $motivo;
        }

        $rsp = $this->_llamar('POST', '/feedback', $cuerpo, $jwt);
        if (!$rsp['ok']) {
            log_message('ERROR', '#TRAZA | AGENTE | Agentes | feedback() >> ' . $rsp['error']);
            return ['error' => 'No se pudo registrar tu calificación'];
        }
        return $rsp['data'];
    }

    public function feedbackNegativo($jwt)
    {
        $rsp = $this->_llamar('GET', '/admin/feedback', null, $jwt);
        return $rsp['ok'] ? $rsp['data'] : ['resumen' => [], 'detalle' => [], 'error' => $rsp['error']];
    }

    /** Estado del orquestador. No necesita token. */
    public function salud()
    {
        $rsp = $this->_llamar('GET', '/salud', null, null, 10);
        return $rsp['ok'] ? $rsp['data'] : ['estado' => 'inaccesible', 'detalle' => $rsp['error']];
    }

    // ------------------------------------------------------------- internos
    private function _llamar($metodo, $ruta, $cuerpo, $jwt, $timeout = 30)
    {
        $url = rtrim(REST_AGENTE, '/') . $ruta;
        log_message('DEBUG', '#TRAZA | AGENTE | Agentes | ' . $metodo . ' ' . $url);

        $headers = ['Accept: application/json'];
        if (!empty($jwt)) {
            $headers[] = 'Authorization: Bearer ' . $jwt;
        }

        $curl = curl_init($url);
        $opts = [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => $timeout,
            CURLOPT_CUSTOMREQUEST  => $metodo,
        ];
        if ($cuerpo !== null) {
            $opts[CURLOPT_POSTFIELDS] = json_encode($cuerpo, JSON_UNESCAPED_UNICODE);
            $headers[] = 'Content-Type: application/json';
        }
        $opts[CURLOPT_HTTPHEADER] = $headers;
        curl_setopt_array($curl, $opts);

        $body   = curl_exec($curl);
        $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $err    = curl_error($curl);
        curl_close($curl);

        if ($body === false) {
            return ['ok' => false, 'error' => 'no se pudo contactar al orquestador: ' . $err];
        }
        $data = json_decode($body, true);
        if ($status >= 300) {
            $detalle = isset($data['detail']) ? $data['detail'] : substr((string) $body, 0, 200);
            return ['ok' => false, 'error' => "HTTP $status — $detalle", 'data' => $data];
        }
        return ['ok' => true, 'data' => $data];
    }
}
