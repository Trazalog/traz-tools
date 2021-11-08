<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Transportistas 
*
* @autor Gerardo Ramos
*/
class Transportistas extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  function __construct(){
    parent::__construct();
  }

  /**
  * Genera un transportista nuevo
  * @param array con datos de Transportista
  * @return ID transportista generado
  */
  function Guardar_Transportista($data){
    $post['_post_transportista'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | TRANSPORTISTAS | Guardar_Transportista()  $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("POST",REST_CORE."/transportista", $post);
    $aux = json_decode($aux["data"]);
    return $aux->GeneratedKeys->Entry;
  }

  /**
  * Listado de Transportistas
  * @param 
  * @return array con datos de transportistas
  */
  function Listar_Transportistas(){
    $empr_id = empresa();
		$aux = $this->rest->callAPI("GET",REST_CORE."/transportistas/$empr_id");
		$aux = json_decode($aux["data"]);
		$transportistas = $aux->transportista->transportistas;
		return $transportistas;
  }

  /**
  * Listado tipos de Transportistas
  * @param 
  * @return array con datos de transportistas
  */
  function Listar_Tipos_Transportistas(){
		$aux = $this->rest->callAPI("GET",REST_CORE."/tablas/tipos_transportistas");
		$aux = json_decode($aux["data"]);
		$tipos_transportistas = $aux->tablas->tabla;
		return $tipos_transportistas;
  }
  
  /**
   * Edita info del Transportista
   * @param array con info
   * @return bool respuesta de servicio
   */
  function Editar_Transportista($transportista)
  {
    $post['_put_transportista'] = $transportista;
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | TRANSPORTISTAS | Editar_Transportista() $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("PUT",REST_CORE."/transportista", $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }
  
  /**
    * Borra transportista por ID
    * @param	int $clie_id
    * @return bool true o false resultado del servicio
    */
    function Borrar_Transportista($clie_id)
    {
      $post['_delete_transportista'] = array("clie_id" => $clie_id);
      log_message('DEBUG','#TRAZA | TRAZ-TOOLS | TRANSPORTISTAS $post: >> '.json_encode($post));
      $aux = $this->rest->callAPI("DELETE",REST_CORE."/transportista", $post);
      $aux = json_decode($aux["status"]);
      return $aux;
    }

}