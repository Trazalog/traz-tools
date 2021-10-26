<?php defined('BASEPATH') OR exit('No direct script access allowed');

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
		$aux = $ci->rest->callAPI("GET",REST_PRD."/transportista/id/".$usernick);
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
		$aux = $ci->rest->callAPI("GET",REST_PRD."/solicitantesTransporte/".$usernick);
		$aux =json_decode($aux["data"]);
		return $aux->solicitantes_transporte->sotr_id;
	}
}

/**
* Devuelve coincidencia de deposito con usuario asignado a deposito
* @param
* @return bool true o false
*/
if(!function_exists('filtrarbyDepo')){

	function filtrarbyDepo($nombreTarea, $depo_id = null)
	{
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
		$group = $memb->group_id->name;
		$group = explode("-", $group);
		return $group[0];

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
    $inactivo = 60;//20min en este caso.

    //Calculamos tiempo de vida inactivo.
    $vida_session = time() - $_SESSION['tiempo'];

        //Compraración para redirigir página, si la vida de sesión sea mayor a el tiempo insertado en inactivo.
        if($vida_session > $inactivo)
        {
            //Removemos sesión.
            session_unset();
            //Destruimos sesión.
            session_destroy();              
            //Redirigimos pagina.
		
			log_message('DEBUG','#TRAZA |LOGIN | ERROR  >> Sesion Expirada!!!');
			
	
			?>
			<script>
				Swal.fire({
				icon: 'error',
				title: 'Oops...',
				text: 'Something went wrong!',
				footer: '<a href="">Why do I have this issue?</a>'
				})

			</script>
			<?php
			
			redirect(DNATO.'main/logout');

            exit();
        }
} else {
    //Activamos sesion tiempo.
    $_SESSION['tiempo'] = time();
}
}
	}



	?>