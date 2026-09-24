<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Dash extends CI_Controller {
	function __construct(){

		parent::__construct();
		$this->load->helper('menu_helper');
		$this->load->helper('file');
		$this->load->model('Dashs');
		$this->load->helper('sesion_helper');
		$this->load->model(PRD.'Tablas');
		
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

			//Aterrizaje: el Administrador entra al tablero; el resto, a la vista por defecto (intacto).
			//El rol admin se resuelve contra Postgres (no Bonita) — ver Dashs::esAdminEmpresa().
			$data['landing'] = $this->Dashs->esAdminEmpresa() ? 'Dash/dashboard' : DEF_VIEW;

			//copyright de footer configurado en core.tablas 
			$footer = $this->Tablas->obtenerTabla('configuraciones_uitoolsfotterCopyright');
			$data['copyright'] = $footer['data'][0]->valor;

			//logo de navbar configurado en core.tablas 
			$footer = $this->Tablas->obtenerTabla('configuraciones_uitoolsLogoNavbar');
			$data['logo_navbar'] = $footer['data'][0]->valor;
			$data['estilo_logo_navbar'] = $footer['data'][0]->valor2;
			$data['texto_logo_navbar'] = $footer['data'][0]->valor3;


			$this->load->view('layout/Admin',$data);
		}else{
			log_message("DEBUG","#TRAZA | CORE | Dash | index() >> Sesion vencida");
			redirect(DNATO."main/login");
		}
	}


	/**
	 * Tablero / Landing del Administrador. Se carga como fragmento dentro de #content
	 * (via linkTo AJAX), por eso NO monta layout/Admin, sólo la vista dashboard/admin_dashboard.
	 * Ver doc/analisis/dashboard-administrador-landing.md
	 */
	function dashboard(){
		log_message("DEBUG","#TRAZA | CORE | Dash | dashboard()");
		if(!$this->session->userdata('empr_id')){
			redirect(DNATO."main/login");
			return;
		}

		$this->config->load('dashboard', TRUE);
		$cfg = $this->config->item('dashboard');

		$memberships = $this->Dashs->obtenerMemberships();

		// --- Sector Suscripción ---
		$nombre = trim((string) $this->session->userdata('first_name').' '.(string) $this->session->userdata('last_name'));
		if($nombre === ''){
			$nombre = (string) $this->session->userdata('usernick');
		}
		if($nombre === ''){
			$nombre = (string) $this->session->userdata('email');
		}

		// Logo del navbar reutilizado como logo de empresa (supuesto A3)
		$logo = $this->Tablas->obtenerTabla('configuraciones_uitoolsLogoNavbar');
		$data['logo_empresa'] = isset($logo['data'][0]->valor) ? $logo['data'][0]->valor : '';

		$data['nombre_usuario']    = $nombre;
		$data['fecha_hoy']         = $this->fechaLarga();
		$data['welcome_msg']       = $cfg['dashboard_welcome_msg'];
		$data['nombre_empresa']    = $this->Dashs->nombreEmpresaActual($memberships);
		$data['cantidad_usuarios'] = $this->Dashs->contarUsuariosEmpresa();
		// Tipo de suscripción (supuesto A5): constante por ahora — Freemium para altas recientes.
		$data['tipo_suscripcion']  = 'Freemium';
		$data['modulos']           = $cfg['dashboard_modulos'];
		$data['actividad']         = $cfg['dashboard_actividad'];

		// --- Sector KPI (scaffolding en Fase 1) ---
		$data['kpis'] = $cfg['dashboard_kpis'];

		$this->load->view('dashboard/admin_dashboard', $data);
	}

	/**
	 * Endpoint AJAX que devuelve un KPI cacheado (JSON) para las cajas del tablero.
	 * Lo consume dashboard_kpis.js. Ruta: Dash/kpi/<nombre>
	 */
	function kpi($nombre = null){
		if(!$this->session->userdata('empr_id')){
			$this->output->set_status_header(401);
			echo json_encode(array('error' => 'sin_sesion'));
			return;
		}
		$kpi = $this->Dashs->obtenerKPI($nombre);
		$this->output
			->set_content_type('application/json')
			->set_output(json_encode($kpi));
	}

	/** Fecha larga en español (server-side). */
	private function fechaLarga(){
		$dias = array('domingo','lunes','martes','miércoles','jueves','viernes','sábado');
		$meses = array('','enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre');
		$d = (int) date('w'); $dia = (int) date('j'); $mes = (int) date('n'); $anio = date('Y');
		return ucfirst($dias[$d]).' '.$dia.' de '.$meses[$mes].' de '.$anio;
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