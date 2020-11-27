-- DROP SCHEMA pro;

CREATE SCHEMA pro AUTHORIZATION postgres;

-- pro.procesos definition

-- Drop table

-- DROP TABLE pro.procesos;

CREATE TABLE pro.procesos (
	proc_id varchar NOT NULL,
	nombre varchar NOT NULL,
	descripcion varchar NOT NULL,
	lanzar_bpm bool NOT NULL,
	planificar_tareas bool NOT NULL,
	eliminado bool NOT NULL DEFAULT false,
	nombre_bpm varchar NULL,
	fec_alta date NOT NULL DEFAULT now(),
	usuario varchar NOT NULL DEFAULT CURRENT_USER,
	usuario_app varchar NOT NULL,
	esin_id varchar NOT NULL,
	empr_id int4 NOT NULL,
	form_id int4 NULL,
	CONSTRAINT procesos_pk PRIMARY KEY (proc_id),
	CONSTRAINT procesos_un UNIQUE (nombre, empr_id)
);


-- pro.procesos foreign keys

ALTER TABLE pro.procesos ADD CONSTRAINT procesos_esin_id_fk FOREIGN KEY (esin_id) REFERENCES core.tablas(tabl_id);
ALTER TABLE pro.procesos ADD CONSTRAINT procesos_form_id_fk FOREIGN KEY (form_id) REFERENCES frm.formularios(form_id);


-- pro.pedidos_trabajo definition

-- Drop table

-- DROP TABLE pro.pedidos_trabajo;

CREATE TABLE pro.pedidos_trabajo (
	petr_id serial NOT NULL,
	cod_proyecto varchar NOT NULL,
	descripcion varchar NOT NULL,
	estado varchar NOT NULL,
	objetivo varchar NOT NULL DEFAULT 0,
	eliminado bool NOT NULL DEFAULT false,
	fec_inicio date NOT NULL,
	fec_entrega date NULL,
	fec_alta date NOT NULL DEFAULT now(),
	usuario varchar NOT NULL DEFAULT CURRENT_USER,
	usuario_app varchar NOT NULL,
	umti_id varchar NOT NULL,
	info_id int4 NOT NULL,
	proc_id varchar NOT NULL,
	empr_id int4 NULL,
	clie_id int4 NULL,
	case_id varchar NULL,
	case_id_final varchar NULL,
	CONSTRAINT pedidos_trabajo_pk PRIMARY KEY (petr_id),
	CONSTRAINT pedidos_trabajo_un UNIQUE (cod_proyecto, empr_id)
);


-- pro.pedidos_trabajo foreign keys

ALTER TABLE pro.pedidos_trabajo ADD CONSTRAINT pedidos_trabajo_clie_id_fk FOREIGN KEY (clie_id) REFERENCES core.clientes(clie_id);
ALTER TABLE pro.pedidos_trabajo ADD CONSTRAINT pedidos_trabajo_fk FOREIGN KEY (proc_id) REFERENCES pro.procesos(proc_id);
ALTER TABLE pro.pedidos_trabajo ADD CONSTRAINT pedidos_trabajo_fk_1 FOREIGN KEY (empr_id) REFERENCES core.empresas(empr_id);
ALTER TABLE pro.pedidos_trabajo ADD CONSTRAINT pedidos_trabajo_umti_id_fk FOREIGN KEY (umti_id) REFERENCES core.tablas(tabl_id);


-- tst.hitos definition

-- Drop table

-- DROP TABLE tst.hitos;

CREATE TABLE tst.hitos (
	numero varchar NOT NULL,
	descripcion varchar NULL,
	fec_inicio timestamp NULL,
	user_id varchar NULL,
	objetivo int4 NULL,
	unidad_tiempo varchar NULL,
	esta_id int4 NULL,
	documento varchar NULL,
	petr_id int4 NOT NULL,
	eliminado bool NOT NULL DEFAULT false,
	fec_alta timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	hito_id serial NOT NULL,
	CONSTRAINT hitos_pk PRIMARY KEY (hito_id)
);


-- tst.hitos foreign keys

ALTER TABLE tst.hitos ADD CONSTRAINT hitos_fk FOREIGN KEY (petr_id) REFERENCES pro.pedidos_trabajo(petr_id);