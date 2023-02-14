CREATE OR REPLACE FUNCTION prd.eliminar_prd_recurso_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  DECLARE
  BEGIN
    /** funcion para utilizarse on insert para insertar el articulo como recurso
     *  v2, elimina equipos @rruiz
     *  v3, correccion no funcionaba, solo actua cuando se toca campo eliminado
     *      ahora borra logicamente y restaura si eliminado ahora es false
     *      captura de que tabla proviene (articulos o equipos) por exception
     */
	if new.eliminado = true and old.eliminado = false then
	
		begin
		   if new.arti_id is not null then
			
		   		update prd.recursos
			    set eliminado = true
			    where arti_id = new.arti_id;

		    end if;
		exception
			when others then
	 		 if new.equi_id is not null then
				update prd.recursos
			   	set eliminado = true
			   	where equi_id = new.equi_id;
			end if;
		end;
	
	elsif new.eliminado = false and old.eliminado = true then
	
		begin
		   if new.arti_id is not null then
			
		   		update prd.recursos
			    set eliminado = false
			    where arti_id = new.arti_id;

		    end if;
		exception
			when others then
	 		 if new.equi_id is not null then
				update prd.recursos
			   	set eliminado = false
			   	where equi_id = new.equi_id;
			end if;
		end;
	
	end if;

	return new;

 exception
	when others then
	    /** capturo cualquier posible excepcion y la retorno como respuesta **/
	    raise 'eliminar_recurso: error al eliminar recurso -em:%-%',old.empr_id, sqlerrm;
   
    END;
$function$
;

