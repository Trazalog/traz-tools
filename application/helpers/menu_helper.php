<?php defined('BASEPATH') OR exit('No direct script access allowed');

if(!function_exists('menu')){
							
    function menu($json, $aux = null)
    {
				$item =  $json->menu_items->menu_item;
				$item2 = $item;
				$nivel1 = "";

				$ul_apertura_menu = '<ul class="sidebar-menu" data-widget="tree">';
				$ul_cierre_menu = '</ul>';
				log_message('INFO','#TRAZA|MENU_HELPER|MENU >> ');
				foreach ($item as $value) {			

					$nivel1_Opcion = $value->opcion;
					$habilitado = $value->habilitado;

					if($habilitado == "true"){

							// solo entra con nivel de raiz
							if($value->nivel == 1){

									$nivel1 .= '<li class="treeview">';

									if ($value->url == "") {
											$nivel1 .= '<a href="#">
																			<i class="fa fa-share"></i> <span>'.$value->texto.'</span>
																			<span class="pull-right-container">
																				<i class="fa fa-angle-left pull-right"></i>
																			</span>
																		</a>';
									} else {
											$nivel1 .= "<a href='#' onclick='linkTo(\"$value->url\")'><i class='fa fa-share-square'></i>".$value->texto."</a>";
									}

									// arma 2º y 3º nivel
									$nivel2 = nivel2($item2, $nivel1_Opcion);
									// agrego el nivel 2 al nivel 1 y lo cierro
									$nivel1 .= $nivel2;
									$nivel1 .= 	'</li>';
									// limpio la variable para no repetir los items
									$nivel2 = "";
							}

					}

				}

				return $ul_apertura_menu .$nivel1. $ul_cierre_menu;				
		}


		function nivel2($items, $nivel1_Opcion ){
			
				log_message('INFO','#TRAZA|MENU_HELPER|NIVEL2 >> ');
				$nivel2 = "";
				$bandLevel2 = 0;

				foreach ($items as $valueLevel2){

						$nivel2_Opcion = $valueLevel2->opcion;
						$nivel2_OPadre = $valueLevel2->opcion_padre;	
				
						if ( $nivel1_Opcion == $nivel2_OPadre ) { // opcion de nivel raiz == opcion hijo
								
								if ($bandLevel2 == 0) {

											$nivel2 .= "<ul class='treeview-menu'>
																	<li class='treeview'>";												
											$nivel2 .= "<a href='#' onclick='linkTo(\"$valueLevel2->url\")'><i class='fa fa-circle-o'></i>".$valueLevel2->texto."</a>";
											$nivel2 .= "</li>";
											$bandLevel2 = 1;
								} else {

											$nivel2 .= "<li class='treeview'>";												
											$nivel2 .= "<a href='#' onclick='linkTo(\"$valueLevel2->url\")'><i class='fa fa-circle-o'></i>".$valueLevel2->texto."</a>";
											$nivel2 .= "</li>";						
								}	
						}

						$nivelActual = $valueLevel2->nivel;
						$camino = $valueLevel2->camino;
						$array = explode(">", $camino);
						$array2 = explode(".", $array[0]);
						
						$abu = $array2[2];
						if ( ($nivelActual == 3) && ($opcionAnterior = $nivel2_OPadre) && ($abu == $nivel1_Opcion)) {

								$nivel3 = nivel3($valueLevel2);								
						}
						$opcionAnterior = $nivel2_Opcion;							
				}

				if (isset($nivel3)) {
					$nivel2 .= $nivel3;
				}					
				// completa el nivel 2 						 
				$nivel2 .= '</ul>';		

				return $nivel2;		
		}

		function nivel3($valueLevel3){

				log_message('INFO','#TRAZA|MENU_HELPER|NIVEL3 >> ');
				$nivel3 = "";
				$nivel3 .= '<li class="treeview">';			
				$nivel3 .= "<a href='#' onclick='linkTo(\"$valueLevel3->url\")'><i class='fa fa-circle-o'></i>".$valueLevel3->texto."</a>";
				$nivel3 .= '</li>';
							
				return $nivel3;
		}	
}
