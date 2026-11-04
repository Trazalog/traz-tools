-- Objetivo: las empresas nuevas reciben el menu de Mantenimiento (H46). Agrega un bloque a
-- core.configuracion_inicial_empresa_trg; el resto de la funcion queda igual a la base de desarrollo.
-- Aplicado en desarrollo el 2026-11-04. Falta TEST y PRODUCCION. Ver doc/migracion/MENU-MAN.md.
CREATE OR REPLACE FUNCTION core.configuracion_inicial_empresa_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  declare
  	v_mensaje varchar;
  	v_superadmin varchar;
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
		(new.nombre,'Responsable Procesos '||new.nombre,'PRO','procesos','core'),
		(new.nombre,'Transportista '||new.nombre,'RESI','residuos_transportista','core'),
		(new.nombre,'Generador '||new.nombre,'RESI','residuos','core'),
		(new.nombre,'Operario Descarga '||new.nombre,'RESI','residuos_transportista','core'),
		(new.nombre,'Operador de Bascula '||new.nombre,'RESI','residuos_transportista','core');
	exception
		when others then
	    	raise warning 'CONFINICEMP: error generando roles %: %', sqlstate,sqlerrm;

	end;



	/** Menu de Mantenimiento (MAN), en su propio bloque: si en un ambiente faltan las opciones MAN en
	 *  seg.menues, el error no se lleva puesto el resto de los menues de la empresa.
	 *  Las opciones salen de lo que cada rol ve en asset (ver toolsAssetUserEmpresa). Dar solo la opcion
	 *  padre habilita todas sus hijas, por eso el Administrador lleva dos filas. */
	begin
		insert into seg.memberships_menues ("group","role",modulo,opcion,usuario_app)
		select new.nombre, r.rol||' '||new.nombre, 'MAN', o.opcion, 'core'
		from unnest(array['Administrador']) r(rol)
		cross join unnest(array['mantenimiento','abm_man']) o(opcion)
		union all
		select new.nombre, r.rol||' '||new.nombre, 'MAN', o.opcion, 'core'
		from unnest(array['Supervisor de Mantenimiento','Planificador de Mantenimiento']) r(rol)
		cross join unnest(array['equipos','bandeja','componentes','solicitud_servicio','informe_servicios','preventivo','backlog',
			            'ordenes_trabajo','plan_mantenimiento','rep_equipo','rep_informe_servicios','rep_ordenes_trabajo',
			            'mantenimiento','abm_man','abm_area','abm_grupo','abm_clientes','abm_sector','abm_criticidad',
			            'abm_proceso','abm_tarea_estandar','abm_marca','abm_sistemas']) o(opcion)
		union all
		select new.nombre, 'Solicitante de Mantenimiento '||new.nombre, 'MAN', o.opcion, 'core'
		from unnest(array['mantenimiento','bandeja','equipos','solicitud_servicio','informe_servicios','preventivo','backlog']) o(opcion);
	exception
		when others then
	    	raise warning 'CONFINICEMP: error generando menu de Mantenimiento %: %', sqlstate,sqlerrm;
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

$function$;
