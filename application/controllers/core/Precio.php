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
	public function verificarNombre()
	{        
        $nombre = $this->input->post('nombre');
        $existe = $this->Precios->existeNombre($nombre);
        if ($existe) {
            echo 'existe';
        } else {
            echo 'no_existe';
        }
	}

    public function agregarListaPrecio() {
        $nombre = $this->input->post('nombre');
        $tipo = $this->input->post('tipo');
        $version = $this->input->post('version');
        $detalle = $this->input->post('detalle');
        $empr_id = intval(empresa());
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
        
        $response = $this->Precios->agregarListaPrecio($data);
    
        if ($response['status'] == 'success') {
            echo json_encode(array('status' => 'success', 'message' => 'Lista de precios enviada con éxito.'));
        } else {
            echo json_encode(array('status' => 'error', 'message' => 'Error al enviar la lista de precios.'));
        }
    }    
    
}