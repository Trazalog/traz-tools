<?php defined('BASEPATH') or exit('No direct script access allowed');

class Test extends CI_Controller
{
    public function __construct()
    {
        parent::__construct();
        $this->load->model('Tests');
    }

    public function test()
    {
        $this->load->model(FRM.'Forms');
        echo form($this->Forms->obtenerXEmpresa('Entrega Materiales', 1));
    }

    public function wso()
    {
        $data = 'descripcion, marca, codigo, ubicacion, estado, fecha_ultimalectura, ultima_lectura, tipo_horas, valor_reposicion, fecha_reposicion, valor, comprobante, descrip_tecnica, numero_serie, adjunto, meta_disponibilidad, fecha_ingreso, fecha_baja, fecha_garantia, prov_id, empr_id, sect_id, ubic_id, grup_id, crit_id, unme_id, area_id, proc_id, usuario_app, usuario, eliminado';
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
