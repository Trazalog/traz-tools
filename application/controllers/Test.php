<?php defined('BASEPATH') or exit('No direct script access allowed');

class Test extends CI_Controller
{
    public function __construct()
    {
        parent::__construct();
    }

    public function index()
    {
      show(wso2('http://10.142.0.7:8280/services/COREDataService/tablas/tipos_no_consumibles'));
    }

    public function sesion()
    {
        show($this->session->userdata());
    }


}
