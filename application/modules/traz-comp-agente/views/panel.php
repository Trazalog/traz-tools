<?php defined('BASEPATH') or exit('No direct script access allowed'); ?>
<!--
  Panel de Quirqui, el Asistente (AGENTE-AS-01), y de Kuntur, el Coach.

  Va en el layout (layout/Admin.php), no en el #content: acompaña al usuario
  en TODAS las pantallas de Tools. Con cada pregunta manda la ruta de la
  pantalla actual (la variable global `site` de lib/props/navegacion.js), y
  el orquestador le da al modelo lo que se hace ahí, sacado de los casos de uso
  de DocTest.

  Quién lo ve: el layout lo incluye solo si el usuario tiene en su menú el ítem
  del agente (seg.menues). Mostrarlo a todos es una decisión comercial — los
  agentes son una suscripción — y no se toma acá.

  KUNTUR (AGENTE-CO-01, CO-03): si la lista de agentes (que filtra la API por
  rol, R1) trae al Coach, aparecen dos pestañas. Kuntur propone metas como
  tarjetas; "Cargar meta" la graba el administrador con su sesión en
  index.php/Objetivos/guardar, que vuelve a verificar que es administrador.

  AVISO DE MEDICIÓN: el texto de #agp-aviso es el que pidió el PM (D9 del plan)
  y está PENDIENTE DE REVISIÓN LEGAL (AGENTE-LEGAL-01). No cambiarlo sin esa
  revisión.
-->
<?php $this->load->view(AGE . 'avatar'); ?>

<div id="agp-boton" title="Preguntale a tu asistente"><span id="agp-boton-avatar"></span><span id="agp-contador"></span></div>

<div id="agp-panel" aria-hidden="true">
  <div class="agp-cabecera">
    <span id="agp-cab-avatar"></span>
    <div class="agp-titulo">
      <strong id="agp-nombre">Quirqui</strong>
      <small id="agp-rol">tu asistente en Trazalog</small>
    </div>
    <button type="button" class="agp-cerrar" title="Cerrar">&times;</button>
  </div>
  <div id="agp-pestanias" hidden></div>

  <div id="agp-aviso-coach" hidden>
    Kuntur te acompaña como administrador: solo lo ves vos. Te propone metas; las cargás vos.
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

  <div id="agp-avisos"></div>
  <div id="agp-propuestas"></div>

  <div id="agp-conversacion">
    <div class="agp-bienvenida" data-agente="asistente">
      Preguntame qué se hace en esta pantalla, o lo que necesites de mantenimiento y almacenes.
    </div>
    <div class="agp-bienvenida" data-agente="coach" hidden>
      Contame qué querés mejorar. Miro tus indicadores y te propongo metas: las cargás vos.
    </div>
  </div>

  <form id="agp-form" autocomplete="off">
    <input type="text" id="agp-pregunta" maxlength="4000" placeholder="Escribí tu pregunta...">
    <button type="submit" id="agp-enviar" title="Enviar">&#10148;</button>
  </form>
</div>

<style>
#agp-boton { position: fixed; right: 22px; bottom: 22px; z-index: 1040; cursor: pointer; }
#agp-boton .tzag { box-shadow: 0 3px 10px rgba(0,0,0,.25); border-radius: 50%; }
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
#agp-contador { position: absolute; top: -4px; right: -4px; z-index: 1; min-width: 18px; height: 18px;
                padding: 0 5px; border-radius: 9px; background: #dd4b39; color: #fff; font-size: 11px;
                line-height: 18px; text-align: center; display: none; }
#agp-avisos { padding: 6px 12px 0; }
.agp-aviso-item { border: 1px solid #e5e5e5; border-left: 3px solid #3c8dbc; border-radius: 3px;
                  padding: 6px 8px; margin-bottom: 6px; font-size: 12px; cursor: pointer; }
.agp-aviso-item.critica { border-left-color: #dd4b39; }
.agp-aviso-item.leido { opacity: .55; }
.agp-aviso-item strong { display: block; }
#agp-propuestas { padding: 6px 12px 0; }
.agp-prop { border: 1px solid #e5e5e5; border-left: 3px solid #f39c12; border-radius: 3px;
            padding: 6px 8px; margin-bottom: 6px; font-size: 12px; }
.agp-prop.lote_vencido { border-left-color: #dd4b39; }
.agp-prop strong { display: block; }
.agp-prop .agp-prop-acciones { margin-top: 4px; }
.agp-prop .agp-prop-acciones a { margin-right: 10px; cursor: pointer; }
.agp-prop .agp-como { display: none; margin-top: 4px; color: #555; }
#agp-pestanias { display: flex; border-bottom: 1px solid #e5e5e5; }
#agp-pestanias[hidden] { display: none; }
#agp-pestanias button { flex: 1; border: 0; background: #fff; padding: 6px; font-size: 12px; cursor: pointer;
                        border-bottom: 2px solid transparent; color: #777; }
#agp-pestanias button.activa { border-bottom-color: #3c8dbc; color: #333; font-weight: 600; }
#agp-aviso-coach { font-size: 11px; color: #777; padding: 6px 12px; background: #f4f7fb;
                   border-bottom: 1px solid #dde6f0; }
.agp-cambio { text-align: center; color: #aaa; font-size: 11px; margin: 10px 0; }
.agp-meta { border: 1px solid #d6e4f0; border-left: 3px solid #3c8dbc; border-radius: 3px;
            padding: 6px 8px; margin-top: 6px; font-size: 12px; background: #fafcfe; }
.agp-meta strong { display: block; }
.agp-meta .agp-meta-motivo { color: #555; margin-top: 2px; }
.agp-meta .agp-meta-acciones { margin-top: 5px; }
.agp-meta .agp-meta-acciones a { margin-right: 10px; cursor: pointer; }
.agp-meta .agp-meta-msg { margin-top: 4px; }
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

    // --- siguiente paso (AGENTE-AS-02) -----------------------------------
    // Se piden al abrir el panel, y otra vez si el usuario cambió de pantalla.
    var pantallaPropuestas = null;
    function cargarPropuestas() {
        var p = pantallaActual();
        if (!p || p === pantallaPropuestas) { return; }
        pantallaPropuestas = p;
        $('#agp-propuestas').empty();
        $.post(BASE + 'sugerencias', { pantalla: p }).done(function (r) {
            // Una propuesta urgente (lote vencido) llama la atención: el avatar pasa a "alerta".
            if ((r.propuestas || []).some(function (x) { return x.tipo === 'lote_vencido'; })) { estado('alerta'); }
            (r.propuestas || []).forEach(function (x) {
                var accion = x.accion || {};
                $('#agp-propuestas').append(
                    '<div class="agp-prop ' + escapar(x.tipo) + '" data-id="' + escapar(x.propuesta_id) + '">' +
                      '<strong>' + escapar(x.titulo) + '</strong>' + escapar(x.detalle) +
                      '<div class="agp-prop-acciones"><a class="agp-ver">Ver cómo</a><a class="agp-descartar">Descartar</a></div>' +
                      '<div class="agp-como">' + escapar(accion.texto) +
                        (accion.ayuda ? ' <a href="<?= base_url() ?>' + escapar(accion.ayuda) + '" target="_blank">Ayuda</a>' : '') +
                      '</div>' +
                    '</div>');
            });
        });
    }
    function responderPropuesta($p, estado) {
        $.post(BASE + 'sugerencia_respuesta', { propuesta_id: $p.data('id'), estado: estado });
    }
    $('#agp-propuestas').on('click', '.agp-ver', function () {
        var $p = $(this).closest('.agp-prop');
        $p.find('.agp-como').show(); $(this).remove();
        responderPropuesta($p, 'aceptada');
    });
    $('#agp-propuestas').on('click', '.agp-descartar', function () {
        var $p = $(this).closest('.agp-prop');
        responderPropuesta($p, 'descartada');
        $p.slideUp(150, function () { $p.remove(); });
    });

    // --- avisos firmados por los agentes (ADR-015) -----------------------------
    // Salen de la campanita de Tools (index.php/Avisos, misma sesion): aca se
    // muestran solo los que firma un agente, con su contador sobre el boton.
    var AVISOS = '<?= base_url() ?>index.php/Avisos/';
    var FIRMAN = { quirqui: 1, kuntur: 1, faustino: 1 };
    function cargarAvisos() {
        $.getJSON(AVISOS + 'mios').done(function (r) {
            var propios = (r.avisos || []).filter(function (x) {
                return !x.leido && FIRMAN[String(x.emisor || '').toLowerCase()];
            });
            var n = propios.length;
            $('#agp-contador').text(n > 9 ? '9+' : n).toggle(n > 0);
            if (n > 0 && !$panel.hasClass('abierto')) { estado('alerta'); }
            var $l = $('#agp-avisos').empty();
            propios.slice(0, 5).forEach(function (x) {
                var enlace = String(x.enlace || '');
                var ok = /^[A-Za-z0-9_\-\/.]+$/.test(enlace);
                $l.append('<div class="agp-aviso-item ' + escapar(x.severidad) + '" data-id="' + escapar(x.aviso_id) + '">' +
                          '<strong>' + escapar(x.titulo) + '</strong>' + escapar(x.cuerpo) +
                          (ok ? ' <a href="<?= base_url() ?>' + escapar(enlace) + '" target="_blank">Ayuda</a>' : '') +
                          '</div>');
            });
        });
    }
    $('#agp-avisos').on('click', '.agp-aviso-item', function () {
        var $a = $(this);
        if ($a.hasClass('leido')) { return; }
        $a.addClass('leido');
        $.post(AVISOS + 'leido/' + parseInt($a.data('id'), 10)).always(function () {
            cargarAvisos();
            if (window.TZAvisos) { window.TZAvisos.refrescar(); }
        });
    });
    cargarAvisos();
    setInterval(cargarAvisos, 5 * 60 * 1000);

    function abrir()  { $panel.addClass('abierto').attr('aria-hidden', 'false'); $('#agp-pregunta').focus();
                        estado('saludo'); cargarPropuestas(); cargarAvisos(); }
    function cerrar() { $panel.removeClass('abierto').attr('aria-hidden', 'true'); estado('despedida'); }

    $('#agp-boton').on('click', function () { $panel.hasClass('abierto') ? cerrar() : abrir(); });
    $panel.on('click', '.agp-cerrar', cerrar);
    $('#agp-que-se-mide').on('click', function (e) { e.preventDefault(); $('#agp-detalle-medicion').toggle(); });

    // --- identidad (AGENTE-ID-05): nombre y avatar vienen de la configuración -----
    // Hasta que llega la respuesta (o si falla) se usa Quirqui, el agente por defecto.
    var agente = { clave: 'quirqui', nombre: 'Quirqui', avatar: 'quirqui' };
    function pintarIdentidad(estado) {
        // En su propio contenedor: el botón también tiene el contador de avisos.
        $('#agp-boton-avatar').html(TZAgente.avatar(agente, estado, true));
        $('#agp-boton').attr('title', 'Preguntale a ' + agente.nombre);
        $('#agp-cab-avatar').html(TZAgente.avatar(agente, estado));
        $('#agp-nombre').text(agente.nombre);
        $('#agp-rol').text(agente.rol === 'coach' ? 'tu coach como administrador' : 'tu asistente en Trazalog');
    }
    function estado(e) { TZAgente.estado($('#agp-boton .tzag, #agp-cab-avatar .tzag'), e); }
    pintarIdentidad('saludo');

    // Con Kuntur en la lista (solo administradores, R1), dos pestañas.
    var disponibles = [];
    function elegir(clave) {
        var a = disponibles.filter(function (x) { return x.clave === clave; })[0];
        if (!a || a.clave === agente.clave) { return; }
        agente = a;
        pintarIdentidad('saludo');
        var coach = agente.rol === 'coach';
        $('#agp-pestanias button').removeClass('activa').filter('[data-clave="' + agente.clave + '"]').addClass('activa');
        $('#agp-aviso').toggle(!coach);
        $('#agp-aviso-coach').prop('hidden', !coach);
        $('.agp-bienvenida').each(function () { $(this).prop('hidden', $(this).data('agente') !== agente.rol); });
        $('#agp-propuestas').toggle(!coach);
        if ($conv.find('.agp-msg').length) {
            $conv.append('<div class="agp-cambio">Ahora hablás con ' + escapar(agente.nombre) + '</div>'); alFinal();
        }
    }
    $.get(BASE + 'agentes').done(function (r) {
        disponibles = r.agentes || [];
        var q = disponibles.filter(function (a) { return a.rol === 'asistente'; })[0];
        var k = disponibles.filter(function (a) { return a.rol === 'coach'; })[0];
        if (q) { agente = q; pintarIdentidad('saludo'); }
        if (q && k) {
            $('#agp-pestanias').prop('hidden', false).html(
                '<button type="button" class="activa" data-clave="' + escapar(q.clave) + '">' + escapar(q.nombre) + '</button>' +
                '<button type="button" data-clave="' + escapar(k.clave) + '">' + escapar(k.nombre) + '</button>');
        }
    });
    $('#agp-pestanias').on('click', 'button', function () { elegir(String($(this).data('clave'))); });

    function pintar(quien, clase, html) {
        $conv.append('<div class="agp-msg ' + clase + '"><div class="agp-quien">' + quien + '</div>' + html + '</div>');
        alFinal();
    }

    // --- metas que propone Kuntur (AGENTE-CO-03) --------------------------------
    // No están grabadas: "Cargar meta" la graba el administrador, con su sesión.
    var OBJETIVOS = '<?= base_url() ?>index.php/Objetivos/';
    function numero(v) { var n = parseFloat(v); return isNaN(n) ? escapar(v) : n.toLocaleString('es-AR', { maximumFractionDigits: 2 }); }
    function fecha(iso) { var p = String(iso || '').split('-'); return p.length === 3 ? p[2] + '/' + p[1] + '/' + p[0] : escapar(iso); }
    // Las propuestas quedan acá, no en un atributo: escapar() no escapa comillas.
    var metasPropuestas = [];
    function tarjetaMeta(m) {
        metasPropuestas.push(m);
        return '<div class="agp-meta" data-i="' + (metasPropuestas.length - 1) + '">' +
               '<strong>Meta propuesta: ' + escapar(m.titulo) + ' ' + (m.operador === '>=' ? '≥' : '≤') + ' ' +
               numero(m.meta) + ' para el ' + fecha(m.hasta) + '</strong>' +
               (m.responsable ? 'Responsable: ' + escapar(m.responsable) : '') +
               '<div class="agp-meta-motivo">' + escapar(m.motivo) + '</div>' +
               '<div class="agp-meta-acciones"><a class="agp-meta-cargar">Cargar meta</a><a class="agp-meta-no">Ahora no</a></div>' +
               '<div class="agp-meta-msg" hidden></div></div>';
    }
    $conv.on('click', '.agp-meta-cargar', function () {
        var $t = $(this).closest('.agp-meta'), m = metasPropuestas[$t.data('i')], $msg = $t.find('.agp-meta-msg');
        $t.find('.agp-meta-acciones').hide();
        $.post(OBJETIVOS + 'guardar', { kpi: m.kpi, operador: m.operador, meta: m.meta, hasta: m.hasta,
                                        responsable: m.responsable || '', propuesto_por: 'kuntur' })
            .done(function () {
                $msg.prop('hidden', false).attr('class', 'agp-meta-msg text-success').text('Meta cargada. La ves en el Tablero, en Metas.');
                if (window.TZMetas) { window.TZMetas.recargar(); }
            })
            .fail(function (xhr) {
                var r = xhr && xhr.responseJSON;
                $msg.prop('hidden', false).attr('class', 'agp-meta-msg text-danger')
                    .text(r && r.error === 'solo_administrador' ? 'Solo el administrador de la empresa carga metas.'
                          : (r && r.error) || 'No se pudo cargar la meta.');
                $t.find('.agp-meta-acciones').show();
            });
    });
    $conv.on('click', '.agp-meta-no', function () {
        var $t = $(this).closest('.agp-meta');
        $t.slideUp(150, function () { $t.remove(); });
    });

    function pintarRespuesta(r) {
        var html = '<div class="agp-texto">' + escapar(r.respuesta) + '</div>';
        (r.propuestas_meta || []).forEach(function (m) { html += tarjetaMeta(m); });
        if (!r.error && r.interaccion_id) {
            html += '<div class="agp-feedback" data-interaccion="' + escapar(r.interaccion_id) + '">' +
                    '<button type="button" data-util="1" title="Me sirvió">👍</button> ' +
                    '<button type="button" data-util="0" title="No me sirvió">👎</button></div>';
        }
        pintar(agente.nombre, r.error ? 'agp-agente agp-error' : 'agp-agente', html);
    }

    $('#agp-form').on('submit', function (e) {
        e.preventDefault();
        var texto = $.trim($('#agp-pregunta').val());
        if (!texto) { return; }
        $('#agp-pregunta').val('');
        $('#agp-enviar').prop('disabled', true);
        pintar('Vos', 'agp-usuario', '<div class="agp-texto">' + escapar(texto) + '</div>');
        pintar(agente.nombre, 'agp-agente agp-pensando-wrap', '<div class="agp-texto agp-pensando">Pensando...</div>');
        estado('pensando');

        $.post(BASE + 'consultar', { pregunta: texto, pantalla: pantallaActual(), agente: agente.clave })
            .done(function (r) { $('.agp-pensando-wrap').remove(); pintarRespuesta(r);
                                 estado('hablando'); setTimeout(function () { estado('saludo'); }, 2500); })
            .fail(function (xhr) {
                $('.agp-pensando-wrap').remove(); estado('saludo');
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
