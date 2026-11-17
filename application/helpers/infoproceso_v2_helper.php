<?php defined('BASEPATH') OR exit('No direct script access allowed');

if (!function_exists('infoproceso_v2')) {

    function infoproceso_v2($tarea)
    {
        $ci =& get_instance();

        if ($tarea->processId != BPM_PROCESS_ID_REPARACION_NEUMATICOS) {
            ob_start();
            infoproceso($tarea);
            return ob_get_clean();
        }

        $case_id = $tarea->caseId;
        $processId = $tarea->processId;

        $aux = $ci->rest->callAPICached("GET", REST_PRO."/pedidoTrabajo/xcaseid/".$case_id);
        $data_generico = json_decode($aux["data"]);
        $aux = $data_generico->pedidoTrabajo;

        if (property_exists($aux, 'nombre_cliente') && property_exists($aux, 'dir_entrega')
            && $aux->nombre_cliente !== null && $aux->nombre_cliente !== '') {
            log_message('DEBUG', '#TRAZA | #INFOPROCESO_V2 | cliente desde pedido >> ' . $case_id);
            $aux_clie = (object) array(
                'cliente' => (object) array(
                    'nombre' => $aux->nombre_cliente,
                    'dir_entrega' => $aux->dir_entrega
                )
            );
        } else {
            log_message('DEBUG', '#TRAZA | #INFOPROCESO_V2 | fallback /cliente >> ' . $case_id);
            $clie_id = $aux->clie_id;
            $aux_clie = $ci->rest->callAPICached("GET", REST_CORE."/cliente/".$clie_id);
            $aux_clie = json_decode($aux_clie["data"]);
        }

        $nombreProceso = 'Reparación de Neumáticos';

        return $ci->load->view(
            BPM . 'cabeceras/reparacion_v2',
            array(
                'aux' => $aux,
                'aux_clie' => $aux_clie,
                'nombreProceso' => $nombreProceso,
                'processId' => $processId
            ),
            true
        );
    }
}
