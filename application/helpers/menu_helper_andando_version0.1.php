<?php defined('BASEPATH') OR exit('No direct script access allowed');
/**
* helper que arma el menu general en funcion de permisos y niveles
*
* @autor Hugo Gallardo
*/

if(!function_exists('menu')){

    function menu($json, $aux = null)
    {
      $item =  $json->menu_items->menu_item;
      $nivel1 = "";
      $itemsSimples = "";
      $itemsCompestos = "";
      $nivel1_habilitado = 0;
      $subniv_habilitado = 0;
      $cont = 0;

      // apertura de menu en sidebar
      $ul_apertura_menu = '<ul class="sidebar-menu" data-widget="tree">';
			$ul_cierre_menu = '</ul>';

      foreach ($item as $value) {

        $habilitado = $value->habilitado;

        // si el item es NIVEL 1
        if($value->nivel == '1'){

            $nivel1_Opcion =$value->opcion;

            if($habilitado == "true"){
              // seteo a 1 para sabeer si hay un nivel 1 vigente
              $nivel1_habilitado = 1;

              // si $subniv_habilitado = 1 => debo cerrar nivel 2
              if ($subniv_habilitado == 1) {
                $nivel1 .= 	'</ul>';
                $nivel1 .= 	'</li>';
              }
              // sino cierro nivel 1 y lo vuelvo a abrir
              // seteo en 0 los subniveles para saber si debo cerrar nivel 1
              $subniv_habilitado = 0;

              $nivel1 .= '<li class="treeview">';
              if ($value->url == "") {
                  $nivel1 .= '<a href="#" title="'.$value->texto_onmouseover.'">
                                  <i class="'.$value->url_icono.'"></i> <span>'.$value->texto.'</span>
                                  <span class="pull-right-container">
                                    <i class="fa fa-angle-left pull-right"></i>
                                  </span>
                                </a>';
              } else {
                  $nivel1 .= "<a href='#' title='$value->texto_onmouseover' onclick='linkTo(\"$value->url\")'><i class='$value->url_icono'></i>".$value->texto."</a>";
              }
            }else{ // nivel 1 no habilitado
              //seteo a 0 para volever a entrar a nivel 1
              $nivel1_habilitado = 0;
            }
        }

        if ($value->nivel == '2'){
            // SI ES SUBNIVEL 2 Y PERTENECE A OPCION PADRE VIGENTE
            $nivel2_OPadre = $value->opcion_padre;
            if( $nivel1_Opcion == $nivel2_OPadre ){

                if($nivel1_habilitado == 1){

                    //entra la primera vez
                    if ($subniv_habilitado == 0) {

                        $nivel2 .= '<ul class="treeview-menu">
                                    <li class="treeview">';
                        $nivel2 .= "<a href='#' title='$value->texto_onmouseover' onclick='linkTo(\"$value->url\")'><i class='$value->url_icono'></i>$value->texto</a>";
                        $nivel2 .= '</li>';
                        // seteo a 1 para saber q hay opciones habilitadas nivel 2
                        $subniv_habilitado = 1;

                    } else {  // agrega las opciones hijas

                        $nivel2 .= '<li class="treeview">';
                        $nivel2 .= "<a href='#' title='$value->texto_onmouseover' onclick='linkTo(\"$value->url\")'><i class='$value->url_icono'></i>$value->texto</a>";
                        $nivel2 .= '</li>';
                    }
                    // agrrego el nivel 2 a la cadena armada
                    $nivel1 .= $nivel2;
                    //limpio  variable para no repetir el subnivel
                    $nivel2 = "";

                }

            }else{

              $nivel2 .= '</ul>'; //cierro nivel padre
              $nivel1 .= $nivel2;

            }

        }

      }
      // echo "hay subnivel: ";
       //echo($nivel1);

      return $ul_apertura_menu .$nivel1. $ul_cierre_menu;

    }
}



