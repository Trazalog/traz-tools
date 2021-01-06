<?php 
    echo selectFromCore('unidad_tiempo','Seleccionar', "unidad_medida_tiempo", true);
    echo selectFromFont('a','Seleccionar', REST_CORE.'/users', array('valor'=>'id_user', 'descripcion'=> 'first_name_user'), true);
    echo selectFromFont('a','Seleccionar', REST_PRD.'/establecimientos/'.empresa(), array('valor'=>'esta_id', 'descripcion'=> 'nombre'), true);
?>