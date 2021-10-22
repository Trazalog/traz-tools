ALTER TABLE alm.alm_lotes ADD CONSTRAINT alm_lotes_un UNIQUE (prov_id, arti_id, depo_id, codigo, batch_id);
