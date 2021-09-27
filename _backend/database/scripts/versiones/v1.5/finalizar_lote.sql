CREATE OR REPLACE FUNCTION prd.finalizar_lote(p_batch_id bigint)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
/** Funcion para finalizar un lote que no tiene producto, y vaciar recipiente 
 *  si no hay otros lotes utilizando el recipiente
 *  @author RRuiz
 */
#print_strict_params on
DECLARE
 v_cantidad alm.alm_lotes.cantidad%type;
 v_reci_id prd.recipientes.reci_id%type;
 v_tieneProd boolean = false;
 v_countLotesRec integer = 0;
 v_mensaje varchar;


BEGIN

	/* Primero obtengo la cantidad del producto asociado al lote, deberia salir 
	 * por excepción y poner la bandera en true			
	 * 
	 */
    RAISE INFO 'PRDFILO - Finalizando lote % ',p_batch_id;

    begin

        v_cantidad = alm.obtener_existencia_batch(p_batch_id);

       RAISE INFO 'PRDFILO - cant %',v_cantidad;
		if v_cantidad is null then
			v_tieneProd = false;
	 	else
       		v_tieneProd = true;
		end if;
    exception 
        when others then
            v_tieneProd = false;
        	RAISE INFO 'PRDFILO - no hay lote asociado, asumimos que es un batch sin producto %:%:% ',p_batch_id,sqlstate,sqlerrm;
    end;
		    
	/* Cambio el estado solo si no tiene producto */
	if v_tieneProd = false then
		RAISE INFO 'PRDFILO - El lote no tiene producto, finalizando';

		update prd.lotes
		set estado = 'FINALIZADO'
		where batch_id = p_batch_id
		returning reci_id into v_reci_id;
		
		select count(1)
		into strict v_countLotesRec
		from prd.lotes
		where reci_id = v_reci_id
		and estado = 'En Curso';
		
		/** Si no hay mas lotes activos en el recipiente lo pongo como VACIO **/
		if (v_countLotesRec = 0) then
    		RAISE INFO 'PRDFILO - Actualizo recipiente como vacio % ',v_reci_id;
			update prd.recipientes
			set estado = 'VACIO'
			where reci_id = v_reci_id;
		end if;
	end if;
    return 'ok';

exception
	when others then
	    /** capturo cualquier posible excepcion y la retorno como respuesta **/
	    raise warning 'PRDFILO: error al finalizar lote %: %', sqlstate,sqlerrm;

		v_mensaje=sqlerrm;
		if v_mensaje is null or v_mensaje = '' then	
	    	raise '>>TOOLSERROR:ERROR_INTERNO<<';
	    else
	    	raise '>>TOOLSERROR:%<<',v_mensaje;
	    end if;

END; 
$function$
;
