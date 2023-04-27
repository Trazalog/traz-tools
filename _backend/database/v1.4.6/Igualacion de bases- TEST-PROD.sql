-- DROP SCHEMA pan;

CREATE SCHEMA pan AUTHORIZATION postgres;

-- pan.deta_entrada_panol definition

-- Drop table

-- DROP TABLE pan.deta_entrada_panol;

CREATE TABLE pan.deta_entrada_panol (
	enpa_id int4 NOT NULL,
	herr_id int4 NOT NULL
);


-- pan.deta_salida_panol definition

-- Drop table

-- DROP TABLE pan.deta_salida_panol;

CREATE TABLE pan.deta_salida_panol (
	sapa_id int4 NOT NULL,
	herr_id int4 NOT NULL
);


-- pan.entrada_panol definition

-- Drop table

-- DROP TABLE pan.entrada_panol;

CREATE TABLE pan.entrada_panol (
	enpa_id serial NOT NULL,
	usuario_app varchar NOT NULL,
	destino varchar NOT NULL,
	empr_id int4 NOT NULL,
	fec_alta date NOT NULL DEFAULT now(),
	usuario varchar NOT NULL DEFAULT CURRENT_USER,
	pano_id int4 NOT NULL,
	observaciones varchar NULL,
	eliminado bool NOT NULL DEFAULT false,
	comprobante varchar NOT NULL,
	responsable varchar NOT NULL,
	CONSTRAINT entrada_panol_pk PRIMARY KEY (enpa_id)
);


-- pan.estanteria definition

-- Drop table

-- DROP TABLE pan.estanteria;

CREATE TABLE pan.estanteria (
	estan_id serial NOT NULL,
	descripcion varchar NULL,
	codigo varchar NOT NULL,
	filas int4 NOT NULL,
	fec_alta timestamp NOT NULL DEFAULT now(),
	usuario_app varchar NOT NULL,
	usuario varchar NULL DEFAULT CURRENT_USER,
	empr_id int4 NOT NULL,
	pano_id int4 NOT NULL,
	CONSTRAINT estanteria_pk PRIMARY KEY (estan_id)
);


-- pan.herramientas definition

-- Drop table

-- DROP TABLE pan.herramientas;

CREATE TABLE pan.herramientas (
	herr_id serial NOT NULL,
	codigo varchar NOT NULL,
	marca varchar NOT NULL,
	modelo varchar NULL,
	tipo varchar NULL,
	descripcion varchar NULL,
	pano_id int4 NOT NULL,
	usuario_app varchar NOT NULL,
	usuario varchar NOT NULL DEFAULT CURRENT_USER,
	fec_alta date NOT NULL DEFAULT now(),
	empr_id int4 NOT NULL,
	eliminado bool NOT NULL DEFAULT false,
	estado varchar NULL DEFAULT 'ACTIVO'::character varying,
	CONSTRAINT herramientas_pk PRIMARY KEY (herr_id)
);


-- pan.panol definition

-- Drop table

-- DROP TABLE pan.panol;

CREATE TABLE pan.panol (
	pano_id serial NOT NULL,
	descripcion varchar NOT NULL,
	direccion varchar NULL,
	loca_id varchar NULL,
	prov_id varchar NULL,
	pais_id varchar NULL,
	lat varchar NULL,
	lng varchar NULL,
	empr_id int4 NOT NULL,
	usuario varchar NOT NULL DEFAULT CURRENT_USER,
	usuario_app varchar NOT NULL,
	eliminado bool NOT NULL DEFAULT false,
	fec_alta date NOT NULL DEFAULT now(),
	esta_id int4 NULL,
	CONSTRAINT panol_pk PRIMARY KEY (pano_id)
);


-- pan.salida_panol definition

-- Drop table

-- DROP TABLE pan.salida_panol;

CREATE TABLE pan.salida_panol (
	sapa_id serial NOT NULL,
	usuario_app varchar NOT NULL,
	destino varchar NOT NULL,
	empr_id int4 NOT NULL,
	fec_alta date NOT NULL DEFAULT now(),
	usuario varchar NOT NULL DEFAULT CURRENT_USER,
	pano_id int4 NOT NULL,
	observaciones varchar NULL,
	eliminado bool NOT NULL DEFAULT false,
	comprobante varchar NOT NULL,
	responsable varchar NOT NULL,
	CONSTRAINT salida_panol_pk PRIMARY KEY (sapa_id)
);


-- pan.trazacomponente definition

-- Drop table

-- DROP TABLE pan.trazacomponente;

CREATE TABLE pan.trazacomponente (
	traz_id serial NOT NULL,
	coeq_id int4 NOT NULL,
	estan_id int4 NULL,
	fila int4 NULL,
	fecha timestamp NULL DEFAULT now(),
	fecha_entrega timestamp NULL,
	ultimo_recibe varchar NOT NULL,
	ultimo_entrega varchar NOT NULL,
	estado varchar NOT NULL,
	observaciones varchar NULL,
	usuario_app varchar NOT NULL,
	usuario varchar NOT NULL DEFAULT CURRENT_USER,
	empr_id int4 NOT NULL,
	eliminado bool NOT NULL DEFAULT false,
	pano_id int4 NOT NULL
);


-- pan.deta_entrada_panol foreign keys

ALTER TABLE pan.deta_entrada_panol ADD CONSTRAINT deta_entrada_pano_herr_idl_fk FOREIGN KEY (herr_id) REFERENCES pan.herramientas(herr_id);
ALTER TABLE pan.deta_entrada_panol ADD CONSTRAINT deta_entrada_panol_entr_panol_fk FOREIGN KEY (enpa_id) REFERENCES pan.entrada_panol(enpa_id);


-- pan.deta_salida_panol foreign keys

ALTER TABLE pan.deta_salida_panol ADD CONSTRAINT deta_salida_panol_herr_id_fk FOREIGN KEY (herr_id) REFERENCES pan.herramientas(herr_id);
ALTER TABLE pan.deta_salida_panol ADD CONSTRAINT deta_salida_panol_sapa_id_fk FOREIGN KEY (sapa_id) REFERENCES pan.salida_panol(sapa_id);


-- pan.entrada_panol foreign keys

ALTER TABLE pan.entrada_panol ADD CONSTRAINT entrada_panol_pano_id_fk FOREIGN KEY (pano_id) REFERENCES pan.panol(pano_id);


-- pan.estanteria foreign keys

ALTER TABLE pan.estanteria ADD CONSTRAINT estanteria_fk FOREIGN KEY (pano_id) REFERENCES pan.panol(pano_id);


-- pan.herramientas foreign keys

ALTER TABLE pan.herramientas ADD CONSTRAINT herramientas_pano_id_fk FOREIGN KEY (pano_id) REFERENCES pan.panol(pano_id);


-- pan.panol foreign keys

ALTER TABLE pan.panol ADD CONSTRAINT panol_esta_id_fk FOREIGN KEY (esta_id) REFERENCES prd.establecimientos(esta_id);


-- pan.salida_panol foreign keys

ALTER TABLE pan.salida_panol ADD CONSTRAINT salida_panol_pano_id_fk FOREIGN KEY (pano_id) REFERENCES pan.panol(pano_id);


-- pan.trazacomponente foreign keys

ALTER TABLE pan.trazacomponente ADD CONSTRAINT trazacomponente_estan_id_fk FOREIGN KEY (estan_id) REFERENCES pan.estanteria(estan_id);
ALTER TABLE pan.trazacomponente ADD CONSTRAINT trazacomponente_pano_id_fk FOREIGN KEY (pano_id) REFERENCES pan.panol(pano_id);

-- DROP SCHEMA pro;

CREATE SCHEMA pro AUTHORIZATION postgres;

-- pro.pedidos_trabajo definition

-- Drop table

-- DROP TABLE pro.pedidos_trabajo;

CREATE TABLE pro.pedidos_trabajo (
	petr_id serial NOT NULL,
	cod_proyecto varchar NOT NULL,
	descripcion varchar NOT NULL,
	estado varchar NULL,
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


-- pro.pedidos_trabajo foreign keys

ALTER TABLE pro.pedidos_trabajo ADD CONSTRAINT pedidos_trabajo_clie_id_fk FOREIGN KEY (clie_id) REFERENCES core.clientes(clie_id);
ALTER TABLE pro.pedidos_trabajo ADD CONSTRAINT pedidos_trabajo_fk FOREIGN KEY (proc_id) REFERENCES pro.procesos(proc_id);
ALTER TABLE pro.pedidos_trabajo ADD CONSTRAINT pedidos_trabajo_fk_1 FOREIGN KEY (empr_id) REFERENCES core.empresas(empr_id);
ALTER TABLE pro.pedidos_trabajo ADD CONSTRAINT pedidos_trabajo_umti_id_fk FOREIGN KEY (umti_id) REFERENCES core.tablas(tabl_id);


-- pro.procesos foreign keys

ALTER TABLE pro.procesos ADD CONSTRAINT procesos_esin_id_fk FOREIGN KEY (esin_id) REFERENCES core.tablas(tabl_id);
ALTER TABLE pro.procesos ADD CONSTRAINT procesos_form_id_fk FOREIGN KEY (form_id) REFERENCES frm.formularios(form_id);

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