CREATE OR REPLACE FUNCTION prd.crear_prd_recurso_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  DECLARE
  BEGIN
    /** funcion para utilizarse on insert para insertar el articulo o equipo como recurso
     *  v2, agrega equipos @rruiz
     *  v3, correccion no funcionaba, 
     *      captura de que tabla proviene (articulos o equipos) por exception
     *      no compara mas id con '', daba exception
     */
	BEGIN
		if new.arti_id is not null then
		    INSERT INTO prd.recursos
		    (tipo
		     ,arti_id
		     ,empr_id
		     )
		    values
		    ('MATERIAL'
		     ,new.arti_id
		     ,new.empr_id);
		end if;
	exception 
		when others then	
		if new.equi_id is not null then
		   INSERT INTO prd.recursos
		    (tipo
		     ,equi_id
		     ,empr_id
		     )
		    values
		    ('TRABAJO'
		     ,new.equi_id
		     ,new.empr_id);
		end if; 
	end; 
	return new;
exception
	when others then
	    /** capturo cualquier posible excepcion y la retorno como respuesta **/
	    raise 'crear_recurso: error al crear recurso-em:%-%',new.empr_id, sqlerrm;

    END;
$function$
;
