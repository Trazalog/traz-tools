<?php defined('BASEPATH') or exit('No direct script access allowed');
/**
* Modelo de Notificaciones 
*
* @autor Rogelio Sanchez
*/
class Notificaciones extends CI_Model {

    public function __construct()
    {
        parent::__construct();
        log_message('DEBUG','#TRAZA | #TRAZ-COMP-NOTIFICACIONES | Notificaciones | cargado exitósamente');
    }
}