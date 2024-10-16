<?php defined('BASEPATH') or exit('No direct script access allowed');
class BPM
{
    private $CI;
    private $REST;

    public function __construct()
    {

        $this->REST = &get_instance()->rest;

    }

    public function getTodoList()
    {

        log_message('DEBUG', '#TRAZA | #BPM >> Obtener Bandeja de Entrada userID: ' . userId());

        $resource = 'API/bpm/humanTask?p=0&c=1000&f=user_id%3D'.userId().'&o=reachedStateDate%20DESC';

        $url = BONITA_URL . $resource;

        $rsp = $this->REST->callAPI('GET', $url, false, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_111);

            return $this->msj(false, ASP_111);

        }

        return $this->msj(true, 'OK', json_decode($rsp['data'], true));
    }

    public function getTarea($id)
    {

        $url = BONITA_URL . 'API/bpm/humanTask/' . $id;

				$rsp = $this->REST->callAPI('GET', $url, false, $this->loggin(userNick(), userPass()));
				

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_110);

            return $this->msj(false, ASP_110);

        }

        return $this->msj(true, 'OK', json_decode($rsp['data'], true));
    }

    public function ObtenerTaskidXNombre($proccesId, $caseId, $nombre) //!FALTA TERMINAR

    {
        $actividades = $this->ObtenerActividades($proccesId, $caseId);

        if ($actividades == null) {
            return 0;
        }

        for ($i = 0; $i < count($actividades); $i++) {

            if ($actividades[$i]["displayName"] == $nombre) {

                return $actividades[$i]["id"];

            }
        }

        return 0;
    }

    public function cerrarTarea($idTarBonita, $contract = null)
    {
        $method = '/execution';

        $resource = 'API/bpm/userTask/';

        $url = BONITA_URL . $resource . $idTarBonita . $method;

        $rsp = $this->REST->callAPI('POST', $url, $contract, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_104);

            return $this->msj(false, ASP_104);

        }

        return $this->msj(true, 'OK');
    }

    // Lanza proceso en BPM
  
    public function lanzarProceso($processId, $contract)
    {
        $resource = 'API/bpm/process/';

        $url = BONITA_URL . $resource . $processId . '/instantiation';

		
         $rsp = $this->REST->callAPI('POST', $url, $contract, $this->loggin(userNick(), userPass()));
        

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> lanzarProceso  >>' . ASP_101);

            return $this->msj(false, ASP_101);

        }

        $dato = json_decode($rsp['data']);
		$resp = $this->setCaseEmpresa($dato->caseId);

        return $this->msj(true, 'OK', json_decode($rsp['data'], true));
    }



    public function ObtenerLineaTiempo($processId, $caseId)
    {
        $param = $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS);

        $data['listAct'] = $this->ObtenerActividades($processId, $caseId, $param);

        $data['listArch'] = $this->ObtenerActividadesArchivadas($processId, $caseId, $param);

        return $data;
    }

    // Obtiene Actividades desde BPM por id de caso
    public function ObtenerActividades($processId, $caseId)
    {
        $url = BONITA_URL . 'API/bpm/activity?p=0&c=200&f=processId%3D' . $processId . '&f=rootCaseId%3D' . $caseId . '&d=assigned_id';

        $rsp = $this->REST->callAPI('GET', $url, false, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_105 . ' | proccesId: ' . $processId . ' | caseId: ' . $caseId);

            return $this->msj(false, ASP_105);

        }

        $array = json_decode($rsp['data'], true);

        $ord = array();

        foreach ($array as $key => $value) {

            if ($value['type'] == 'MULTI_INSTANCE_ACTIVITY') {unset($array[$key]);}

        }

        foreach ($array as $key => $value) {

            $ord[] = strtotime($value['last_update_date']);

        }

        array_multisort($ord, SORT_DESC, $array);

        return $array;
    }


  /**
		*Elimina Case_id en BPM 
		* @param //$processId, $caseId, $session.
		* @return array json
		**/
    public function eliminarCaso($processId, $caseId)
    {
        
    // DELETE http://10.142.0.13:8280/tools/bpm/proceso/instancia 
  //  {"caseid":"11208","session":"fruta"}

       // $resource = '/proceso/instancia';

       // $url = REST_API_BPM . $resource ;

       $url = REST_API_BPM;
       
        $data = array(
            "caseid" => $caseId,
            "session" => 'fruta'
    
        );

        $rsp = $this->REST->callAPI('DELETE', $url, $data, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        $status = ($rsp['status']);

            if ($status == true) {

            log_message('DEBUG', '#TRAZA | #BPM - Eliminar Caso >> Se Elimino Caso Correctamente');

            return $rsp;

        } elseif ($status == false) {

            log_message('ERROR', '#TRAZA | #BPM - Eliminar Caso >> NO Se Elimino Caso');

            /*
            Analizar si se updatea de nuevo el pedido para cambiar el estado de true a false
            en tabla de pedidos
            */

            return $rsp;

        } else {

            log_message('ERROR', '#TRAZA | #BPM - Eliminar Caso >> NO Se Elimino Caso - ERROR TREMENDO');

          //  $this->eliminarPedidoTrabajo($petr_id);

            return $rsp;


        }
    }


    // Obtiene Actividades Archivadas desde BPM por id de caso
    public function ObtenerActividadesArchivadas($processId, $caseId)
    {
        $url = BONITA_URL . 'API/bpm/archivedActivity?p=0&c=200&f=processId%3D' . $processId . '&f=rootCaseId%3D' . $caseId . '&d=assigned_id';

        $rsp = $this->REST->callAPI('GET', $url, false, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        $array = json_decode($rsp['data'], true);

        $ord = array();

        foreach ($array as $key => $value) {

            if ($value['type'] == 'MULTI_INSTANCE_ACTIVITY') {unset($array[$key]);}

        }

        foreach ($array as $key => $value) {

            $ord[] = strtotime($value['last_update_date']);
        }

        array_multisort($ord, SORT_DESC, $array);

        return $array;
    }

    // Comentarios
    public function ObtenerComentarios($caseId)
    {
        $processInstance = 'processInstanceId%3D' . $caseId;

        $url = BONITA_URL . 'API/bpm/comment?f=' . $processInstance . '&o=postDate%20DESC&p=0&c=200&d=userId';

        $rsp = $this->REST->callAPI('GET', $url, false, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_112);

            return $this->msj(false, ASP_112);

        }

				//        return $this->msj(true, 'OK', json_decode($rsp['data'], true));
          return json_decode($rsp['data'], true);
    }

    public function guardarComentario($caseId)//$caseId, $comentario
    {
        $data = $caseId;
        // $data = array(
        //     'processInstanceId' => $caseId,
        //     'content' => $comentario,
        // );

        $url = BONITA_URL . 'API/bpm/comment';

        $rsp = $this->REST->callAPI('POST', $url, $data, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_108);

            return $this->msj(false, ASP_108);

        }

     //        return $this->msj(true, 'OK', json_decode($rsp['data'], true));
     return json_decode($rsp['data'], true);
    }

    public function actualizarIdOT($caseId, $ot)
    {

        $contract = array(
            "type" => "java.lang.Integer",
            "value" => (integer) $ot,
        );

        $variableName = '/execution';
        $resource = 'API/bpm/caseVariable/';
        $variableName = 'gIdOT';
        $url = BONITA_URL . $resource . $caseId . "/" . $variableName;

        $rsp = $this->REST->callAPI('PUT', $url, $contract, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_114 . ' | Variable: ' . $variableName . ' | Contract: ' . json_encode($contract));

            return $this->msj(false, ASP_114);

        }

        return $this->msj(true, 'OK');

    }

    public function getCaseVariable($caseId, $var)
    {

        $var = '/' . $var;

        $url = BONITA_URL . 'API/bpm/caseVariable/' . $caseId . $var;

        $rsp = $this->REST->callAPI('GET', $url, null, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_115 . ' | Variable: ' . $var . ' | caseId: ' . $caseId);

            return $this->msj(false, ASP_115);

        }

        return $this->msj(true, 'OK', json_decode($rsp['data'])->value);
    }

    public function getActivityVariable($taskId, $var)
    {

        $urlResource = 'API/bpm/activityVariable/' . $taskId . '/' . $var;

        $rsp = $this->REST->callAPI('GET', BONITA_URL . $urlResource, null, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_115 . ' | Variable: ' . $var . ' | taskId: ' . $taskId);

            return $this->msj(false, ASP_115);

        }

        return $this->msj(true, 'OK', json_decode($rsp['data'])->value);

    }

    public function setUsuario($task, $user)
    {
        $contract = array(
            "assigned_id" => $user,
        );

        $resource = 'API/bpm/humanTask/';

        $url = BONITA_URL . $resource . $task;

        $rsp = $this->REST->callAPI('PUT', $url, $contract, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_107 . ' | Task: ' . $task . ' | Contract: ' . json_encode($contract));

            return $this->msj(false, ASP_107);

        }

        return $this->msj(true, 'OK');
    }

    public function getUser($user)
    {
        $list = $this->getUsuariosBPM();

        if (!$list['status']) {return $this->msj(false, ASP_106);}

        foreach ($list['data'] as $o) {

            if ($o['userName'] == $user) {

                return $this->msj(true, 'OK', $o);

            }

        }

        log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_113);

        return $this->msj(false, ASP_113);
    }

    public function getUsuariosBPM()
    {
        $resource = 'API/identity/user?p=0&c=50000'; // siempre debe haber un numero alto por la cantidad de usr

        $url = BONITA_URL . $resource;

        $rsp = $this->REST->callAPI('GET', $url, false, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_106);

            return $this->msj(false, ASP_106);

        }

        return $this->msj(true, 'OK', json_decode($rsp['data'], true));
    }

    // Con usrId local devuelve usr en BPM
    public function getInfoSisUserenBPM($usrId)
    {

        $CI = &get_instance();
        $CI->load->database();
        $CI->db->select('sisusers.usrNick');
        $CI->db->from('sisusers');
        $CI->db->where('sisusers.usrId', $usrId);
        $query = $CI->db->get();
        $usrNick = $query->row('usrNick');

        $idUsrBPM = $this->getUser($usrNick);
        return $idUsrBPM;
    }

		// con userIdBpm devuelve las memberships de ese usuario
		public function getMemeberships($userIdBpm){

				log_message('DEBUG', '#TRAZA | #BPM >> Obtener Bandeja de Entrada userID: ' . userId());

				$resource = 'API/identity/membership?p=0&c=10&f=user\_id%3d';

				$url = BONITA_URL . $resource .$userIdBpm .'&d=role\_id';

				$rsp = $this->REST->callAPI('GET', $url, false, $this->loggin(BPM_ADMIN_USER, BPM_ADMIN_PASS));

				if (!$rsp['status']) {

						log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_111);
						return $this->msj(false, ASP_111);
				}

				return $this->msj(true, 'OK', json_decode($rsp['data'], true));
		}

    public function loggin($user, $pass)
    {
        $data = array(
            'username' => $user,
            'password' => $pass,
            'redirect' => 'false',
        );

        $url = BONITA_URL . 'loginservice';

        $rsp = $this->REST->callAPI('GET', $url, $data, false);

        if (!$rsp['status']) {

            log_message('DEBUG', '#TRAZA | #BPM >> ' . ASP_109);
            //validaSesionBPM();
            return false;

        }

        return $this->crearHeader($rsp['header']);
    }

    public function crearHeader($headers)
    {
        $headers = explode("\r\n", $headers);

        // extrae cookies para que sea dinamico el cambio
        $idsesion = explode(';', explode('JSESSIONID=', $headers[2])[1])[0];
        $bonita_tenant = explode('bonita.tenant=', $headers[1])[1];
        $apiToken = explode(';', explode('X-Bonita-API-Token=', $headers[3])[1])[0];

        $parametros = array(
            // "X-Bonita-API-Token: " . $apiToken,
            // "Cookie: JSESSIONID=" . $idsesion . ";X-Bonita-API-Token=" . $apiToken . ";bonita.tenant=" . $bonita_tenant,
            // "Content-Type: application/json;"
            "Cookie: bonita_tenant=" . $bonita_tenant . ";JSESSIONID=" . $idsesion . ";X-Bonita-API-Token=" . $apiToken,
            "X-Bonita-API-Token: " . $apiToken,
            "Content-Type: application/json",
        );

        return $parametros;
    }

    public function msj($status, $msj, $data = false)
    {
        return array(
            'status' => $status,
            'msj' => $msj,
            'data' => $data,
        );
    }

	/**
		* Agrega la relacion case_id con empr_id desp de lanzar PROCESOS
		* @param string case_id
		* @returnarray con mensaje depandiendo del resultado
		*/
		function setCaseEmpresa($caseid){

            $empr_id = empresa();

			log_message('DEBUG','#TRAZA|BPM|setCaseEmpresa($caseid) >> '.json_encode($caseid));
			log_message('DEBUG','#TRAZA|BPM|setCaseEmpresa($caseid)  $empr_id>> '.json_encode($empr_id));

           $string_case_id = (string)$caseid;

			$data = array("case_id"=>$string_case_id,"empr_id"=>$empr_id);

			$CI = &get_instance();
			$CI->load->database();
			$resp = $CI->db->insert('core.case_empresa', $data);

			if ($resp === FALSE) {

				log_message('ERROR','#TRAZA|BPM|setCaseEmpresa($caseid) >> ERROR No se actualizó la tabla core.case_empresa con el case_id');
				return $this->msj(false, 'No se guardo el case_id');
			} else {

				log_message('INFO','#TRAZA|BPM|setCaseEmpresa($caseid) >> Guardado Exitoso');
				return $this->msj(true, 'Guardado exitosamente');
			}

		}

}