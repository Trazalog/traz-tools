-- ============================================================================
--  VERIFICACION DEL KPI DE DISPONIBILIDAD
--
--  Query TAL CUAL esta en MANDataService.dbs (getKPIDisponibiidadPorFecha),
--  con los parametros :fec_inicio / :fec_fin / :id_empresa reemplazados por
--  variables de sesion. La logica NO se toco.
--
--  USO:  mysql -h <host> -u <user> -p <base> < verificar-kpi-disponibilidad.sql
--
--  Comparar el resultado contra UNA barra del grafico "Disponibilidad [%]"
--  del dashboard de Asset Planner, con el mismo mes y la misma empresa.
-- ============================================================================

-- >>> AJUSTAR ESTOS TRES VALORES <<<
SET @id_empresa = 6;              -- id_empresa del cliente que se ve en la pantalla
SET @fec_inicio = '2026-07-01';   -- primer dia del mes de la barra a comparar
SET @fec_fin    = '2026-07-31';   -- ultimo dia de ese mes


-- ---------------------------------------------------------------------------
-- PASO 0 — Prerrequisito: la tabla que alimenta el KPI tiene que estar poblada
-- ---------------------------------------------------------------------------
--  historial_lecturas_mem es ENGINE=MEMORY: se vacia cada vez que reinicia
--  MySQL, y la repuebla el evento 'ejecutar_historial_lecturas_mem'. Si el
--  event_scheduler esta apagado, queda vacia y TODO KPI da NULL.
SELECT 'event_scheduler' AS chequeo, @@event_scheduler AS valor
UNION ALL
SELECT 'filas en historial_lecturas_mem', CAST(COUNT(*) AS CHAR) FROM historial_lecturas_mem
UNION ALL
SELECT 'filas en historial_lecturas', CAST(COUNT(*) AS CHAR) FROM historial_lecturas;


-- ---------------------------------------------------------------------------
-- PASO 1 — El KPI, tal cual lo calcula el DataService
-- ---------------------------------------------------------------------------
select activas.horas_activas / totales.horas_totales * 100 as disponibilidad
from
(select sum(his_lec.horas) horas_activas
from
(
select h.id_lectura ,
	h.id_equipo,
	h.fecha_inicio, 
	IFNULL(h.fecha_fin, str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')) fecha_fin,
	TIMESTAMPDIFF( MINUTE , h.fecha_inicio, IFNULL(h.fecha_fin,str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')))/24 horas,
	h.estado,
	h.id_empresa,
	h.fec_inicio_usr,
	h.fec_fin_usr
from
    (select param.fec_inicio fec_inicio_usr, param.fec_fin fec_fin_usr,
	hl.id_lectura,
	e.id_equipo,
	hl.fecha fecha_inicio, 
	(select hl2.fecha
	from historial_lecturas_mem hl2
	where hl2.id_equipo = hl.id_equipo
	and hl2.id_lectura > hl.id_lectura
	order by hl2.id_lectura
	limit 1) fecha_fin
	,hl.estado
	,e.id_empresa
from historial_lecturas_mem hl 
	, equipos e
	,(select
            @fec_inicio fec_inicio,
            @fec_fin fec_fin
    )
      param
where e.id_equipo = hl.id_equipo) h) his_lec
where his_lec.id_empresa= @id_empresa
and his_lec.estado = 'AC'
and (his_lec.fecha_inicio <= str_to_date( concat( fec_inicio_usr,' 00:00:00') , '%Y-%m-%d %H:%i:%s')
and his_lec.fecha_fin >= str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s') and his_lec.fecha_fin >= his_lec.fecha_inicio
or (
	  	(his_lec.fecha_inicio >= str_to_date( concat( fec_inicio_usr,' 00:00:00') , '%Y-%m-%d %H:%i:%s') 
	 	and his_lec.fecha_fin <= str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')and his_lec.fecha_fin >= his_lec.fecha_inicio) 
	 	or(
	 		his_lec.fecha_inicio <= str_to_date( concat( fec_inicio_usr,' 00:00:00') , '%Y-%m-%d %H:%i:%s') 
	 		and( his_lec.fecha_fin <= str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s') 
	 		and his_lec.fecha_inicio >= str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')and his_lec.fecha_fin >= his_lec.fecha_inicio) 
	 	)
	 	or(his_lec.fecha_inicio >= str_to_date( concat( fec_inicio_usr,' 00:00:00') , '%Y-%m-%d %H:%i:%s')
	 		and
	 		(
	 		his_lec.fecha_inicio < str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')
	 		and his_lec.fecha_fin >= str_to_date( concat(fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')and his_lec.fecha_fin >= his_lec.fecha_inicio
			)
	 	)
	))
	) activas
,(select sum(his_lec.horas) horas_totales
from (
select h.id_lectura ,
	h.id_equipo,
	h.fecha_inicio, 
	IFNULL(h.fecha_fin, str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')) fecha_fin,
	TIMESTAMPDIFF( MINUTE , h.fecha_inicio, IFNULL(h.fecha_fin,str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')))/24 horas,
	h.estado,
	h.id_empresa,
	h.fec_inicio_usr,
	h.fec_fin_usr
from 
(select param.fec_inicio fec_inicio_usr, param.fec_fin fec_fin_usr,
	hl.id_lectura,
	e.id_equipo,
	hl.fecha fecha_inicio, 
	(select hl2.fecha
	from historial_lecturas_mem hl2
	where hl2.id_equipo = hl.id_equipo
	and hl2.id_lectura > hl.id_lectura
	order by hl2.id_lectura
	limit 1) fecha_fin
	,hl.estado
	,e.id_empresa
from historial_lecturas_mem hl 
	, equipos e
	,(select
            @fec_inicio fec_inicio,
            @fec_fin fec_fin
    )
      param
where e.id_equipo = hl.id_equipo) h) his_lec
where his_lec.id_empresa= @id_empresa
and (his_lec.fecha_inicio <= str_to_date( concat( fec_inicio_usr,' 00:00:00') , '%Y-%m-%d %H:%i:%s')
and his_lec.fecha_fin >= str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s') and his_lec.fecha_fin >= his_lec.fecha_inicio
or (
	  	(his_lec.fecha_inicio >= str_to_date( concat( fec_inicio_usr,' 00:00:00') , '%Y-%m-%d %H:%i:%s') 
	 	and his_lec.fecha_fin <= str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')and his_lec.fecha_fin >= his_lec.fecha_inicio) 
	 	or(
	 		his_lec.fecha_inicio <= str_to_date( concat( fec_inicio_usr,' 00:00:00') , '%Y-%m-%d %H:%i:%s') 
	 		and( his_lec.fecha_fin <= str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s') 
	 		and his_lec.fecha_inicio >= str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')and his_lec.fecha_fin >= his_lec.fecha_inicio) 
	 	)
	 	or(his_lec.fecha_inicio >= str_to_date( concat( fec_inicio_usr,' 00:00:00') , '%Y-%m-%d %H:%i:%s') 
	 		and
	 		(
	 		his_lec.fecha_inicio < str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')
	 		and his_lec.fecha_fin >= str_to_date( concat( fec_fin_usr,' 23:59:59') , '%Y-%m-%d %H:%i:%s')and his_lec.fecha_fin >= his_lec.fecha_inicio
			)
	 	)
	))) totales;



-- ---------------------------------------------------------------------------
-- PASO 2 — Diagnostico: tramos con duracion NEGATIVA
-- ---------------------------------------------------------------------------
--  El calculo cierra cada tramo con "la lectura siguiente POR id_lectura".
--  Si esa lectura tiene una fecha ANTERIOR, el tramo dura negativo y resta
--  en vez de sumar. En desarrollo hay 115 casos asi.
--
--  Si en este ambiente da 0, el calculo esta sano aca y la diferencia con
--  desarrollo es de datos. Si da > 0, el mismo problema existe en produccion.
SELECT
    COUNT(*)                                   AS pares_totales,
    SUM(CASE WHEN fecha_fin < fecha_inicio THEN 1 ELSE 0 END) AS pares_invertidos,
    SUM(CASE WHEN fecha_fin < fecha_inicio
             THEN TIMESTAMPDIFF(MINUTE, fecha_inicio, fecha_fin) ELSE 0 END) AS minutos_negativos
FROM (
    SELECT hl.id_lectura, hl.fecha AS fecha_inicio,
           (SELECT hl2.fecha FROM historial_lecturas_mem hl2
             WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
             ORDER BY hl2.id_lectura LIMIT 1) AS fecha_fin
      FROM historial_lecturas_mem hl
      JOIN equipos e ON e.id_equipo = hl.id_equipo
     WHERE e.id_empresa = @id_empresa
) t
WHERE fecha_fin IS NOT NULL;


-- ---------------------------------------------------------------------------
-- PASO 3 — Los 10 casos invertidos mas grandes (para verlos concretos)
-- ---------------------------------------------------------------------------
SELECT id_lectura, id_equipo, fecha_inicio, fecha_fin,
       TIMESTAMPDIFF(MINUTE, fecha_inicio, fecha_fin) AS minutos
FROM (
    SELECT hl.id_lectura, hl.id_equipo, hl.fecha AS fecha_inicio,
           (SELECT hl2.fecha FROM historial_lecturas_mem hl2
             WHERE hl2.id_equipo = hl.id_equipo AND hl2.id_lectura > hl.id_lectura
             ORDER BY hl2.id_lectura LIMIT 1) AS fecha_fin
      FROM historial_lecturas_mem hl
      JOIN equipos e ON e.id_equipo = hl.id_equipo
     WHERE e.id_empresa = @id_empresa
) t
WHERE fecha_fin < fecha_inicio
ORDER BY minutos ASC
LIMIT 10;


-- ---------------------------------------------------------------------------
-- PASO 3-bis — Fechas cero ('0000-00-00'), el caso mas destructivo
-- ---------------------------------------------------------------------------
--  En desarrollo aparecio una lectura con fecha 0000-00-00 00:00:00. Al
--  usarse como fin de tramo aporta -1.064.991.934 minutos (unos 2000 anios
--  en negativo) y por si sola domina la suma de todo el periodo.
--
--  Si aca devuelve 0 filas, este ambiente no tiene ese problema.
SELECT id_lectura, id_equipo, fecha, lectura, estado, observacion
  FROM historial_lecturas
 WHERE fecha = '0000-00-00 00:00:00'
    OR YEAR(fecha) < 2000
 LIMIT 10;


-- ---------------------------------------------------------------------------
-- PASO 4 — La unidad de la columna 'horas'
-- ---------------------------------------------------------------------------
--  El query hace TIMESTAMPDIFF(MINUTE,...)/24 y llama 'horas' al resultado.
--  Minutos / 24 no son horas (habria que dividir por 60). Esto NO afecta a la
--  disponibilidad (es un cociente y el factor se cancela), pero SI a MTTR y
--  MTTF, que devuelven la magnitud sin dividir.
SELECT 120 AS minutos_reales,
       120/24 AS 'valor_que_reporta_el_query',
       120/60 AS 'horas_reales';
