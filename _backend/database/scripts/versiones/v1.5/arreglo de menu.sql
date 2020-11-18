

referencias para orden de menu
* PRD -> 100
* LOG -> 200
* ALM -> 300
* PAN -> 400
* TAR -> 500
* BPM (BAND DE ENTRADA) -> 600

-- agregar modulo BPM al constraint de la tabla menu
ALTER TABLE seg.menues DROP CONSTRAINT menues_check
ALTER TABLE seg.menues ADD CONSTRAINT menues_check CHECK ((((modulo)::text = 'PRD'::text) OR ((modulo)::text = 'CORE'::text) OR ((modulo)::text = 'ALM'::text) OR ((modulo)::text = 'MAN'::text) OR ((modulo)::text = 'TAR'::text) OR ((modulo)::text = 'PAN'::text) OR ((modulo)::text = 'LOG'::text) OR ((modulo)::text = 'SEG'::text) OR ((modulo)::text = 'TRZ'::text) OR ((modulo)::text = 'PRO'::text) OR ((modulo)::text = 'FIS'::text) OR ((modulo)::text = 'BPM'::text) ))

-- arega opcion de bandeja aparte
INSERT INTO seg.menues (modulo, opcion, texto, url, javascript, orden, url_icono, texto_onmouseover, eliminado, fec_alta, usuario, usuario_app, opcion_padre) VALUES('BPM', 'tareas', 'Tareas', NULL, NULL, 10, 'fa fa-star', 'Bandeja de Tareas', 0, '2020-09-24 13:12:55.471177-03', 'postgres', 'postgres', NULL);

INSERT INTO memberships_menues (modulo, opcion, "group", "role", fec_alta, usuario, usuario_app) VALUES('BPM', 'bandeja_tareas', 'Empresa_Test', 'Solicitante', '2020-10-02', 'postgres', 'postgres');