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
      $subniv_habilitado = 0;
      $cont = 0;

      // apertura de menu en sidebar
      $ul_apertura_menu = '<ul class="sidebar-menu" data-widget="tree">';
			$ul_cierre_menu = '</ul>';

      foreach ($item as $value) {

        $habilitado = $value->habilitado;

        // si el item es NIVEL 1
        if($value->nivel == 1){

            if($habilitado == "true"){
              // if($nivel1_Opcion != $value->opcion){

              //    cierro opcion item nivel 1 ( segunda pasada)
              //    pego subnivel 2 y abro nivel 1 nuevamete
              //    $nivel1_Opcion = $value->opcion;

              // }

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


            }

            if($subniv_habilitado == 1){
              echo "hay items en TRUE";
            }else{
              echo "todos los items estan en FALSE";
            }
            $cont++;
        }

        // si el item es NIVEL 2
        if ($value->nivel == 2){

          // recorrer todos hasta qe cambie la opcion padre
          $nivel2_OPadre = $value->opcion_padre;
          if($nivel1_Opcion == $nivel2_OPadre){
              echo $value->texto."    ";

              if($habilitado == "true"){
                echo "Subnivel TRUE";
                // cambio bandera para saber q hay opciones habilitadas de a una
                $subniv_habilitado = 1;
                // agrego el subitem
                // $itemsSimples += nivel2($item);
              }else{
                echo "Subnivel FALSE";
                // agrego subitems
                // $itemsCompestos += nivel2($item);
              }
          }

        }
      }
      echo "contador: ";
      var_dump($cont);

      return $ul_apertura_menu .$nivel1. $ul_cierre_menu;

    }
}



