CREATE OR REPLACE FUNCTION core.habilita_superadmin_empresa()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  declare
  	v_mensaje varchar;
    v_tabla varchar;
  BEGIN
    /** Genero menues en la empresa para el superadmin, y ademas le doy permisos para crear usuarios en user.business
     */
	insert into seg.memberships_menues ("group","role",opcion,modulo)
	values (new.nombre,'Admin','CORE','core');

	insert into seg.users_business (busines, email)
	select (new.nombre,t.descripcion)
	from core.tablas t
	where t.tabl_id  ='coresuper_admin';
	
	  
	return new;

exception
	when others then
	    /** capturo cualquier posible excepcion y la retorno como respuesta **/
	    raise warning 'HABILSUPADM: error habilitando superadmin %: %', sqlstate,sqlerrm;

		v_mensaje=sqlerrm;
		if v_mensaje is null or v_mensaje = '' then	
	    	raise '>>TOOLSERROR:ERROR_INTERNO<<';
	    else
	    	raise '>>TOOLSERROR:%<<',v_mensaje;
	    end if;
end;

$function$
;
;
