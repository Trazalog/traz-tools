CREATE OR REPLACE FUNCTION prd.crear_proceso_productivo_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  declare
  BEGIN
    /** funcion para utilizarse on insert para insertar el proceso productivo por defecto en una empresa
     * 
     */

	INSERT INTO prd.procesos
	(nombre, empr_id)
	VALUES('Proceso Default '||new.descripcion,new.empr_id);

	return new;
exception
	when others then
	    /** capturo cualquier posible excepcion y la retorno como respuesta **/
	    raise 'crear_prd_proceso: error al crear proceso %-%-%',new.empr_id,sqlstate,sqlerrm;

    END;
$function$
;
