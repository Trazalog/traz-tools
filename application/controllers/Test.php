<?php defined('BASEPATH') or exit('No direct script access allowed');

class Test extends CI_Controller
{
    public function __construct()
    {
        parent::__construct();
        $this->load->model('Tests');
    }

    public function wso()
    {
        $data = 'id_notaPedido, fecha, justificacion, estado';
        $data = explode(', ', $data);
        foreach ($data as $o) {
            $xdata[$o] = "$$o";
        }

        show($xdata);
    }

    public function index()
    {
      $this->load->view('pedidos_trabajo/dash', $data);
    }

    public function view()
    {
        $data = $this->input->get();
        $this->load->view('testView', $data);
    }
}
