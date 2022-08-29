<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Modelo de Establecimientos 
*
* @autor Gerardo Ramos
*/
class Establecimientos extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  public function __construct(){
    parent::__construct();
  }

  /**
  * Listado de Establecimientos
  * @param 
  * @return array con listado de establecimientos
  */
  public function listarEstablecimientos() {
    $empr_id = empresa();
    $resource = "/establecimientos/".$empr_id;
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi('GET', $url);
    $aux = json_decode($aux["data"]);
    $establecimientos = $aux->establecimientos->establecimiento;
    return $establecimientos;
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
    // $es = array();
    // foreach ($valores as $val)
    // {
    //   $estado = $val['tabl_id'];
    //   array_push($es, $estado);
    // }
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
  public function guardarEstablecimiento($data){
    $estado = urldecode($data['estado']);
    $localidad = urldecode($data['localidad']);
    $post['_post_establecimiento'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | VALORES | guardarEstablecimiento()  $post: >> '.json_encode($post));
    $post['_post_establecimiento']['pais'] = urlencode($data['pais']);
    $post['_post_establecimiento']['estado'] = $estado;
    $post['_post_establecimiento']['localidad'] = $localidad;
    $resource = '/establecimiento';
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi("POST", $url, $post); 
    // $aux = json_decode($aux["status"]);
    return $aux;
  }

  /**
  * Genera un valor nuevo
  * @param array con datos del valor
  * @return ID valor generado
  */
  public function guardarEdicionEstablecimiento($data){
    $estado = urldecode($data['estado']);
    $localidad = urldecode($data['localidad']);
    // $estado = $data['estado'];
    // $localidad = $data['localidad'];
    $post['_post_establecimiento'] = $data;
    log_message('DEBUG','#TRAZA| TRAZ-TOOLS | VALORES | guardarEdicionEstablecimiento()  $post: >> '.json_encode($post));
    // $post['_post_establecimiento']['pais'] = urlencode($data['pais']);
    // $post['_post_establecimiento']['pais'] = urldecode($data['pais']);
    $post['_post_establecimiento']['estado'] = $estado;
    $post['_post_establecimiento']['localidad'] = $localidad;
    $resource = '/establecimiento';
    $url = REST_CORE . $resource;
    $aux = $this->rest->callApi("PUT", $url, $post); 
    // $aux = json_decode($aux["data"]);
    // return $aux->GeneratedKeys->Entry;
    return $aux;
  }

  /**
    * Borra establecimiento por ID
    * @param	int $esta_id
    * @return bool true o false resultado del servicio
    */
  public function borrarEstablecimiento($esta_id) {
    $post['_delete_establecimiento'] = array("esta_id" => $esta_id);
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | ESTABLECIMIENTO $post: >> '.json_encode($post));
    $aux = $this->rest->callAPI("DELETE",REST_CORE."/establecimiento", $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }

  public function listarDepositosXEstablecimiento($esta_id,$empr_id) 
  {
    log_message('DEBUG', 'Establecimientos/listarDepositosXEstablecimiento(esta_id)-> ' . $esta_id);
    log_message('DEBUG', 'Establecimientos/listarDepositosXEstablecimiento(empr_id)-> ' . $empr_id);
    $resource = '/depositos/establecimiento/' . $esta_id . '/empresa/' . $empr_id;
    $url = REST_CORE . $resource;
    $rsp = $this->rest->callAPI("GET", $url, $empr_id);
    if ($rsp['status']) {
        $rsp = json_decode($rsp['data']);
    }
    $valores = $rsp->depositos->deposito;
    return $valores;
  }
  /**
	* Agrega un deposito con encargado/s
	* @param array datos deposito
	* @return array resultado de servicio de guardado
	*/
  public function guardarDeposito($data){
    log_message('DEBUG','#TRAZA | #CORE | Establecimientos | guardarDeposito($deposito)');
    $url = REST_CORE . '/deposito/establecimiento';
    
    $deposito['esta_id'] = $data['esta_id'];
    $deposito['descripcion'] = $data['descripcion'];
    $deposito['empr_id'] = empresa();

    $post['_post_deposito_establecimiento'] = $deposito;
    $rsp_deposito = $this->rest->callApi('POST', $url, $post);

    log_message('DEBUG','#TRAZA | #CORE | guardarDeposito() | GUARDAR $deposito: >> '.json_encode($rsp_deposito));

    if($rsp_deposito['status']){
      $depo_id = json_decode($rsp_deposito['data'])->respuesta->depo_id;
      $rsp['deposito']['status'] = $rsp_deposito['status'];
      $rsp['deposito']['msj'] = "Se añadio el deposito correctamente";
    }else{
      $rsp['deposito']['status'] = $rsp_deposito['status'];
      $rsp['deposito']['data'] = $rsp_deposito['data'];
      $rsp['deposito']['msj'] = "Se produjo un error al guardar el deposito";
    }
    if(!empty($depo_id)){
        $batch_req = [];
        if(is_array($data['encargadosDeposito'])){
        $url_encargados = REST_CORE.'/_post_deposito_encargado_batch_req';

        foreach ($data['encargadosDeposito'] as $key) {
          $aux['depo_id'] = $depo_id;
          $aux['user_id'] =  $key;
    
          $batch_req['_post_deposito_encargado_batch_req']['_post_deposito_encargado'][] = $aux;
        }

        $rsp_encargados = $this->rest->callApi('POST', $url_encargados, $batch_req);

      }else{
        $url_encargados = REST_CORE.'/deposito/encargado';

        $aux['depo_id'] = $depo_id;
        $aux['user_id'] =  $data['encargadosDeposito'];
        
        $encargadosDeposito['_post_deposito_encargado'] = $aux;
        
        $rsp_encargados = $this->rest->callApi('POST', $url_encargados, $encargadosDeposito);
      }

      log_message('DEBUG','#TRAZA | #CORE | guardarDeposito() | GUARDAR $encargados: >> '.json_encode($rsp_encargados));
      
      if($rsp_encargados['status']){
        $rsp['encargados']['status'] = $rsp_encargados['status'];
        $rsp['encargados']['msj'] = "Se agregaron los encargados correctamente";
      }else{
        $rsp['encargados']['status'] = $rsp_encargados['status'];
        $rsp['encargados']['data'] = $rsp_encargados['data'];
        $rsp['encargados']['msj'] = "Se produjo un error al guardar los encargados";
      }
    }
    return $rsp;
  }
  /**
	* Editar un deposito y la relacion con sus encargado/s
	* @param array datos deposito
	* @return array resultado de servicio de guardado
	*/
  public function editarDeposito($data){
    log_message('DEBUG','#TRAZA | #CORE | Establecimientos | editarDeposito($deposito)');
    $url = REST_CORE . '/deposito/establecimiento';
    
    $deposito['esta_id'] = $data['esta_id'];
    $deposito['descripcion'] = $data['descripcion'];
    $deposito['depo_id'] = $data['depo_id'];
    $deposito['empr_id'] = empresa();

    $put['_put_deposito_establecimiento'] = $deposito;
    $rsp_deposito = $this->rest->callApi('PUT', $url, $put);

    log_message('DEBUG','#TRAZA | #CORE | editarDeposito() | editar $deposito: >> '.json_encode($rsp_deposito));

    if($rsp_deposito['status']){
      $rsp['deposito']['status'] = $rsp_deposito['status'];
      $rsp['deposito']['msj'] = "Se edito el deposito correctamente";
    }else{
      $rsp['deposito']['status'] = $rsp_deposito['status'];
      $rsp['deposito']['data'] = $rsp_deposito['data'];
      $rsp['deposito']['msj'] = "Se produjo un error al editar el deposito";
    }
    //Elimino la relacion con los encargados
    $rspDeleteEncargados = $this->borrarEncargadosDeposito($depo_id);

    $batch_req = [];
    if(is_array($data['encargadosDeposito'])){
      $url_encargados = REST_CORE.'/_post_deposito_encargado_batch_req';

      foreach ($data['encargadosDeposito'] as $key) {
        $aux['depo_id'] = $data['depo_id'];
        $aux['user_id'] =  $key;
  
        $batch_req['_post_deposito_encargado_batch_req']['_post_deposito_encargado'][] = $aux;
      }
      $rsp_encargados = $this->rest->callApi('POST', $url_encargados, $batch_req);

    }else{
      $url_encargados = REST_CORE.'/deposito/encargado';

      $aux['depo_id'] = $data['depo_id'];
      $aux['user_id'] =  $data['encargadosDeposito'];
      
      $encargadosDeposito['_post_deposito_encargado'] = $aux;
      
      $rsp_encargados = $this->rest->callApi('POST', $url_encargados, $encargadosDeposito);
    }

    log_message('DEBUG','#TRAZA | #CORE | editarDeposito() | GUARDAR $encargados: >> '.json_encode($rsp_encargados));
    
    if($rsp_encargados['status']){
      $rsp['encargados']['status'] = $rsp_encargados['status'];
      $rsp['encargados']['msj'] = "Se agregaron los encargados correctamente";
    }else{
      $rsp['encargados']['status'] = $rsp_encargados['status'];
      $rsp['encargados']['data'] = $rsp_encargados['data'];
      $rsp['encargados']['msj'] = "Se produjo un error al guardar los encargados";
    }
    return $rsp;
  }
  /**
	* Elimina el deposito y la relacion con sus encargado/s
	* @param integer depo_id
	* @return array resultado de servicio de guardado
	*/
  public function borrarDeposito($depo_id){
    $rspEncargados = $this->borrarEncargadosDeposito($depo_id);
    $post['_delete_deposito'] = array("depo_id" => $depo_id);
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | Establecimientos | borrarDeposito() $post: >> '.json_encode($post));
    $resource = '/deposito';
    $url = REST_CORE . $resource;
    $aux = $this->rest->callAPI("DELETE", $url, $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }
  /**
	* Elimina la relacion de los encargados con lso depositos
	* @param integer depo_id
	* @return array resultado de servicio de guardado
	*/
  public function borrarEncargadosDeposito($depo_id){
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | Establecimientos | borrarEncargadosDeposito()');
    $url = REST_CORE.'/deposito/encargado';
    $encargados['depo_id'] = $depo_id;
    $del['_delete_deposito_encargado'] = $encargados;
    $aux = $this->rest->callApi('DELETE', $url, $del);
    return $aux;
  }
  public function listarPanolesXEstablecimiento($esta_id) 
  {
    log_message('DEBUG', 'Establecimientos/listarPanolesXEstablecimiento(esta_id)-> ' . $esta_id);
    $resource = '/panol/establecimiento/' . $esta_id;
    $url = REST_PAN . $resource;
    $rsp = $this->rest->callAPI("GET", $url);
    if ($rsp['status']) {
        $rsp = json_decode($rsp['data']);
    }
    $valores = $rsp->panoles->panol;
    return $valores;
  }

  public function borrarPanol($pano_id)
  {
    $post['_delete_panol'] = array("pano_id" => $pano_id, "eliminado" => "1");
    log_message('DEBUG','#TRAZA | TRAZ-TOOLS | ETAPAS | borrarArticuloEntrada() $post: >> '.json_encode($post));
    $resource = '/panol/estado';
    $url = REST_PAN . $resource;
    $aux = $this->rest->callAPI("PUT", $url, $post);
    $aux = json_decode($aux["status"]);
    return $aux;
  }

  /**
  * Devuelve usuarios activos segun empresa
  * @param 
  * @return lista de usuarios por empresa
  */
  function obtenerUsuarios(){
          
    $aux = $this->rest->callAPI("GET",REST_CORE."/users/".empresa());
    $aux = json_decode($aux["data"]);

    log_message("DEBUG", "#TRAZA | #CORE | ESTABLECIMIENTOS | obtenerUsuarios() response >> ".json_encode($aux));

    return $aux;
  }
  /**
  * Guarda el pañol y los encargados del mismo
  * @param 
  * @return pano_id
  */
  public function guardarPanol($data){
    
    $panol['usuario_app'] = userNick(); 
    $panol['empr_id'] = empresa();
    $panol['nombre'] = $data['nombre'];
    $panol['descripcion'] = $data['descripcion'];
    $panol['esta_id'] = $data['esta_id'];

    $post['_post_panol'] = $panol;
    
    $url_panol = REST_PAN.'/panol';
    $rsp_panol = $this->rest->callApi('POST', $url_panol, $post);

    log_message('DEBUG','#TRAZA | #CORE | guardarPanol | GUARDAR $panol: >> '.json_encode($rsp_panol));

    if($rsp_panol['status']){
      $pano_id = json_decode($rsp_panol['data'])->respuesta->pano_id;
      $rsp['panol']['status'] = $rsp_panol['status'];
      $rsp['panol']['msj'] = "Se añadio el pañol correctamente";
    }else{
      $rsp['panol']['data'] = $rsp_panol['data'];
      $rsp['panol']['msj'] = "Se produjo un error al guardar el pañol";
    }

    $batch_req = [];
    if(is_array($data['encargados'])){
      $url_encargados = REST_PAN.'/_post_panol_encargado_batch_req';

      foreach ($data['encargados'] as $key) {
        $aux['pano_id'] = $pano_id;
        $aux['user_id'] =  $key;
  
        $batch_req['_post_panol_encargado_batch_req']['_post_panol_encargado'][] = $aux;
      }

      $rsp_encargados = $this->rest->callApi('POST', $url_encargados, $batch_req);

    }else{
      $url_encargados = REST_PAN.'/panol/encargado';

      $aux['pano_id'] = $pano_id;
      $aux['user_id'] =  $data['encargados'];

      $encargados['_post_panol_encargado'] = $aux;

      $rsp_encargados = $this->rest->callApi('POST', $url_encargados, $encargados);
    }


    log_message('DEBUG','#TRAZA | #CORE | guardarPanol | GUARDAR $encargados: >> '.json_encode($rsp_encargados));
    
    if($rsp_encargados['status']){
      $rsp['encargados']['status'] = $rsp_encargados['status'];
      $rsp['encargados']['msj'] = "Se agregaron los encargados correctamente";
    }else{
      $rsp['encargados']['data'] = $rsp_encargados['data'];
      $rsp['encargados']['msj'] = "Se produjo un error al guardar los encargados";
    }
    return $rsp;
  }

  public function getPanoles()
    {
        $empr_id = empresa();
        $url = REST_PAN.'/panol/empresa/'.$empr_id;
				$array = $this->rest->callAPI("GET",$url);
				$resp =  json_decode($array['data']);
				return $resp;
    }
}