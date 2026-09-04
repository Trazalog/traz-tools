<?php defined('BASEPATH') or exit('No direct script access allowed'); ?>
<!--
  Entrevista al experto. FRAGMENTO: se inyecta en el #content del layout.

  Tres pasos en la misma pantalla, uno visible a la vez:
    1. elegir tema de la agenda
    2. conversar
    3. revisar y validar los hechos que quedaron
-->
<div class="box box-primary" id="ag-ent">

  <div class="box-header with-border">
    <h3 class="box-title">
      <i class="fa fa-microphone"></i>
      Capturar conocimiento
      <small style="margin-left:8px" id="ag-ent-sub">elegí un tema para empezar</small>
    </h3>
  </div>

  <!-- ---------------------------------------------------------- paso 1 -->
  <div class="box-body" id="ag-paso-tema">
    <div class="form-group" style="max-width:420px">
      <label for="ag-experto">¿Quién va a responder?</label>
      <select id="ag-experto" class="form-control"></select>
    </div>

    <p class="ag-ayuda">
      Los temas están ordenados por lo que más falta hoy: pesa la taxonomía,
      pero sobre todo <strong>qué equipos generan más órdenes de trabajo</strong>
      en los clientes.
    </p>

    <div id="ag-temas" class="ag-temas"></div>
  </div>

  <!-- ---------------------------------------------------------- paso 2 -->
  <div class="box-body" id="ag-paso-charla" style="display:none">
    <div id="ag-charla" class="ag-charla"></div>
  </div>

  <div class="box-footer" id="ag-pie-charla" style="display:none">
    <form id="ag-ent-form" autocomplete="off">
      <div class="input-group">
        <input type="text" id="ag-ent-respuesta" class="form-control" maxlength="8000"
               placeholder="Contestá con tus palabras...">
        <span class="input-group-btn">
          <button type="submit" class="btn btn-primary btn-flat">Responder</button>
        </span>
      </div>
    </form>
    <p class="ag-ayuda" style="margin-top:8px">
      Contestá como le explicarías a un colega. Los números concretos y los casos
      que te acuerdes son lo que más sirve.
      <a href="#" id="ag-terminar">Terminar y ordenar lo que conté</a>
    </p>
  </div>

  <!-- ---------------------------------------------------------- paso 3 -->
  <div class="box-body" id="ag-paso-hechos" style="display:none">
    <p class="ag-ayuda">
      Esto es lo que entendí. <strong>Revisalo y corregí lo que haga falta</strong> —
      lo que apruebes queda como conocimiento del agente, así que si algo no
      quedó bien dicho, cambialo.
    </p>
    <div id="ag-hechos"></div>
    <button type="button" id="ag-cerrar-sesion" class="btn btn-primary">Listo, cerrar</button>
  </div>
</div>

<style>
.ag-temas .ag-tema { border: 1px solid #ddd; border-radius: 3px; padding: 10px 12px;
                     margin-bottom: 8px; cursor: pointer; }
.ag-temas .ag-tema:hover { background: #f7f9fa; border-color: #3c8dbc; }
.ag-temas .ag-tema h4 { margin: 0 0 3px; font-size: 15px; }
.ag-temas .ag-tema p { margin: 0; font-size: 12.5px; color: #888; }
.ag-temas .ag-prio { float: right; font-size: 11px; color: #999; }
.ag-charla { max-height: 55vh; overflow-y: auto; }
.ag-turno { margin-bottom: 16px; }
.ag-turno .ag-quien { font-size: 11px; text-transform: uppercase; letter-spacing: .05em;
                      color: #999; font-weight: 600; margin-bottom: 3px; }
.ag-turno .ag-texto { white-space: pre-wrap; line-height: 1.55; }
.ag-agente-t .ag-texto { background: #f7f9fa; border-left: 3px solid #3c8dbc;
                         padding: 9px 12px; border-radius: 2px; }
.ag-hecho { border: 1px solid #ddd; border-radius: 3px; padding: 10px 12px; margin-bottom: 10px; }
.ag-hecho textarea { width: 100%; font-size: 13.5px; border: none; resize: vertical;
                     background: transparent; }
.ag-hecho .ag-meta { font-size: 11px; color: #999; margin: 4px 0 8px; }
.ag-hecho.ag-listo { border-color: #00a65a; background: #f6fbf8; }
.ag-hecho.ag-fuera { opacity: .5; }
.ag-ayuda { font-size: 12px; color: #999; }
.ag-pensando-e { color: #aaa; font-style: italic; }
</style>

<script>
(function () {
    var BASE = '<?= base_url() . AGE ?>agente/';
    var sesion = null;

    function esc(t) { return $('<div>').text(t == null ? '' : t).html(); }

    // ------------------------------------------------------------ paso 1
    function cargarExpertos() {
        $.get(BASE + 'expertos', function (r) {
            var $s = $('#ag-experto').empty();
            (r.expertos || []).forEach(function (e) {
                $s.append('<option value="' + e.experto_id + '">' + esc(e.nombre) + '</option>');
            });
            if (!(r.expertos || []).length) {
                $s.append('<option value="">— no hay expertos cargados —</option>');
            }
        });
    }

    function cargarTemas() {
        $.get(BASE + 'agenda', function (r) {
            var $t = $('#ag-temas').empty();
            (r.temas || []).forEach(function (t) {
                var area = { man: 'Mantenimiento', alm: 'Almacenes', general: 'General' }[t.modulo] || t.modulo;
                $t.append(
                    '<div class="ag-tema" data-tema="' + t.tema_id + '">' +
                      '<span class="ag-prio">' + esc(area) + ' · prioridad ' + Math.round(t.prioridad) + '</span>' +
                      '<h4>' + esc(t.nombre) + '</h4>' +
                      '<p>' + esc(t.descripcion || '') + '</p>' +
                    '</div>');
            });
        });
    }

    $('#ag-temas').on('click', '.ag-tema', function () {
        var tema = $(this).data('tema');
        var experto = $('#ag-experto').val();
        if (!experto) { alert('Elegí quién va a responder.'); return; }

        $.post(BASE + 'entrevista_iniciar', { experto_id: experto, tema_id: tema })
            .done(function (r) {
                if (r.error) { alert(r.error); return; }
                sesion = r.sesion_id;
                $('#ag-paso-tema').hide();
                $('#ag-paso-charla, #ag-pie-charla').show();
                $('#ag-ent-sub').text(r.tema);
                turno('agente', r.pregunta);
                $('#ag-ent-respuesta').focus();
            })
            .fail(function () { alert('No se pudo iniciar la entrevista.'); });
    });

    // ------------------------------------------------------------ paso 2
    function turno(quien, texto) {
        var clase = quien === 'agente' ? 'ag-turno ag-agente-t' : 'ag-turno';
        var etiqueta = quien === 'agente' ? 'Agente' : 'Vos';
        $('#ag-charla').append('<div class="' + clase + '"><div class="ag-quien">' + etiqueta +
            '</div><div class="ag-texto">' + esc(texto) + '</div></div>');
        var c = $('#ag-charla');
        c.scrollTop(c[0].scrollHeight);
    }

    $('#ag-ent-form').on('submit', function (e) {
        e.preventDefault();
        var texto = $.trim($('#ag-ent-respuesta').val());
        if (!texto || !sesion) { return; }
        $('#ag-ent-respuesta').val('');
        turno('experto', texto);
        $('#ag-charla').append('<div class="ag-turno ag-pensando-e" id="ag-esp">Pensando la próxima pregunta...</div>');

        $.post(BASE + 'entrevista_responder', { sesion_id: sesion, respuesta: texto })
            .done(function (r) {
                $('#ag-esp').remove();
                if (r.cerrar) { turno('agente', r.mensaje); estructurar(); return; }
                turno('agente', r.pregunta);
            })
            .fail(function () {
                $('#ag-esp').remove();
                turno('agente', 'Se me cortó. Probá de nuevo en un momento.');
            });
    });

    $('#ag-terminar').on('click', function (e) { e.preventDefault(); estructurar(); });

    // ------------------------------------------------------------ paso 3
    function estructurar() {
        $('#ag-pie-charla').hide();
        $('#ag-charla').append('<div class="ag-turno ag-pensando-e" id="ag-esp2">Ordenando lo que me contaste...</div>');

        $.post(BASE + 'entrevista_estructurar', { sesion_id: sesion })
            .done(function (r) {
                $('#ag-esp2').remove();
                if (r.error) { alert(r.error); $('#ag-pie-charla').show(); return; }
                var $h = $('#ag-hechos').empty();
                (r.hechos || []).forEach(function (h) {
                    $h.append(
                        '<div class="ag-hecho" data-hecho="' + h.hecho_id + '">' +
                          '<textarea rows="3">' + esc(h.contenido) + '</textarea>' +
                          '<div class="ag-meta">' +
                            (h.tipo_equipo ? esc(h.tipo_equipo) + ' · ' : '') +
                            (h.situacion ? esc(h.situacion) + ' · ' : '') +
                            'confianza ' + h.confianza +
                          '</div>' +
                          '<button type="button" class="btn btn-xs btn-success ag-ok">Está bien</button> ' +
                          '<button type="button" class="btn btn-xs btn-default ag-no">Descartar</button>' +
                        '</div>');
                });
                $('#ag-paso-charla').hide();
                $('#ag-paso-hechos').show();
            })
            .fail(function () {
                $('#ag-esp2').remove();
                alert('No se pudo ordenar la entrevista.');
                $('#ag-pie-charla').show();
            });
    }

    $('#ag-hechos').on('click', '.ag-ok, .ag-no', function () {
        var $c = $(this).closest('.ag-hecho');
        var ok = $(this).hasClass('ag-ok');
        // Se manda el texto del textarea: si el experto lo corrigió, vale el suyo.
        $.post(BASE + 'entrevista_validar', {
            hecho_id: $c.data('hecho'),
            aprobado: ok ? 'true' : 'false',
            contenido: ok ? $c.find('textarea').val() : ''
        }).done(function () {
            $c.removeClass('ag-listo ag-fuera').addClass(ok ? 'ag-listo' : 'ag-fuera');
            $c.find('button').prop('disabled', true);
        });
    });

    $('#ag-cerrar-sesion').on('click', function () {
        $.post(BASE + 'entrevista_cerrar', { sesion_id: sesion }).always(function () {
            sesion = null;
            $('#ag-paso-hechos').hide();
            $('#ag-charla').empty();
            $('#ag-paso-tema').show();
            $('#ag-ent-sub').text('elegí un tema para empezar');
            cargarTemas();
        });
    });

    cargarExpertos();
    cargarTemas();
})();
</script>
