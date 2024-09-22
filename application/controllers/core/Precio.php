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
		// $data['items'] = $this->Componentes->listaArticulos();
    	$this->load->view('core/precios/list', $data);
	}

	/**
     * Guarda el listado de los Precios.
     *
     * @return  Array  Devuelve un arreglo con los Precios.
     */
	public function verificarNombre()
	{
        // Obtener el nombre enviado por AJAX
        $nombre = $this->input->post('nombre');

        // Llamar al modelo para verificar si el nombre existe
        $existe = $this->Precios->existeNombre($nombre);

        // Enviar la respuesta
        if ($existe) {
            echo 'existe';  // Enviar "existe" si el nombre ya está registrado
        } else {
            echo 'no_existe';  // Enviar "no_existe" si no está registrado
        }
	}
}