---
name: Modales Tools
description: Crear o modificar modales Bootstrap/AdminLTE en traz-tools (CodeIgniter): cabecera bg-blue (#dd4b39), footer Cancelar/Imprimir, loader wo()/wc(), DataTable y printThis. Usar cuando se pida un modal nuevo o se ajuste uno existente en application/modules.
---

# Modales en traz-tools

Guía para armar modales consistentes con el resto del sistema (AdminLTE 2 + Bootstrap 3 + CodeIgniter 3).

Referencia viva: `application/modules/traz-comp-pan/views/herramienta/modals/modal_editar.php`
(también `application/modules/traz-comp-almacenes/views/ajustestock/list.php` y
`application/modules/traz-comp-almacenes/views/movimientosinternos/list.php`).

Plantilla lista para copiar: `templates/modal.php` (relativa a este `SKILL.md`).

## Reglas clave

1. **Cabecera siempre `class="modal-header bg-blue"`.**
   En este proyecto `AdminLTE.min.css` redefine `.bg-blue` como `#dd4b39`, que es el rojo
   por defecto del sistema. **No** escribir `<style>` propio, `style="background-color:..."`,
   ni clases `.bg-red` (no existe en este build).
2. **La “×” de cierre va en blanco:** `<span aria-hidden="true" style="color:white;">&times;</span>`.
   Sin eso queda negra sobre el rojo.
3. **Footer con la dupla estándar:** `btn btn-default` (Cancelar/Cerrar) + `btn btn-primary`
   (Imprimir/Guardar). Si el modal se imprime, el footer y la cabecera llevan `hidden-print`.
4. **Un `id` único y descriptivo**, con `tabindex="-1"`, `role="dialog"` y `aria-labelledby`
   apuntando al `id` del `h4.modal-title`.
5. **Loader global `wo()` / `wc()`** (definidas en `application/views/layout/general_scripts.php`):
   `wo()` al abrir una acción asíncrona y `wc()` **siempre** al terminar. Cerrar en el callback
   `complete` de `$.ajax` (o en un `finally`) para que el overlay no quede trabado cuando la
   respuesta viene vacía o falla.
6. **Datos dinámicos con `.text()`, nunca `html()`**, para evitar XSS:
   `$('<td>').text(row.campo || '')`. Para armar HTML con datos, escapar con un helper `esc()`.
7. **No agregar CSS de layout adentro del modal.** Usar clases de Bootstrap/AdminLTE
   (`row`, `col-*`, `table`, `text-center`, `text-right`, etc.).

## Anatomía

```html
<!-- MODAL <NOMBRE> -->
<div class="modal fade" id="modalNombre" tabindex="-1" role="dialog" aria-labelledby="modalNombreLabel">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
                <h4 class="modal-title" id="modalNombreLabel">Título</h4>
            </div>
            <div class="modal-body">
                <!-- contenido -->
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-primary" onclick="imprimirNombre()">
                    <i class="fa fa-print"></i> Imprimir
                </button>
            </div>
        </div>
    </div>
</div>
```

Agrandar: `class="modal-dialog modal-lg"` (o `style="width: 90%; max-width: 1200px;"` como en
`list.php` de movimientos internos).

## Cómo se monta el modal

Elegir según el caso:

- **Estático en la vista:** declararlo en el `.php` y abrirlo con `$('#modalX').modal('show')`.
- **Dinámico por AJAX:** dejar `<div id="modalContainer"></div>` y que el controller devuelva
  la vista con `$this->load->view(...)`; el JS hace `$('#modalContainer').html(response)` y
  después `$('#modalX').modal('show')`. Patrón: `Movimientointerno::modalReImpresion()`.
- **Componente compartido:** si la vista se reutiliza en varios listados, cargarla con
  `<?php $this->load->view(COD . 'componentes/modalX'); ?>` (ver
  `traz-comp-codigos/views/componentes/modalMovimientoInterno.php`).

## Endpoints y helpers

- URLs dentro de una vista: `<?php echo base_url(ALM) ?>Modulo/metodo` (misma convención que el
  resto del listado) o `<?php echo base_url(); ?>...` para assets.
- Respuestas: el controller hace `echo json_encode($rows)` y el JS usa `dataType: 'json'`.
- Si el modal se abre desde un ícono de DataTable, leer los datos así:

```js
var $icon = $(element);
var $tr = $icon.closest('tr');
var rowData = {};
try {
    rowData = $('#tabla').DataTable().row($tr).data() || {};
} catch (e) { rowData = {}; }
var id = $icon.data('id') || rowData.id || null;
```

Conviene igual poner `data-*` en el ícono: `data-id`, `data-otro`, etc.

## Impresión

Usar `printThis` (jQuery plugin ya cargado globalmente):

```js
function imprimirNombre() {
    var base = '<?php echo base_url()?>';
    $('#modalNombre .modal-content').printThis({
        debug: false,
        importCSS: true,
        importStyle: true,
        pageTitle: 'Título',
        printContainer: true,
        loadCSS: base + 'lib/bower_components/bootstrap/dist/css/bootstrap.min.css',
        copyTagClasses: true,
        printDelay: 500,
        base: base
    });
}
```

Marcar con `hidden-print` (Bootstrap) lo que no debe salir: cabecera, footer, botones, inputs.
Si solo se imprime el `.modal-body`, apuntar `printThis` a ese contenedor (`class="modalBodyX"`,
como en el modal de QR).

## Verificación

1. `C:\xampp\php\php.exe -l <archivo>` para cada archivo PHP tocado.
2. Si el bloque JS es nuevo y extenso, extraerlo a un `.js` temporal y correr `node --check`.
3. Prueba visual sin navegador manual: crear un HTML temporal en la raíz del proyecto que cargue
   Bootstrap + FontAwesome + `AdminLTE.min.css` por `http://localhost/traz-tools/...`, incluir el
   markup del modal, rellenar los campos con jQuery y abrirlo, y sacar captura con
   `C:\Program Files\Google\Chrome\Application\chrome.exe --headless=new --disable-gpu
   --no-sandbox --user-data-dir=<temp> --virtual-time-budget=3000 --window-size=1000,700
   --screenshot=<png> http://localhost/traz-tools/_temp.html`. Borrar el HTML temporal al final.
4. Revisar que `wo()`/`wc()` queden balanceados en todos los caminos (éxito, vacío, error).

## Checklist antes de dar por terminado

- [ ] `modal-header bg-blue` y “×” blanca.
- [ ] `id`, `aria-labelledby` y `modal-title` coherentes.
- [ ] Footer con Cancelar + acción primaria.
- [ ] `wo()`/`wc()` balanceados.
- [ ] Contenido dinámico escapado con `.text()`.
- [ ] `printThis` apuntando al contenedor correcto y `hidden-print` donde corresponde.
- [ ] `php -l` OK y prueba visual hecha.
