<?php defined('BASEPATH') or exit('No direct script access allowed');

class Test extends CI_Controller
{
    public function __construct()
    {
        parent::__construct();
    }

    public function index()
    {
      $this->load->view('pedidos_trabajo/dash');
    }

    public function view()
    {
        $data = $this->input->get();
        $this->load->view('testView', $data);
    }

    public function pedidosTrabajos()
    {
        $this->load->view('pedidos_trabajo/lista_pedidos');
    }

    public function hitos($petaId)
    {
        $this->load->view('pedidos_trabajo/lista_hitos');
    }


}
