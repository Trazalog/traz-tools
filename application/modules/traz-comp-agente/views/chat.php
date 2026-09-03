<?php defined('BASEPATH') or exit('No direct script access allowed'); ?>
<!--
  Chat del Agente Minero.

  Esto es un FRAGMENTO, no una pagina: se inyecta en el #content del layout
  Admin, igual que cualquier otro modulo de Tools. Por eso no lleva <html>,
  <head>, <body>, content-wrapper ni <section> propios -- el layout ya los trae,
  y duplicarlos deja el contenido despues de </html>, sin estilos.
-->
<div class="box box-primary">
  <div class="box-header with-border">
    <h3 class="box-title">
      <i class="fa fa-comments-o"></i>
      Agente Minero
      <small style="margin-left:8px">consultá sobre mantenimiento y almacenes</small>
    </h3>
  </div>

  <div class="box-body">
    <div id="ag-conversacion" class="direct-chat-messages">
      <div class="ag-bienvenida">
        <p><strong>Preguntame lo que necesites.</strong> Sé de mantenimiento de equipos y de almacenes,
           y puedo consultar los datos reales de tu empresa.</p>
        <p class="ag-ejemplos">
          <a href="#" class="ag-ejemplo">¿Cada cuánto se cambian las muelas de una chancadora?</a>
          <a href="#" class="ag-ejemplo">¿Qué órdenes de trabajo tengo abiertas?</a>
          <a href="#" class="ag-ejemplo">¿Tengo stock de filtros de aceite?</a>
          <a href="#" class="ag-ejemplo">¿Hay material próximo a vencer?</a>
        </p>
      </div>
    </div>
  </div>

  <div class="box-footer">
    <form id="ag-form" autocomplete="off">
      <div class="input-group">
        <input type="text" id="ag-pregunta" class="form-control" maxlength="4000"
               placeholder="Escribí tu consulta..." aria-label="Consulta al agente">
        <span class="input-group-btn">
          <button type="submit" id="ag-enviar" class="btn btn-primary btn-flat">
            Enviar
          </button>
        </span>
      </div>
    </form>
    <p class="ag-aviso">
      <i class="fa fa-info-circle"></i>
      El agente puede equivocarse. Verificá los datos críticos antes de intervenir un equipo.
    </p>
  </div>
</div>

<style>
#ag-conversacion { height: auto; max-height: 55vh; overflow-y: auto; padding: 5px 2px; }
.ag-msg { margin-bottom: 18px; }
.ag-msg .ag-quien { font-weight: 600; font-size: 11px; text-transform: uppercase;
                    letter-spacing: .05em; color: #999; margin-bottom: 4px; }
.ag-msg .ag-texto { white-space: pre-wrap; line-height: 1.55; }
.ag-usuario .ag-texto { background: #f7f9fa; border-left: 3px solid #3c8dbc;
                        padding: 9px 12px; border-radius: 2px; }
.ag-agente .ag-texto { padding: 2px 0; }
.ag-error .ag-texto { color: #dd4b39; }
.ag-fuentes { font-size: 11px; color: #999; margin-top: 6px; }
.ag-feedback { margin-top: 8px; font-size: 13px; }
.ag-feedback .btn { padding: 1px 9px; }
.ag-feedback .elegido { background: #eaf3f9; border-color: #3c8dbc; }
.ag-feedback .ag-gracias { color: #999; margin-left: 6px; font-size: 12px; }
.ag-comentario { margin-top: 8px; display: none; }
.ag-comentario textarea { width: 100%; font-size: 13px; margin-bottom: 4px; }
.ag-bienvenida { color: #777; }
.ag-ejemplos a { display: inline-block; margin: 4px 6px 0 0; padding: 4px 12px;
                 border: 1px solid #ddd; border-radius: 14px; font-size: 12.5px;
                 color: #3c8dbc; text-decoration: none; }
.ag-ejemplos a:hover { background: #f7f9fa; }
.ag-aviso { font-size: 11px; color: #aaa; margin: 8px 0 0; }
.ag-pensando { color: #aaa; font-style: italic; }
</style>

<script>
(function () {
    var BASE = '<?= base_url() . AGE ?>agente/';
    var $conv = $('#ag-conversacion');

    function escapar(t) { return $('<div>').text(t == null ? '' : t).html(); }
    function alFinal()  { $conv.scrollTop($conv[0].scrollHeight); }

    function pintarUsuario(texto) {
        $conv.append('<div class="ag-msg ag-usuario"><div class="ag-quien">Vos</div>' +
                     '<div class="ag-texto">' + escapar(texto) + '</div></div>');
        alFinal();
    }

    function pintarPensando() {
        $conv.append('<div class="ag-msg ag-agente ag-pensando-wrap">' +
                     '<div class="ag-quien">Agente</div>' +
                     '<div class="ag-texto ag-pensando">Pensando...</div></div>');
        alFinal();
    }

    function sacarPensando() { $('.ag-pensando-wrap').remove(); }

    // En qué se apoyó la respuesta: deja ver si el agente miró los datos
    // propios de la empresa o solo el conocimiento general.
    function pintarFuentes(r) {
        var frags = r.fragmentos || [];
        var conocimiento = frags.filter(function (f) { return f.origen === 'conocimiento'; }).length;
        var memoria = frags.filter(function (f) { return f.origen === 'memoria'; }).length;
        var tools = (r.tools_llamadas || []).map(function (t) { return t.tool; });
        var partes = [];

        if (conocimiento) { partes.push(conocimiento + ' fragmento(s) de conocimiento'); }
        if (memoria)      { partes.push(memoria + ' de memoria de tu empresa'); }
        if (tools.length) { partes.push('consultó: ' + tools.join(', ')); }
        if (!partes.length) { partes.push('sin fuentes recuperadas'); }

        return '<div class="ag-fuentes">' + escapar(partes.join(' · ')) + '</div>';
    }

    function pintarFeedback(id) {
        return '<div class="ag-feedback" data-interaccion="' + escapar(id) + '">' +
                 '<button type="button" class="btn btn-default btn-xs ag-util" data-util="1" title="Me sirvió">👍</button> ' +
                 '<button type="button" class="btn btn-default btn-xs ag-util" data-util="0" title="No me sirvió">👎</button>' +
                 '<span class="ag-gracias"></span>' +
                 '<div class="ag-comentario">' +
                   '<textarea class="form-control" rows="2" placeholder="¿Qué falló? (opcional)"></textarea>' +
                   '<button type="button" class="btn btn-xs btn-default ag-enviar-comentario">Enviar comentario</button>' +
                 '</div>' +
               '</div>';
    }

    function pintarAgente(r) {
        var clase = r.error ? 'ag-msg ag-agente ag-error' : 'ag-msg ag-agente';
        var html = '<div class="' + clase + '"><div class="ag-quien">Agente</div>' +
                   '<div class="ag-texto">' + escapar(r.respuesta) + '</div>';
        if (!r.error) {
            html += pintarFuentes(r);
            if (r.interaccion_id) { html += pintarFeedback(r.interaccion_id); }
        }
        $conv.append(html + '</div>');
        alFinal();
    }

    function preguntar(texto) {
        $('#ag-enviar').prop('disabled', true);
        pintarUsuario(texto);
        pintarPensando();

        $.post(BASE + 'consultar', { pregunta: texto })
            .done(function (r) { sacarPensando(); pintarAgente(r); })
            .fail(function (xhr) {
                sacarPensando();
                if (xhr.status === 401) {
                    // Token vencido: se reconecta solo, sin perder lo escrito.
                    $('#ag-pregunta').val(texto);
                    window.location = BASE + 'conectar';
                    return;
                }
                pintarAgente({ error: true,
                    respuesta: 'No se pudo enviar la consulta. Revisá tu conexión y probá de nuevo.' });
            })
            .always(function () {
                $('#ag-enviar').prop('disabled', false);
                $('#ag-pregunta').focus();
            });
    }

    $('#ag-form').on('submit', function (e) {
        e.preventDefault();
        var texto = $.trim($('#ag-pregunta').val());
        if (!texto) { return; }
        $('#ag-pregunta').val('');
        preguntar(texto);
    });

    $conv.on('click', '.ag-ejemplo', function (e) {
        e.preventDefault();
        preguntar($(this).text());
    });

    // --- feedback ---------------------------------------------------------
    $conv.on('click', '.ag-util', function () {
        var $b = $(this), $caja = $b.closest('.ag-feedback');
        var util = $b.data('util') === 1;

        $caja.find('.ag-util').removeClass('elegido');
        $b.addClass('elegido');

        $.post(BASE + 'feedback', {
            interaccion_id: $caja.data('interaccion'),
            util: util ? 'true' : 'false'
        }).done(function () {
            $caja.find('.ag-gracias').text(util ? '¡Gracias!' : 'Gracias, lo vamos a revisar.');
            // El detalle se pide solo cuando algo no sirvió: es donde aporta.
            if (!util) { $caja.find('.ag-comentario').show(); }
        }).fail(function () {
            $caja.find('.ag-gracias').text('No se pudo registrar.');
        });
    });

    $conv.on('click', '.ag-enviar-comentario', function () {
        var $caja = $(this).closest('.ag-feedback');
        var texto = $.trim($caja.find('textarea').val());
        if (!texto) { return; }

        $.post(BASE + 'feedback', {
            interaccion_id: $caja.data('interaccion'),
            util: 'false',
            comentario: texto
        }).done(function () {
            $caja.find('.ag-comentario').hide();
            $caja.find('.ag-gracias').text('Gracias, quedó registrado.');
        });
    });

    $('#ag-pregunta').focus();
})();
</script>
