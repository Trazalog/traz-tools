<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Precios 
*
* @autor Gerardo Ramos
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
		// $query = $aux->lista;

    // Si hay al menos un resultado, el nombre existe
    if (isset($aux->lista) && !empty($aux->lista->nombre) && $aux->lista->nombre === $nombre) {
      return true;
    } else {
      return false;
    }
  }
}