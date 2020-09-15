
<li class="treeview">
		<a href="#">
			<i class="fa fa-share"></i> <span>Nivel 1</span>
			<span class="pull-right-container">
				<i class="fa fa-angle-left pull-right"></i>
			</span>
		</a>
		<ul class="treeview-menu">	
			
				<li class="treeview">
						<a href="#"><i class="fa fa-circle-o"></i> Nivel 2
							<span class="pull-right-container">
								<i class="fa fa-angle-left pull-right"></i>
							</span>
						</a>
						<ul class="treeview-menu">
								
							<li><a href="#"><i class="fa fa-circle-o"></i> Nivel 3</a></li>
							
						</ul>
				</li>
		
		</ul>
</li>

********************respaldo funcionando
function menu($json, $aux = null)
    {				
				$item =  $json->menu_items->menu_item;
				//var_dump($item);die;
				 $item2 = $item;
				// $item3 = $item;
				$bandLevel2 = 0;
				$bandLevel3 = 0;

				$nivel1 = "";

				$ul = '<ul class="sidebar-menu" data-widget="tree">';

				foreach ($item as $value) {			
					$nivel1_Opcion = $value->opcion;
					
					// solo entra con nivel de raiz
					if($value->nivel == 1){
					
						$nivel1 .= '<li class="treeview">';						
						$nivel1 .= '<a href="#">
													<i class="fa fa-share"></i> <span>'.$value->texto.'</span>
													<span class="pull-right-container">
														<i class="fa fa-angle-left pull-right"></i>
													</span>
												</a>';
						foreach ($item2 as $valueLevel2){
								
								$nivel2_OPadre = $valueLevel2->opcion_padre;	
								// $cierreLiLevel2 = '</li>';
								if ( $nivel1_Opcion == $nivel2_OPadre ) { // opcion de nivel raiz == opcion hijo

										if ($bandLevel2 == 0) {

											$nivel2 .= '<ul class="treeview-menu">
																	<li class="treeview">';
											$nivel2 .= '<a href="#"><i class="fa fa-circle-o"></i>'.$valueLevel2->texto.'
																		
																	</a></li>'	;
											$bandLevel2 = 1;						
										} else {
													$nivel2 .= '<li class="treeview">';
													$nivel2 .= '<a href="#"><i class="fa fa-circle-o"></i>'.$valueLevel2->texto.'<span class="pull-right-container">
																				</span>
																			</a></li>'	;
										}		

								} 

						}
						// completa el nivel 2 
						$cierreLevel2 = '</ul>';
						$nivel2 .= $cierreLevel2;
						$bandLevel2 = 0;				
						// agrego el nivel 2 al nivel 1 y lo cierro
						$nivel1 .= $nivel2;
						$cierreLevel1 = '</li>';
						$nivel1 .= 	$cierreLevel1;
						// limpio la variable para no repetir los items
						$nivel2 = ""; 
					}		
					
				}

				return $ul.$nivel1.'</ul>';
		}



		//***************** */
								
		// foreach ($item3 as $valueLevel3){
			
		// 	$nivel3_OPadre = $valueLevel3->opcion_padre;	

		// 	if ( ($nivel2_Opcion == $nivel3_OPadre) && ($nivel2_OPadre == $nivel1_Opcion)  ) {
			
		// 		// $nivel3 .= '<ul>';
		// 		// $nivel3 .= '<li class="treeview">';
		// 		// $nivel3 .= '<a href="#"><i class="fa fa-circle-o"></i>'.$valueLevel3->texto.'<span class="pull-right-container">
		// 		// 									</span>
		// 		// 								</a></li>'	;	
				
		// 		if ($bandLevel3 == 0) {

		// 			$nivel3 .= '<ul class="treeview-menu">
		// 									<li class="treeview">';
		// 			$nivel3 .= '<a href="#"><i class="fa fa-circle-o"></i>'.$valueLevel3->texto.'
												
		// 									</a></li>'	;
		// 			$bandLevel3 = 1;						
		// 		} else {
		// 					$nivel3 .= '<li class="treeview">';
		// 					$nivel3 .= '<a href="#"><i class="fa fa-circle-o"></i>'.$valueLevel3->texto.'<span class="pull-right-container">
		// 												</span>
		// 											</a></li>'	;
		// 		}	
		// 	}										
		// }
		// //cierro nivel 3
		// $nivel3 .= '</ul>';	
		// // agrego el nivel 3 al nivel 2 
		// $nivel2 .= $nivel3;			
		// // limpio la variable para no repetir los items
		// $nivel3 = "";

	//*************** */



















