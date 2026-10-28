<?php defined('BASEPATH') or exit('No direct script access allowed');

// NTFDataService (ADR-015). Va acá y no en constants.php porque ese archivo es
// core: cuando se apruebe, la constante se mueve allá y este define queda inerte.
defined('REST_NTF') or define('REST_NTF', HOST . '/services/NTFDataService');

/**
 * Avisos de Tools: la campanita y los dispositivos del usuario (ADR-015).
 *
 * Empresa y usuario salen SIEMPRE de la sesión, nunca del navegador: el
 * DataService confía en lo que le pasa el servidor, y las funciones de ntf
 * solo dejan ver y marcar lo del usuario en su empresa.
 */
class Avisos_model extends CI_Model
{
    public function __construct()
    {
        parent::__construct();
        $this->load->helper('sesion_helper');
    }

    /** Los avisos del usuario, los no leídos primero (máx. 30). */
    public function mios()
    {
        $rsp = $this->_get('/avisos/emprid/' . rawurlencode(empresa()) . '/nick/' . rawurlencode(userNick()));
        if (!isset($rsp->avisos->aviso)) {
            return array();
        }
        $lista = is_array($rsp->avisos->aviso) ? $rsp->avisos->aviso : array($rsp->avisos->aviso);
        $avisos = array();
        foreach ($lista as $a) {
            $avisos[] = array(
                'aviso_id'  => (string) $a->aviso_id,
                'tipo'      => (string) $a->tipo,
                'titulo'    => (string) $a->titulo,
                'cuerpo'    => (string) $a->cuerpo,
                'severidad' => (string) $a->severidad,
                'enlace'    => (string) $a->enlace,
                'emisor'    => (string) $a->emisor,
                'leido'     => ((string) $a->leido) === 'true',
                'fec_alta'  => (string) $a->fec_alta,
            );
        }
        return $avisos;
    }

    /** El número de la campanita. */
    public function noLeidos()
    {
        $rsp = $this->_get('/avisos/noleidos/emprid/' . rawurlencode(empresa()) . '/nick/' . rawurlencode(userNick()));
        return isset($rsp->no_leidos->cantidad) ? (int) $rsp->no_leidos->cantidad : 0;
    }

    /** Marca leído un aviso propio, o todos con $aviso_id vacío. Devuelve cuántos cambió. */
    public function marcarLeido($aviso_id = '')
    {
        $rsp = $this->_enviar('PUT', '/aviso/leido', array('_put_aviso_leido' => array(
            'empr_id'  => empresa(),
            'usuario'  => userNick(),
            'aviso_id' => (string) $aviso_id,
        )));
        return isset($rsp->respuesta->marcados) ? (int) $rsp->respuesta->marcados : 0;
    }

    /** Registra el navegador del usuario (token de Firebase). */
    public function registrarDispositivo($token, $plataforma = 'web')
    {
        $rsp = $this->_enviar('POST', '/dispositivo', array('_post_dispositivo' => array(
            'empr_id'    => empresa(),
            'usuario'    => userNick(),
            'token'      => (string) $token,
            'plataforma' => (string) $plataforma,
        )));
        return isset($rsp->respuesta->dispositivo_id);
    }

    /** Da de baja el navegador (al salir). */
    public function bajaDispositivo($token)
    {
        $rsp = $this->_enviar('PUT', '/dispositivo/baja', array('_put_dispositivo_baja' => array(
            'empr_id' => empresa(),
            'usuario' => userNick(),
            'token'   => (string) $token,
        )));
        return isset($rsp->respuesta->bajas) ? (int) $rsp->respuesta->bajas : 0;
    }

    private function _get($ruta)
    {
        try {
            $rsp = $this->rest->callAPI('GET', REST_NTF . $ruta);
            return isset($rsp['data']) ? json_decode($rsp['data']) : null;
        } catch (Exception $e) {
            log_message('ERROR', '#TRAZA | CORE | Avisos_model | _get() >> ' . $e->getMessage());
            return null;
        }
    }

    private function _enviar($metodo, $ruta, $cuerpo)
    {
        try {
            $rsp = $this->rest->callAPI($metodo, REST_NTF . $ruta, $cuerpo);
            return isset($rsp['data']) ? json_decode($rsp['data']) : null;
        } catch (Exception $e) {
            log_message('ERROR', '#TRAZA | CORE | Avisos_model | _enviar() >> ' . $e->getMessage());
            return null;
        }
    }
}
