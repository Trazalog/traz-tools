-- v2.8.1.3 — agrega el clonado del formulario "Entrega Materiales" de la empresa plantilla 9000
-- a cada empresa nueva, y apunta core.tablas configuraciones/formulario_entrega_materiales al clon.
-- Idempotente (CREATE OR REPLACE); asume la v2.8.1.2 ya aplicada (la función ya se llama
-- configuracion_inicial_empresa_trg), por eso no se dropea el nombre viejo.
CREATE OR REPLACE FUNCTION core.configuracion_inicial_empresa_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  declare
  	v_mensaje varchar;
  	v_superadmin varchar;
  	v_tmpl_form_id integer;
  	v_new_form_id integer;
  begin

	begin
		/** Calculo el super admin */
		select t.descripcion superadmin
		into strict v_superadmin	
		from core.tablas t
		where t.tabl_id  ='coresuper_admin';

	exception
		when no_data_found then
			/** Si no esta configurado, usamos el usuario default */
			v_superadmin = 'jperez@prueba.com';
		when others then
	    	raise warning 'CONFINICEMP: error calculando superadmin  %: %', sqlstate,sqlerrm;
	end;

	/** Menues
	 *  Genero menues para los roles de la empresa 
     */
	begin
		
		insert into seg.memberships_menues ("group","role",modulo,opcion,usuario_app)
		values 
		(new.nombre,'Administrador '||new.nombre,'CORE','core','core'),
		(new.nombre,'Responsable de Almacén '||new.nombre,'ALM','almacenes','core'),
		(new.nombre,'Solicitante de Almacén '||new.nombre,'ALM','almacenes_solicitante','core'),
		(new.nombre,'Responsable de Producción '||new.nombre,'LOG','logistica','core'),
		(new.nombre,'Responsable de Producción '||new.nombre,'PRD','produccion','core'),
		(new.nombre,'Responsable de Producción '||new.nombre,'PRD','reportes','core'),
		(new.nombre,'Responsable de Producción '||new.nombre,'CORE','core','core'),
		(new.nombre,'Responsable de Lote '||new.nombre,'PRD','lotes_operarios','core'),
		(new.nombre,'Responsable de Pañol '||new.nombre,'PAN','panol','core'),
		(new.nombre,'Planificador de Tareas '||new.nombre,'TAR','tareas','core'),
		(new.nombre,'Responsable Procesos '||new.nombre,'PRO','procesos','core');
	exception
		when others then
	    	raise warning 'CONFINICEMP: error generando roles %: %', sqlstate,sqlerrm;

	end;


	begin
		/* Doy permiso al superadmin para crear usuarios en la empresa*/
		insert into seg.users_business (busines, email)
		values (new.nombre,v_superadmin);
	
		/* Doy rol de Administrador al super usuario */
		insert into seg.memberships_users ("group","role",email,usuario_app) 
		values (new.nombre,'Administrador '||new.nombre,v_superadmin,'core');
	exception
		when others then
	    	raise warning 'CONFINICEMP: error asignando permisos a superadmin  %: %', sqlstate,sqlerrm;
	end;

	
	begin
		/** Genero listas de valores por default en empresa */
		INSERT INTO core.tablas
		(tabla, valor, valor2, valor3, descripcion, empr_id)
		VALUES
		('sectores', 'fabrica', NULL, NULL, 'Fábrica', new.empr_id),
		('sectores', 'galpon', NULL, NULL, 'Galpón',  new.empr_id),
		( 'ticl_id', 'Propio', '', '', 'Propio ',  new.empr_id),
		( 'tipo_articulo', 'Insumo ', '', '', 'Insumo ',  new.empr_id),
		('tipo_articulo', 'Materia prima', '', '', 'Materia prima',  new.empr_id),
		('tipo_articulo', 'Producto en proceso', '', '', 'Producto en proceso',  new.empr_id),
		('tipo_articulo', 'Producto final', '', '', 'Producto final',  new.empr_id),
		('tipos_transportistas', 'Externo', '', '', 'Externo',  new.empr_id),
		('tipos_transportistas', 'Propio', '', '', 'Propio',  new.empr_id),
		('unidades_medida', 'lt', '', '', 'Litros',  new.empr_id),
		('unidades_medida', 'm', '', '', 'Metros',  new.empr_id),
		('unidades_medida', 'mm', '', '', 'Milímetros',  new.empr_id),
		('unidades_medida', 'un', '', '', 'Unidades',  new.empr_id);
	exception
		when others then
	    	raise warning 'CONFINICEMP: error creando valores por defecto en core.tablas  %: %', sqlstate,sqlerrm;
	end;


	begin
		/** Clona el formulario "Entrega Materiales" de la empresa plantilla 9000 a la empresa nueva.
		 *  La pantalla de entrega resuelve el formulario por core.tablas configuraciones/formulario_entrega_materiales,
		 *  asi que ademas se apunta esa config al form clonado. Si 9000 no tiene ese formulario, no se hace nada. */
		select f.form_id
		into v_tmpl_form_id
		from frm.formularios f
		where f.empr_id = 9000
		  and f.nombre = 'Entrega Materiales'
		  and coalesce(f.eliminado, 0) <> 1
		order by f.form_id desc
		limit 1;

		if v_tmpl_form_id is not null then
			/* Cabecera del formulario, con el empr_id nuevo (form_id lo genera el serial) */
			insert into frm.formularios (nombre, descripcion, eliminado, empr_id)
			select nombre, descripcion, eliminado, new.empr_id
			from frm.formularios
			where form_id = v_tmpl_form_id
			returning form_id into v_new_form_id;

			/* Campos (definicion) del formulario, apuntando al form clonado */
			insert into frm.items (label, name, tipo_dato, valo_id, orden, variable, form_id, eliminado, requerido, valor, columna, multiple)
			select label, name, tipo_dato, valo_id, orden, variable, v_new_form_id, eliminado, requerido, valor, columna, multiple
			from frm.items
			where form_id = v_tmpl_form_id
			  and coalesce(eliminado, false) = false;

			/* La pantalla de entrega lee esta config para saber que formulario mostrar */
			insert into core.tablas (tabla, valor, descripcion, empr_id)
			values ('configuraciones', 'formulario_entrega_materiales', v_new_form_id::text, new.empr_id);
		end if;
	exception
		when others then
	    	raise warning 'CONFINICEMP: error clonando formulario Entrega Materiales %: %', sqlstate,sqlerrm;
	end;

	return new;

exception
	when others then
	    /** capturo cualquier posible excepcion y la retorno como respuesta **/
	    raise warning 'CONFINICEMP: error habilitando superadmin %: %', sqlstate,sqlerrm;

		v_mensaje=sqlerrm;
		if v_mensaje is null or v_mensaje = '' then	
	    	raise '>>TOOLSERROR:ERROR_INTERNO<<';
	    else
	    	raise '>>TOOLSERROR:%<<',v_mensaje;
	    end if;
end;

$function$
;

