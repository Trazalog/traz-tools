create schema sta;

-- Drop table


-- DROP TABLE sta.articulos;

CREATE TABLE sta.articulos (
	id varchar NULL,
	"Etapa" varchar NULL,
	"U. Medida" varchar NULL,
	"Código" varchar NULL,
	"Descripción" varchar NULL,
	procesado bool NULL DEFAULT false,
	fec_proceso date NULL
);

-- Drop table

-- DROP TABLE sta.articulos_etapas;

CREATE TABLE sta.articulos_etapas (
	"Etapa" varchar NULL,
	"Entrada" varchar NULL,
	"Producto" varchar NULL,
	"Salida" varchar NULL,
	procesado bool NULL DEFAULT false,
	fec_proceso date NULL
);

CREATE OR REPLACE PROCEDURE sta.bulkload_articulos(p_archivo character varying, p_empr_id integer)
 LANGUAGE plpgsql
AS $procedure$
	DECLARE 
	v_codigo_aux varchar;
	v_descripcion_aux varchar;
 	v_umedida_aux varchar;
 	v_tipo_aux varchar;
	cur_articsv CURSOR FOR SELECT
						ltrim(rtrim(upper(ar."Código")))
						, ar."Descripción"
						, ltrim(rtrim(upper( ar."U. Medida")))
						, sta.calcula_tipo_articulo(ar."Código")
						FROM sta.articulos ar
						WHERE ar.procesado = FALSE;

 	BEGIN
		/**
		 * Carga de un archivo csv
		 * 	con columnas "Código","Descripción", "U. Medida"
		 * los datos en alm_articulos
		 * la primer fila de csv debe tener estos nombres no importa el orden
		 */
	    RAISE INFO 'BULKART: Cargando archivo % con empresa %',p_archivo, p_empr_id;
	
		BEGIN
		
		   EXECUTE 
			FORMAT('COPY sta.articulos (id,"Etapa","U. Medida","Código","Descripción") FROM %s WITH CSV HEADER'
		    ,p_archivo);
	       
		    RAISE INFO 'BULKART: Archivo cargado';
       
		    RAISE INFO 'BULKART: Eliminando registros sin codigo o descripcion con empresa %',p_empr_id;

			DELETE FROM sta.articulos ar 
			WHERE ar."Código" IS  NULL
			OR ar."Descripción" IS NULL;

			RAISE INFO 'BULKART: Insertando registros';
			open cur_articsv;
			loop
				fetch cur_articsv into v_codigo_aux,v_descripcion_aux,v_umedida_aux,v_tipo_aux;
				exit when NOT FOUND;
	    		
				RAISE INFO 'BULKART: Procesando registro  %-%-%-%',v_codigo_aux,v_descripcion_aux,v_umedida_aux,v_tipo_aux;
      		
				INSERT INTO
					alm.alm_articulos (
					    barcode 
					    ,descripcion 
					    ,costo 
					    ,es_caja 
					    ,cantidad_caja 
					    ,punto_pedido 
					    ,estado 
					    ,unidad_medida 
					    ,empr_id 
					    ,es_loteado
					    ,tipo)
				 VALUES(
						v_codigo_aux
						,v_descripcion_aux
						,0
						,FALSE
						,0
						,0
						,'AC'
						,v_umedida_aux
						,p_empr_id
						,FALSE
						,v_tipo_aux);
			end loop;
			CLOSE cur_articsv;
			RAISE INFO 'BULKART: Registros cargados, marcando batch como procesado';

			UPDATE
				sta.articulos
			SET
				procesado = TRUE
				, fec_proceso = now()
			WHERE
				procesado = FALSE;
			commit;
			RAISE INFO 'BULKART: Carga bulk terminada exitosamente';
	EXCEPTION	
		when others then
			/* Borro el actual CSV con error*/
			rollback;
			DELETE FROM sta.articulos ar 
			WHERE ar.procesado = FALSE;
			raise EXCEPTION 'BULKART: error al cargar batch de articulos %: %', sqlstate,sqlerrm;

	END;

END;
$procedure$
;

CREATE OR REPLACE PROCEDURE sta.bulkload_articulos_etapas(p_archivo character varying, p_empr_id integer)
 LANGUAGE plpgsql
AS $procedure$
	DECLARE 
	v_etapa_aux varchar;
	v_entrada_aux varchar;
 	v_salida_aux varchar;
 	v_producto_aux varchar;
 	v_etap_id int4;
	cur_artietapcsv CURSOR FOR SELECT
						ltrim(rtrim(upper(ae."Etapa")))
						, ltrim(rtrim(upper(ae."Entrada"))) 
						, ltrim(rtrim(upper(ae."Producto"))) 
						, ltrim(rtrim(upper(ae."Salida"))) 
						FROM sta.articulos_etapas ae 
						WHERE ae.procesado = FALSE;

 	BEGIN
		/**
		 * Carga de un archivo csv
		 * 	con columnas "Etapa","Entrada", "Producto","Salida"
		 * los datos en prd.etapas_materiales (entrada), prd.etapas_productos y prd.etapas_salidas
		 * la primer fila de csv debe tener estos nombres no importa el orden
		 */
	    RAISE INFO 'BULKARET: Cargando archivo % con empresa %',p_archivo, p_empr_id;

		BEGIN
		   EXECUTE 
			FORMAT('COPY sta.articulos_etapas ("Etapa","Entrada","Producto","Salida") FROM %s WITH CSV HEADER'
		    ,p_archivo);
	       
		    RAISE INFO 'BULKARET: Archivo cargado';
       
		    RAISE INFO 'BULKARET: Eliminando registros invalidos  %',p_empr_id;

			DELETE FROM sta.articulos_etapas ar 
			WHERE ar."Etapa" IS  NULL
			OR (ar."Entrada" = '0' AND ar."Producto" = '0'AND ar."Salida" ='0')
			OR (ar."Entrada" IS NULL AND ar."Producto" IS NULL AND ar."Salida" IS NULL);

			RAISE INFO 'BULKARET: Insertando registros';
			open cur_artietapcsv;
			loop
				fetch cur_artietapcsv into v_etapa_aux,v_entrada_aux,v_producto_aux,v_salida_aux;
				exit when NOT FOUND;
	    		
				RAISE INFO 'BULKARET: Obtengo etapa %',v_etapa_aux;
	
				SELECT etap_id 
				INTO STRICT v_etap_id
				FROM prd.etapas e 
				WHERE UPPER(E.nombre )= v_etapa_aux
				AND e.empr_id = p_empr_id;
			
				RAISE INFO 'BULKARET: Procesando registro  %(%)-%-%-%<<',v_etapa_aux,v_etap_id,v_entrada_aux,v_producto_aux,v_salida_aux;      		


				IF v_entrada_aux IS NOT NULL AND v_entrada_aux != '' AND v_entrada_aux !='0' THEN 
				
					RAISE INFO 'BULKARET: Insertando en etapas_materiales  %(%)-%<<',v_etapa_aux,v_etap_id,v_entrada_aux;      		
					BEGIN
						
						INSERT INTO prd.etapas_materiales
						(arti_id 
						,etap_id )
						SELECT a.arti_id
						,v_etap_id
						FROM alm.alm_articulos a 
						WHERE a.barcode = v_entrada_aux
						AND a.empr_id =p_empr_id;
					EXCEPTION
						WHEN unique_violation THEN
							RAISE INFO 'BULKARET: Registro existente, obviando';      		
					END;
				
					END IF;
			
				IF v_producto_aux IS NOT NULL AND v_producto_aux != '' AND v_producto_aux !='0' THEN 
				
					BEGIN 
						RAISE INFO 'BULKARET: Insertando en etapas_productos  %(%)-%<<',v_etapa_aux,v_etap_id,v_producto_aux;      		
						INSERT INTO prd.etapas_productos
						(arti_id 
						,etap_id )
						SELECT a.arti_id
						,v_etap_id
						FROM alm.alm_articulos a 
						WHERE a.barcode = v_producto_aux
						AND a.empr_id =p_empr_id;

					EXCEPTION
						WHEN unique_violation THEN
							RAISE INFO 'BULKARET: Registro existente, obviando';      		
					END;

				END IF;
			
				IF v_salida_aux IS NOT NULL AND v_salida_aux != '' AND v_salida_aux !='0' THEN 

					BEGIN 
						RAISE INFO 'BULKARET: Insertando en etapas_salidas  %(%)-%<<',v_etapa_aux,v_etap_id,v_salida_aux;      		
						INSERT INTO prd.etapas_salidas 
						(arti_id 
						,etap_id )
						SELECT a.arti_id
						,v_etap_id
						FROM alm.alm_articulos a 
						WHERE a.barcode = v_salida_aux
						AND a.empr_id =p_empr_id;
					EXCEPTION
						WHEN unique_violation THEN
							RAISE INFO 'BULKARET: Registro existente, obviando';      		
					END;

				END IF;
		
	
			end loop;
			CLOSE cur_artietapcsv;
			RAISE INFO 'BULKARET: Registros cargados, marcando batch como procesado';

			UPDATE
				sta.articulos_etapas 
			SET
				procesado = TRUE
				, fec_proceso = now()
			WHERE
				procesado = FALSE;
			commit;	 
			RAISE INFO 'BULKARET: Carga bulk terminada exitosamente';
	EXCEPTION	
		when others then
			/* Borro el actual CSV con error*/
			rollback;
			DELETE FROM sta.articulos_etapas ar 
			WHERE ar.procesado = FALSE;
			raise EXCEPTION 'BULKARET: error al cargar batch de articulos %: %', sqlstate,sqlerrm;

	END;

END;
$procedure$
;

