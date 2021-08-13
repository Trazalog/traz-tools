<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Valores 
*
* @autor Gerardo Ramos
*/
class Valores extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  function __construct(){
    parent::__construct();
  }

  /**
  * Listado de Valores
  * @param 
  * @return array con listado de valores
  */
  function Listar_Valores(){
    $empr_id = empresa();
    $aux = $this->rest->callAPI("GET",REST_CORE."/tablas/lista/empresa/", $empr_id);
    $aux = json_decode($aux["data"]);
    $valores = $aux->tablas->tabla;
    return $valores;
  }

  /**
  * Obtener contenido de un Valor
  * @param valor de tabla
  * @return array con datos del valor
  */
  function getValor($tabla){
    $post['_post_valor'] = $tabla;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | VALORES | getValor() $post: >> '.json_encode($post));
    $empre_id = empresa();
    $aux = $this->rest->callAPI("GET",REST_CORE."/tabla/".$tabla."/empresa/",$empre_id);
    $aux = json_decode($aux["data"]);
    $valores = $aux->tablas->tabla;
    return $valores;
  }

  /**
  * Genera un valor nuevo
  * @param array con datos del valor
  * @return ID valor generado
  */
  function guardarValor($data){
    $post['_post_valor'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | VALORES | guardarValor()  $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("POST",REST_CORE."/tablas", $post);
    $aux = json_decode($aux["data"]);
    return $aux->GeneratedKeys->Entry;
  }
  
  /**
    * Borrado lógico de valor por ID
    * @param	int $tabl_id
    * @return bool true o false resultado del servicio
    */
    function borrarValor($tabl_id)
    {
      $post['_delete_valor'] = array("tabl_id" => $tabl_id);
      log_message('DEBUG','#TRAZA | TRAZ-TOOLS | VALORES | borrarValor() $post: >> '.json_encode($post));
      $aux = $this->rest->callAPI("DELETE",REST_CORE."/tabla", $post);
      $aux = json_decode($aux["status"]);
      return $aux;
    }

}