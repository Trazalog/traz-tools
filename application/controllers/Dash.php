<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Dash extends CI_Controller {
	function __construct(){

		parent::__construct();
		$this->load->helper('menu_helper');
		$this->load->helper('file');
		$this->load->model('Dashs');
		
		// si esta vencida la sesion redirige al login
		$data = $this->session->userdata();
		log_message('DEBUG','#Main/login | '.json_encode($data));
		if(!$data['email']){
			log_message('DEBUG','#TRAZA|DASH|CONSTRUCT|ERROR  >> Sesion Expirada!!!');
			redirect(DNATO.'main/login');
		}
	}

	function index(){

		$aux = $this->Dashs->obtenerMenu();
		$data['menu'] = menu($aux);
		$this->load->view('layout/Admin',$data);
	}

}

?>