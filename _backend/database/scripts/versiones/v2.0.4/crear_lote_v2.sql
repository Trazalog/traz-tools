CREATE OR REPLACE FUNCTION prd.crear_lote_v2(p_lote_id character varying, p_arti_id integer, p_prov_id integer, p_batch_id_padre bigint, p_cantidad double precision, p_cantidad_padre double precision, p_num_orden_prod character varying, p_reci_id integer, p_etap_id integer, p_usuario_app character varying, p_empr_id integer, p_forzar_agregar character varying DEFAULT 'false'::character varying, p_fec_vencimiento date DEFAULT NULL::date, p_recu_id integer DEFAULT NULL::integer, p_tipo_recurso character varying DEFAULT NULL::character varying, p_planificado character varying DEFAULT 'false'::character varying, p_batch_id bigint DEFAULT NULL::bigint,p_fec_alta timestamp default null::TIMESTAMP)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
/** @version v1.3
 *  Funcion para generar un nuevo lote, y finalizar los lotes padres en la cadena productiva
 *  Recibe como parametro un id de lote
 *  y un recipiente donde crear el batch.
 *  Si el recipiente esta ocupado, devuelve el error con un mensaje para que el usuario tome una decisión 
 *  y vuelva a llamar a la funcion con p_forzar_agregar = treu
 *  p_lote_id character varying Código de lote a generar
 *  p_arti_id integer  Articulo a asociar como PRODUCTO en el nuevo lote, si es 0 es un lote sin PRODUCTO
 *  p_prov_id integer  Proveedor del articulo a generar
 *  p_batch_id_padre bigint Batch Id del lote padre, si viene 0 es un lote al inicio de la cadena productiva y no tiene padre
 *  p_cantidad double precision Cantidad a generar en stock del nuevo 
 *  p_cantidad_padre double precision Cantidad a descontar del lote padre informado (si fue informado)
 *  p_num_orden_prod character varying Orden de producción asociada al lote
 *  p_reci_id integer Id de recipiente a asociar al nuevo lote
 *  p_etap_id integer Id de Etapa productiva (prd.etapas) al cual representa este lote
 *  p_usuario_app character varying usuario que genera el lote
 *  p_empr_id integer Id de empresa
 *  p_forzar_agregar character varying DEFAULT c_false::character varying Bandera que fuerza a unificar lotes con 
                                                                       distinto articulo o id de lote en un mismo recipiente por 
                                                                       petición del usuario. Si viene en false, y el recipiente 
                                                                       esta LLENO, informará en una excepction TOOLSERROR si es 
                                                                       mismo arituclo  o lote 
 *  p_fec_vencimiento date DEFAULT NULL::date fecha de vencimiento del actual lote
 *  p_recu_id integer DEFAULT NULL::integer Recurso de trabajo asociado a la generación del lote, por ejemplo operario
 *  p_tipo_recurso character varying DEFAULT NULL::character varying  tipo del recurso informado
 *  p_planificado character varying DEFAULT c_false::character varying Si es true, genera un lote en modo PLANIFICADO, no generando 
                                                                    información de stock y permitiendo utilziar recipientes LLENOS 
                                                                    para un futuro uso
 *  p_batch_id bigint DEFAULT NULL::bigint Informa si estamos trabajando sobre un batch existente ya, por ej: era un batch PLANIFICADO que vamos a Iniciar
 *  p_fec_alta timestamp DEFAULT NULL:timestamp Fecha informada de inicio de producción del lote, si viene null se usa la fecha actual
 *  *  RETURNS character varying Batch id generado
 *  @author RRuiz
 */
#print_strict_params on
DECLARE
 v_estado_recipiente prd.recipientes.estado%type; 
 v_batch_id prd.lotes.batch_id%type;
 v_batch_id_aux prd.lotes.batch_id%type;
 v_mensaje varchar;
 v_reci_id_padre prd.recipientes.reci_id%type;
 v_depo_id prd.recipientes.depo_id%type;
 v_lote_id prd.lotes.lote_id%type;
 v_arti_id alm.alm_lotes.arti_id%type;
 v_cantidad_padre alm.alm_lotes.cantidad%type;
 v_recu_id prd.recursos_lotes.recu_id%type;
 v_resultado varchar;
 v_estado varchar;
 v_cantidad float;
 v_cuenta integer;
 v_artDif boolean = false;
 v_lotDif boolean = false;
 v_lotartIgual boolean = false;
 v_countLotesRec integer = 0;
 v_info_error varchar;
 v_step varchar = '0';
 v_index integer = 1;
 c_en_curso constant varchar := 'En Curso';
 c_planificado constant varchar  := 'PLANIFICADO';
 c_finalizado constant varchar := 'FINALIZADO';
 c_vacio constant varchar := 'VACIO';
 c_lleno constant varchar := 'LLENO';
 c_true constant varchar := 'true';
 c_false constant varchar := 'false';

 verificarRecipiente CURSOR (p_batch_id INTEGER
			   ,p_arti_id INTEGER
			   ,p_lote_id VARCHAR)for 
			   				select lo.batch_id
							,case when al.arti_id is null then 0 else al.arti_id end arti_id
							,case when lo.lote_id is null then '' else lo.lote_id end lote_id
							from prd.lotes lo
							left join alm.alm_lotes al on lo.batch_id = al.batch_id
							where reci_id  = p_reci_id
							and ((al.arti_id != p_arti_id or al.arti_id is null) or (lo.lote_id != p_lote_id or lo.lote_id is null))
							and lo.estado = c_en_curso ;


BEGIN
		
		/* seteo el estado inicial dependiendo si se llama al procedure desde Guardar o desde Planificar estapa */
		if (p_planificado=c_true) then
			v_estado = c_planificado;
		else
			v_estado = c_en_curso;
		end if;
		
		/**************************
		 * BLOQUE 1: VALIDO EL ESTADO DEL RECIPIENTE Y SI NO ESTA VACIO PIDO AL USUARIO TOMAR ACCION
		 */
	    v_step='1';
		begin
		        
			RAISE INFO 'PRDCRLO - BL1 valido reci - ṕ_forzar_agregar = %, p_lote_id % ', p_forzar_agregar, p_lote_id;

			/** Valido que el recipiente exista **/
			select reci.estado
				   ,reci.depo_id
			into strict v_estado_recipiente
				,v_depo_id
			from PRD.RECIPIENTES reci
			where reci.reci_id = p_reci_id;

				       
	    	/*
		 	* 1 - si forzar_agregar = false, verifica si el recipiente esta vacio, si no esta vacio 
		 	*  a) verifica si en el recipiente esta el mismo articulo, sino retorna RECI_NO_VACIO_DIST_ART
		 	*  b) si es mismo articulo y distinto lote retorna RECI_NO_VACIO_DIST_LOTE_IGUAL_ART
		 	*  c) si es mismo arituclo y lote retorna RECI_NO_VACIO_MISMO_IGUAL_ART_LOTE
                	*/	
	    	v_step='2';
    
			if v_estado_recipiente = c_lleno then
				open verificarRecipiente(p_reci_id,p_arti_id,p_lote_id);
				loop
					fetch verificarRecipiente into v_batch_id_aux ,v_arti_id,v_lote_id;
					exit when NOT FOUND;
      
       				if v_arti_id != p_arti_id then 
       					RAISE DEBUG 'PRDCRLO - revisando recipientes batch v_arti_id p arti id % % %',v_batch_id_aux,v_arti_id,p_arti_id;
						v_artDif = true;
					elsif v_lote_id != p_lote_id then
       					RAISE DEBUG 'PRDCRLO - revisando recipientes batch v_lote_id p lote id % >%< >%<',v_batch_id_aux,v_lote_id,p_lote_id;
						v_lotDif = true;					        		
					else 
						v_lotartIgual = true;
					end if;
				end loop;
				close verificarRecipiente;
				RAISE INFO 'PRDCRLO - revisando recipientes banderas % % %',v_artDif,v_lotDif,v_lotartIgual;
			    v_step='3';

			
				/* Corto la ejecución, hay que advertir al usuario que el recipiente no esta vacio y que decida que hacer **/
	    		if p_forzar_agregar=c_false and p_planificado = c_false then
	
	    			v_info_error = 'reci_id='||p_reci_id||'-arti_id='||p_arti_id||'-lote_id='||p_lote_id;
					if v_artDif then
			            v_mensaje = 'RECI_NO_VACIO_DIST_ART'; /* caso a */
						raise exception 'RECI_NO_VACIO_DIST_ART-%',v_info_error;
					elsif v_lotDif then
			            v_mensaje = 'RECI_NO_VACIO_DIST_LOTE_IGUAL_ART'; /* caso b */
				    	raise exception 'RECI_NO_VACIO_DIST_LOTE_IGUAL_ART-%',v_info_error;
					else
			            v_mensaje = 'RECI_NO_VACIO_IGUAL_ART_LOTE'; /* caso c */
				    	raise exception 'RECI_NO_VACIO_IGUAL_ART_LOTE-%',v_info_error;
					end if;
				else	
					if v_lotartIgual then
						v_artDif = false;
						v_lotDif = false;
					end if;
				end if;	
	
			end if;
				  
		exception	   
			when too_many_rows then
		        RAISE INFO 'PRDCRLO - error 9 - recipiente duplicado %', p_reci_id;
				v_mensaje = 'RECI_DUPLICADO';
		        raise exception 'RECI_DUPLICADO:%',p_reci_id;

			when NO_DATA_FOUND then
		        RAISE INFO 'PRDCRLO - error 2 - recipiente no encontrado %', p_reci_id;
				v_mensaje = 'RECI_NO_ENCONTRADO';
		        raise exception 'RECI_NO_ENCONTRADO:%',p_reci_id;
		       
		end;	
		v_step='4';

   /*******************************************
    * BLOQUE 2 CREO O REUTILIZO LOTE
    * 
    * Una vez validado el recipiente, creo el nuevo lote
    * si forzar agregar = true, entonces
    *  para el caso a) crea un nuevo lote con mismo reci_id (unifica recipientes)
    *  para el caso b) crea un nuevo lote con mismo reci_id (unifica recipientes)
    *  para el caso c) actualiza la existencia del lote con mismo arti y lote (unifica lote)
     **/

    RAISE INFO 'PRDCRLO - BL2  lote -  v_estado_recipiente % v_artDif % v_lotDif % ', v_estado_recipiente,v_artDif,v_lotDif;
		
    /* CAMINO 1: Si es un lote planificado o si unifica recipientes o unifica lote */
    if ( p_planificado = c_true or ( v_estado_recipiente = c_vacio or  v_artDif or  v_lotDif ) )then
   
	begin

			v_step='5';
             /* CASO 1: Si p_batch_id no viene vacio me informan un batch id existente, 
               es decir viene de un batch guardado pero no iniciado, no lo inserto sino actualizo el batch, puede ser que 
               este actualizando los datos del planificado o bien iniciando, depende de si p_planificado es true o false */


    		if p_batch_id is not null and p_batch_id != 0 then
    			RAISE INFO 'PRDCRLO - reu lote -  v_estado = %, p_lote_id % y v_batch_id %: ', v_estado, p_lote_id, p_batch_id;

    			v_batch_id = p_batch_id;
    			
    			with updated_batch as (
	    			update prd.lotes 
	    			set lote_id = p_lote_id
	    				,estado = v_estado
	    				,num_orden_prod = p_num_orden_prod
	    				,reci_id = p_reci_id
	    				,usuario_app_ult_modificacion  = p_usuario_app 
	    				,fec_planificado = case when v_estado = c_planificado then now() else fec_planificado end 
	    				,fec_iniciado  = case when v_estado = c_en_curso then 
	    									case when p_fec_alta is null then now() else p_fec_alta end
	    								 else null::timestamp end
	    			where batch_id = v_batch_id
	    			returning 1)
	    			
				select count(1)
				from updated_batch
				into strict v_cuenta;
                
                /* Si no actualizó nada, el batch_id no existia */
				if v_cuenta = 0 then
			    	    RAISE INFO 'PRDCLO - no se encontro el batch id % cuenta % ', p_batch_id,v_cuenta;
			    	    raise 'BATCH_NO_ENCONTRADO';
			    end if;
    			
				    		
    		ELSE
             /* CASO 2 - no se informa p_batch_id existente, genero un nuevo lote **/
    		    v_step='6';

    		    RAISE INFO 'PRDCRLO - ins lote -  p_lote_id % ', p_lote_id;

				with inserted_batch as (
					insert into 
					prd.lotes (
					lote_id
					,estado
					,num_orden_prod
					,etap_id
					,usuario_app
					,reci_id
					,empr_id
					,fec_planificado
					,fec_iniciado)	
					values (
					p_lote_id
					,v_estado
					,p_num_orden_prod
					,p_etap_id
					,p_usuario_app
					,p_reci_id
					,p_empr_id
					,case when v_estado = c_planificado then now() else null::TIMESTAMP  end 
					,case when v_estado = c_en_curso  then 
						case when p_fec_alta is null then now() else p_fec_alta end 
					 else null::TIMESTAMP END
					)
					returning batch_id
				)

				select batch_id
				into strict v_batch_id
				from inserted_batch;

				RAISE INFO 'PRDCRLO - ins lote -  v_batch_id % ', v_batch_id;

			end if;
		
			/** si estay grabando planificado no debo lockear el recipiente */
			if v_estado != c_planificado then		
			    
			    /** Actualizo el recipiente como lleno
			     */
			    update prd.recipientes 
			    set estado = c_lleno
			    where reci_id = p_reci_id;

			end if;
						
		    v_step='7';

	   exception
		   when others then
		        RAISE INFO 'PRDCRLO - error 5 - error creando lote y recipiente  %:% ',sqlstate,sqlerrm;
			v_mensaje = 'BATCH_NO_ENCONTRADO';
		        raise exception 'BATCH_NO_ENCONTRADO:%',sqlerrm;
		   end;
    else /** CAMINO 2: Existe un recipiente lleno con mismo arti_id y lote_id que el lote que queremos crear, no lo creo sino unifico **/
	begin
			RAISE INFO 'PRDCRLO - nada con lote -  p_forzar_agregar = %', p_forzar_agregar;

	        select lo.batch_id
	        into strict v_batch_id
	        from prd.lotes lo
	             ,alm.alm_lotes al
	        where reci_id  = p_reci_id
            and lo.lote_id = p_lote_id 
	        and al.arti_id = p_arti_id
			and lo.batch_id = al.batch_id
	        and lo.estado = c_en_curso;

	       	/** Venia de un lote planificado, que al unificarse con uno existente lo damos por finalizado */
	        if p_batch_id is not null and p_batch_id != 0 then 
	        	update prd.lotes 
	        	set estado = c_finalizado 	
	        	    ,usuario_app_ult_modificacion  = p_usuario_app 
	        	    ,fec_finalizado = now()
	        	where batch_id = p_batch_id;
	        end if;
			v_step='8';

    exception
		   when NO_DATA_FOUND then
		        RAISE INFO 'PRDCRLO - error 20 - error buscando lote para unificar reci,lote,arti:%:%:% error %:% ',p_reci_id,p_lote_id,p_arti_id,sqlstate,sqlerrm;
			v_mensaje = 'BATCH_NO_ENCONTRADO';
		        raise exception 'BATCH_NO_ENCONTRADO:%',sqlerrm;
		   end;
				  
    end if;

   
    /********************************************************************************
     * BLOQUE 3: PADRES
     * ASOCIACION CON LOTES PADRE Y ACTUALIZACION ESTADOS Y DE CANTIDADES
     * 
     */
	RAISE INFO 'PRDCRLO - BL3 -  padres -  estado % batch id padre %',v_estado,p_batch_id_padre;

    if v_estado !=  c_planificado  then
		v_step='9';

    	/** Actualizo el arbol de batchs colocando el 
	     *  nuevo batch como hijo del p_batch_id_padre
	     * si el padre viene en 0 es un batch al inicio 
	     * del proceso productivo 
	     */
		insert into prd.lotes_hijos (
		batch_id
		,batch_id_padre
		,empr_id
		,cantidad
		,cantidad_padre)
		values
		(v_batch_id
		,case when p_batch_id_padre = 0 then null else p_batch_id_padre end
		,p_empr_id
		,p_cantidad
		,p_cantidad_padre);
		
		RAISE INFO 'PRDCRLO - Batch id % generado en recipiente %',v_batch_id,p_reci_id;
	
	    /**Cambiamos el estado del lote padre  a FINALIZADO si ya no quedan existencias
		 * y vacio el recipiente
		 */
		if (p_batch_id_padre !=0 ) then

                --Obtengo la existencia actual del padre para entender si finalizar
                v_step='10';

                begin
                    v_cantidad_padre = alm.obtener_existencia_batch(p_batch_id_padre);
                exception 
                    when others then
                        RAISE INFO 'PRDCRLO - no hay lote asociado, asumimos que es un batch sin producto %:%:% ',p_batch_id_padre,sqlstate,sqlerrm;
                        v_cantidad_padre = 0;
                end;
            		
				v_step='10,5';
				RAISE INFO 'PRDCRLO - cantidad padre existente:informada %.%',v_cantidad_padre,p_cantidad_padre;
		
                /* Si no queda producto en el lote padre, o si el lote no tiene asociado un producto, 
                   lo finalizo e intento vaciar el recipiente (si no existen otros lotes En curso en el mismo)*/
				if v_cantidad_padre - p_cantidad_padre = 0 or v_cantidad_padre=0 then
			
					RAISE INFO 'PRDCRLO - Finalizando lote % ',p_batch_id_padre;
					v_step='11';
	
					update prd.lotes
					set estado = c_finalizado
						,usuario_app_ult_modificacion  = p_usuario_app 
						,fec_finalizado = now()
					where batch_id = p_batch_id_padre
					returning reci_id into v_reci_id_padre;
					
					select count(1)
					into strict v_countLotesRec
					from prd.lotes
					where reci_id = v_reci_id_padre
					and estado = c_en_curso;
					
					/** Si no hay mas lotes activos en el recipiente lo pongo como VACIO **/
					if (v_countLotesRec = 0) then
						update prd.recipientes
						set estado = c_vacio
						where reci_id = v_reci_id_padre;
					end if;
				end if;
			
		
				/**
				 * Actualizo la existencia del padre si tiene producto asociado
				 */
                if v_cantidad_padre != 0 then
                    RAISE INFO 'PRDCRLO - actualizo existencia %:% ',p_batch_id_padre,p_cantidad_padre;
                    v_step='11,5';
                    v_resultado = alm.extraer_lote_articulo(p_batch_id_padre,p_cantidad_padre);
                end if;

			
		end if;

	
    end if;	

	/*************************************************************************************
	 * BLOQUE 4: ACTUALIZACION DE LOTE DEL PRODUCTO EN PRODUCCION
	 * EN ALMACENES EN CASO DE INFORMARSE ARTI_ID 
	 * 
	 */
	RAISE INFO 'PRDCRLO - BL4 -  lote producto - p_arti_id % v_estado %',p_arti_id,v_estado;
    /* si se informa articulos del lote los inserto en alm_lotes, sino no */
	if p_arti_id != 0 and v_estado != c_planificado  then 
		v_step='12';

		/** Si el recipiente esta vacio o unifico recipiente, creo un lote, sino actualizo el existente**/
		if v_estado_recipiente = c_vacio or  v_artDif or  v_lotDif then
	    		
				v_resultado = alm.crear_lote_articulo(
										p_prov_id
										,p_arti_id 
										,v_depo_id
										,p_lote_id 
										,p_cantidad 
										,p_fec_vencimiento
										,p_empr_id 
										,v_batch_id );
		else
			    RAISE INFO 'PRDCRLO - es un batch existente, agrego cantidad % al batch %',p_cantidad,v_batch_id;
	    		v_resultado = alm.agregar_lote_articulo(v_batch_id ,p_cantidad);

		end if;						
		RAISE INFO 'PRDCRLO - resultado ops almacen %',v_resultado;

	end if;

    /*************************************************************************
	 * BLOQUE 5: ACTUALIZACION DE RECURSO DE TRABAJO EN CASO DE INFORMARSE
	 * Viene informado en p_recu_id
	 */
    RAISE INFO 'PRDCRLO - BL5 RECURSO TRABAJO - recu_id %',p_recu_id;


	/** Si el actual lote tiene un recurso asociado lo asocio **/
    if p_recu_id is not null and p_recu_id != 0 then
       v_step='13';
	
       begin

	       RAISE INFO 'PRDCRLO - p_recu_id = %', p_recu_id;

			/** Valido que el recursos  exista  **/
			select recu_id
			into strict v_recu_id
			from prd.recursos recu
			where recu.recu_id = p_recu_id;

			/** Eliminio todo si fue grabado como planificado**/
			delete from prd.recursos_lotes
			where batch_id = v_batch_id
			and tipo=p_tipo_recurso;

			/* Inserto el recurso **/
			insert into prd.recursos_lotes(batch_id
											,recu_id
											,empr_id
											,cantidad
											,tipo)
					values (v_batch_id
							,p_recu_id
							,p_empr_id
							,p_cantidad
							,p_tipo_recurso);
						
		exception	   
		
			when NO_DATA_FOUND then
		        RAISE INFO 'PRDCRLO - error 10 - recurso no encontrado %', p_recu_id;
				v_mensaje = 'RECU_NO_ENCONTRADO';
		        raise exception 'RECU_NO_ENCONTRADO:%',p_recu_id;
		       
		end;	

	end if;

	v_step='14';

    call prd.audit_lote(v_batch_id,'batch generado: '||v_batch_id||
                            ' lote:'||p_lote_id||
                            ' batch padre:'|| p_batch_id_padre||
                            ' recipiente: '||p_reci_id||
                            ' articulo: '||p_arti_id||
                            ' recurso ' ||p_recu_id||
                            ' forzar_agregar: '||p_forzar_agregar 
                            ,v_step);
    
	return v_batch_id;


exception
	when others then
	    /** capturo cualquier posible excepcion y la retorno como respuesta **/
	    raise warning 'crear_lote: error al crear lote %: %', sqlstate,sqlerrm;

		v_mensaje=sqlerrm;
		if v_mensaje is null or v_mensaje = '' then	
	    	raise '>>TOOLSERROR:ERROR_INTERNO<<';
	    else
	    	raise '>>TOOLSERROR:%:%<<',v_mensaje,v_step;
	    end if;

END; 
$function$
;

