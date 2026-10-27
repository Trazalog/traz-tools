# Análisis de impacto — Formulario "Entrega Materiales" por empresa + entrega sin formulario

## Objetivo

Qué es: el análisis de impacto para que una empresa nueva **clone su propio formulario "Entrega
Materiales"** desde la empresa plantilla 9000, y para que la pantalla de entrega **permita entregar
aunque no exista** ese formulario. Trae la causa confirmada, los cambios concretos y lo que falta
confirmar, para aprobación del PM antes de tocar nada.
Para quién: Rodolfo (PM).
Cuándo leerlo: antes de implementar/desplegar.
Qué NO cubre: no cambia cómo la pantalla resuelve el form (sigue por `configuraciones`); no hace un
backfill del formulario a empresas ya existentes (con el fix de la vista igual podrán entregar — ver §7).

> Reemplaza la versión anterior de este documento (que proponía una constante con un id fijo); esa
> idea quedó descartada porque los formularios son **por empresa**.

## Metadata

- **Fecha:** 2026-09-13
- **Clase de riesgo:** 🔴 (toca el trigger/stored procedure de creación de empresa — schema core) +
  🟡 (vista de entrega en `traz-comp-almacenes`)
- **Diseño definido por el PM** (3 requisitos, abajo). No es decisión de arquitectura mía.
- **Estado:** esperando aprobación. **No se modificó ningún archivo.**

## Requisitos (PM, 2026-09-13)

1. Al crearse una empresa, crear un formulario "Entrega Materiales" **copiando** el de la empresa
   **9000**, con el `empr_id` recién generado.
2. Si ese formulario no existe en 9000, **no crearlo** (sin error).
3. La pantalla de entrega debe **permitir entregar aunque no exista** el formulario "Entrega
   Materiales" para ese `empr_id` (la resolución sigue por `configuraciones.formulario_entrega_materiales`;
   si no hay valor, no muestra formulario y deja entregar).

## Estado actual (verificado)

- **El SP YA está versionado** en `_backend/database/scripts/versiones/v2.8.1.2/`
  (`configuracion_inicial_empresa_trg_func.sql` + `..._trg.sql`) — idéntico al que pasó el PM. Así que
  no hay que "versionarlo": hay que **agregarle** el bloque de clonado en una versión nueva.
- **Modelo de datos de formularios:**
  - `frm.formularios` = cabecera (form_id, nombre, descripcion, empr_id, eliminado).
  - `frm.items` = **definición de campos** del formulario (name, label, requerido, valo_id, orden,
    form_id, tipo_dato, columna, multiple, eliminado). *(Es lo que hay que clonar, junto con la
    cabecera.)*
  - `frm.instancias_formularios` = instancias **llenadas** (no se clonan).
- **La pantalla resuelve el form por `configuraciones`**: `Entrega_Material.php:50` →
  `getTablaValor('configuraciones','formulario_entrega_materiales')`. Para que una empresa nueva use su
  clon, el SP debe **setear esa config** al `form_id` clonado.
- **Renderizar un form por id no filtra por `empr_id`** (solo el *listado* filtra), así que el modelo
  por-empresa funciona sin tocar la resolución.
- **El bug del punto 3:** en `view_entrega_pedido_pendiente.php`, las tres funciones de finalizar
  (`cerrarTarea`, `cerrarTareaParcial`, `cerrarTareaSinEntrega`) hacen:
  ```js
  idFormDinamico = "#"+$('.frm-new').find('form').attr('id');   // sin form → "#undefined"
  if (idFormDinamico != "#undefined") { newInfoID = await frmGuardarConPromesa(...) }
  if (newInfoID) { } else { alertify.error("Error al Agregar Formulario dinamico"); return; }
  ```
  Cuando no hay formulario, `newInfoID` queda `undefined` y **corta**. Por eso hoy una empresa sin
  form no puede entregar.

## Cambio 1 — SP `core.configuracion_inicial_empresa_trg()` (versión nueva)

Agregar, dentro del SP (en su propio `begin/exception ... when others then raise warning` como los
demás bloques, para **no tumbar el alta** si algo falla), la lógica:

```plpgsql
declare v_tmpl_form_id integer; v_new_form_id integer;
...
begin
    /* Clona el formulario "Entrega Materiales" de la empresa plantilla 9000 */
    select f.form_id into v_tmpl_form_id
    from frm.formularios f
    where f.empr_id = 9000 and f.nombre = 'Entrega Materiales' and f.eliminado <> 1
    limit 1;

    if v_tmpl_form_id is not null then
        -- cabecera
        insert into frm.formularios (nombre, descripcion, empr_id, eliminado)
        select nombre, descripcion, new.empr_id, eliminado
        from frm.formularios where form_id = v_tmpl_form_id
        returning form_id into v_new_form_id;

        -- campos (definición)
        insert into frm.items (form_id, name, label, requerido, valo_id, orden, tipo_dato, columna, multiple, eliminado)
        select v_new_form_id, name, label, requerido, valo_id, orden, tipo_dato, columna, multiple, eliminado
        from frm.items where form_id = v_tmpl_form_id and eliminado = false;

        -- que la pantalla (que lee configuraciones) use el clon
        insert into core.tablas (tabla, valor, descripcion, empr_id)
        values ('configuraciones', 'formulario_entrega_materiales', v_new_form_id::text, new.empr_id);
    end if;
exception when others then
    raise warning 'CONFINICEMP: error clonando formulario Entrega Materiales %: %', sqlstate, sqlerrm;
end;
```

- **`empr_id` no tiene el problema del proveedor**: acá es SQL nativo en Postgres (`new.empr_id`
  integer), no pasa por el DataService.
- **⚠️ A CONFIRMAR (bloqueante para escribir el INSERT final):** el **DDL exacto** de
  `frm.formularios` y `frm.items` — necesito las columnas y cuáles son `NOT NULL`, porque el repo no
  tiene el schema y no puedo consultar la BD. Las de arriba están **inferidas del código**; si hay
  alguna columna `NOT NULL` que no listé, el INSERT falla. Pasame un `\d frm.formularios` y
  `\d frm.items` (o el DDL) y lo dejo exacto.
- **Versionado:** va como versión nueva (p.ej. `v2.8.1.3/`) con el `..._func.sql` completo
  (CREATE OR REPLACE, idempotente) siguiendo el patrón de `v2.8.1.2/`.

## Cambio 2 — Vista de entrega (punto 3), `traz-comp-almacenes`

En `view_entrega_pedido_pendiente.php`, en las **tres** funciones de finalizar, mover el chequeo de
`newInfoID` **adentro** del `if` que detecta formulario, para que sin formulario se pueda finalizar:

```js
idFormDinamico = "#"+$('.frm-new').find('form').attr('id');
if (idFormDinamico != "#undefined") {
    wo();
    var newInfoID = await frmGuardarConPromesa($(idFormDinamico));
    if (!newInfoID) { wc(); alertify.error("Error al Agregar Formulario dinamico"); return; }
}
// si no hay formulario, se continúa: se puede entregar sin form
```

- **A verificar en la prueba:** que el POST de cierre (`Proceso/cerrarTarea`) tolere `info_id` nulo
  (sin form) — si hoy el backend asume un `info_id`, hay que contemplarlo. Se confirma corriendo el
  ciclo.

## Plan de verificación (post-aprobación)

1. Aplicar el SP nuevo (BD) y desplegar la vista (traz-comp-almacenes) en DEMO.
2. Precondición: que la empresa 9000 tenga el formulario "Entrega Materiales" (confirmar).
3. Seedear empresa nueva → verificar que quedó su form clonado y `configuraciones.formulario_entrega_materiales`.
4. Correr `@ALM-UC-010` → recepción → pedido → aprobación → **entrega parcial (Ent. Parcial)** →
   **entrega del resto (Entregado)** en verde, con el formulario clonado.
5. Caso sin form (empresa vieja tipo DocTest Empresa SA): entregar debe funcionar **sin** formulario.
6. Regresión: `npm run test:all` sin cambios.

## Rollback

- SP: reaplicar la versión v2.8.1.2 (sin el bloque de clonado) — es `CREATE OR REPLACE`, reversible.
  Los datos ya sembrados (forms clonados, config) quedan; no molestan.
- Vista: revertir el cambio de las 3 funciones.
- Sin migración destructiva.

## Compatibilidad

- **Empresas existentes:** intactas. Siguen resolviendo por su `configuraciones` (las que tienen 26,
  siguen con 26). El SP solo agrega el clon para empresas **nuevas**.
- **Cambio aditivo** en BD (nuevas filas) y acotado en la vista (permitir un camino que hoy corta).

## Qué queda afuera

- **Backfill** del formulario a empresas viejas: no se hace. Con el fix de la vista (punto 3) igual
  van a poder entregar (sin formulario). Si más adelante se quiere que tengan el form, es un backfill
  aparte.
