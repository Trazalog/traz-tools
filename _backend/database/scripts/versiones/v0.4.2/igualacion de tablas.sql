ALTER TABLE tst.tareas_planificadas ADD hora_duracion varchar NULL;

ALTER TABLE tst.tareas_planificadas ADD empr_id int4 NULL;

ALTER TABLE prd.movimientos_trasportes ADD empr_id int4 NOT NULL;
