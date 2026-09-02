<?php defined('BASEPATH') or exit('No direct script access allowed'); ?>
<!-- Chat del Agente Minero. Se monta sobre el layout Admin de Tools. -->
<div class="content-wrapper">
  <section class="content-header">
    <h1>Agente Minero <small>consultá sobre mantenimiento y almacenes</small></h1>
  </section>

  <section class="content">
    <div class="row">
      <div class="col-md-12">
        <div class="box box-primary" id="caja-chat">
          <div class="box-body" id="conversacion">
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

          <div class="box-footer">
            <form id="form-consulta" autocomplete="off">
              <div class="input-group">
                <input type="text" id="pregunta" class="form-control" maxlength="4000"
                       placeholder="Escribí tu consulta..." aria-label="Consulta al agente">
                <span class="input-group-btn">
                  <button type="submit" id="btn-enviar" class="btn btn-primary">Enviar</button>
                </span>
              </div>
            </form>
            <p class="ag-aviso">
              El agente puede equivocarse. Verificá los datos críticos antes de intervenir un equipo.
            </p>
          </div>
        </div>
      </div>
    </div>
  </section>
</div>

<style>
#conversacion { max-height: 60vh; overflow-y: auto; padding: 15px; }
.ag-msg { margin-bottom: 18px; }
.ag-msg .ag-quien { font-weight: 600; font-size: 12px; text-transform: uppercase;
                    letter-spacing: .04em; color: #777; margin-bottom: 4px; }
.ag-msg .ag-texto { white-space: pre-wrap; line-height: 1.55; }
.ag-usuario .ag-texto { background: #f4f6f8; border-left: 3px solid #3c8dbc;
                        padding: 10px 12px; border-radius: 3px; }
.ag-agente .ag-texto { padding: 2px 0; }
.ag-error .ag-texto  { color: #a94442; }
.ag-fuentes { font-size: 12px; color: #888; margin-top: 6px; }
.ag-fuentes .label { font-weight: normal; }
.ag-feedback { margin-top: 8px; font-size: 13px; }
.ag-feedback button { border: 1px solid #ddd; background: #fff; border-radius: 3px;
                      padding: 2px 9px; margin-right: 4px; cursor: pointer; }
.ag-feedback button:hover { background: #f4f6f8; }
.ag-feedback button.elegido { border-color: #3c8dbc; background: #eaf3f9; }
.ag-feedback .ag-gracias { color: #777; }
.ag-comentario { margin-top: 6px; display: none; }
.ag-comentario textarea { width: 100%; font-size: 13px; }
.ag-bienvenida { color: #666; }
.ag-ejemplos a { display: inline-block; margin: 4px 6px 0 0; padding: 4px 10px;
                 border: 1px solid #ddd; border-radius: 14px; font-size: 13px; }
.ag-aviso { font-size: 11px; color: #999; margin: 8px 0 0; }
.ag-pensando { color: #999; font-style: italic; }
</style>

<script>
(function () {
    var BASE = '<?= base_url() . AGE ?>agente/';
    var $conv = $('#conversacion');

    function escapar(t) {
        return $('<div>').text(t == null ? '' : t).html();
    }

    function alFinal() {
        $conv.scrollTop($conv[0].scrollHeight);
    }

    function pintarUsuario(texto) {
        $conv.append(
            '<div class="ag-msg ag-usuario"><div class="ag-quien">Vos</div>' +
            '<div class="ag-texto">' + escapar(texto) + '</div></div>'
        );
        alFinal();
    }

    function pintarPensando() {
        $conv.append('<div class="ag-msg ag-agente ag-pensando-wrap">' +
                     '<div class="ag-quien">Agente</div>' +
                     '<div class="ag-texto ag-pensando">Pensando...</div></div>');
        alFinal();
    }

    function sacarPensando() {
        $('.ag-pensando-wrap').remove();
    }

    // Resumen de en qué se apoyó la respuesta. Es lo que permite que el usuario
    // sepa si el agente miró sus datos o solo el conocimiento general.
    function pintarFuentes(r) {
        var partes = [];
        var frags = r.fragmentos || [];
        var conocimiento = frags.filter(function (f) { return f.origen === 'conocimiento'; }).length;
        var memoria = frags.filter(function (f) { return f.origen === 'memoria'; }).length;
        var tools = (r.tools_llamadas || []).map(function (t) { return t.tool; });

        if (conocimiento) { partes.push(conocimiento + ' fragmento(s) de conocimiento'); }
        if (memoria)      { partes.push(memoria + ' de memoria de tu empresa'); }
        if (tools.length) { partes.push('consultó: ' + tools.join(', ')); }
        if (!partes.length) { partes.push('sin fuentes recuperadas'); }

        return '<div class="ag-fuentes">' + escapar(partes.join(' · ')) + '</div>';
    }

    function pintarFeedback(id) {
        return '' +
        '<div class="ag-feedback" data-interaccion="' + escapar(id) + '">' +
          '<button type="button" class="ag-util" data-util="1" title="Me sirvió">👍</button>' +
          '<button type="button" class="ag-util" data-util="0" title="No me sirvió">👎</button>' +
          '<span class="ag-gracias"></span>' +
          '<div class="ag-comentario">' +
            '<textarea rows="2" placeholder="¿Qué falló? (opcional)"></textarea>' +
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
        $('#btn-enviar').prop('disabled', true);
        pintarUsuario(texto);
        pintarPensando();

        $.post(BASE + 'consultar', { pregunta: texto })
            .done(function (r) {
                sacarPensando();
                pintarAgente(r);
            })
            .fail(function (xhr) {
                sacarPensando();
                if (xhr.status === 401) {
                    // Se venció el token: se reconecta solo, sin perder lo escrito.
                    $('#pregunta').val(texto);
                    window.location = BASE + 'conectar';
                    return;
                }
                pintarAgente({
                    error: true,
                    respuesta: 'No se pudo enviar la consulta. Revisá tu conexión y probá de nuevo.'
                });
            })
            .always(function () {
                $('#btn-enviar').prop('disabled', false);
                $('#pregunta').focus();
            });
    }

    $('#form-consulta').on('submit', function (e) {
        e.preventDefault();
        var texto = $.trim($('#pregunta').val());
        if (!texto) { return; }
        $('#pregunta').val('');
        preguntar(texto);
    });

    $conv.on('click', '.ag-ejemplo', function (e) {
        e.preventDefault();
        preguntar($(this).text());
    });

    // --- feedback ---------------------------------------------------------
    $conv.on('click', '.ag-util', function () {
        var $b = $(this);
        var $caja = $b.closest('.ag-feedback');
        var util = $b.data('util') === 1;

        $caja.find('.ag-util').removeClass('elegido');
        $b.addClass('elegido');

        $.post(BASE + 'feedback', {
            interaccion_id: $caja.data('interaccion'),
            util: util ? 'true' : 'false'
        }).done(function () {
            $caja.find('.ag-gracias').text(util ? '¡Gracias!' : 'Gracias, lo vamos a revisar.');
            // Solo pedimos el detalle cuando algo no sirvió: es donde aporta.
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

    $('#pregunta').focus();
})();
</script>
