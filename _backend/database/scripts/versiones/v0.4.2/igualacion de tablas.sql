ALTER TABLE tst.tareas_planificadas ADD hora_duracion varchar NULL;

ALTER TABLE tst.tareas_planificadas ADD empr_id int4 NULL;

ALTER TABLE prd.movimientos_trasportes ADD empr_id int4 NOT NULL;


ALTER TABLE core.clientes ADD empr_id int4 NOT NULL;
ALTER TABLE core.clientes ADD CONSTRAINT clientes_fk2 FOREIGN KEY (empr_id) REFERENCES core.empresas(empr_id);
ALTER TABLE core.clientes ADD estado varchar NULL;