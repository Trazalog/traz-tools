<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Dash extends CI_Controller {
	function __construct(){

		parent::__construct();
		$this->load->helper('menu_helper');
		$this->load->helper('file');
		$this->load->model('Dashs');
		$this->load->helper('sesion_helper');
		//verifica si esta inactivo
		//40minutos de inactividad y redirecciona a login
		validarInactividad();
	}

	function index(){
		log_message("DEBUG","#TRAZA | CORE | Dash | index()");
		$data = $this->session->userdata();
		if(isset($data['empr_id'])){
			
			log_message('DEBUG','#TRAZA | CORE | Dash | index() $data: >> '.json_encode($data));
				
			$data['memberships'] = $this->Dashs->obtenerMemberships();
			$aux = $this->Dashs->obtenerMenu();
			$data['menu'] = menu($aux);
			$this->load->view('layout/Admin',$data);
		}else{
			log_message("DEBUG","#TRAZA | CORE | Dash | index() >> Sesion vencida");
			redirect(DNATO."main/login");
		}
	}


	function cambiarDeEmpresa(){

		$empr_id = $this->input->post('empr_id');
		$group = $this->input->post('group');
		$this->session->set_userdata('empr_id', $empr_id);
		$this->session->set_userdata('groupBpm', $group);
		$empresa_nueva = empresa();
		echo json_encode($empresa_nueva);
	}

}

?>