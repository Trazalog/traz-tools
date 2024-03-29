<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Envases 
*
* @autor Gerardo Ramos
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
    $envase['empr_id'] = empresa();
		$envase['usuario_app'] = userNick();
		$envase['nombre'] = $data['nombre'];
		$envase['descripcion'] = $data['descripcion'];
		$envase['unidad_medida'] = $data['unidad_medida'];
		$envase['capacidad'] = $data['contenido'];
		$envase['tara'] = $data['tara'];
		$envase['receta'] = $data['receta'];
		$post['_post_envase'] = $envase;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | ENVASES | Guardar_Envase()  $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("POST",REST_CORE."/envase", $post);
    $aux = json_decode($aux["status"]);
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
    $empr_id = empresa();
		$aux = $this->rest->callAPI("GET",REST_PRD."/formulasxempresas/$empr_id");
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
  function Editar_Envase($data)
  {
    // $envase['empr_id'] = empresa();
		// $envase['usuario_app'] = userNick();
		$envase['empa_id'] = $data['empa_id'];
		$envase['nombre'] = $data['nombre'];
		$envase['descripcion'] = $data['descripcion'];
		$envase['unidad_medida'] = $data['unidad_medida'];
		$envase['capacidad'] = $data['contenido'];
		$envase['tara'] = $data['tara'];
		$envase['receta'] = $data['receta'];
		// $post['_post_envase'] = $envase;
    $post['_put_envase'] = $envase;
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | ENVASES | Editar_Envase() $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("PUT",REST_CORE."/envase", $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }
  
  /**
    * Borra envase por ID
    * @param	int $empa_id
    * @return bool true o false resultado del servicio
    */
    function Borrar_Envase($empa_id)
    {
      $post['_delete_envase'] = array("empa_id" => $empa_id);
      log_message('DEBUG','#TRAZA | TRAZ-TOOLS | ENVASE $post: >> '.json_encode($post));
      $aux = $this->rest->callAPI("DELETE",REST_CORE."/envase", $post);
      $aux = json_decode($aux["status"]);
      return $aux;
    }

}