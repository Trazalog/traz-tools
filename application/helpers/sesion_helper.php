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
		$aux = $ci->rest->callAPI("GET",REST."/transportista/id/".$usernick);
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
		$aux = $ci->rest->callAPI("GET",REST."/solicitantesTransporte/".$usernick);
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

if(!function_exists('validarSesion')){

    function validarSesion(){
        $ci = &get_instance();
        $userdata = $ci->session->userdata('user_data');
        if(empty($userdata['email'])) redirect(base_url().'login/main/logout/'); 
    }

}