<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Precio extends CI_Controller 
{
    function __construct(){
      parent::__construct();
      $this->load->model('core/Precios');    
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
    	// $data['list'] = $this->Precios->Listar_Precios();
    	// $data['tipos_precios'] = $this->Precios->Listar_Tipos_Precios();
    	$this->load->view('core/precios/view', $data);
    }

}