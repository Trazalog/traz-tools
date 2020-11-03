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
    $aux = $this->rest->callAPI("GET",REST_CORE."/menuitems/porEmail/$email/porGrupo/$grupo");
    $aux =json_decode($aux["data"]);
    return $aux;
  }

  /**
  * Obtiene las memberships por id de user en BPM
  * @param 
  * @return
  */  //FIXME: ACA TRAERE LAS MEMBRESIAS Y DEVOLVER PARA MOSTRAR EN PERFIL
  function obtenerMemberships()
  {
    $userIdBpm = userIdBpm();
    $aux = $this->rest->callAPI("GET",REST_BPM."/memberships/xUserid/".$userIdBpm."/session/dd");
    $aux =json_decode($aux["data"]);

    $data = $this->armarMembership($aux->payload);

    return $data;
  }
  /**
  * Devuelve array con memberships y empr_id
  * @param array devuelto con info de BPM
  * @return array ordenado con membrerhips
  */
  function armarMembership($data){

    $roleBPM = "";
    $groupBPM = "";

    foreach ($data as $value) {

      $roleBPM = $value->role_id->name;
      $groupBPM = $value->group_id->displayName;

      $nom = explode("-", $value->group_id->name);
      $empr_id = $nom[0];
      $key = $empr_id;
      $opciones[$key] = $groupBPM . " - " . $roleBPM;
    }

    return $opciones;

  }

}