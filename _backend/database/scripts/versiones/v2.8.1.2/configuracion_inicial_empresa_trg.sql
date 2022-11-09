drop trigger habilita_superadmin_ai after;

create trigger configuracion_inicial_empresa_ai after
insert
    on
    core.empresas for each row execute procedure core.configuracion_inicial_empresa_trg();
