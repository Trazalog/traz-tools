<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Metas (objetivos) sobre los KPIs de la empresa (KPI-OBJ, ADR-A9).
 *
 * Las graba el administrador desde el Tablero; Kuntur solo las propone y las lee
 * por MCP (ADR-A8). Empresa y usuario salen SIEMPRE de la sesión.
 * DataService: ToolsKPIDataService (REST_KPI), v2.8.1.6/kpi_objetivos.sql.
 */
class Objetivos_model extends CI_Model
{
    public function __construct()
    {
        parent::__construct();
        $this->load->helper('sesion_helper');
    }

    /** Metas de la empresa, con el valor actual y si se cumple. $todas suma canceladas y vencidas. */
    public function lista($todas = false)
    {
        $rsp = $this->_llamar('GET', '/objetivos/emprid/' . rawurlencode(empresa()) . '?todos=' . ($todas ? 'true' : 'false'));
        if (!isset($rsp['json']->objetivos->objetivo)) {
            return array();
        }
        $lista = $rsp['json']->objetivos->objetivo;
        $lista = is_array($lista) ? $lista : array($lista);
        $metas = array();
        foreach ($lista as $o) {
            $metas[] = array(
                'objetivo_id'   => (string) $o->objetivo_id,
                'kpi'           => (string) $o->kpi,
                'descripcion'   => (string) $o->descripcion,
                'fuente'        => (string) $o->fuente,
                'operador'      => (string) $o->operador,
                'meta'          => (string) $o->meta,
                'desde'         => (string) $o->desde,
                'hasta'         => (string) $o->hasta,
                'responsable'   => (string) $o->responsable,
                'estado'        => (string) $o->estado,
                'propuesto_por' => (string) $o->propuesto_por,
                'usuario_alta'  => (string) $o->usuario_alta,
                'valor_actual'  => $o->valor_actual === null ? null : (string) $o->valor_actual,
                'cumple'        => $o->cumple === null ? null : ((string) $o->cumple === 'true'),
            );
        }
        return $metas;
    }

    /**
     * Graba una meta confirmada por el usuario de la sesión.
     * @return array ['ok' => bool, 'objetivo_id' => ..., 'error' => texto para mostrar]
     */
    public function guardar($m)
    {
        $rsp = $this->_llamar('POST', '/objetivo', array('_post_objetivo' => array(
            'empr_id'       => empresa(),
            'kpi'           => $m['kpi'],
            'fuente'        => $m['fuente'],
            'operador'      => $m['operador'],
            'meta'          => $m['meta'],
            'desde'         => '',
            'hasta'         => $m['hasta'],
            'responsable'   => $m['responsable'],
            'propuesto_por' => $m['propuesto_por'],
            'usuario'       => userNick(),
        )));
        if (isset($rsp['json']->respuesta->objetivo_id)) {
            return array('ok' => true, 'objetivo_id' => (string) $rsp['json']->respuesta->objetivo_id);
        }
        return array('ok' => false, 'error' => $this->_motivo($rsp['texto']));
    }

    /** Cancela una meta de la empresa. Devuelve cuántas canceló (0 o 1). */
    public function cancelar($objetivo_id)
    {
        $rsp = $this->_llamar('PUT', '/objetivo/cancelar', array('_put_objetivo_cancelar' => array(
            'empr_id'     => empresa(),
            'objetivo_id' => (string) $objetivo_id,
            'usuario'     => userNick(),
        )));
        return isset($rsp['json']->respuesta->cancelados) ? (int) $rsp['json']->respuesta->cancelados : 0;
    }

    /**
     * Las validaciones de la base (KPI inexistente, ya hay una vigente) llegan como
     * fault del DataService: se rescata el mensaje para mostrárselo al usuario.
     */
    private function _motivo($texto)
    {
        if (preg_match('/ERROR:\s*([^\n\\\\]+)/', (string) $texto, $m)) {
            return trim($m[1]);
        }
        return 'No se pudo guardar la meta. Probá de nuevo en un momento.';
    }

    private function _llamar($metodo, $ruta, $cuerpo = null)
    {
        try {
            $rsp = $cuerpo === null
                ? $this->rest->callAPI($metodo, REST_KPI . $ruta)
                : $this->rest->callAPI($metodo, REST_KPI . $ruta, $cuerpo);
            $texto = isset($rsp['data']) ? (string) $rsp['data'] : '';
            return array('json' => json_decode($texto), 'texto' => $texto);
        } catch (Exception $e) {
            log_message('ERROR', '#TRAZA | CORE | Objetivos_model | _llamar() >> ' . $e->getMessage());
            return array('json' => null, 'texto' => $e->getMessage());
        }
    }
}
