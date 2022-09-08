<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Equipos 
*
* @autor Gerardo Ramos
*/
class Equipos extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  function __construct(){
    parent::__construct();
  }

  /**
  * Genera un equipo nuevo
  * @param array con datos de Equipo
  * @return ID equipo generado
  */
  function Guardar_Equipo($equipo){
		$equipo['estado'] = 'AC';
		$equipo['fecha_ultimalectura'] = '1900-01-01';
		$equipo['ultima_lectura'] = '0';
    $equipo['empr_id'] = empresa();
		$post['_post_equipo'] = $equipo;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | EQUIPOS | Guardar_Equipo()  $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("POST",REST_CORE."/equipo", $post);
    $aux = json_decode($aux["status"]);
  }

  /**
  * Listado de Equipos
  * @param 
  * @return array con datos de equipos
  */
  function Listar_Equipos(){
    $empr_id = empresa();
		$aux = $this->rest->callAPI("GET",REST_CORE."/equipos/empresa/$empr_id");
		$aux = json_decode($aux["data"]);
		$equipos = $aux->equipos->equipo;
		return $equipos;
  }

  /**
  * Listado de tipos_activos
  * @param 
  * @return array con datos de tipos_activos
  */
  function Listar_TiposActivos(){
    $tipo = 'tipos_activos';
		$aux = $this->rest->callAPI("GET",REST_CORE."/tablas/$tipo");
		$aux = json_decode($aux["data"]);
		$tipos_activos = $aux->tablas->tabla;
		return $tipos_activos;
  }

  /**
  * Listado de Sectores
  * @param 
  * @return array con datos de sectores
  */
  function Listar_Sectores(){
    $sector = 'sectores';
		$aux = $this->rest->callAPI("GET",REST_CORE."/tablas/$sector");
		$aux = json_decode($aux["data"]);
		$sectores = $aux->tablas->tabla;
		return $sectores;
  }

  /**
  * Listado de Areas
  * @param 
  * @return array con datos de areas
  */
  function Listar_Areas(){
		$aux = $this->rest->callAPI("GET",REST_CORE."/tabla/areas/empresa/".empresa());
		$aux = json_decode($aux["data"]);
		$areas = $aux->tablas->tabla;
		return $areas;
  }

    /**
  * Listado de Criticidad
  * @param 
  * @return array con datos de criticidad
  */
  function Listar_Criticidad(){
    $criticidad = 'criticidad';
		$aux = $this->rest->callAPI("GET",REST_CORE."/tablas/$criticidad");
		$aux = json_decode($aux["data"]);
		$criticidad = $aux->tablas->tabla;
		return $criticidad;
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
  * Listado de Unidades de medida
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
  * Listado tipos de Equipos
  * @param 
  * @return array con datos de equipos
  */
  function Listar_Tipos_Equipos(){
		$aux = $this->rest->callAPI("GET",REST_CORE."/tablas/tipos_equipos");
		$aux = json_decode($aux["data"]);
		$tipos_equipos = $aux->tablas->tabla;
		return $tipos_equipos;
  }
  
  /**
   * Edita info del Equipo
   * @param array con info
   * @return bool respuesta de servicio
   */
  function Editar_Equipo($data)
  {
		$equipo['empa_id'] = $data['empa_id'];
		$equipo['nombre'] = $data['nombre'];
		$equipo['descripcion'] = $data['descripcion'];
		$equipo['unidad_medida'] = $data['unidad_medida'];
		$equipo['capacidad'] = $data['contenido'];
		$equipo['tara'] = $data['tara'];
		$equipo['receta'] = $data['receta'];
    $post['_put_equipo'] = $equipo;
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | EQUIPOS | Editar_Equipo() $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("PUT",REST_CORE."/equipo", $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }
  
  /**
    * Borra equipo por ID
    * @param	int $equi_id
    * @return bool true o false resultado del servicio
    */
    function Borrar_Equipo($equi_id)
    {
      $post['_delete_equipo'] = array("equi_id" => $equi_id);
      log_message('DEBUG','#TRAZA | TRAZ-TOOLS | EQUIPO $post: >> '.json_encode($post));
      $aux = $this->rest->callAPI("DELETE",REST_CORE."/equipo", $post);
      $aux = json_decode($aux["status"]);
      return $aux;
    }

}