<?php defined('BASEPATH') or exit('No direct script access allowed');

if (!function_exists('form')) {
    function form($data)
    {
        $html = "<form id='$data->id' data-info='".(isset($data->info_id)?$data->info_id:null)."'>";
        foreach ($data->items as $key => $e) {
            switch ($e->tipo) {
                case 'titulo':
                    $html .= "<h$e->tam>$e->label</h$e->tam>";
                    break;
                case 'comentario':
                    $html .= "<p class='text-info'>$e->label</p>";
                    break;
                case 'input':
                    $html .= input($e);
                    break;
                case 'select':
                    $html .= select($e);
                    break;
                case 'date':
                    $html .= datepicker($e);
                    break;
                case 'check':
                    $html .= check($e);
                    break;
                case 'radio':
                    $html .= radio($e);
                    break;
                case 'file':
                    $html .= archivo($e);
                    break;
                case 'textarea':
                    $html .= textarea($e);
                    break;
                default:
                    $html .= "<hr>";
                    break;
            }
        }
        return $html . '<button class="btn btn-primary pull-right save-form">Guardar</button></form>';
    }
    function input($e)
    {
        return
            "<div class='form-group'>
                <label for=''>$e->label" . ($e->requerido ? "<strong class='text-danger'> *</strong>" : null) . ":</label>
                <input class='form-control' value='".(isset($e->valor)?$e->valor:null)."' type='text' placeholder='Escriba su Texto...' id='$e->name'  name='$e->name' " . ($e->requerido ? req() : null) . "/>
            </div>";
    }
    function select($e)
    {
        $val = '<option value=""> -Seleccionar- </option>';
        foreach ($e->values as $o) {
            $val .= "<option value='$o->value' ".((isset($e->valor) && $e->valor== $o->value)?'selected':null).">$o->label</option>";
        }
        return
            "<div class='form-group'>
            <label for=''>$e->label" . ($e->requerido ? "<strong class='text-danger'> *</strong>" : null) . ":</label>
            <select class='form-control' name='$e->name'>$val</select>
        </div>";
    }
    function datepicker($e)
    {
        return
            "<div class='form-group'>
                <label for=''>$e->label" . ($e->requerido ? "<strong class='text-danger'> *</strong>" : null) . ":</label>
                <input class='form-control datepicker' value='".(isset($e->valor)?$e->valor:null)."' type='text' placeholder='dd/mm/aaaa' id='$e->name'  name='$e->name' " . ($e->requerido ? req() : null) . " data-bv-date-format='DD/MM/YYYY' data-bv-date-message='Formato de Fecha Inválido'/>
            </div>";
    }
    function check($e)
    {
        $html = "";
        foreach ($e->values as $key => $o) {
            $html .= "<div class='checkbox'>
                                <label>
                                    <input type='checkbox' name='$e->name[]' class='flat-red' value='$o->value' " . ($key == 0 && $e->requerido ? req() : null) . ((isset($e->valor) && strpos("_".$e->valor,$o->value)>0?' checked':null)).">
                                    $o->label
                                </label>
                            </div>";
        }
        // $html .= "<input class='hidden' type='checkbox' name='$e->name[]' value=' ' checked>";
        return
            "<div class='form-group'><label>$e->label" . ($e->requerido ? "<strong class='text-danger'> *</strong>" : null) . ":</label><div style='margin-left: 10%;'> $html</div></div>";
    }
    function radio($e)
    {   
        $html = '';
        foreach ($e->values as $key => $o) {
            $html .= "<div class='radio'>
                        <label>
                            <input type='radio' name='$e->name' class='flat-red' value='$o->value' ".($key == 0 && $e->requerido ? req() : null)." ".((isset($e->valor) && $e->valor== $o->value)?'checked':null).">
                            $o->label
                        </label>
                    </div>";
        }
        return 
        "<div class='form-group'><label>$e->label" . ($e->requerido ? "<strong class='text-danger'> *</strong>" : null) . ":</label><div style='margin-left: 10%;'> $html</div></div>";
    }
    function archivo($e)
    {
        $file  = null;
        if(isset($e->valor)){
            $url = base_url(files.$e->valor);
            $file = " download='$e->valor' href='$url' ";
        }else{
            $file = "style='display: none;'";
        }
        return
            "<div class='form-group'>
                  <label>$e->label" . ($e->requerido ? "<strong class='text-danger'> *</strong>" : null) . ":</label>
                  <input id='$e->name' type='file' name='$e->name' ".($e->requerido ? req() : null)
                  .">
                  <p class='help-block show-file'><a $file class='help-button col-sm-4 download' title='Descargar' download><i
                    class='fa fa-download'></i> Ver Adjunto</a></p>
             </div><br>";
    }
    function textarea($e){
        return
         "<div class='form-group'>
            <label>$e->label</label>
            <textarea class='form-control' rows='3' placeholder='Ingrese Texto...' id='$e->name' type='file' name='$e->name' ".($e->requerido ? req() : null)
            .">".(isset($e->valor)?$e->valor:null)."</textarea>
        </div>";
    }

    
if (!function_exists('req')) {
    function req(){
        return  
        ' data-bv-notempty
          data-bv-notempty-message="Campo Obligatorio *" ';
    }
}

}