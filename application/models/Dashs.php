<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Representa la entidad 
*
* @autor Hugo Gallardo
*/
class Dashs extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  function __construct(){
  parent::__construct();
  }

  /**
  * Devuelve items menu
  * @param
  * @return array items de menu y permisos de distintos tipos de usuarios
  */
  function obtenerMenu(){

    $email = $this->session->userdata('email');
    #$grupo = "grupotest";
    $aux = $this->rest->callAPI("GET",REST_CORE."menuitems/porEmail/$email/porGrupo/$grupo");
    $aux =json_decode($aux["data"]);
    return $aux;
  }

}