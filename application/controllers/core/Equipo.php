<?php defined('BASEPATH') OR exit('No direct script access allowed');

class Equipo extends CI_Controller 
{
    function __construct(){
      parent::__construct();
      $this->load->model('core/Equipos');    
    } 

    /**
	 *  Muestra el ABM de los equipos.
	 *
	 * @param
	 * @return  void
	 */

    function index(){
      log_message('INFO','#TRAZA | EQUIPOS | index()  >> ');
	  $data['listadoTiposActivos'] = $this->Equipos->Listar_TiposActivos();
	  $data['listadoSectores'] = $this->Equipos->Listar_Sectores();
	  $data['listadoAreas'] = $this->Equipos->Listar_Areas();
	  $data['listadoUnidades'] = $this->Equipos->Listar_Unidades_Medidas();
	  $data['listadoCriticidad'] = $this->Equipos->Listar_Criticidad();
	//   $data['listadoFormulas'] = $this->Equipos->Listar_Formulas();
    //   $data['list'] = $this->Equipos->Listar_Equipos();
    //   $data['tipos_equipos'] = $this->Equipos->Listar_Tipos_Equipos();
      $this->load->view('core/equipos/view', $data);
    }
    
 /**
     * Devuelve un listado de las Equipos.
     *
     * @return  Array   Devuelve un arreglo con las Equipos.
     */
		function Listar_Equipos()
	{
		log_message('INFO','#TRAZA| EQUIPOS | Listar_Equipos() >> ');
		$data['list'] = $this->Equipos->Listar_Equipos();
    	$this->load->view('core/equipos/list', $data);
	}
    /**
	* Guarda equipo
	* @param array equipo
	* @return bool true o false segun resultado de servicio de guardado
	*/
	function Guardar_Equipo()
	{
		log_message('ERROR', '#TRAZA | EQUIPOS | guardar()');
		$equipo = $this->input->post('datos');
		$resp = $this->Equipos->Guardar_Equipo($equipo);
		if ( !$resp ) {
			log_message('ERROR', '#TRAZA | EQUIPOS | guardar()');
			echo json_encode(false);
			return;
		} else {
			echo json_encode(true);
			return;
		}
	}

	/**
	* Edita info de Equipo
	* @param array con informacion de Equipo
	* @return bool true o false respuesta del servicio
	*/
	function Editar_Equipo()
	{
    log_message('INFO','#TRAZA | EQUIPOS | Editar_Equipo() >> ');
		$equipo = $this->input->post('datos');
		// $equipo['usuario_app'] = userNick();
		$resp = $this->Equipos->Editar_Equipo($equipo);
		echo json_encode($resp);
	}

	/**
	* Borra Equipo por id
	* @param
	* @return bool true o false
	*/
	public function Borrar_Equipo()
	{
		log_message('INFO','#TRAZA | EQUIPOS | Borrar_Equipo() >> ');
		$equi_id = $this->input->post('equi_id');
		$result = $this->Equipos->Borrar_Equipo($equi_id);
		echo json_encode($result);
	}
}    