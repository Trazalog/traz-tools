-- ============================================================================
-- Alinear core.tablas / paises_registracion con el geo de paises  (DEMO y PROD)
-- ----------------------------------------------------------------------------
-- QUE ARREGLA
--   El combo de paises de la registracion sale de `tabla='paises_registracion'`,
--   que guarda el codigo ISO en `valor` ('AR') y el nombre en `descripcion`
--   ('Argentina'). Pero los ESTADOS no se buscan por el codigo: se buscan por el
--   nombre, concatenado (getEstados de COREDataService):
--
--     tabla = 'estados_paises' || <descripcion>      -> estados_paisesArgentina
--
--   Asi que si la `descripcion` de paises_registracion no coincide CARACTER POR
--   CARACTER con el `valor` de `tabla='paises'`, el combo de estados vuelve VACIO
--   y no hay ningun error en ningun log: la query simplemente no encuentra filas.
--
--   Verificado: `paises_registracion` tiene 'Peru' y el geo carga 'Perú'. Quien se
--   registra eligiendo Peru no ve ninguna provincia.
--
-- QUE HACE Y QUE NO
--   Corrige solo la `descripcion`, y solo de las filas que tienen un equivalente
--   en `paises` ignorando acentos y mayusculas. NO toca `tabl_id`, NO toca `valor`,
--   NO inserta paises nuevos, NO da de baja nada.
--
--   Por que eso es seguro: lo que las demas tablas guardan como referencia es el
--   `tabl_id` (seg.users.reg_pais_id, core.empresas.pais_id, prd.establecimientos.pais),
--   y el `tabl_id` lo arma el trigger como tabla||valor. Como ni `tabla` ni `valor`
--   cambian, el `tabl_id` queda igual y ninguna referencia se rompe.
--
--   IDEMPOTENTE: la condicion `r.descripcion <> p.valor` hace que la segunda
--   corrida no actualice nada. Re-ejecutable sin efectos.
--
-- COMO SE CORRE
--   En el servidor de la base, contra la base de ESE ambiente:
--     psql -h <host> -p <puerto> -U <usuario> -d <base> -f geo-paises-registracion.sql
--
--   La PARTE 1 y la PARTE 3 son solo SELECT: se pueden correr sueltas para ver el
--   estado sin cambiar nada. La PARTE 2 es la unica que escribe, y va en transaccion.
--
-- LO QUE QUEDA PARA DECIDIR (partes 4 y 5, comentadas a proposito)
--   · Que paises se ofrecen en la registracion es una decision de producto, no la
--     toma este script: la PARTE 4 esta comentada.
--   · 'Alemania' (DE) no esta en el geo —el dataset es de paises hispanohablantes—
--     asi que nunca va a tener estados. La PARTE 5 ayuda a decidir que hacer.
--
-- Relacionado: geo-paises-hispanohablantes.sql (carga paises, estados y localidades)
-- Fecha: 2026-10-22
-- ============================================================================


-- ===================== PARTE 1 — DIAGNOSTICO (solo lectura) =================
-- Corre esto PRIMERO y guarda la salida. Es el estado del que partis.
--   en_paises = 0  -> la descripcion no existe como valor en 'paises'
--   estados   = 0  -> el combo de estados va a venir VACIO para ese pais
--   usuarios      -> cuantos usuarios ya se registraron con ese pais

select r.valor                                        as codigo,
       r.descripcion,
       (select count(*) from core.tablas p
         where p.tabla = 'paises'
           and p.valor = r.descripcion
           and p.eliminado = false)                   as en_paises,
       (select count(*) from core.tablas e
         where e.tabla = 'estados_paises' || r.descripcion
           and e.eliminado = false)                   as estados,
       (select count(*) from seg.users u
         where u.reg_pais_id = r.tabl_id)             as usuarios
  from core.tablas r
 where r.tabla = 'paises_registracion'
   and r.eliminado = false
 order by 4, 2;


-- ===================== PARTE 2 — EL ARREGLO =================================
-- Alinea la descripcion con el nombre canonico de 'paises', solo donde difieren
-- unicamente por acentos o mayusculas. Se usa translate() y no la extension
-- unaccent, que puede no estar instalada.

begin;

update core.tablas r
   set descripcion = p.valor
  from core.tablas p
 where r.tabla     = 'paises_registracion'
   and r.eliminado = false
   and p.tabla     = 'paises'
   and p.eliminado = false
   and r.descripcion <> p.valor
   and lower(translate(r.descripcion, 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiounAEIOUUN'))
     = lower(translate(p.valor,       'áéíóúüñÁÉÍÓÚÜÑ', 'aeiounAEIOUUN'));

-- Si la salida de arriba dice UPDATE 0 en la primera corrida, no habia nada
-- desalineado y podes hacer rollback tranquilo: no cambia nada igual.
commit;


-- ===================== PARTE 3 — VERIFICACION (solo lectura) ================
-- Despues del commit, esto tiene que mostrar en_paises=1 y estados>0 en todas
-- las filas, salvo los paises que no esten en el geo (ver PARTE 5).

select r.valor                                        as codigo,
       r.descripcion,
       (select count(*) from core.tablas e
         where e.tabla = 'estados_paises' || r.descripcion
           and e.eliminado = false)                   as estados,
       case when exists (select 1 from core.tablas e
                          where e.tabla = 'estados_paises' || r.descripcion
                            and e.eliminado = false)
            then 'OK'
            else 'SIN ESTADOS'
       end                                            as resultado
  from core.tablas r
 where r.tabla = 'paises_registracion'
   and r.eliminado = false
 order by 4 desc, 2;


-- ===================== PARTE 4 — AGREGAR PAISES (comentada) =================
-- Que paises se ofrecen en la registracion es decision de producto. Hoy hay 7;
-- el geo tiene 21 con estados y localidades cargados.
--
-- Esto agrega los que falten tomando la `descripcion` DEL PROPIO 'paises', asi
-- que por construccion no pueden volver a desalinearse. Es el mismo patron del
-- geo: on conflict (tabl_id) solo normaliza, nunca cambia valor ni tabl_id.
--
-- Para usarlo: descomentar, y dejar en el `in (...)` del final SOLO los paises
-- que se quieran ofrecer. Sin ese filtro entran los 21.
--
-- begin;
-- insert into core.tablas (tabla, valor, descripcion)
-- select 'paises_registracion', iso.codigo, p.valor
--   from core.tablas p
--   join (values
--           ('Argentina','AR'), ('Bolivia','BO'), ('Chile','CL'),
--           ('Colombia','CO'), ('Costa Rica','CR'), ('Cuba','CU'),
--           ('República Dominicana','DO'), ('Ecuador','EC'),
--           ('El Salvador','SV'), ('España','ES'), ('Guatemala','GT'),
--           ('Guinea Ecuatorial','GQ'), ('Honduras','HN'), ('México','MX'),
--           ('Nicaragua','NI'), ('Panamá','PA'), ('Paraguay','PY'),
--           ('Perú','PE'), ('Puerto Rico','PR'), ('Uruguay','UY'),
--           ('Venezuela','VE')
--        ) as iso(nombre, codigo) on iso.nombre = p.valor
--  where p.tabla = 'paises'
--    and p.eliminado = false
--    and p.valor in ('Argentina','Bolivia','Ecuador','México','Perú','Uruguay')
-- on conflict (tabl_id) do update
--    set descripcion = excluded.descripcion,
--        eliminado   = false;
-- commit;


-- ===================== PARTE 5 — 'Alemania' (comentada) =====================
-- 'Alemania' (DE) no esta en el geo, que es solo de paises hispanohablantes, asi
-- que su combo de estados siempre va a venir vacio. Antes de decidir, mirar si
-- hay usuarios registrados con ese pais:
--
--   select u.usua_id, u.email
--     from seg.users u
--    where u.reg_pais_id = 'paises_registracionDE';
--
-- Tres caminos, en orden de menor a mayor trabajo:
--   a) Dejarla y aceptar que el combo de estados venga vacio.
--   b) Sacarla de la lista con baja LOGICA (nunca borrado real: si hay usuarios
--      registrados con ella, sus referencias siguen resolviendo):
--
--        update core.tablas
--           set eliminado = true
--         where tabl_id = 'paises_registracionDE'
--           and tabla   = 'paises_registracion';
--
--   c) Cargarle estados y localidades de otra fuente, con el mismo patron del
--      geo: tabla='estados_paisesAlemania', y
--           tabla='localidades_estados_paisesAlemania<estado>'.
