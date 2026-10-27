<?php defined('BASEPATH') or exit('No direct script access allowed'); ?>
<!--
  Panel de Quirqui, el Asistente (AGENTE-AS-01).

  Va en el layout (layout/Admin.php), no en el #content: acompaña al usuario
  en TODAS las pantallas de Tools. Con cada pregunta manda la ruta de la
  pantalla actual (la variable global `site` de lib/props/navegacion.js), y
  el orquestador le da al modelo lo que se hace ahí, sacado de los casos de uso
  de DocTest.

  Quién lo ve: el layout lo incluye solo si el usuario tiene en su menú el ítem
  del agente (seg.menues). Mostrarlo a todos es una decisión comercial — los
  agentes son una suscripción — y no se toma acá.

  AVISO DE MEDICIÓN: el texto de #agp-aviso es el que pidió el PM (D9 del plan)
  y está PENDIENTE DE REVISIÓN LEGAL (AGENTE-LEGAL-01). No cambiarlo sin esa
  revisión.
-->
<div id="agp-boton" title="Preguntale a Quirqui">
  <span class="agp-avatar agp-avatar-grande">Q</span>
</div>

<div id="agp-panel" aria-hidden="true">
  <div class="agp-cabecera">
    <span class="agp-avatar">Q</span>
    <div class="agp-titulo">
      <strong>Quirqui</strong>
      <small>tu asistente en Trazalog</small>
    </div>
    <button type="button" class="agp-cerrar" title="Cerrar">&times;</button>
  </div>

  <div id="agp-aviso">
    Lo que hables con Quirqui se usa para medir indicadores de tu empresa.
    <a href="#" id="agp-que-se-mide">¿Qué se mide?</a>
    <div id="agp-detalle-medicion">
      Se registran tus consultas y las respuestas para mejorar el asistente. El administrador de
      tu empresa puede pedir indicadores de cumplimiento sobre el trabajo que cargás en Trazalog
      —por ejemplo, tareas cerradas en plazo—. Lo que conversás con Quirqui no se le muestra.
    </div>
  </div>

  <div id="agp-conversacion">
    <div class="agp-bienvenida">
      Preguntame qué se hace en esta pantalla, o lo que necesites de mantenimiento y almacenes.
    </div>
  </div>

  <form id="agp-form" autocomplete="off">
    <input type="text" id="agp-pregunta" maxlength="4000" placeholder="Escribí tu pregunta...">
    <button type="submit" id="agp-enviar" title="Enviar">&#10148;</button>
  </form>
</div>

<style>
#agp-boton { position: fixed; right: 22px; bottom: 22px; z-index: 1040; cursor: pointer; }
.agp-avatar { display: inline-flex; align-items: center; justify-content: center;
              width: 32px; height: 32px; border-radius: 50%; background: #3c8dbc;
              color: #fff; font-weight: bold; flex-shrink: 0; }
.agp-avatar-grande { width: 54px; height: 54px; font-size: 22px;
                     box-shadow: 0 3px 10px rgba(0,0,0,.25); }
#agp-panel { position: fixed; right: 22px; bottom: 88px; width: 360px; max-width: calc(100vw - 32px);
             height: 520px; max-height: calc(100vh - 120px); z-index: 1041; background: #fff;
             border-radius: 6px; box-shadow: 0 6px 24px rgba(0,0,0,.25); display: none;
             flex-direction: column; overflow: hidden; }
#agp-panel.abierto { display: flex; }
.agp-cabecera { display: flex; align-items: center; gap: 10px; padding: 10px 12px;
                background: #f7f9fa; border-bottom: 1px solid #e5e5e5; }
.agp-titulo { flex: 1; line-height: 1.2; }
.agp-titulo small { display: block; color: #888; }
.agp-cerrar { border: 0; background: none; font-size: 22px; color: #888; cursor: pointer; }
#agp-aviso { font-size: 11px; color: #777; padding: 6px 12px; background: #fffbe6;
             border-bottom: 1px solid #f0e6b8; }
#agp-detalle-medicion { display: none; margin-top: 4px; }
#agp-conversacion { flex: 1; overflow-y: auto; padding: 10px 12px; font-size: 13px; }
.agp-bienvenida { color: #888; }
.agp-msg { margin: 8px 0; }
.agp-usuario .agp-texto { background: #eaf3f9; padding: 7px 10px; border-radius: 4px; }
.agp-quien { font-size: 11px; color: #999; margin-bottom: 2px; }
.agp-error .agp-texto { color: #dd4b39; }
.agp-pensando { color: #aaa; font-style: italic; }
.agp-feedback { margin-top: 4px; }
.agp-feedback button { border: 1px solid #ddd; background: #fff; border-radius: 3px;
                       padding: 0 7px; cursor: pointer; }
.agp-feedback .elegido { background: #eaf3f9; border-color: #3c8dbc; }
#agp-form { display: flex; border-top: 1px solid #e5e5e5; }
#agp-pregunta { flex: 1; border: 0; padding: 10px 12px; font-size: 13px; outline: none; }
#agp-enviar { border: 0; background: #3c8dbc; color: #fff; padding: 0 14px; cursor: pointer; }
#agp-enviar:disabled { opacity: .5; }
</style>

<script>
(function () {
    var BASE = '<?= base_url() . AGE ?>agente/';
    var $panel = $('#agp-panel'), $conv = $('#agp-conversacion');

    function escapar(t) { return $('<div>').text(t == null ? '' : t).html(); }
    function alFinal()  { $conv.scrollTop($conv[0].scrollHeight); }
    // La pantalla donde está el usuario: la última que cargó linkTo().
    function pantallaActual() { return (typeof site === 'string' && site) ? site : ''; }

    function abrir()  { $panel.addClass('abierto').attr('aria-hidden', 'false'); $('#agp-pregunta').focus(); }
    function cerrar() { $panel.removeClass('abierto').attr('aria-hidden', 'true'); }

    $('#agp-boton').on('click', function () { $panel.hasClass('abierto') ? cerrar() : abrir(); });
    $panel.on('click', '.agp-cerrar', cerrar);
    $('#agp-que-se-mide').on('click', function (e) { e.preventDefault(); $('#agp-detalle-medicion').toggle(); });

    function pintar(quien, clase, html) {
        $conv.append('<div class="agp-msg ' + clase + '"><div class="agp-quien">' + quien + '</div>' + html + '</div>');
        alFinal();
    }

    function pintarRespuesta(r) {
        var html = '<div class="agp-texto">' + escapar(r.respuesta) + '</div>';
        if (!r.error && r.interaccion_id) {
            html += '<div class="agp-feedback" data-interaccion="' + escapar(r.interaccion_id) + '">' +
                    '<button type="button" data-util="1" title="Me sirvió">👍</button> ' +
                    '<button type="button" data-util="0" title="No me sirvió">👎</button></div>';
        }
        pintar('Quirqui', r.error ? 'agp-agente agp-error' : 'agp-agente', html);
    }

    $('#agp-form').on('submit', function (e) {
        e.preventDefault();
        var texto = $.trim($('#agp-pregunta').val());
        if (!texto) { return; }
        $('#agp-pregunta').val('');
        $('#agp-enviar').prop('disabled', true);
        pintar('Vos', 'agp-usuario', '<div class="agp-texto">' + escapar(texto) + '</div>');
        pintar('Quirqui', 'agp-agente agp-pensando-wrap', '<div class="agp-texto agp-pensando">Pensando...</div>');

        $.post(BASE + 'consultar', { pregunta: texto, pantalla: pantallaActual() })
            .done(function (r) { $('.agp-pensando-wrap').remove(); pintarRespuesta(r); })
            .fail(function (xhr) {
                $('.agp-pensando-wrap').remove();
                pintarRespuesta({ error: true, respuesta: xhr.status === 401
                    ? 'Tu sesión venció. Recargá la página para seguir.'
                    : 'No se pudo enviar la consulta. Revisá tu conexión y probá de nuevo.' });
            })
            .always(function () { $('#agp-enviar').prop('disabled', false); $('#agp-pregunta').focus(); });
    });

    $conv.on('click', '.agp-feedback button', function () {
        var $b = $(this), $caja = $b.closest('.agp-feedback');
        $caja.find('button').removeClass('elegido');
        $b.addClass('elegido');
        $.post(BASE + 'feedback', { interaccion_id: $caja.data('interaccion'),
                                    util: $b.data('util') === 1 ? 'true' : 'false' });
    });
})();
</script>
