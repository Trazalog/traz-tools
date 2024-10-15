<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Precio extends CI_Controller 
{
    function __construct(){
      parent::__construct();
      $this->load->model('core/Precios');
      $this->load->model(ALM.'traz-comp/Componentes');
    } 

    /**
	*  Muestra el ABM de listas de precios.
	*
	* @param
	* @return  void
	*/
    function index()
	{        
    	log_message('INFO','#TRAZA | PRECIOS | index()  >> ');
    	$data['listas_precios'] = $this->Precios->getListasPrecios();
        $data['items'] = $this->Componentes->listaArticulos();
    	$this->load->view('core/precios/view', $data);
    }

	/**
     * Devuelve un listado de los Precios.
     *
     * @return  Array  Devuelve un arreglo con los Precios.
     */
	public function listarPrecios()
	{
        $this->load->model(ALM.'traz-comp/Componentes');
		log_message('INFO','#TRAZA| ESTABLECIMIENTOS | listarPrecios() >> ');
		$data['listas_precios'] = $this->Precios->getListasPrecios();
    	$this->load->view('core/precios/list', $data);
	}

	/**
     * Guarda el listado de los Precios.
     *
     * @return  Array  Devuelve un arreglo con los Precios.
     */
	public function verificarNombre(){        
        $nombre = $this->input->post('nombre');
        $existe = $this->Precios->existeNombre($nombre);
        if ($existe) {
            echo 'existe';
        } else {
            echo 'no_existe';
        }
	}
    /**
     * Guarda cabecera y su detalle de la nueva lista de Precios.
     * @return Array resultado de la operacion.
    */
    public function agregarListaPrecio() {
        log_message('DEBUG','#TRAZA | CORE | Precio | agregarListaPrecio()');
        $nombre = $this->input->post('nombre');
        $tipo = $this->input->post('tipo');
        $version = $this->input->post('version');
        $detalle = $this->input->post('detalle');
        $articulos = $this->input->post('articulos');
        $empr_id = empresa();
        $usr_alta = userNick();
        $usr_app_alta = userNick();
        $usr_ult_modif = userNick();
        $usr_app_ult_modif = userNick();
        
        $fec_ult_modif = date('Y-m-d H:i:s');

        $data = array(
            'nombre' => $nombre,
            'tipo' => $tipo,
            'version' => $version,
            'detalle' => $detalle,
            'empr_id' => $empr_id,
            'usr_alta' => $usr_alta,
            'usr_app_alta' => $usr_app_alta,
            'usr_ult_modif' => $usr_ult_modif,
            'usr_app_ult_modif' => $usr_app_ult_modif,
            'fec_ult_modif' => $fec_ult_modif
        );
        //PASO 1 genero la cabecera de la lista de precios
        $lipr_id = $this->Precios->agregarListaPrecio($data);
        //PASO 2 genero la version de la lista de precios, validando paso anterior
        if($lipr_id){
            $velp_id = $this->Precios->agregarVersionListaPrecio($lipr_id, $data);
        }else{
            log_message('DEBUG','#TRAZA | CORE | Precio | agregarListaPrecio() >> PASO 1 FALLIDO');
            echo json_encode(array('status' => false, 'message' => 'Error al agregar la cabecera de la lista de precios.'));
            exit;
        }
        //PASO 3 genero el detalle(articulos) de la lista de precios, validando paso anterior
        if($velp_id){
            $response = $this->Precios->agregarDetalleListaPrecio($velp_id, $articulos);
        }else{
            log_message('DEBUG','#TRAZA | CORE | Precio | agregarListaPrecio() >> PASO 2 FALLIDO');
            echo json_encode(array('status' => false, 'message' => 'Error al agregar la version de la lista de precios.'));
            exit;
        }
        
        if ($response['status']) {
            echo json_encode(array('status' => true, 'message' => 'Lista de precios enviada con éxito.'));
        } else {
            echo json_encode(array('status' => false, 'message' => 'Error al agregar los artículos de la lista de precios.'));
        }
    }    
    
}