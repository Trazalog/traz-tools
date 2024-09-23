<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Precios 
*
*/
class Precios extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  function __construct(){
    parent::__construct();
  }

  /**
  * Listado de precios
  * @param 
  * @return array con datos de listas de precios
  */
  function getListasPrecios(){
    $empr_id = empresa();
		$aux = $this->rest->callAPI("GET",REST_CORE."/listas_precios/$empr_id");
		$aux = json_decode($aux["data"]);
		$listas_precios = $aux->listas->lista;
		return $listas_precios;
  }

  /**
  * Función para verificar si el nombre ya existe en la base de datos
  * @param 
  * @return true o false
  */
  public function existeNombre($nombre) {
    $aux = $this->rest->callAPI("GET",REST_CORE."/lista_precio_valida_nombre/$nombre");
		$aux = json_decode($aux["data"]);
    if (isset($aux->lista) && !empty($aux->lista->nombre) && $aux->lista->nombre === $nombre) {
      return true;
    } else {
      return false;
    }
  }

  public function agregarListaPrecio($data) {
    $post = array(
        'nombre' => $data['nombre'],
        'tipo' => $data['tipo'],
        'version' => $data['version'],
        'detalle' => $data['detalle'],
        'empr_id' => intval($data['empr_id']),  // Convertir empr_id a int
        'usr_alta' => $data['usr_alta'],
        'usr_app_alta' => $data['usr_app_alta'],
        'usr_ult_modif' => $data['usr_ult_modif'],
        'usr_app_ult_modif' => $data['usr_app_ult_modif'],
        'fec_ult_modif' => $data['fec_ult_modif']  // Dejar como string con formato timestamp
    );

    log_message('DEBUG', '#TRAZA| LISTA PRECIOS | agregarListaPrecio() $post: ' . json_encode($post));
    
    $resource = '/lista_precio';
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi("POST", $url, json_encode($post)); 
    return $aux;
  }

}