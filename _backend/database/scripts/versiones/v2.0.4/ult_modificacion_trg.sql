CREATE OR REPLACE FUNCTION core.ult_modificacion_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
	BEGIN
		new.fec_ult_modificacion = now();
		return new;
	exception 
		when others then 
	    	raise warning 'ult_modif: error al setear fecha ult modif %: %', sqlstate,sqlerrm;

	END;
$function$
;
