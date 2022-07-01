<?php defined('BASEPATH') or exit('No direct script access allowed');
/**
* Controlador de Notificaciones 
*
* @autor Rogelio Sanchez
*/
require_once('./lib/google-api-php-client/vendor/autoload.php');
use Google\Client;
use Google\Service\Docs;
class Notificacion extends CI_Controller
{
    public function __construct(){
        parent::__construct();
        $this->load->model('Notificaciones');
		// $this->load->library('google-api-php-client/vendor/autoload.php');
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
        // $client = new Google\Client();
        // $client->setApplicationName("Client_Library_Examples");
        // $client->setDeveloperKey("AAAAiH5SNuQ:APA91bHnxXwO7ujdaR_nPhAF3mtTTZ6fy6pOq4l45flSnCjTctc1ROuzLjgbU4iKIZe14dgVG2gylTMIcJJq5TYvRJLRKoWRDB0rufVjjicuU2GtHlHySaMMbYlc5G_UOChJ68OHz1iQ");
        // $client->setDeveloperKey("AIzaSyD-D8C5EuzKsYxAfIKJeps-IPT3RUEuQjU");
        
        // $service = new Google\Service\Books($client);
        // $query = 'Henry David Thoreau';
        // $optParams = [
        //   'filter' => 'free-ebooks',
        // ];
        // $results = $service->volumes->listVolumes($query, $optParams);
        
        // foreach ($results->getItems() as $item) {
        //   echo $item['volumeInfo']['title'], "<br /> \n";
        // }
        // putenv('GOOGLE_APPLICATION_CREDENTIALS=/path/to/keyfile.json');
        // $cloud = new Service();
        // $val = $this->validate([
        //     'nId' => 'required',
        // ]);
        $dipositivo = $this->input->post('dispositivo');
        // $noti_id = $this->input->post('noti_id');
        $noti_id = "fbklobO7nfXFAP1eNHAK_K:APA91bHqCSOwHAOd0_QogsWSgtx8YVnS3MOIMh0MvnQxVG_joCqGTnVc2p3STy0orwtXbh8rT1WegZKw45aUdiHDV91p3EdmddP325JnTTOKh99s0GtpHSLp0vC5nd-9jGNDFQqpamm1";

        $title = 'Demo Notification'; 
        $message = 'First codeigniter notification for mobile';
        // $d_type = $this->request->getVar('device_type');
 
        $accesstoken = 'AAAAiH5SNuQ:APA91bHnxXwO7ujdaR_nPhAF3mtTTZ6fy6pOq4l45flSnCjTctc1ROuzLjgbU4iKIZe14dgVG2gylTMIcJJq5TYvRJLRKoWRDB0rufVjjicuU2GtHlHySaMMbYlc5G_UOChJ68OHz1iQ';
 
        // $URL = 'https://fcm.googleapis.com/fcm/send';
        $URL = 'https://fcm.googleapis.com/v1/projects/baupedistribuidora-3eee5/messages:send';
        // El parametro 'to:' es el TOKEN del dispositivo, es decir el generado en la funcion getToken()
            $post_data = '{
                "to" : "' . $noti_id . '",
                "data" : {
                    "body" : "",
                    "title" : "' . $title . '",
                    "type" : "' . $dipositivo . '",
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
        $headr[] = 'Authorization: Bearer ' . $accesstoken;
        curl_setopt($crl, CURLOPT_SSL_VERIFYPEER, false);
 
        curl_setopt($crl, CURLOPT_URL, $URL);
        curl_setopt($crl, CURLOPT_HTTPHEADER, $headr);
 
        curl_setopt($crl, CURLOPT_POST, true);
        curl_setopt($crl, CURLOPT_POSTFIELDS, $post_data);
        curl_setopt($crl, CURLOPT_SSL_VERIFYHOST, 0);
        curl_setopt($crl, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($crl, CURLOPT_RETURNTRANSFER, true);
        $rest = json_decode(curl_exec($crl));
        log_message("DEBUG","#TRAZA | #TRAZ-COMP-NOTIFICACIONES | Notificacion >>>>>> respuesta servicio : ".$rest); 
        if ($rest->error->status === 'UNAUTHENTICATED') {
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

    function haceAlgo(){
        $client = new Google_Client();

        // Authentication with the GOOGLE_APPLICATION_CREDENTIALS environment variable
        $client->useApplicationDefaultCredentials(); 

        // Alternatively, provide the JSON authentication file directly.
        $client->setAuthConfig('./lib/baupedistribuidora-3eee5-7ea477122da1.json');

        // Add the scope as a string (multiple scopes can be provided as an array)
        $client->addScope('https://www.googleapis.com/auth/firebase.messaging');

        // Returns an instance of GuzzleHttp\Client that authenticates with the Google API.
        //El token se genera luego del ->post y se encuentra en httpClient->config->handler->stack[4][0]->tokenCallback->this->token->access_token
        $httpClient = $client->authorize();

        // Your Firebase project ID
        $project = "baupedistribuidora-3eee5";

        // Creates a notification for subscribers to the debug topic
        $message = [
            "message" => [
                "topic" => "algo",
                "notification" => [
                    "body" => "This is an FCM notification message!",
                    "title" => "FCM Message",
                ]
            ]
        ];

        // Send the Push Notification - use $response to inspect success or errors
        $response = $httpClient->post("https://fcm.googleapis.com/v1/projects/{$project}/messages:send", ['json' => $message]);
        // $respuesta['status'] = $respose->statusCode; privada
        // $respuesta['message'] = $response->reasonPhrase;privada
        echo json_encode($response);
    }
}