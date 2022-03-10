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
  * Listado de Valores
  * @param 
  * @return array con listado de valores
  */
  function Listar_Valores(){
    $data = $this->session->userdata();
    if($data['email'] == TOOLS_ADMIN_USER){
      $resource = "/tablas/lista/empresa/";
      $url = REST_CORE . $resource;
      $aux = $this->rest->callApi('GET', $url);
		} else {
      $resource = "/tablas/lista/empresa/".empresa();
      $url = REST_CORE . $resource;
      $aux = $this->rest->callApi('GET', $url);
    }
    $aux = json_decode($aux["data"]);
    $valores = $aux->tablas->tabla;
    return $valores;    
  }

  /**
  * Obtener contenido de un Valor
  * @param valor de tabla
  * @return array con datos del valor
  */
  function getValor($tabla){
    $post['_post_valor'] = $tabla;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | VALORES | getValor() $post: >> '.json_encode($post));
    $empre_id = '';
    $usuario = $this->session->userdata();
    // SI EL USUARIO NO ES ADMIN ENTONCES LE MANDAMOS EL ID DE EMPRESA PARA QUE CONCANTENE
    if ($usuario['email'] != TOOLS_ADMIN_USER) {
      $empre_id = empresa();
    }
    $resource = "/tabla/".$tabla."/empresa/".$empre_id;
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi('GET', $url); 
    $aux = json_decode($aux["data"]);
    $valores = $aux->tablas->tabla;
    return $valores;
  }

  /**
  * Genera un valor nuevo
  * @param array con datos del valor
  * @return ID valor generado
  */
  function guardarValor($data){
    $post['_post_valor'] = $data;
    // $post['_post_valor']['empr_id'] = '';
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | VALORES | guardarValor()  $post: >> '.json_encode($post));
    $usuario = $this->session->userdata();
    // SI HAY ALGO CON "-" QUE LO CORTE
    if (strpos($post['_post_valor']['tabla'], "-")) {
      $nombres = explode("-", $post['_post_valor']['tabla']);
      $post['_post_valor']['empr_id'] = $nombres[0];
      $post['_post_valor']['tabla'] = $nombres[1];
    }
    // SI EL USUARIO NO ES ADMIN ENTONCES LE MANDAMOS EL ID DE EMPRESA PARA QUE CONCANTENE
    if ($usuario['email'] != TOOLS_ADMIN_USER) {
      $post['_post_valor']['empr_id'] = empresa();
    }
    if ($post['_post_valor']['empr_id'] == "999999") {
      $post['_post_valor']['empr_id'] = "";
    }
    $aux = $this->rest->callAPI("POST",REST_CORE."/tablas", $post);
    $aux = json_decode($aux["data"]);
    return $aux->GeneratedKeys->Entry;
  }

  /**
  * Editar un valor
  * @param array con datos del valor
  * @return ID valor generado
  */
  function editarValor($data){
    $post['_post_valor'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | VALORES | guardarValor()  $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("PUT",REST_CORE."/tabla", $post);
    $aux = json_decode($aux["data"]);
    return $aux->GeneratedKeys->Entry;
  }
  
  /**
    * Borrado lógico de valor por ID
    * @param	int $tabl_id
    * @return bool true o false resultado del servicio
    */
    function borrarValor($tabl_id)
    {
      $post['_delete_valor'] = array("tabl_id" => $tabl_id);
      log_message('DEBUG','#TRAZA | TRAZ-TOOLS | VALORES | borrarValor() $post: >> '.json_encode($post));
      $aux = $this->rest->callAPI("DELETE",REST_CORE."/tabla", $post);
      $aux = json_decode($aux["status"]);
      return $aux;
    }

  /**
  * Listado de Empresas
  * @param 
  * @return array con listado de empresas
  */
  function Listar_Empresas(){
    $resource = "/empresas";
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi('GET', $url);
    $aux = json_decode($aux["data"]);
    $empresas = $aux->empresas->empresa;
    return $empresas;    
  }

}