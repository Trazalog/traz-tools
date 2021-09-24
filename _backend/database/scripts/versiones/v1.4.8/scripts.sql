ALTER TABLE prd.formulas ADD empr_id int4 NOT NULL DEFAULT 1;
ALTER TABLE prd.formulas ALTER COLUMN empr_id DROP DEFAULT;
ALTER TABLE core.transportistas ADD empr_id int4 NOT NULL DEFAULT 1;
ALTER TABLE core.transportistas ALTER COLUMN empr_id DROP DEFAULT;
