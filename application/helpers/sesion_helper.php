<?php defined('BASEPATH') OR exit('No direct script access allowed');


if(!function_exists('validarUrlSinSesion')){

	/**
	 * Verifica si la url actual valida con token en lugar de sesion
	* @author rruiz
	*/
	 function validarUrlSinSesion(){

		$ci =& get_instance();
		$ci->load->model( COD.'Urls' );

		$url=$ci->uri->uri_string();
		$urls=$ci->Urls->obtenerUrls();
		$urlvalida=false;
		log_message("DEBUG","La url es".$url);

		foreach ($urls as $an_url) {

			preg_match('/.{/', $an_url->url, $matches1, PREG_OFFSET_CAPTURE);
			preg_match('/.\?/', $an_url->url, $matches2, PREG_OFFSET_CAPTURE);
			if($matches1[0][1] < $matches2[0][1]){
				$initialPosition =$matches1[0][1] ; 
			}
			else {
				$initialPosition =$matches2[0][1] ; 
			}

			$urlacomp=substr($an_url->url, 0,$initialPosition+1);
			
			if (strpos($url, $urlacomp)) { 
				$urlvalida=true;
				log_message("DEBUG","urls valida: ".$an_url->url." comparada con ".$urlacomp);
			}
		}

		return $urlvalida;

	}   
}

/**
* Devuelve el id de usuario en Dnato (sistema login)
* @param
* @return string $userid (id de usuario logueado en sistema)
*/
if(!function_exists('userId')){

    function userId()
    {
		$ci =& get_instance();
		$user = userNick();
		$userBPM = $ci->bpm->getUser($user);
		$userid = $userBPM['data']['id'];
		return  $userid;
    }
}

/**
* Devuelve nick coincidente en dnato y BPM
* @param
* @return string $usernick
*/
if(!function_exists('userNick')){

    function userNick()
    {
        $ci =& get_instance();
        $usernick  = $ci->session->userdata('usernick');
				return  $usernick;
    }
}

/**
* Devuelve el id de susuario en BPM
* @param
* @return 
*/
if(!function_exists('userIdBpm')){
		function userIdBpm()
		{
				$ci =& get_instance();
				$userIdBpm  = $ci->session->userdata('userIdBpm');
				return  $userIdBpm;
		}
}

/**
* Devuelve id de transportista por nickName de usuario logueado
* @param
* @return string $tran_id (tran_id en log.transportistas)
*/
if(!function_exists('usrIdTransportistaByNick')){

	function usrIdTransportistaByNick(){
		$ci =& get_instance();
		$usernick = userNick();
		$aux = $ci->rest->callAPI("GET",REST_RESI."/transportista/id/".$usernick);
		$aux =json_decode($aux["data"]);
		return $aux->transportista->tran_id;
	}
}

/**
* Devuelve id de Generador por nick de usuario logueado
* @param
* @return string $sotr_id
*/
if(!function_exists('usrIdGeneradorByNick')){

	function usrIdGeneradorByNick(){

		$ci =& get_instance();
		$usernick = userNick();
		$aux = $ci->rest->callAPI("GET",REST_RESI."/solicitantesTransporte/".$usernick);
		$aux =json_decode($aux["data"]);
		return $aux->solicitantes_transporte->sotr_id;
	}
}

/**
* Devuelve coincidencia de deposito con usuario asignado a deposito para mostrar en BANDEJA DE ENTRADA
* @param string $nombreTarea; @param integer $depo_id
* @return bool true o false
*/
if(!function_exists('filtrarbyDepo')){

	function filtrarbyDepo($nombreTarea, $depo_id = null){
		$ci =& get_instance();
    	$userdata  = $ci->session->userdata();
		$mostrar = true;
		// si usuario es usuario de deposito
		if (($nombreTarea == "Certifica Vuelco")) {
			$user_depo_id = $userdata['depo_id'];
			//no coincide usuario deposito con deposito asignado
			if (!($user_depo_id == $depo_id)) {
				$mostrar = false;
			}
		}

		return $mostrar;
	}
}

/**
* Devuelve correspondencua entre Case_id con Empresa
* @param
* @return bool true o false
*/
if(!function_exists('bandejaEmpresa')){
	
	function bandejaEmpresa($case_id, $empr_id)
	{
		$ci =& get_instance();
		$aux = $ci->rest->callAPI("GET",REST_CORE."/bandeja/linea/validar/case_id/".$case_id."/empr_id/".$empr_id);
		$aux =json_decode($aux["data"]);
		
		if ($aux->respuesta->case_id) {
			return  true;
		} else {
			return  false;
		}
	}
}


/**
* Devuelve pass de usuario en BPM
* @param 
* @return 
*/
if(!function_exists('userPass')){

    function userPass()
    {
        return BPM_USER_PASS;
    }
}

/**
* Devuelve empr_id desde lavariable de usuario
* @param
* @return int empr_id
*/
if(!function_exists('empresa')){

    function empresa(){
        $ci =& get_instance();
        $empr_id  = $ci->session->userdata('empr_id');
				return  $empr_id;
    }
}

/**
* Devuelve empr_id desde group BPM
* @param 
* @return 
*/
if(!function_exists('empr_id_BPM')){
	function empr_id_BPM($memb)
	{
		//Codigo Anterior
		//$group = $memb->group_id->name; 
		//$group = explode("-", $group);
		//return $group[0];
		//Fin de Codigo anterior
		if(strpos($memb->group_id->name,'-') !== false){
			// Explode con -
			list($id_memb, $memb_name) = explode ("-",$memb->group_id->name); 
			if($id_memb && $memb_name){
				return $id_memb;
			}


		}else{
			// Explode con espacio
			return $memb;
		}


	}
}
if(!function_exists('validarSesion')){

// // si esta vencida la sesion redirige al login
     function validarSesion(){

		$userdata_email = $_SESSION['email'];
		
		if(isset($userdata_email)){
			;
			$userdata_email = $_SESSION['email'];
		}
		else{
			$userdata_email = '0';
		}

		if($userdata_email != '0') {
			log_message('DEBUG','#TRAZA |LOGIN | OK  >> Sesion Iniciada!!!');

			}
			else{
					redirect(DNATO.'main/logout');
					//echo base_url('Login/log_out');
					log_message('DEBUG','#TRAZA |LOGIN | ERROR  >> Sesion Expirada!!!');

					return;
			}


   }

}	


if(!function_exists('validarInactividad')){
	
	function validarInactividad(){			
		//Comprobamos si esta definida la sesión 'tiempo'.
		if(isset($_SESSION['tiempo']) ) {
			//Tiempo en segundos para dar vida a la sesión.
			$inactivo = 4000;//40min en este caso.
			//Calculamos tiempo de vida inactivo.
			$vida_session = time() - $_SESSION['tiempo'];
			//Compraración para redirigir página, si la vida de sesión sea mayor a el tiempo insertado en inactivo.
			if($vida_session > $inactivo){
				//Removemos sesión.
				session_unset();
				//Destruimos sesión.
				session_destroy();              
				//Redirigimos pagina.
				//Verificamos si la presente URL no debe validarse con Sesion sino con Token
				if (!validarUrlSinSesion() ){
					echo base_url('Login/log_out');
					log_message('DEBUG','#TRAZA |LOGIN | ERROR  >> Sesion Expirada!!!');						
					exit();
				}
			}else{
				//Refresco el tiempo luego de actividad
				//Verificamos si la presente URL no debe validarse con Sesion sino con Token
				if (!validarUrlSinSesion() ){
					validarSesion();
					$_SESSION['tiempo'] = time();
				}
			}
		} else {
			//Activamos sesion tiempo.
			$_SESSION['tiempo'] = time();
		}
	}
}
?>