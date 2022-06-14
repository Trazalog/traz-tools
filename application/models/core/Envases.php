<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Envases 
*
* @autor Rogelio Sanchez
*/
class Envases extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  function __construct(){
    parent::__construct();
  }

  /**
  * Genera un envase nuevo
  * @param array con datos de Envase
  * @return ID envase generado
  */
  function Guardar_Envase($data){
    $post['_post_envase'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | CLIENTES | Guardar_CLiente()  $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("POST",REST_CORE."/envase", $post);
    $aux = json_decode($aux["data"]);
    return $aux->GeneratedKeys->Entry;
  }

  /**
  * Listado de Envases
  * @param 
  * @return array con datos de envases
  */
  function Listar_Envases(){
    $empr_id = empresa();
		$aux = $this->rest->callAPI("GET",REST_CORE."/envases/empresa/$empr_id");
		$aux = json_decode($aux["data"]);
		$envases = $aux->envase->envases;
		return $envases;
  }

  /**
  * Listado de Formulas
  * @param 
  * @return array con datos de formulas
  */
  function Listar_Formulas(){
		$aux = $this->rest->callAPI("GET",REST_PRD."/getFormulas");
		$aux = json_decode($aux["data"]);
		$formulas = $aux->formulas->formula;
		return $formulas;
  }

    /**
  * Listado de Unidades de nedida
  * @param 
  * @return array con datos de unidades de medida
  */
  function Listar_Unidades_Medidas(){
		$aux = $this->rest->callAPI("GET",REST_CORE."/unidades_medidas");
		$aux = json_decode($aux["data"]);
		$unidades = $aux->unidades->unidad;
		return $unidades;
  }

  /**
  * Listado tipos de Envases
  * @param 
  * @return array con datos de envases
  */
  function Listar_Tipos_Envases(){
		$aux = $this->rest->callAPI("GET",REST_CORE."/tablas/tipos_envases");
		$aux = json_decode($aux["data"]);
		$tipos_envases = $aux->tablas->tabla;
		return $tipos_envases;
  }
  
  /**
   * Edita info del Envase
   * @param array con info
   * @return bool respuesta de servicio
   */
  function Editar_Envase($envase)
  {
    $post['_put_envase'] = $envase;
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | CLIENTES | Editar_Envase() $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("PUT",REST_CORE."/envase", $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }
  
  /**
    * Borra envase por ID
    * @param	int $clie_id
    * @return bool true o false resultado del servicio
    */
    function Borrar_Envase($clie_id)
    {
      $post['_delete_envase'] = array("clie_id" => $clie_id);
      log_message('DEBUG','#TRAZA | TRAZ-TOOLS | CLIENTES $post: >> '.json_encode($post));
      $aux = $this->rest->callAPI("DELETE",REST_CORE."/envase", $post);
      $aux = json_decode($aux["status"]);
      return $aux;
    }

}