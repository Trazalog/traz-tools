<?php defined('BASEPATH') or exit('No direct script access allowed');

class REST
{
    public function callAPI($method, $url, $data = null, $token = array())
    {
        log_message('DEBUG', '#TRAZA | #REST | #CURL | #URL >> ' . $url);

        try {
            $curl = curl_init();
            $data = is_array($data)?json_encode($data):$data;
            switch ($method) {
                case "POST":
                    curl_setopt($curl, CURLOPT_POST, true);
                    if ($data) {
                        curl_setopt($curl, CURLOPT_POSTFIELDS, $data);
                        array_push($token, 'Content-Type: application/json');
                        log_message('DEBUG', '#TRAZA | #REST | #CURL | #PAYLOAD >> ' . $data);
                    } else {
                        curl_setopt($curl, CURLOPT_POSTFIELDS, null);
                    }

                    break;
                case "PUT":
                    curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "PUT");
                    if ($data) {
                        curl_setopt($curl, CURLOPT_POSTFIELDS, $data);
                        array_push($token, 'Content-Type: application/json');
                        log_message('DEBUG', '#TRAZA | #REST | #CURL | #PAYLOAD >> ' . $data);
                    }

                    break;

                case "DELETE":
                    curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "DELETE");
                    if ($data) {
                        curl_setopt($curl, CURLOPT_POSTFIELDS, $data);
                        array_push($token, 'Content-Type: application/json');
                        log_message('DEBUG', '#TRAZA | #REST | #CURL | #PAYLOAD >> ' . $data);
                    }

                    break;
                default:
                    if (!strpos($url, 'bonita')) {
                        array_push($token, 'Accept: application/json');
                    }

                    if ($data && !is_numeric($data)) {
                        $url = sprintf("%s?%s", $url, http_build_query(json_decode($data)));
                    }

            }

            // OPTIONS:
            curl_setopt($curl, CURLOPT_URL, $url);
            curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($curl, CURLOPT_HEADER, true);
            curl_setopt($curl, CURLINFO_HEADER_OUT, true);
            //SON PARA YUDICA, NO TIENE CERTIF SSL
            curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, 0);
            curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, 0);

            //Tell cURL that it should only spend 10 seconds
            //trying to connect to the URL in question.
            curl_setopt($curl, CURLOPT_CONNECTTIMEOUT, 30);

            //A given cURL operation should only take
            //30 seconds max.
            curl_setopt($curl, CURLOPT_TIMEOUT, 30);

            if ($token) {

                curl_setopt($curl, CURLOPT_HTTPHEADER, $token);

            }

            // EXECUTE:
            $result = curl_exec($curl);

            $headerSent = curl_getinfo($curl, CURLINFO_HEADER_OUT);

            if (!$result) {
                log_message('DEBUG', '#TRAZA | #REST | #CURL >> Fallo Conexión');
                throw new Exception(curl_error($curl), curl_errno($curl));
                return ['status' => false, 'header' => false, 'data' => false, 'code' => '404'];
            }

            $response_code = curl_getinfo($curl, CURLINFO_HTTP_CODE);

            $header_size = curl_getinfo($curl, CURLINFO_HEADER_SIZE);

            $headers = substr($result, 0, $header_size);

            $body = substr($result, $header_size);

            curl_close($curl);
            if ($response_code >= 300) {

                // log_message('DEBUG', '#TRAZA | #REST | #CURL | #HTTP_CODE >> ' . $response_code);

                // log_message('DEBUG', '#TRAZA | #REST | #CURL | #HEADER RESPUESTA>> ' . $headers);

                // log_message('DEBUG', '#TRAZA | #REST | #CURL | #BODY >> ' . json_encode($body));

                log_message('ERROR', '#TRAZA | #REST | #CURL | #HTTP_CODE >> ' . $response_code);
                log_message('ERROR', '#TRAZA | #REST | #CURL | #HEADER SALIDA >> ' . $headerSent);
                log_message('ERROR', '#TRAZA | #REST | #CURL | #HEADER SALIDA BODY >> ' . json_encode($data));

                log_message('ERROR', '#TRAZA | #REST | #CURL | #HEADER RESPUESTA >> ' . $headers);
                log_message('ERROR', '#TRAZA | #REST | #CURL | #BODY >> ' . json_encode($body));

            }

            return ['status' => ($response_code < 300), 'header' => $headers, 'data' => $body, 'code' => $response_code];

        } catch (Exception $e) {

            trigger_error(sprintf(
                'Curl failed with error #%d: %s',
                $e->getCode(), $e->getMessage()),
                E_USER_ERROR);

        }
    }

}
