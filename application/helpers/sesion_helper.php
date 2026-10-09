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

		// si usuario es usuario de deposito
		if (($nombreTarea == "Aprueba pedido de Recursos Materiales") || ($nombreTarea == "Entrega pedido pendiente") ) {

			$user_id = $userdata['id'];
			$ci =& get_instance();

			// obtiene los depósitos asignados al usuario
			$aux = $ci->rest->callAPI("GET",REST_CORE.'/depositos/encargado/'.$user_id);
			$aux =  json_decode($aux['data']);
    		$depositos = $aux->encargados->depositos;

			// Recorre todos los depósitos y verifica si no coinciden con $depo_id
			if ($depo_id != "" && is_array($depositos)) {
				$mostrar = false;
				foreach ($depositos as $deposito) {
					if ($deposito->depo_id == $depo_id) {
						$mostrar = true;
					}
				}
			} else {
				$mostrar = true; // Si no hay $depo_id se tiene que mostrar
			}
		}

		return $mostrar;
	}
}

/**
 * Devuelve los panoles a cargo del usuario logueado con su establecimiento
 * Es la fuente unica de la asignacion de panoles: de aca se derivan
 * filtrarbyPano() y establecimientosByPano(), para no repetir la llamada.
 * @return array con los panoles asignados (pano_id, esta_id, nombre, descripcion)
 */
if(!function_exists('encargadosByPano')){

	function encargadosByPano(){
		$ci =& get_instance();
		$userdata = $ci->session->userdata();
		$user_id  = $userdata['id'];

		if (empty($user_id)) {
			return array();
		}

		// obtiene los panoles asignados al usuario
		$aux = $ci->rest->callAPI("GET", REST_PAN.'/panol/encargado/usuario/'.$user_id);
		$aux = json_decode($aux['data']);

		$panoles = isset($aux->encargados->panoles) ? $aux->encargados->panoles : array();

		// WSO2 devuelve un objeto en vez de array cuando hay 1 solo resultado
		if (empty($panoles) || !is_array($panoles)) {
			$panoles = empty($panoles) ? array() : array($panoles);
		}

		return $panoles;
	}
}

/**
 * Devuelve los panoles a cargo del usuario logueado
 * Un mismo usuario puede estar a cargo de varios panoles, por eso se
 * devuelve una lista de pano_id y no un unico valor.
 * Si el usuario no tiene panoles asignados devuelve un array vacio, y el
 * llamador debe interpretar eso como "sin restriccion" (ve todo).
 * @return array con los pano_id asignados al usuario
 */
if(!function_exists('filtrarbyPano')){

	function filtrarbyPano(){
		$ci =& get_instance();
		$user_id = $ci->session->userdata('id');

		$pano_ids = array();
		foreach (encargadosByPano() as $pano) {
			if (isset($pano->pano_id)) {
				$pano_ids[] = $pano->pano_id;
			}
		}

		log_message('DEBUG','#TRAZA | SESION | filtrarbyPano() >> user_id: '.$user_id.' panoles: '.json_encode($pano_ids));

		return $pano_ids;
	}
}

/**
 * Devuelve los establecimientos de los panoles a cargo del usuario
 * Cada panol pertenece a un establecimiento (P.esta_id), asi que de los
 * panoles que administra el usuario se deducen los establecimientos que
 * puede usar.
 * Si el usuario no tiene panoles asignados devuelve un array vacio, y el
 * llamador debe interpretar eso como "sin restriccion" (ve todo).
 * @return array con los esta_id deducidos, sin repetidos
 */
if(!function_exists('establecimientosByPano')){

	function establecimientosByPano(){
		$ci =& get_instance();
		$user_id = $ci->session->userdata('id');

		$esta_ids = array();
		foreach (encargadosByPano() as $pano) {
			if (isset($pano->esta_id)) {
				$esta_ids[(string) $pano->esta_id] = $pano->esta_id;
			}
		}
		$esta_ids = array_values($esta_ids);

		log_message('DEBUG','#TRAZA | SESION | establecimientosByPano() >> user_id: '.$user_id.' establecimientos: '.json_encode($esta_ids));

		return $esta_ids;
	}
}

/**
 * Lee un campo de un registro que puede venir como objeto o como array
 * Necesario porque json_decode devuelve stdClass pero algunos modelos de PAN
 * arman arrays asociativos a mano, por ejemplo Orders::obtenerHerramientasPanol().
 * @param mixed registro
 * @param string campo
 * @return mixed|null
 */
if(!function_exists('valorCampo')){

	function valorCampo($registro, $campo){
		if (is_array($registro)) {
			return isset($registro[$campo]) ? $registro[$campo] : null;
		}

		return isset($registro->$campo) ? $registro->$campo : null;
	}
}

/**
 * Normaliza a array una respuesta de WSO2
 * json_decode devuelve un objeto cuando hay un solo resultado y un array
 * cuando hay varios; el resto del codigo asume siempre un array.
 * @param mixed lista
 * @return array
 */
if(!function_exists('normalizarLista')){

	function normalizarLista($lista){
		if (empty($lista) || !is_array($lista)) {
			return empty($lista) ? array() : array($lista);
		}

		return $lista;
	}
}

/**
 * Deja solo los establecimientos de los panoles a cargo del usuario
 * Si el usuario no tiene panoles asignados devuelve la lista completa, que
 * es el mismo criterio que usan los listados.
 * @param lista de {esta_id, nombre}
 * @return array
 */
if(!function_exists('filtrarEstablecimientosPorUsuario')){

	function filtrarEstablecimientosPorUsuario($establecimientos){
		$establecimientos = normalizarLista($establecimientos);

		$esta_ids = array_map('strval', establecimientosByPano());

		// sin panoles asignados no se restringe nada
		if (empty($esta_ids)) {
			return $establecimientos;
		}

		$establecimientos = array_values(array_filter($establecimientos, function ($establec) use ($esta_ids) {
			return in_array(strval(valorCampo($establec, 'esta_id')), $esta_ids, true);
		}));

		log_message('DEBUG','#TRAZA | SESION | filtrarEstablecimientosPorUsuario() >> esta_ids: '.json_encode($esta_ids).' encontrados: '.count($establecimientos));

		return $establecimientos;
	}
}

/**
 * Deja solo las herramientas que estan en el panol seleccionado
 * El listado que usan los formularios de salida y entrada es por estado
 * (ACTIVO / TRANSITO) y no viene filtrado por panol, asi que hay que cruzarlo
 * acá. Cada herramienta trae su pano_id porque /herramientas/estado/{estado}
 * lo devuelve. Se conserva la forma de cada herramienta para no cambiar el
 * contrato con el JS de orders/view_.php y unloads/view_.php.
 * @param lista de {herrId, herrcodigo, herrdescrip, herrmarca, pano_id, ...}
 * @return array
 */
if(!function_exists('filtrarHerramientasPorPano')){

	function filtrarHerramientasPorPano($herramientas){
		$herramientas = normalizarLista($herramientas);

		$ci =& get_instance();
		$pano_id = $ci->input->post('pano_id');

		// sin panol no se puede saber de que panol es la herramienta
		if (empty($pano_id)) {
			log_message('ERROR','#TRAZA | SESION | filtrarHerramientasPorPano() >> llego sin pano_id');

			return array();
		}

		$herramientas = array_values(array_filter($herramientas, function ($herr) use ($pano_id) {
			return strval(valorCampo($herr, 'pano_id')) === strval($pano_id);
		}));

		log_message('DEBUG','#TRAZA | SESION | filtrarHerramientasPorPano() >> pano_id: '.$pano_id.' encontradas: '.count($herramientas));

		return $herramientas;
	}
}

/**
 * Deja solo las herramientas que estan en un panol a cargo del usuario
 * A diferencia de filtrarHerramientasPorPano() NO mira el panol seleccionado:
 * se usa para la recepcion, donde la herramienta puede entrar en cualquier
 * panol del usuario y el unico requisito es que este en TRANSITO.
 * Si el usuario no tiene panoles asignados devuelve la lista completa, que
 * es el mismo criterio que usan el resto de los filtros por usuario.
 * @param lista de {herrId, herrcodigo, herrdescrip, herrmarca, pano_id, ...}
 * @return array
 */
if(!function_exists('filtrarHerramientasPorPanosDelUsuario')){

	function filtrarHerramientasPorPanosDelUsuario($herramientas){
		$herramientas = normalizarLista($herramientas);

		$pano_ids = array_map('strval', filtrarbyPano());

		// sin panoles asignados no se restringe nada
		if (empty($pano_ids)) {
			return $herramientas;
		}

		$herramientas = array_values(array_filter($herramientas, function ($herr) use ($pano_ids) {
			return in_array(strval(valorCampo($herr, 'pano_id')), $pano_ids, true);
		}));

		log_message('DEBUG','#TRAZA | SESION | filtrarHerramientasPorPanosDelUsuario() >> pano_ids: '.json_encode($pano_ids).' encontradas: '.count($herramientas));

		return $herramientas;
	}
}

/**
 * Indica si el usuario puede operar sobre un panol
 * Si el usuario no tiene panoles asignados no se restringe nada y devuelve
 * true, que es el mismo criterio que usan los listados y los desplegables.
 * @param pano_id
 * @return bool
 */
if(!function_exists('usuarioManejaPano')){

	function usuarioManejaPano($pano_id){
		$pano_ids = array_map('strval', filtrarbyPano());

		// sin panoles asignados no se restringe nada
		if (empty($pano_ids)) {
			return true;
		}

		return in_array(strval($pano_id), $pano_ids, true);
	}
}

/**
 * Deja solo los panoles a cargo del usuario
 * Si el usuario no tiene panoles asignados devuelve la lista completa, que
 * es el mismo criterio que usan los listados.
 * @param lista de {pano_id, nombre, ...}
 * @return array
 */
if(!function_exists('filtrarPanolesPorUsuario')){

	function filtrarPanolesPorUsuario($panoles){
		$panoles = normalizarLista($panoles);

		$pano_ids = array_map('strval', filtrarbyPano());

		// sin panoles asignados no se restringe nada
		if (empty($pano_ids)) {
			return $panoles;
		}

		$panoles = array_values(array_filter($panoles, function ($panol) use ($pano_ids) {
			return in_array(strval(valorCampo($panol, 'pano_id')), $pano_ids, true);
		}));

		log_message('DEBUG','#TRAZA | SESION | filtrarPanolesPorUsuario() >> pano_ids: '.json_encode($pano_ids).' encontrados: '.count($panoles));

		return $panoles;
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

        // Se devuelve SIEMPRE como string. Los DataServices declaran 2.314 de
        // sus 2.321 parametros como STRING, asi que un entero en el payload JSON
        // los rompe con "Value type miss match, Expected value type - string,
        // but found - NUMBER" y la operacion no se hace (hallazgo H-071).
        //
        // El tipo que tenia la sesion dependia de quien la escribio, y ya hubo
        // dos incidentes por eso: el empr_id temporal del registro definido como
        // entero (H-072) y los call sites que mandan empresa() sin castear
        // (H-073). Castear aca cubre los ~360 usos del helper de una vez, en vez
        // de arreglar cada payload por separado.
        //
        // Se preserva el null: quien no tiene sesion sigue recibiendo null y no
        // una cadena vacia, para no cambiar el comportamiento de los if.
        return $empr_id === null ? null : (string) $empr_id;
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