-- ============================================================================
-- Cargar core.tablas / paises_registracion  (DEMO y PRODUCCIÓN)
-- ----------------------------------------------------------------------------
-- QUE ES
--   Los paises del combo de la REGISTRACION de usuarios salen de core.tablas con
--   `tabla='paises_registracion'`. Esta tabla es aparte de `tabla='paises'` (que
--   usan empresas y establecimientos) y es la que puede faltar en un ambiente
--   nuevo: si no tiene filas, el combo de la registracion viene VACIO.
--
--   Este script la carga, es idempotente, y deja el ambiente verificado.
--
-- LA CONVENCION, QUE NO ES LA OBVIA
--   En paises_registracion:  valor = codigo ISO ('AR')   descripcion = nombre ('Argentina')
--
--   Pero los ESTADOS no se buscan por el codigo: se buscan por el NOMBRE,
--   concatenado (getEstados / getLocalidades de COREDataService):
--
--     tabla = 'estados_paises' || <descripcion>                     -> estados_paisesArgentina
--     tabla = 'localidades_estados_paises' || <pais> || <estado>
--
--   Asi que la `descripcion` tiene que coincidir CARACTER POR CARACTER con el
--   `valor` de `tabla='paises'`. Si no, el combo de estados vuelve vacio y NO HAY
--   NINGUN ERROR EN NINGUN LOG: la query simplemente no encuentra filas. Es el
--   bug que tenia el DEMO, con 'Peru' sin acento contra el 'Perú' del geo.
--
--   Por eso este script NO escribe los nombres a mano: los toma del propio
--   `paises`, asi que por construccion no pueden desalinearse.
--
-- PRERREQUISITO
--   Antes de esto tiene que estar corrido `geo-paises-hispanohablantes.sql`, que
--   carga `paises` (21), `estados_paises*` (530) y `localidades_estados_paises*`
--   (25.505). La PARTE 0 lo verifica y te dice si falta.
--
-- IDEMPOTENTE Y NO DESTRUCTIVO
--   `on conflict (tabl_id) do update` solo normaliza `descripcion` y reactiva
--   (eliminado=false). NUNCA cambia `tabla`, `valor` ni `tabl_id`, asi que las
--   referencias existentes por tabl_id —seg.users.reg_pais_id,
--   core.empresas.pais_id, prd.establecimientos.pais— quedan intactas.
--   Re-ejecutable sin efectos.
--
-- COMO SE CORRE
--   En el servidor de la base, contra la base de ESE ambiente:
--     psql -h <host> -p <puerto> -U <usuario> -d <base> -f geo-paises-registracion.sql
--
--   Las PARTES 0, 1 y 4 son solo SELECT. La PARTE 2 es la unica que escribe.
--
-- QUE PAISES CARGA
--   Los 6 que ya tenia el DEMO y estan en el geo: Argentina, Bolivia, Ecuador,
--   México, Perú y Uruguay. Para ofrecer mas, ver el comentario de la PARTE 2:
--   el mapeo ISO de los 21 ya esta escrito, solo hay que agregarlos al filtro.
--   'Alemania' va aparte, en la PARTE 3, porque no esta en el geo.
--
-- Fecha: 2026-10-22 | Relacionado: geo-paises-hispanohablantes.sql
-- ============================================================================


-- ===================== PARTE 0 — PRERREQUISITO (solo lectura) ===============
-- Si `paises` da 0, PARA: primero corre geo-paises-hispanohablantes.sql.

select 'paises'                     as tabla, count(*) as filas,
       case when count(*) = 0 then '>>> FALTA: corre primero geo-paises-hispanohablantes.sql'
            else 'ok' end           as estado
  from core.tablas where tabla = 'paises' and eliminado = false
union all
select 'estados_paises*', count(*),
       case when count(*) = 0 then '>>> FALTA: corre primero geo-paises-hispanohablantes.sql'
            else 'ok' end
  from core.tablas where tabla like 'estados_paises%' and eliminado = false
union all
select 'localidades_*', count(*),
       case when count(*) = 0 then '>>> FALTA: corre primero geo-paises-hispanohablantes.sql'
            else 'ok' end
  from core.tablas where tabla like 'localidades_estados_paises%' and eliminado = false;


-- ===================== PARTE 1 — QUE HAY HOY (solo lectura) =================
-- En un ambiente nuevo esto devuelve 0 filas. Guarda la salida: es el estado
-- del que partis.

select r.valor as codigo, r.descripcion,
       (select count(*) from core.tablas e
         where e.tabla = 'estados_paises' || r.descripcion
           and e.eliminado = false)  as estados
  from core.tablas r
 where r.tabla = 'paises_registracion'
   and r.eliminado = false
 order by 2;


-- ===================== PARTE 2 — LA CARGA ===================================
-- Inserta tomando la `descripcion` del propio `paises`, asi que no puede quedar
-- desalineada. El `in (...)` del final es la lista que se ofrece: para agregar
-- paises, sumalos ahi con el nombre EXACTO como figura en el mapeo de abajo.

begin;

insert into core.tablas (tabla, valor, descripcion)
select 'paises_registracion', iso.codigo, p.valor
  from core.tablas p
  join (values
          ('Argentina','AR'), ('Bolivia','BO'), ('Chile','CL'),
          ('Colombia','CO'), ('Costa Rica','CR'), ('Cuba','CU'),
          ('República Dominicana','DO'), ('Ecuador','EC'),
          ('El Salvador','SV'), ('España','ES'), ('Guatemala','GT'),
          ('Guinea Ecuatorial','GQ'), ('Honduras','HN'), ('México','MX'),
          ('Nicaragua','NI'), ('Panamá','PA'), ('Paraguay','PY'),
          ('Perú','PE'), ('Puerto Rico','PR'), ('Uruguay','UY'),
          ('Venezuela','VE')
       ) as iso(nombre, codigo) on iso.nombre = p.valor
 where p.tabla = 'paises'
   and p.eliminado = false
   and p.valor in ('Argentina', 'Bolivia', 'Ecuador', 'México', 'Perú', 'Uruguay')
on conflict (tabl_id) do update
   set descripcion = excluded.descripcion,
       eliminado   = false;

-- Red de seguridad para un ambiente que YA tenia la tabla con el nombre mal
-- escrito (el caso 'Peru' del DEMO): alinea la descripcion con el nombre
-- canonico de `paises` cuando difieren solo por acentos o mayusculas. Se usa
-- translate() y no la extension unaccent, que puede no estar instalada.
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

commit;


-- ===================== PARTE 3 — 'Alemania' (comentada, opcional) ===========
-- El DEMO tiene tambien 'Alemania' (DE). No esta en el geo —que es solo de
-- paises hispanohablantes— asi que su combo de estados SIEMPRE va a venir vacio.
-- No la cargo por defecto. Si en produccion se la quiere ofrecer igual:
--
--   begin;
--   insert into core.tablas (tabla, valor, descripcion)
--   values ('paises_registracion', 'DE', 'Alemania')
--   on conflict (tabl_id) do update
--      set descripcion = excluded.descripcion, eliminado = false;
--   commit;
--
-- Y si mas adelante se le quieren cargar divisiones, el patron es el del geo:
--   tabla='estados_paisesAlemania' y tabla='localidades_estados_paisesAlemania<estado>'.
--
-- Para ver si alguien ya se registro con ella antes de sacarla de una lista:
--   select u.usua_id, u.email from seg.users u
--    where u.reg_pais_id = 'paises_registracionDE';
--
-- Si se decide sacarla, va baja LOGICA, nunca borrado real (las referencias de
-- los usuarios que la eligieron tienen que seguir resolviendo):
--   update core.tablas set eliminado = true
--    where tabl_id = 'paises_registracionDE' and tabla = 'paises_registracion';


-- ===================== PARTE 4 — VERIFICACION (solo lectura) ================
-- Todas las filas tienen que decir OK. Un 'SIN ESTADOS' significa que ese pais
-- va a mostrar el combo de provincias vacio.

select r.valor as codigo, r.descripcion,
       (select count(*) from core.tablas e
         where e.tabla = 'estados_paises' || r.descripcion
           and e.eliminado = false)  as estados,
       case when exists (select 1 from core.tablas e
                          where e.tabla = 'estados_paises' || r.descripcion
                            and e.eliminado = false)
            then 'OK' else 'SIN ESTADOS' end as resultado
  from core.tablas r
 where r.tabla = 'paises_registracion'
   and r.eliminado = false
 order by 4 desc, 2;

-- Y que el endpoint que consume la registracion devuelva esas mismas filas:
--   GET <HOST>/services/COREDataService/tablas/paises_registracion
