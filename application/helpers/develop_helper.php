<?php defined('BASEPATH') OR exit('No direct script access allowed');

if(!function_exists('getJson'))
{ 
    function getJson($file, $show = false)
    {
        $url = base_url('json/') .  $file . '.json';
        $rsp = json_decode(file_get_contents($url));
        if($show)
        {
            //echo var_dump($rsp);
            echo $rsp;
        }else
        {
            return $rsp;
        }
    }

    function wso2Msj($rsp)
    {
        $rsp['data'] = json_decode( $rsp['data']);
        $msj = $rsp['data']->Fault->faultstring;
        preg_match('~>>([^{]*)<<~i', $msj, $match);
        log_message('DEBUG', '#WSO2 #RESPONCE: ' . $match[1]);
    }
}
?>