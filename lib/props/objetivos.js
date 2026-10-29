/*
 * Metas sobre los KPIs (KPI-OBJ, ADR-A9), dentro del Tablero del Administrador.
 * Markup en application/views/dashboard/objetivos.php; datos de index.php/Objetivos/*
 * (empresa y usuario salen de la sesión, no de acá).
 *
 *  - Lista las metas vigentes con el valor de hoy y si se cumple.
 *  - Alta: una meta por indicador. Si ya hay una vigente, el servidor lo dice.
 *  - Cancelar: baja lógica, pide confirmación en la misma fila (sin confirm()).
 */
(function ($) {
    'use strict';

    var URL = '';

    function texto(s) {
        return $('<div>').text(s == null ? '' : String(s)).html();
    }

    function numero(v) {
        if (v === null || v === undefined || v === '') { return null; }
        var n = parseFloat(v);
        return isNaN(n) ? null : n;
    }

    function formato(v) {
        var n = numero(v);
        return n === null ? '—' : n.toLocaleString('es-AR', { maximumFractionDigits: 2 });
    }

    function fecha(iso) {
        var p = String(iso || '').split('-');
        return p.length === 3 ? p[2] + '/' + p[1] + '/' + p[0] : texto(iso);
    }

    function mensaje(txt, error) {
        $('#tz-meta-msg').prop('hidden', !txt).toggleClass('text-danger', !!error)
            .toggleClass('text-success', !error).text(txt || '');
    }

    function estado(m) {
        if (m.fuente === 'man' && m.cumple === null) {
            return '<span class="tz-sd" title="Lo calcula Mantenimiento: lo evalúa Kuntur">Se evalúa aparte</span>';
        }
        if (m.cumple === null) { return '<span class="tz-sd">Sin dato todavía</span>'; }
        return m.cumple ? '<span class="tz-ok">Se cumple</span>' : '<span class="tz-no">No se cumple</span>';
    }

    function pintar(r) {
        var $sel = $('#tz-meta-kpi').empty();
        $.each(r.kpis || [], function (_, k) {
            $sel.append($('<option>').val(k.nombre).text(k.titulo));
        });

        var metas = r.metas || [];
        var $c = $('#tz-metas-cuerpo').empty();
        if (!metas.length) {
            $c.append('<div class="tz-vacio">Todavía no hay metas. Cargá la primera abajo.</div>');
            return;
        }
        var titulos = {};
        $.each(r.kpis || [], function (_, k) { titulos[k.nombre] = k.titulo; });

        var $t = $('<table><thead><tr><th>Indicador</th><th>Meta</th><th>Hoy</th><th>Estado</th>'
            + '<th>Para el</th><th>Responsable</th><th></th></tr></thead><tbody></tbody></table>');
        $.each(metas, function (_, m) {
            var nombre = titulos[m.kpi] || m.descripcion || m.kpi;
            var origen = m.propuesto_por === 'kuntur' ? '<span class="tz-kuntur" title="La propuso Kuntur">Kuntur</span>' : '';
            $('<tr>').attr('data-id', m.objetivo_id).html(
                '<td>' + texto(nombre) + origen + '</td>'
                + '<td>' + (m.operador === '>=' ? '≥ ' : '≤ ') + formato(m.meta) + '</td>'
                + '<td>' + formato(m.valor_actual) + '</td>'
                + '<td>' + estado(m) + '</td>'
                + '<td>' + fecha(m.hasta) + '</td>'
                + '<td>' + texto(m.responsable) + '</td>'
                + '<td class="text-right"><a href="#" class="tz-meta-cancelar">Cancelar</a></td>'
            ).appendTo($t.find('tbody'));
        });
        $c.append($('<div class="tz-metas-tabla">').append($t));
    }

    function cargar() {
        $.getJSON(URL + 'lista').done(pintar).fail(function (xhr) {
            var txt = xhr && xhr.status === 403 ? 'Solo el administrador de la empresa ve las metas.'
                : 'No se pudieron cargar las metas.';
            $('#tz-metas-cuerpo').html('<div class="tz-vacio">' + texto(txt) + '</div>');
            if (xhr && xhr.status === 403) { $('#tz-meta-form').hide(); }
        });
    }

    function init(base) {
        URL = (base || window.TZ_BASE_URL || '') + 'index.php/Objetivos/';
        // Por defecto, fin de año. Fechas en hora local (toISOString usaría UTC).
        var hoy = new Date();
        var dos = function (n) { return (n < 10 ? '0' : '') + n; };
        $('#tz-meta-hasta').attr('min', hoy.getFullYear() + '-' + dos(hoy.getMonth() + 1) + '-' + dos(hoy.getDate()))
            .val(hoy.getFullYear() + '-12-31');
        cargar();
    }

    $(document).on('submit', '#tz-meta-form', function (e) {
        e.preventDefault();
        var $b = $(this).find('button').prop('disabled', true);
        mensaje('');
        $.post(URL + 'guardar', $(this).serialize()).done(function () {
            mensaje('Meta guardada.', false);
            $('#tz-meta-valor, #tz-meta-resp').val('');
            cargar();
        }).fail(function (xhr) {
            var r = xhr && xhr.responseJSON;
            mensaje(r && r.error ? r.error : 'No se pudo guardar la meta.', true);
        }).always(function () { $b.prop('disabled', false); });
    });

    $(document).on('click', '#tz-metas .tz-meta-cancelar', function (e) {
        e.preventDefault();
        var $a = $(this);
        if (!$a.hasClass('tz-confirmar')) {
            $a.addClass('tz-confirmar text-danger').text('¿Seguro? Cancelar');
            setTimeout(function () { $a.removeClass('tz-confirmar text-danger').text('Cancelar'); }, 4000);
            return;
        }
        var id = $a.closest('tr').data('id');
        $.post(URL + 'cancelar/' + id).always(cargar);
    });

    window.TZMetas = { init: init, recargar: cargar };
})(jQuery);
