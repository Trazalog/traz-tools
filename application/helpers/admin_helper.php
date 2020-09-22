<?php defined('BASEPATH') OR exit('No direct script access allowed');

if(!function_exists('modal'))
{ 
    function modal($e)
    {
       return 
       "<div class='modal fade' id='$e->id'>
          <div class='modal-dialog'>
            <div class='modal-content'>
              <div class='modal-header'>
                <button type='button' class='close' data-dismiss='modal' aria-label='Close'>
                  <span aria-hidden='true'>&times;</span></button>
                <h4 class='modal-title'>$e->titulo</h4>
              </div>
              <div class='modal-body'>
                $e->body
              </div>
              <div class='modal-footer'>
                <button type='button' class='btn btn-default pull-left' data-dismiss='modal'>Close</button>
                ".(isset($e->accion)?"<button type='button' class='btn btn-primary btn-accion'>$e->accion</button>":null)."
              </div>
            </div>
          </div>
        </div>";
    }
}

if (!function_exists('bolita')) {
    function bolita($texto, $color, $detalle = null)
    {
        return

            '<span data-toggle="tooltip" title="' . $detalle . '" class="badge bg-' . $color . ' estado">' . $texto . '</span>';
    }

    function estadoPedido($estado)
    {
        switch ($estado) {
            case 'Creada':
                return bolita($estado, 'purple');
                break;
            case 'Solicitado':
                return bolita($estado, 'orange');
                break;
            case 'Aprobado':
                return bolita($estado, 'green');
                break;
            case 'Rechazado':
                return bolita($estado, 'red');
                break;
            case 'Ent. Parcial':
                return bolita($estado, 'blue');
                break;
            case 'Entregado':
                return bolita($estado, 'green');
                break;
            case 'Cancelado':
                return bolita($estado, 'red');
                break;
            default:
                return bolita('S/E', '');
                break;
        }
    }

    function estado($estado)
    {
        #   $estado =  trim($estado);

        switch ($estado) {

            //Estado Generales
            case 'AC':
                return bolita('Activo', 'green');
                break;
            case 'IN':
                return bolita('Inactivo', 'red');
                break;

            //Estado Camiones
            case 'ASIGNADO':
                return bolita('Asignado', 'blue');
                break;
            case 'EN CURSO':
                return bolita('En Curso', 'green');
                break;
            case 'FINALIZADO':
                return bolita('Finalizado', 'yellow');
                break;

            //Estado Etapas
            case 'En Curso':
                return bolita('En Curso', 'green');
                break;
            case 'finalizado':
                return bolita('Finalizado', 'yellow');
                break;

            //Estado por Defecto
            default:
                return bolita('S/E', '');
                break;
        }
    }

}


if (!function_exists('estado')) {

	function estado($estado)
	{
			#   $estado =  trim($estado);

			switch ($estado) {

					//Estado Generales
					case 'AC':
							return bolita('Activo', 'green');
							break;
					case 'IN':
							return bolita('Inactivo', 'red');
							break;

					//Estado Camiones
					case 'ASIGNADO':
							return bolita('Asignado', 'blue');
							break;
					case 'EN CURSO':
							return bolita('En Curso', 'green');
							break;
					case 'FINALIZADO':
							return bolita('Finalizado', 'yellow');
							break;

					//Estado Etapas
					case 'En Curso':
							return bolita('En Curso', 'green');
							break;
					case 'finalizado':
							return bolita('Finalizado', 'yellow');
							break;

					//Estado por Defecto
					default:
							return bolita('S/E', '');
							break;
			}
	}

}


?>