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
        $data = '{
            "lotes": {
              "lote": [
                {
                  "batch_id": "875",
                  "level": "3",
                  "arti_descripcion": "Ajo Cosechado. / VARIEDAD: Chino convencional",
                  "arti_barcode": "PP0001",
                  "lote_fec_alta": "28-01-2021",
                  "reci_tipo": "PRODUCTIVO",
                  "path_lote_id": "LF2801_03 | LF2801_03 | LF2801_3",
                  "etap_nombre": "Finca",
                  "batch_id_padre": null,
                  "path": "877-876-875",
                  "lote_estado": "En Curso",
                  "lote_num_orden_prod": "OLF2801_3",
                  "reci_nombre": "N12",
                  "lote_id": "LF2801_3"
                },
                {
                  "batch_id": "870",
                  "level": "4",
                  "arti_descripcion": "Ajo Clasificado. / VARIEDAD: Chino convencional. / CALIBRE: 7",
                  "arti_barcode": "PR0015",
                  "lote_fec_alta": "28-01-2021",
                  "reci_tipo": "PRODUCTIVO",
                  "path_lote_id": "LF2801_03 | LF2801_03 | LF2801_02 | LF2801_02",
                  "etap_nombre": "Finca",
                  "batch_id_padre": null,
                  "path": "877-876-871-870",
                  "lote_estado": "En Curso",
                  "lote_num_orden_prod": "OLF2801_01",
                  "reci_nombre": "Chotintintan",
                  "lote_id": "LF2801_02"
                },
                {
                  "batch_id": "871",
                  "level": "3",
                  "arti_descripcion": "Ajo Cosechado. / VARIEDAD: Chino convencional",
                  "arti_barcode": "PP0001",
                  "lote_fec_alta": "28-01-2021",
                  "reci_tipo": "DEPOSITO",
                  "path_lote_id": "LF2801_03 | LF2801_03 | LF2801_02",
                  "etap_nombre": "DEPOSITO",
                  "batch_id_padre": "870",
                  "path": "877-876-871",
                  "lote_estado": "En Curso",
                  "lote_num_orden_prod": "OLF2801_01",
                  "reci_nombre": "Descarga 2",
                  "lote_id": "LF2801_02"
                },
                {
                  "batch_id": "876",
                  "level": "2",
                  "arti_descripcion": "Ajo Clasificado. / VARIEDAD: Chino convencional. / CALIBRE: 7",
                  "arti_barcode": "PR0015",
                  "lote_fec_alta": "28-01-2021",
                  "reci_tipo": "PRODUCTIVO",
                  "path_lote_id": "LF2801_03 | LF2801_03",
                  "etap_nombre": "Finca",
                  "batch_id_padre": "871",
                  "path": "877-876",
                  "lote_estado": "FINALIZADO",
                  "lote_num_orden_prod": "OLF2801_03",
                  "reci_nombre": "N13",
                  "lote_id": "LF2801_03"
                },
                {
                  "batch_id": "876",
                  "level": "2",
                  "arti_descripcion": "Ajo Clasificado. / VARIEDAD: Chino convencional. / CALIBRE: 7",
                  "arti_barcode": "PR0015",
                  "lote_fec_alta": "28-01-2021",
                  "reci_tipo": "PRODUCTIVO",
                  "path_lote_id": "LF2801_03 | LF2801_03",
                  "etap_nombre": "Finca",
                  "batch_id_padre": "875",
                  "path": "877-876",
                  "lote_estado": "FINALIZADO",
                  "lote_num_orden_prod": "OLF2801_03",
                  "reci_nombre": "N13",
                  "lote_id": "LF2801_03"
                },
                {
                  "batch_id": "877",
                  "level": "1",
                  "arti_descripcion": "Ajo Cosechado. / VARIEDAD: Chino convencional",
                  "arti_barcode": "PP0001",
                  "lote_fec_alta": "28-01-2021",
                  "reci_tipo": "DEPOSITO",
                  "path_lote_id": "LF2801_03",
                  "etap_nombre": "DEPOSITO",
                  "batch_id_padre": "876",
                  "path": "877",
                  "lote_estado": "En Curso",
                  "lote_num_orden_prod": "OLF2801_03",
                  "reci_nombre": "preSO",
                  "lote_id": "LF2801_03"
                }
              ]
            }
          }';
          $data = json_decode($data)->lotes->lote;
          $arbol = array();
          foreach ($data as $o) {
              $arbol[$o->level][$o->batch_id] = $o;
          }
          for ($i=sizeof($arbol); $i <= 1 ; $i--) { 
             foreach ($arbol[$i] as $o) {
                 $arbol[$i-1][$o->bat]
             }
          }
          show($arbol);
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
