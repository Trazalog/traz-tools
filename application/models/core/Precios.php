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
}