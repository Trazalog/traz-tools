
-- pro.pedidos_trabajo_forms definition

-- Drop table

-- DROP TABLE pedidos_trabajo_forms;

CREATE TABLE pro.pedidos_trabajo_forms (
	nom_tarea varchar NOT NULL,
	task_id varchar NOT NULL,
	fec_alta date NOT NULL DEFAULT now(),
	usuario varchar NOT NULL DEFAULT CURRENT_USER,
	usuario_app varchar NOT NULL,
	petr_id int4 NOT NULL,
	info_id int4 NOT NULL,
	CONSTRAINT pedidos_trabajo_forms_pk PRIMARY KEY (petr_id, info_id, task_id)
);


-- pro.pedidos_trabajo_forms foreign keys

ALTER TABLE pro.pedidos_trabajo_forms ADD CONSTRAINT pedidos_trabajo_forms_petr_id_fk FOREIGN KEY (petr_id) REFERENCES pro.pedidos_trabajo(petr_id);








