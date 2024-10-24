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
    log_message('DEBUG', "#TRAZA | CORE | Precios | getListasPrecios()");
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
    log_message('DEBUG', "#TRAZA | CORE | Precios | existeNombre($nombre)");
    $aux = $this->rest->callAPI("GET",REST_CORE."/lista_precio_valida_nombre/".urlencode($nombre));
		$aux = json_decode($aux["data"]);
    if (isset($aux->lista) && !empty($aux->lista->nombre) && $aux->lista->nombre === $nombre) {
      return true;
    } else {
      return false;
    }
  }
  /**
  * Crea la cabecera de la lista de precios y devuelve el lipr_id generado
  * @param Array $data datos cargados en modal de alta
  * @return Integer/Bool $lipr_id en caso de exito, false en caso de error
  */
  public function agregarListaPrecio($data) {
    $post['post_lista_precio'] = array(
      'nombre' => $data['nombre'],
      'tipo' => $data['tipo'],
      'detalle' => $data['detalle'],
      'empr_id' => $data['empr_id'],
      'usr_alta' => $data['usr_alta'],
      'usr_app_alta' => $data['usr_app_alta'],
      'usr_ult_modif' => $data['usr_ult_modif'],
      'usr_app_ult_modif' => $data['usr_app_ult_modif'],
      'fec_ult_modif' => $data['fec_ult_modif']
    );

    log_message('DEBUG', '#TRAZA | CORE | Precios | agregarListaPrecio() $post: ' . json_encode($post));
    
    $resource = '/lista_precio';
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi("POST", $url, $post);

    if ($aux['status']) {
      $lipr_id = json_decode($aux['data'])->respuesta->lipr_id;
      return $lipr_id;
    } else {
      return false;
    }
  }
  /**
  * Crea la version de la lista de precios
  * @param Array $data datos cargados en modal de alta
  * @return Bool true en caso de exito, false en caso de error
  */
  public function agregarVersionListaPrecio($lipr_id, $data){
    log_message('DEBUG', "#TRAZA | CORE | Precios | agregarVersionListaPrecio($lipr_id, ". json_encode($data)." )");

    $post['post_version_lista_precio'] = array(
      'lipr_id' => $lipr_id,
      'nro_version' => $data['version'],
      'descripcion' => $data['detalle'],
      'usr_alta' => $data['usr_alta'],
      'usr_app_alta' => $data['usr_app_alta'],
      'usr_ult_modif' => $data['usr_ult_modif'],
      'usr_app_ult_modif' => $data['usr_app_ult_modif'],
      'fec_ult_modif' => $data['fec_ult_modif']
    );
    
    $resource = '/version_lista_precio';
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi("POST", $url, $post);

    if ($aux['status']) {
      $velp_id = json_decode($aux['data'])->respuesta->velp_id;
      return $velp_id;
    } else {
      return false;
    }
  }
  /**
  * Crea el detalle de la lista de precios con los articulos seleccionados
  * Obtengo el recu_id con el arti_id para la relacion en costos_recursos
  * @param Integer $velp_id id generado al crear la version de la lista de precios
  * @param Array $data articulos cargados en modal de alta
  * @return Array resultado de la operacion
  */
  public function agregarDetalleListaPrecio($velp_id, $articulos){
    $batch_req = [];
    foreach ($articulos as $key) {
      $aux['recu_id'] = $this->getRecursoId($key['arti_id']);
      $aux['velp_id'] = $velp_id;
      $aux['precio'] = $key['precio'];

      $post['_post_costo_recurso'][] = $aux;
    }
    $batch_req['_post_costo_recurso_batch_req'] = $post;

    log_message('DEBUG', "#TRAZA | CORE | Precios | agregarDetalleListaPrecio($lipr_id, ". json_encode($articulos)." )");
    
    $resource = '/costo_recurso_batch_req';
    $url = REST_CORE . $resource;
    $rsp = $this->rest->callApi("POST", $url, $batch_req);

    return $rsp;
  }
  /**
  * Obtiene el recu_id a partir del arti_id
  * @param Integer $arti_id id del articulo
  * @return Integer $recu_id id del recurso asociado al articulo
  */
  public function getRecursoId($arti_id){
    log_message('DEBUG', "#TRAZA | CORE | Precios | getRecursoId($arti_id)");

    $aux = $this->rest->callAPI("GET",REST_PRD_ETAPAS."/recurso/$arti_id");
    $aux = json_decode($aux["data"]);
    $recu_id = $aux->recurso->recu_id;
    return $recu_id;
  }
}