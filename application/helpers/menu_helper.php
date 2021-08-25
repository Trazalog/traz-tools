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
      //var_dump($item);
      $nivel1 = "";
      $nivel1_habilitado = 0;
      $subniv_habilitado = 0;
      $nivel2_Hab = "";
      $nivel2_No_Hab = "";
      $band_niv2_habilitado = 0;

      // apertura de menu en sidebar
      $ul_apertura_menu = '<ul class="sidebar-menu" data-widget="tree">';
			$ul_cierre_menu = '</ul>';

      foreach ($item as $value) {

        $habilitado = $value->habilitado;

        // si el item es NIVEL 1
        if($value->nivel == '1'){

            $nivel1_Opcion =$value->opcion;

            if($habilitado == "true"){
              // seteo a 1 para saber si hay un nivel 1 vigente
              $nivel1_habilitado = 1;

              // si $subniv_habilitado = 1 => cierro nivel 2 y nivel 1
              if ($subniv_habilitado == 1) {
                $nivel1 .= '</ul>';
                $nivel1 .= 	'</li>';
                //seteo para nueva iteracion de nivel 2
                $band_niv2_habilitado = 0;
              }

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

        // si el item es NIVEL 2
        if ($value->nivel == '2'){

            // SI ES SUBNIVEL 2 Y PERTENECE A OPCION PADRE VIGENTE
            $nivel2_OPadre = $value->opcion_padre;
            if( $nivel1_Opcion == $nivel2_OPadre ){

                if($nivel1_habilitado == 1){

                    //entra la primera vez
                    if ($subniv_habilitado == 0) {

                        // seteo a 1 para saber q hay opciones hab de nivel 2
                        $subniv_habilitado = 1;
                        //si el item esta habilitado
                        if($habilitado == "true") {

                            // seteo si hay por lo menos 1 item habilitado
                            $band_niv2_habilitado = 1;

                            $nivel2_Hab .= '<ul class="treeview-menu">
                            <li class="treeview">';
                            $nivel2_Hab .= "<a href='#' title='$value->texto_onmouseover' onclick='linkTo(\"$value->url\")'><i class='$value->url_icono'></i>$value->texto</a>";
                            $nivel2_Hab .= '</li>';

                            $menu_nivel2_Hab .= $nivel2_Hab;

                        } else {

                            $nivel2_No_Hab .= '<ul class="treeview-menu">
                            <li class="treeview">';
                            $nivel2_No_Hab .= "<a href='#' title='$value->texto_onmouseover' onclick='linkTo(\"$value->url\")'><i class='$value->url_icono'></i>$value->texto</a>";
                            $nivel2_No_Hab .= '</li>';

                            $menu_nivel2_No_Hab .= $nivel2_No_Hab;
                        }

                    } else {  // agrega las opc hijas a partir de 2º entrada

                        if($habilitado == "true") {

                            $nivel2_Hab .= '<li class="treeview">';
                            $nivel2_Hab .= "<a href='#' title='$value->texto_onmouseover' onclick='linkTo(\"$value->url\")'><i class='$value->url_icono'></i>$value->texto</a>";
                            $nivel2_Hab .= '</li>';

                            $menu_nivel2_Hab .= $nivel2_Hab;
                        }else{

                            $nivel2_No_Hab .= '<li class="treeview">';
                            $nivel2_No_Hab .= "<a href='#' title='$value->texto_onmouseover' onclick='linkTo(\"$value->url\")'><i class='$value->url_icono'></i>$value->texto</a>";
                            $nivel2_No_Hab .= '</li>';

                            $menu_nivel2_No_Hab .= $nivel2_No_Hab;
                        }
                    }
                    // si al menos un item nivel 2 esta habilitado guarda habilitados
                    if ($band_niv2_habilitado == 1) {
                      $nivel1 .= $nivel2_Hab;
                    } else {
                      $nivel1 .= $menu_nivel2_No_Hab;
                    }

                    //limpio  variables para no repetir el subnivel
                    $nivel2_Hab = "";

                    $menu_nivel2_No_Hab = "";
                    $nivel2_No_Hab = "";

                }

            }

        }

      }

      return $ul_apertura_menu .$nivel1. $ul_cierre_menu;

    }
}



