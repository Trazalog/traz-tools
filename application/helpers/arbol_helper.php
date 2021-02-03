<?php defined('BASEPATH') OR exit('No direct script access allowed');

if(!function_exists('nodo'))
{ 
    function nodo($e, $childrens =  false){
        $hijos = array();
        foreach ($childrens as $key => $o) {
            $hijos[] = nodo($o, $o->hijos);
        }
        $data = array(
            'head' => $e->lote_id,
            'id' => $e->batch_id,
            'contents' => infoNodo($e)
        );
        if($hijos) $data['children'] = $hijos;
        return $data;
    }

    function infoNodo($e){
        return 
        "
        <p><b>Estado:</b> $e->lote_estado</p>
        <p><b>Alta: </b>$e->lote_fec_alta</p>
        <p><b>Etapa: </b>$e->etap_nombre</p>
        <p><b>Recipiente: </b>$e->reci_nombre</p>
        <p><b>Tipo: </b>$e->reci_tipo</p>
        <p><b>Batch: </b>$e->batch_id</p>
        ";
    }
}