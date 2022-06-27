<?php defined('BASEPATH') or exit('No direct script access allowed');
/**
* Controlador de Notificaciones 
*
* @autor Rogelio Sanchez
*/
 
class Notificacion extends CI_Controller
{
    public function __construct(){
        parent::__construct();
        $this->load->model('Notificaciones');
		
		// si esta vencida la sesion redirige al login
		$data = $this->session->userdata();
		if(!$data['email']){
			log_message('DEBUG','#TRAZA | #TRAZ-COMP-NOTIFICACIONES | __construct | ERROR  >> Sesion Expirada!!!');
			redirect(DNATO.'main/login');
		}
    }
    /**
     * Write code on Method
     *
     * @return response()
     */
    public function index()
    {    
        log_message('DEBUG','#TRAZA | #TRAZ-COMP-NOTIFICACIONES | Notificacion| index()');
        $this->load->view('test_view');
    }
    
    /**
     * Write code on Method
     *
     * @return response()
    */
    public function sendPushNotification(){  
         
        // $val = $this->validate([
        //     'nId' => 'required',
        // ]);
        $dipositivo = $this->input->post('dispositivo');
        $noti_id = $this->input->post('noti_id');
        // $notification_id = $this->request->getVar('nId');

        $title = 'Demo Notification'; 
        $message = 'First codeigniter notification for mobile';
        // $d_type = $this->request->getVar('device_type');
 
        $accesstoken = 'AAAAiH5SNuQ:APA91bHnxXwO7ujdaR_nPhAF3mtTTZ6fy6pOq4l45flSnCjTctc1ROuzLjgbU4iKIZe14dgVG2gylTMIcJJq5TYvRJLRKoWRDB0rufVjjicuU2GtHlHySaMMbYlc5G_UOChJ68OHz1iQ';
 
        $URL = 'https://fcm.googleapis.com/fcm/send';
        // $URL = 'https://fcm.googleapis.com/v1/projects/myproject-b5ae1/messages:send';
 
            $post_data = '{
                "to" : "' . $noti_id . '",
                "data" : {
                    "body" : "",
                    "title" : "' . $title . '",
                    "type" : "' . $dipositivo . '",
                    "id" : "' . $noti_id . '",
                    "message" : "' . $message . '",
                },
                "notification" : {
                    "body" : "' . $message . '",
                    "title" : "' . $title . '",
                    "type" : "' . $dipositivo . '",
                    "id" : "' . $noti_id . '",
                    "message" : "' . $message . '",
                    "icon" : "new",
                    "sound" : "default"
                },
 
            }';
 
        $crl = curl_init();
 
        $headr = array();
        $headr[] = 'Content-type: application/json';
        $headr[] = 'Authorization: key=' . $accesstoken;
        curl_setopt($crl, CURLOPT_SSL_VERIFYPEER, false);
 
        curl_setopt($crl, CURLOPT_URL, $URL);
        curl_setopt($crl, CURLOPT_HTTPHEADER, $headr);
 
        curl_setopt($crl, CURLOPT_POST, true);
        curl_setopt($crl, CURLOPT_POSTFIELDS, $post_data);
        curl_setopt($crl, CURLOPT_RETURNTRANSFER, true);
        log_message("DEBUG","ESTO >> ".json_encode($crl));
        $rest = curl_exec($crl);
 
        if ($rest === false) {
            $result_noti = 0;
            $rsp['status'] = false;
            $rsp['msg'] = "Errorsito perri";
        } else {
            $result_noti = 1;
            $rsp['status'] = true;
            $rsp['msg'] = "Todo correcto";
        }
        echo json_encode($rsp);
    }
}