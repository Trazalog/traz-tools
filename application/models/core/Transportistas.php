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
    // $aux = json_decode($aux["data"]);
    return $aux;
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
		$transportistas = $aux->transportistas->transportista;
		return $transportistas;
  }

  /**
   * Obtener listado de paises
  * @return array con listado de paises
  */
  function listarPaises() {
    $resource = "/paises";
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi('GET', $url);
    $aux = json_decode($aux["data"]);
    $paises = $aux->paises->pais;
    return $paises;
  }

  /**
   * Obtener estados dependiendo el pais seleccionado
  * @param valor de pais
  * @return array con listado de estados
  */
  function getEstados($pais) {
      $post['_post_valor'] = $pais;
      log_message('DEBUG','#TRAZA| TRAZ-TOOLS | TRANSPORTISTAS | getEstados() $post: >> '.json_encode($post));
      $pais = urlencode($pais);
      $resource = "/estados/pais/".$pais;
      $url = REST_CORE . $resource;
      $aux = $this->rest->callApi('GET', $url); 
      $aux = json_decode($aux["data"]);
      $valores = $aux->estados->estado;
      return $valores;
  }

  /**
   * Obtener localidades dependiendo del pais y estado seleccionado
  * @param valor de pais y estado
  * @return array con listado de localidades
  */
  function getLocalidades($pais, $estado) {
      $post['_post_pais'] = $pais;
      $post['_post_estado'] = $estado;
      log_message('DEBUG','#TRAZA| TRAZ-TOOLS | TRANSPORTISTAS | getLocalidades() $post: >> '.json_encode($post));
      $pais = urlencode($pais);
      $estado = urlencode($estado);
      $resource = '/localidades/pais/' . $pais . '/estado/' . $estado;
      $url = REST_CORE . $resource;
      $aux = $this->rest->callApi('GET', $url); 
      $aux = json_decode($aux["data"]);
      $valores = $aux->localidades->localidad;
      return $valores;
  }

  /**
  * Listado tipos de transporte
  * @param 
  * @return array con datos de tipos de transporte
  */
  function getTiposTransporte(){
    $aux = $this->rest->callAPI("GET",REST_CORE."/tablas/tipos_transporte");
		$aux = json_decode($aux["data"]);
		$tipos_transporte = $aux->tablas->tabla;
		return $tipos_transporte;
  }

  /**
  * Listado tipos de Transportistas
  * @param 
  * @return array con datos de transportistas
  */
  function Listar_Tipos_Transportistas(){
    $aux = $this->rest->callAPI("GET",REST_CORE."/tabla/tipos_transportistas/empresa/".empresa());
		// $aux = $this->rest->callAPI("GET",REST_CORE."/tablas/tipos_transportistas");
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
    // $aux = json_decode($aux["status"]);
    return $aux;
  }
  
  /**
  * Borra transportista por ID
  * @param	int $tran_id
  * @return bool true o false resultado del servicio
  */
  function Borrar_Transportista($tran_id)
  {
    $post['_delete_transportista'] = array("tran_id" => $tran_id);
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | TRANSPORTISTAS $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("DELETE",REST_CORE."/transportista", $post);
    return $aux;
  }

  /**
  * Valida CUIT
  * @param	array con Info
  * @return array resultado del servicio
  */
  function Validar_cuit($cuit) {
    $aux= array("cuit" => $cuit);
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | TRANSPORTISTAS | Validar_cuit() $aux: >> '.json_encode($aux));
    $aux=$this->rest->callAPI("GET",REST_CORE."/transportistas/cuit/".$aux['cuit']);
    return json_encode($aux);

  }

}