<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Clientes 
*
* @autor Rogelio Sanchez
*/
class Clientes extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  function __construct(){
    parent::__construct();
  }

  /**
  * Genera un cliente nuevo
  * @param array con datos de Cliente
  * @return ID cliente generado
  */
  function Guardar_Cliente($data){
    $post['_post_cliente'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | CLIENTES | Guardar_CLiente()  $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("POST",REST_CORE."/cliente", $post);
    $aux = json_decode($aux["data"]);
    return $aux->GeneratedKeys->Entry;
  }

  /**
  * Listado de Clientes
  * @param 
  * @return array con datos de clientes
  */
  function Listar_Clientes(){
    $empre_id = empresa();
		$aux = $this->rest->callAPI("GET",REST_CORE."/clientes/porEmpresa/$empre_id/porEstado/ACTIVO");
		$aux = json_decode($aux["data"]);
		$clientes = $aux->cliente->clientes;
		return $clientes;
  }

  /**
  * Listado tipos de Clientes
  * @param 
  * @return array con datos de clientes
  */
  function Listar_Tipos_Clientes(){
		$aux = $this->rest->callAPI("GET",REST_CORE."/tablas/tipos_clientes");
		$aux = json_decode($aux["data"]);
		$tipos_clientes = $aux->tablas->tabla;
		return $tipos_clientes;
  }
  
  /**
   * Edita info del Cliente
   * @param array con info
   * @return bool respuesta de servicio
   */
  function Editar_Cliente($cliente)
  {
    $post['_put_cliente'] = $cliente;
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | CLIENTES | Editar_Cliente() $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("PUT",REST_CORE."/cliente", $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }
  
  /**
    * Borra cliente por ID
    * @param	int $clie_id
    * @return bool true o false resultado del servicio
    */
    function Borrar_Cliente($clie_id)
    {
      $post['_delete_cliente'] = array("clie_id" => $clie_id);
      log_message('DEBUG','#TRAZA | TRAZ-TOOLS | CLIENTES $post: >> '.json_encode($post));
      $aux = $this->rest->callAPI("DELETE",REST_CORE."/cliente", $post);
      $aux = json_decode($aux["status"]);
      return $aux;
    }

}