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
  * Genera un valore nuevo
  * @param array con datos de Cliente
  * @return ID valor generado
  */
  function guardarValor($data){
    $post['_post_cliente'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | LISTA DE VALORES | guardarValor()  $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("POST",REST_CORE."/tablas", $post);
    $aux = json_decode($aux["data"]);
    return $aux->GeneratedKeys->Entry;
  }

  /**
  * Listado de Valores
  * @param 
  * @return array con datos de valores
  */
  function Listar_Valores(){
    $empr_id = empresa();
    $aux = $this->rest->callAPI("GET",REST_CORE."/tablas/lista/empresa/", $empr_id);
    $aux = json_decode($aux["data"]);
    $valores = $aux->tablas->tabla;
    return $valores;
  }

  /**
  * Contenido de un Valor
  * @param 
  * @return array con datos del valor
  */
  function getValor($tabla){
    $empre_id = empresa();
    $aux = $this->rest->callAPI("GET",REST_CORE."/tabla/".$tabla."/empresa/",$empre_id);
    $aux = json_decode($aux["data"]);
    $valores = $aux->tablas->tabla;
    return $valores;
  }

  /**
  * Listado tipos de Valores
  * @param 
  * @return array con datos de valores
  */
  function Listar_Tipos_Valores(){
		$aux = $this->rest->callAPI("GET",REST_CORE."/tablas/tipos_valores");
		$aux = json_decode($aux["data"]);
		$tipos_valores = $aux->tablas->tabla;
		return $tipos_valores;
  }
  
  /**
   * Edita info del Cliente
   * @param array con info
   * @return bool respuesta de servicio
   */
  function Editar_Cliente($cliente)
  {
    $post['_put_cliente'] = $cliente;
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | VALORES | Editar_Cliente() $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("PUT",REST_CORE."/cliente", $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }
  
  /**
    * Borra tabla por ID
    * @param	int $tabl_id
    * @return bool true o false resultado del servicio
    */
    function borrarValor($tabl_id)
    {
      $post['_delete_tabla'] = array("tabl_id" => $tabl_id);
      log_message('DEBUG','#TRAZA | TRAZ-TOOLS | VALORES $post: >> '.json_encode($post));
      $aux = $this->rest->callAPI("DELETE",REST_CORE."/tabla", $post);
      $aux = json_decode($aux["status"]);
      return $aux;
    }

}