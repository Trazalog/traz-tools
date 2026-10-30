<?php
/**
 * Plantilla de modal para traz-tools.
 * Copiar en la vista que corresponda y reemplazar los placeholders.
 * Cabecera: bg-blue = #dd4b39 (color por defecto del sistema en este build de AdminLTE).
 * Ver .opencode/skills/modales-tools/SKILL.md
 */
?>
<!-- MODAL __NOMBRE__ -->
<div class="modal fade" id="modal__Nombre__" tabindex="-1" role="dialog" aria-labelledby="modal__Nombre__Label">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
                <h4 class="modal-title" id="modal__Nombre__Label">__TITULO__</h4>
            </div>
            <div class="modal-body">
                <div class="row">
                    <div class="col-xs-12">
                        <table id="tabla__Nombre__" class="table table-bordered table-hover">
                            <thead>
                                <tr>
                                    <th>__COLUMNA_1__</th>
                                    <th>__COLUMNA_2__</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-primary" onclick="imprimir__Nombre__()">
                    <i class="fa fa-print"></i> Imprimir
                </button>
            </div>
        </div>
    </div>
</div>

<script>
// Apertura desde un icono de DataTable
function modal__Nombre__(element) {
    wo();

    var $icon = $(element);
    var $tr = $icon.closest('tr');

    var rowData = {};
    try {
        rowData = $('#__tabla_listado__').DataTable().row($tr).data() || {};
    } catch (e) {
        rowData = {};
    }

    var id = $icon.data('id') || rowData.id || null;

    var $tbody = $('#tabla__Nombre__ tbody');
    $tbody.empty();

    $('#modal__Nombre__').modal('show');

    if (!id) {
        $tbody.html('<tr><td colspan="2" class="text-center text-danger">No se pudo identificar el registro.</td></tr>');
        wc();
        return;
    }

    $.ajax({
        type: 'POST',
        dataType: 'json',
        data: { id: id },
        url: '<?php echo base_url(ALM) ?>__Modulo__/__metodo__',
        success: function(rows) {
            $tbody.empty();

            if (!Array.isArray(rows) || rows.length === 0) {
                $tbody.append('<tr><td colspan="2" class="text-center">Sin datos registrados.</td></tr>');
                return;
            }

            rows.forEach(function(row) {
                $tbody.append(
                    $('<tr>')
                        .append($('<td>').text(row.campo1 || ''))
                        .append($('<td>').text(row.campo2 || ''))
                );
            });
        },
        error: function() {
            $tbody.html('<tr><td colspan="2" class="text-center text-danger">No se pudieron cargar los datos.</td></tr>');
        },
        complete: function() {
            wc();
        }
    });
}

// Impresion del modal
function imprimir__Nombre__() {
    var base = '<?php echo base_url()?>';
    $('#modal__Nombre__ .modal-content').printThis({
        debug: false,
        importCSS: true,
        importStyle: true,
        pageTitle: '__TITULO__',
        printContainer: true,
        loadCSS: base + 'lib/bower_components/bootstrap/dist/css/bootstrap.min.css',
        copyTagClasses: true,
        printDelay: 500,
        base: base
    });
}
</script>
