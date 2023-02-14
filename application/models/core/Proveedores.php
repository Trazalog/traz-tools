<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Proveedores 
*
* @autor Gerardo Ramos
*/
class Proveedores extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  public function __construct(){
    parent::__construct();
  }

  /**
  * Listado de Proveedores
  * @param 
  * @return array con listado de proveedores
  */
  public function listarProveedores() {
    $empr_id = empresa();
    $resource = "/proveedores/".$empr_id;
    $url = REST_ALM . $resource;
    $aux = $this->rest->callApi('GET', $url);
    $aux = json_decode($aux["data"]);
    $proveedores = $aux->proveedores->proveedor;
    return $proveedores;
  }

  public function listarPaises() {
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
  public function getEstados($pais) {
    $post['_post_valor'] = $pais;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | ESTABLECIMIENTOS | getEstados() $post: >> '.json_encode($post));
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
  public function getLocalidades($pais, $estado) {
    $post['_post_pais'] = $pais;
    $post['_post_estado'] = $estado;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | ESTABLECIMIENTOS | getLocalidades() $post: >> '.json_encode($post));
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
  * Genera un valor nuevo
  * @param array con datos del valor
  * @return ID valor generado
  */
  public function guardarProveedor($data){
    $estado = urldecode($data['estado']);
    $localidad = urldecode($data['localidad']);
    $post['_post_proveedor'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | VALORES | guardarProveedor()  $post: >> '.json_encode($post));
    $post['_post_proveedor']['estado'] = $estado;
    $post['_post_proveedor']['localidad'] = $localidad;
    $resource = '/proveedores';
    $url = REST_ALM . $resource;
    $aux = $this->rest->callApi("POST", $url, $post); 
    return $aux;
  }

  /**
  * Genera un valor nuevo
  * @param array con datos del valor
  * @return ID valor generado
  */
  public function guardarEdicionProveedor($data){
    $estado = urldecode($data['estado']);
    $localidad = urldecode($data['localidad']);
    $post['_post_proveedor'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | VALORES | guardarEdicionProveedor()  $post: >> '.json_encode($post));
    $post['_post_proveedor']['estado'] = $estado;
    $post['_post_proveedor']['localidad'] = $localidad;
    $resource = '/proveedor';
    $url = REST_ALM . $resource;
    $aux = $this->rest->callApi("PUT", $url, $post); 
    return $aux;
  }

  /**
    * Borra proveedor por ID
    * @param	int $prov_id
    * @return bool true o false resultado del servicio
    */
  public function borrarProveedor($prov_id) {
    $post['_delete_proveedor'] = array("prov_id" => $prov_id);
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | PROVEEDOR $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("DELETE",REST_ALM."/proveedor", $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }

  public function listarDepositosXProveedor($prov_id,$empr_id) 
  {
    log_message('DEBUG', 'Proveedores/listarDepositosXProveedor(prov_id)-> ' . $prov_id);
    log_message('DEBUG', 'Proveedores/listarDepositosXProveedor(empr_id)-> ' . $empr_id);
    $resource = '/depositos/proveedor/' . $prov_id . '/empresa/' . $empr_id;
    $url = REST_CORE . $resource;
    $rsp = $this->rest->callAPI("GET", $url, $empr_id);
    if ($rsp['status']) {
        $rsp = json_decode($rsp['data']);
    }
    $valores = $rsp->depositos->deposito;
    return $valores;
  }

  public function guardarDeposito($deposito)
  {
    $post['_post_deposito_proveedor'] = $deposito;
    log_message('DEBUG','#TRAZA|TRAZA-COMP-PRD|DEPOSITOS POR PROVEEDOR|GUARDAR $post: >> '.json_encode($post));
    $resource = '/deposito/proveedor';
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi('POST', $url, $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }

  public function borrarDeposito($depo_id)
  {
    $post['_delete_deposito'] = array("depo_id" => $depo_id);
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | ETAPAS | borrarArticuloEntrada() $post: >> '.json_encode($post));
    $resource = '/deposito';
    $url = REST_CORE . $resource;
    $aux = $this->rest->callAPI("DELETE", $url, $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }

}