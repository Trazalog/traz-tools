<?php defined('BASEPATH') OR exit('No direct script access allowed');

if (!function_exists('info_orden')) {
    function info_orden($id_OT=null){
        $ci =& get_instance();			
            //load databse library
            $ci->load->database();		
        if($id_OT){
            $resultOT = null;       
            $ci->db->select('tareas.descripcion AS tareaDescrip,
                                            orden_trabajo.descripcion AS otDescrip,
                                            orden_trabajo.fecha,
                                            orden_trabajo.id_orden,
                                            orden_trabajo.duracion,
                                            orden_trabajo.estado');	
            $ci->db->from('orden_trabajo');		
            $ci->db->join('sim_test.tareas', 'tareas.id_tarea = orden_trabajo.id_tarea','left');			
            $ci->db->where('orden_trabajo.id_orden', $id_OT);
            $queryOT = $ci->db->get();			
            if($queryOT->num_rows() > 0){
                    $resultOT = $queryOT->row_array();
            }
            if(!$resultOT) return;
            return '
                        <div class="col-xs-12 col-sm-4">
                            <div class="form-group">
                                    <label style="margin-top: 7px;">Nº Orden Trabajo: </label>
                                    <input type="text" id="ot" class="form-control" value="'.$resultOT['id_orden'].'" disabled/>
                            </div>						
                        </div>                            
                        <div class="col-xs-12 col-sm-4">
                            <div class="form-group">
                                    <label style="margin-top: 7px;">Descripción: </label>
                                    <input type="text"  class="form-control" value="'.$resultOT['otDescrip'].'" disabled/>
                            </div>						
                        </div>
                        <div class="col-xs-12 col-sm-4">
                            <div class="form-group">
                                    <label style="margin-top: 7px;">Fecha: </label>
                                    <input type="text" id="codigo" class="form-control" value="'.$resultOT['fecha'].'" disabled/>
                            </div>
                        </div>
                        <div class="col-xs-12 col-sm-4">
                            <label style="margin-top: 7px;">Duración: </label>
                            <input type="text" id="duracion" class="form-control"  value="'.$resultOT['duracion'].'" disabled/>
                        </div>                        
                        <div class="col-xs-12 col-sm-4">
                            <label style="margin-top: 7px;">Tarea: </label>
                            <input type="text" class="form-control"  value="'.$resultOT['tareaDescrip'].'" disabled/>
                        </div>                        
                        <div class="col-xs-12 col-sm-4">
                            <label style="margin-top: 7px;">Estado: </label>
                            <input type="text" class="form-control"  value="'.$resultOT['estado'].'" disabled/>
                        </div>';
        }	
    }
}