create trigger eliminar_producto_au after
update
    on
    alm.alm_articulos for each row execute procedure prd.eliminar_prd_recurso_trg();

create trigger crear_recurso_ai after
insert
    on
    core.equipos for each row execute procedure prd.crear_prd_recurso_trg();

create trigger eliminar_recurso_au after
update
    on
    core.equipos for each row execute procedure prd.eliminar_prd_recurso_trg();

CREATE OR REPLACE FUNCTION prd.crear_prd_recurso_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  DECLARE
  BEGIN
    /** funcion para utilizarse on insert para insertar el articulo o equipo como recurso
     *  v2, agrega equipos @rruiz
     */
	if new.arti_id is not null or new.arti_id <> '' then
	    INSERT INTO prd.recursos
	    (tipo
	     ,arti_id
	     ,empr_id
	     )
	    values
	    ('MATERIAL'
	     ,new.arti_id
	     ,new.empr_id);
	elsif new.equi_id is not null or new.equi_id <> '' then
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
    return new;
exception
	when others then
	    /** capturo cualquier posible excepcion y la retorno como respuesta **/
	    raise 'crear_recurso: error al crear recurso ar:%-eq:%-em:%-%',new.arti_id,new.equi_id,new.empr_id, sqlerrm;

    END;
$function$
;


CREATE OR REPLACE FUNCTION prd.eliminar_prd_recurso_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  DECLARE
  BEGIN
    /** funcion para utilizarse on insert para insertar el articulo como recurso
     *  v2, elimina equipos @rruiz
     */
	if new.eliminado = true and new.arti_id is not null then
	    update prd.recursos
	    set eliminado = true
	    where arti_id = new.arti_id;
	elsif new.eliminado = true and new.equi_id is not null then
		update prd.recursos
	   	set eliminado = true
	   	where equi_id = new.equi_id;
	end if;
	return new;

    exception
	when others then
	    /** capturo cualquier posible excepcion y la retorno como respuesta **/
	    raise 'eliminar_recurso: error al eliminar recurso ar:%-eq:%-em:%-%',old.arti_id,old.equi_id,old.empr_id, sqlerrm;
   
    END;
$function$
;

