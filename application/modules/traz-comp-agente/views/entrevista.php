<?php defined('BASEPATH') or exit('No direct script access allowed'); ?>
<?php $this->load->view(AGE . 'avatar'); ?>
<!--
  Entrevista al experto con Faustino. FRAGMENTO: se inyecta en el #content del layout.

  Tres pasos en la misma pantalla, uno visible a la vez:
    1. elegir tema de la agenda
    2. conversar con Faustino
    3. revisar y validar los hechos que quedaron

  Rediseño AGENTE-UX-01 (2026-11-26, pedido del PM: "la veo muy pobre
  visualmente, y el avatar de Faustino no aparece"): cabecera con Faustino y
  los tres pasos, temas como tarjetas, charla en globos con su avatar y su
  estado (pensando / hablando / escuchando), avance de la charla y cierre.
  La industria arranca con la que declaró la empresa (entrevista de Kuntur).
  Los endpoints son los mismos de E4.
-->
<div class="box box-primary" id="ag-ent">

  <div class="ag-cab">
    <span id="ag-cab-avatar"></span>
    <div class="ag-cab-texto">
      <h3>Faustino</h3>
      <p id="ag-ent-sub">Te hago preguntas sobre lo que sabés para que no se pierda. Elegí un tema para empezar.</p>
    </div>
    <ol class="ag-pasos" aria-label="Pasos">
      <li class="activo" data-paso="tema"><span>1</span> Tema</li>
      <li data-paso="charla"><span>2</span> Charla</li>
      <li data-paso="hechos"><span>3</span> Revisión</li>
    </ol>
  </div>

  <div class="ag-msg" id="ag-msg" role="alert" hidden></div>

  <!-- ---------------------------------------------------------- paso 1 -->
  <div class="box-body" id="ag-paso-tema">
    <div class="ag-filtros">
      <div class="form-group">
        <label for="ag-experto">¿Quién va a responder?</label>
        <select id="ag-experto" class="form-control"></select>
      </div>
      <!-- La agenda por industria (ADR-A11): a un experto de oil & gas no se le
           pregunta por chancadoras. "Todas" no filtra. -->
      <div class="form-group">
        <label for="ag-vertical">Industria</label>
        <select id="ag-vertical" class="form-control">
          <option value="">Todas</option>
          <option value="mineria">Minería</option>
          <option value="oil_gas">Oil &amp; gas</option>
          <option value="electricidad">Electricidad</option>
        </select>
        <small class="ag-ayuda" id="ag-vertical-nota" hidden>Es la industria que declaró tu empresa. Podés cambiarla.</small>
      </div>
    </div>

    <p class="ag-ayuda">
      Los temas están ordenados por lo que más falta hoy: pesa la taxonomía,
      pero sobre todo <strong>qué equipos generan más órdenes de trabajo</strong>
      en los clientes.
    </p>

    <div id="ag-temas" class="ag-temas"></div>
  </div>

  <!-- ---------------------------------------------------------- paso 2 -->
  <div class="box-body" id="ag-paso-charla" hidden>
    <div class="ag-avance" id="ag-avance">
      <div class="ag-avance-texto"><span id="ag-avance-n">Primera pregunta</span><span class="ag-ayuda">una charla suele tener unas <span id="ag-avance-total">6</span> preguntas</span></div>
      <div class="ag-avance-barra"><div id="ag-avance-relleno"></div></div>
    </div>
    <div id="ag-charla" class="ag-charla" aria-live="polite"></div>
  </div>

  <div class="box-footer" id="ag-pie-charla" hidden>
    <form id="ag-ent-form" autocomplete="off">
      <textarea id="ag-ent-respuesta" class="form-control" rows="3" maxlength="8000"
                placeholder="Contestá con tus palabras, como le explicarías a un colega..."></textarea>
      <div class="ag-pie-acciones">
        <span class="ag-ayuda">Los números concretos y los casos que te acuerdes son lo que más sirve. <kbd>Ctrl</kbd>+<kbd>Enter</kbd> envía.</span>
        <a href="#" id="ag-terminar" class="btn btn-default btn-sm">Terminar y ordenar lo que conté</a>
        <button type="submit" class="btn btn-primary btn-sm" id="ag-enviar">Responder</button>
      </div>
    </form>
  </div>

  <!-- ---------------------------------------------------------- paso 3 -->
  <div class="box-body" id="ag-paso-hechos" hidden>
    <div class="ag-globo ag-de-faustino ag-intro-hechos">
      <span class="ag-globo-avatar" data-avatar="hablando"></span>
      <div class="ag-globo-texto">
        Esto es lo que entendí. <strong>Revisalo y corregí lo que haga falta</strong>: lo que
        apruebes queda como conocimiento de los agentes, así que si algo no quedó bien dicho,
        cambialo antes de aprobarlo.
      </div>
    </div>
    <div class="ag-revisados" id="ag-revisados"></div>
    <div id="ag-hechos" class="ag-hechos"></div>
    <div class="ag-cierre-acciones">
      <button type="button" id="ag-cerrar-sesion" class="btn btn-primary">Listo, cerrar</button>
    </div>
  </div>

  <!-- ------------------------------------------------------------ cierre -->
  <div class="box-body" id="ag-paso-fin" hidden>
    <div class="ag-fin">
      <span id="ag-fin-avatar"></span>
      <h4>¡Gracias!</h4>
      <p id="ag-fin-texto"></p>
      <button type="button" id="ag-otro-tema" class="btn btn-primary">Elegir otro tema</button>
    </div>
  </div>
</div>

<style>
#ag-ent { overflow: hidden; }
#ag-ent [hidden] { display: none !important; }
.ag-cab { display: flex; align-items: center; gap: 14px; padding: 14px 16px;
          background: linear-gradient(135deg, #fbf6f0 0%, #f4ebe0 100%); border-bottom: 1px solid #eadccb; }
.ag-cab .tzag { width: 72px; height: 72px; }
.ag-cab .tzag .tzag-ini { font-size: 28px; }
.ag-cab-texto { flex: 1; min-width: 0; }
.ag-cab-texto h3 { margin: 0 0 2px; font-size: 20px; color: #5b3a1a; }
.ag-cab-texto p { margin: 0; color: #7a6450; font-size: 13px; }
.ag-pasos { display: flex; gap: 6px; list-style: none; margin: 0; padding: 0; }
.ag-pasos li { display: flex; align-items: center; gap: 6px; padding: 5px 10px; border-radius: 14px;
               font-size: 12px; color: #9a8a7a; background: rgba(255,255,255,.6); }
.ag-pasos li span { display: inline-flex; width: 18px; height: 18px; border-radius: 50%; align-items: center;
                    justify-content: center; background: #e5d8c8; color: #fff; font-weight: 600; font-size: 11px; }
.ag-pasos li.activo { color: #5b3a1a; background: #fff; box-shadow: 0 1px 2px rgba(0,0,0,.08); font-weight: 600; }
.ag-pasos li.activo span { background: #8a5a2b; }
.ag-pasos li.hecho span { background: #00a65a; }
@media (max-width: 767px) { .ag-cab { flex-wrap: wrap; } .ag-pasos { width: 100%; justify-content: space-between; } }

.ag-msg { margin: 12px 16px 0; padding: 8px 12px; border-radius: 3px; background: #fdecea; color: #a94442;
          border: 1px solid #f5c6c2; font-size: 13px; }

.ag-filtros { display: flex; flex-wrap: wrap; gap: 16px; }
.ag-filtros .form-group { flex: 1 1 240px; max-width: 360px; }
.ag-temas { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
.ag-tema { display: flex; flex-direction: column; gap: 6px; border: 1px solid #e3e3e3; border-radius: 6px;
           padding: 12px 14px; cursor: pointer; background: #fff; transition: border-color .15s, box-shadow .15s;
           text-align: left; width: 100%; font: inherit; color: inherit; }
.ag-tema:hover, .ag-tema:focus { border-color: #8a5a2b; box-shadow: 0 2px 8px rgba(138,90,43,.15); outline: none; }
.ag-tema h4 { margin: 0; font-size: 15px; font-weight: 600; }
.ag-tema p { margin: 0; font-size: 12.5px; color: #777; flex: 1; }
.ag-tema-pie { display: flex; align-items: center; gap: 8px; font-size: 11px; color: #999; }
.ag-chip { display: inline-block; padding: 1px 8px; border-radius: 10px; background: #f1ebe4; color: #7a5532; font-size: 11px; }
.ag-prio { flex: 1; height: 4px; background: #eee; border-radius: 2px; overflow: hidden; }
.ag-prio > div { height: 100%; background: #8a5a2b; }
.ag-vacio { padding: 24px; text-align: center; color: #999; border: 1px dashed #ddd; border-radius: 6px; }

.ag-avance { margin-bottom: 12px; }
.ag-avance-texto { display: flex; justify-content: space-between; font-size: 12px; color: #666; margin-bottom: 4px; }
.ag-avance-barra { height: 6px; background: #eee; border-radius: 3px; overflow: hidden; }
#ag-avance-relleno { height: 100%; width: 4%; background: #8a5a2b; transition: width .4s; }
.ag-charla { max-height: 55vh; overflow-y: auto; padding: 4px 2px; }
.ag-globo { display: flex; align-items: flex-end; gap: 8px; margin-bottom: 14px; }
.ag-globo-avatar .tzag { width: 40px; height: 40px; }
.ag-globo-texto { max-width: 78%; padding: 10px 13px; border-radius: 12px; line-height: 1.55; white-space: pre-wrap;
                  font-size: 13.5px; }
.ag-de-faustino .ag-globo-texto { background: #f7f1ea; border-bottom-left-radius: 3px; color: #3d2b1a; }
.ag-de-experto { justify-content: flex-end; }
.ag-de-experto .ag-globo-texto { background: #3c8dbc; color: #fff; border-bottom-right-radius: 3px; }
.ag-pensando-e .ag-globo-texto { color: #a08a73; font-style: italic; }
.ag-puntos::after { content: ''; animation: ag-puntos 1.2s steps(4) infinite; }
@keyframes ag-puntos { 0% { content: ''; } 25% { content: '.'; } 50% { content: '..'; } 75% { content: '...'; } }
#ag-pie-charla textarea { resize: vertical; }
.ag-pie-acciones { display: flex; align-items: center; gap: 8px; margin-top: 8px; flex-wrap: wrap; }
.ag-pie-acciones .ag-ayuda { flex: 1; min-width: 200px; }

.ag-intro-hechos .ag-globo-texto { max-width: 100%; white-space: normal; }
.ag-revisados { font-size: 12px; color: #666; margin: 0 0 8px; }
.ag-hechos { display: grid; gap: 10px; }
.ag-hecho { border: 1px solid #e3e3e3; border-left: 4px solid #d2c3b2; border-radius: 6px; padding: 10px 12px; background: #fff; }
.ag-hecho textarea { width: 100%; font-size: 13.5px; border: 1px solid transparent; border-radius: 3px; resize: vertical;
                     background: transparent; padding: 4px; }
.ag-hecho textarea:focus { border-color: #ddd; background: #fffdf9; outline: none; }
.ag-hecho .ag-meta { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; font-size: 11px; color: #999; margin: 6px 0 8px; }
.ag-hecho-acciones { display: flex; gap: 6px; align-items: center; }
.ag-hecho-estado { margin-left: auto; font-size: 12px; font-weight: 600; }
.ag-hecho.ag-listo { border-left-color: #00a65a; background: #f6fbf8; }
.ag-hecho.ag-listo .ag-hecho-estado { color: #00a65a; }
.ag-hecho.ag-fuera { border-left-color: #bbb; opacity: .6; }
.ag-hecho.ag-fuera .ag-hecho-estado { color: #888; }
.ag-cierre-acciones { margin-top: 14px; text-align: right; }

.ag-fin { text-align: center; padding: 24px 12px; }
.ag-fin .tzag { width: 96px; height: 96px; }
.ag-fin h4 { margin: 12px 0 6px; font-size: 18px; color: #5b3a1a; }
.ag-fin p { color: #666; max-width: 460px; margin: 0 auto 16px; }
.ag-ayuda { font-size: 12px; color: #999; }
</style>

<script>
(function () {
    var BASE = '<?= base_url() . AGE ?>agente/';
    // Faustino no se ofrece por /agentes (D-05): su identidad es fija, como la de los otros dos.
    var FAUSTINO = { clave: 'faustino', nombre: 'Faustino', avatar: 'faustino' };
    var AREAS = { man: 'Mantenimiento', alm: 'Almacenes', general: 'General' };
    var sesion = null, primeraCarga = true, aprobados = 0, descartados = 0, totalHechos = 0;

    function esc(t) { return $('<div>').text(t == null ? '' : t).html(); }

    function mensaje(texto) {
        $('#ag-msg').text(texto || '').prop('hidden', !texto);
    }

    function paso(nombre) {
        var orden = ['tema', 'charla', 'hechos'], i = orden.indexOf(nombre);
        $('#ag-ent .ag-pasos li').each(function () {
            var j = orden.indexOf($(this).data('paso'));
            $(this).toggleClass('activo', j === i).toggleClass('hecho', i < 0 || j < i);
        });
        $('#ag-paso-tema').prop('hidden', nombre !== 'tema');
        $('#ag-paso-charla').prop('hidden', nombre !== 'charla');
        $('#ag-pie-charla').prop('hidden', nombre !== 'charla');
        $('#ag-paso-hechos').prop('hidden', nombre !== 'hechos');
        $('#ag-paso-fin').prop('hidden', nombre !== 'fin');
        mensaje('');
    }

    function estado(e) {
        TZAgente.estado($('#ag-cab-avatar .tzag'), e);
    }

    $('#ag-cab-avatar').html(TZAgente.avatar(FAUSTINO, 'saludo', true));
    $('#ag-paso-hechos [data-avatar]').html(TZAgente.avatar(FAUSTINO, 'hablando'));

    // ------------------------------------------------------------ paso 1
    function cargarExpertos() {
        $.get(BASE + 'expertos', function (r) {
            var $s = $('#ag-experto').empty();
            (r.expertos || []).forEach(function (e) {
                $s.append('<option value="' + esc(e.experto_id) + '">' + esc(e.nombre) + '</option>');
            });
            if (!(r.expertos || []).length) {
                $s.append('<option value="">— no hay expertos cargados —</option>');
            }
        });
    }

    function cargarTemas() {
        var $t = $('#ag-temas').html('<div class="ag-vacio">Buscando los temas que más faltan...</div>');
        $.get(BASE + 'agenda', { vertical: $('#ag-vertical').val() }, function (r) {
            // La primera vez, la industria que declaró la empresa (si la declaró).
            if (primeraCarga) {
                primeraCarga = false;
                if (r.vertical_empresa && !$('#ag-vertical').val() &&
                    $('#ag-vertical option[value="' + r.vertical_empresa + '"]').length) {
                    $('#ag-vertical').val(r.vertical_empresa);
                    $('#ag-vertical-nota').prop('hidden', false);
                    cargarTemas();
                    return;
                }
            }
            var temas = r.temas || [];
            $t.empty();
            if (!temas.length) {
                $t.html('<div class="ag-vacio">No quedan temas pendientes para esta industria. ¡Buen trabajo!</div>');
                return;
            }
            var max = Math.max.apply(null, temas.map(function (t) { return t.prioridad || 0; })) || 1;
            temas.forEach(function (t) {
                var area = AREAS[t.modulo] || t.modulo;
                $t.append(
                    '<button type="button" class="ag-tema" data-tema="' + esc(t.tema_id) + '" data-nombre="' + esc(t.nombre) + '">' +
                      '<h4>' + esc(t.nombre) + '</h4>' +
                      '<p>' + esc(t.descripcion || '') + '</p>' +
                      '<span class="ag-tema-pie">' +
                        '<span class="ag-chip">' + esc(area) + '</span>' +
                        '<span class="ag-prio" title="Prioridad ' + Math.round(t.prioridad) + '"><div style="width:' +
                          Math.max(6, Math.round(100 * (t.prioridad || 0) / max)) + '%"></div></span>' +
                      '</span>' +
                    '</button>');
            });
        }).fail(function () {
            $t.html('<div class="ag-vacio">No se pudieron traer los temas. Probá de nuevo en un momento.</div>');
        });
    }

    $('#ag-vertical').on('change', function () { $('#ag-vertical-nota').prop('hidden', true); cargarTemas(); });

    $('#ag-temas').on('click', '.ag-tema', function () {
        var $b = $(this), tema = $b.data('tema'), experto = $('#ag-experto').val();
        if (!experto) { mensaje('Elegí quién va a responder.'); $('#ag-experto').focus(); return; }
        $b.prop('disabled', true);
        estado('pensando');

        $.post(BASE + 'entrevista_iniciar', { experto_id: experto, tema_id: tema })
            .done(function (r) {
                if (r.error) { mensaje(r.error); estado('saludo'); return; }
                sesion = r.sesion_id;
                $('#ag-charla').empty();
                paso('charla');
                $('#ag-ent-sub').text('Tema: ' + (r.tema || $b.data('nombre')));
                avance(r.intercambios || 0, r.sugeridos);
                globo('faustino', r.pregunta);
                $('#ag-ent-respuesta').focus();
            })
            .fail(function () { mensaje('No se pudo iniciar la entrevista. Probá de nuevo en un momento.'); estado('saludo'); })
            .always(function () { $b.prop('disabled', false); });
    });

    // ------------------------------------------------------------ paso 2
    function avance(n, total) {
        total = total || parseInt($('#ag-avance-total').text(), 10) || 6;
        $('#ag-avance-total').text(total);
        $('#ag-avance-n').text(n === 0 ? 'Primera pregunta' : 'Llevás ' + n + (n === 1 ? ' respuesta' : ' respuestas'));
        $('#ag-avance-relleno').css('width', Math.min(100, Math.max(4, Math.round(100 * n / total))) + '%');
    }

    function globo(quien, texto, clase) {
        var deFaustino = quien === 'faustino';
        var $g = $('<div class="ag-globo ' + (deFaustino ? 'ag-de-faustino' : 'ag-de-experto') + (clase ? ' ' + clase : '') + '">' +
                   (deFaustino ? '<span class="ag-globo-avatar">' + TZAgente.avatar(FAUSTINO, clase ? 'pensando' : 'hablando') + '</span>' : '') +
                   '<div class="ag-globo-texto"></div></div>');
        $g.find('.ag-globo-texto').text(texto == null ? '' : texto);
        if (clase) { $g.find('.ag-globo-texto').addClass('ag-puntos'); }
        $('#ag-charla').append($g);
        var c = $('#ag-charla');
        c.scrollTop(c[0].scrollHeight);
        if (deFaustino && !clase) { estado('hablando'); }
        return $g;
    }

    $('#ag-ent-respuesta').on('focus input', function () { estado('escuchando'); });
    $('#ag-ent-respuesta').on('keydown', function (e) {
        if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); $('#ag-ent-form').submit(); }
    });

    $('#ag-ent-form').on('submit', function (e) {
        e.preventDefault();
        var texto = $.trim($('#ag-ent-respuesta').val());
        if (!texto || !sesion) { return; }
        $('#ag-ent-respuesta').val('');
        $('#ag-enviar').prop('disabled', true);
        globo('experto', texto);
        var $espera = globo('faustino', 'Pensando la próxima pregunta', 'ag-pensando-e');
        estado('pensando');

        $.post(BASE + 'entrevista_responder', { sesion_id: sesion, respuesta: texto })
            .done(function (r) {
                $espera.remove();
                if (r.error) { globo('faustino', 'Se me cortó. Probá de nuevo en un momento.'); return; }
                if (r.cerrar) { avance(r.sugeridos || 6, r.sugeridos); globo('faustino', r.mensaje); estructurar(); return; }
                avance(r.intercambios || 0, r.sugeridos);
                globo('faustino', r.pregunta);
            })
            .fail(function () {
                $espera.remove();
                globo('faustino', 'Se me cortó. Probá de nuevo en un momento.');
            })
            .always(function () { $('#ag-enviar').prop('disabled', false); });
    });

    $('#ag-terminar').on('click', function (e) { e.preventDefault(); estructurar(); });

    // ------------------------------------------------------------ paso 3
    function contarRevisados() {
        var pendientes = totalHechos - aprobados - descartados;
        $('#ag-revisados').text(totalHechos ? (aprobados + descartados) + ' de ' + totalHechos + ' revisados' +
            (pendientes ? ' · te faltan ' + pendientes : ' · ¡listo!') : '');
    }

    function estructurar() {
        $('#ag-pie-charla').prop('hidden', true);
        var $espera = globo('faustino', 'Ordenando lo que me contaste', 'ag-pensando-e');
        estado('pensando');

        $.post(BASE + 'entrevista_estructurar', { sesion_id: sesion })
            .done(function (r) {
                $espera.remove();
                if (r.error) { mensaje(r.error); $('#ag-pie-charla').prop('hidden', false); return; }
                var $h = $('#ag-hechos').empty();
                aprobados = 0; descartados = 0; totalHechos = (r.hechos || []).length;
                (r.hechos || []).forEach(function (h) {
                    $h.append(
                        '<div class="ag-hecho" data-hecho="' + esc(h.hecho_id) + '">' +
                          '<textarea rows="3" aria-label="Lo que entendió Faustino">' + esc(h.contenido) + '</textarea>' +
                          '<div class="ag-meta">' +
                            (h.tipo_equipo ? '<span class="ag-chip">' + esc(h.tipo_equipo) + '</span>' : '') +
                            (h.situacion ? '<span class="ag-chip">' + esc(h.situacion) + '</span>' : '') +
                            '<span>confianza ' + esc(h.confianza) + '</span>' +
                          '</div>' +
                          '<div class="ag-hecho-acciones">' +
                            '<button type="button" class="btn btn-xs btn-success ag-ok">Está bien</button>' +
                            '<button type="button" class="btn btn-xs btn-default ag-no">Descartar</button>' +
                            '<span class="ag-hecho-estado"></span>' +
                          '</div>' +
                        '</div>');
                });
                if (!totalHechos) {
                    $h.html('<div class="ag-vacio">No saqué nada concreto de esta charla. Podés cerrarla y probar con otro tema.</div>');
                }
                contarRevisados();
                paso('hechos');
                estado('hablando');
            })
            .fail(function () {
                $espera.remove();
                mensaje('No se pudo ordenar la entrevista. Probá de nuevo.');
                $('#ag-pie-charla').prop('hidden', false);
            });
    }

    $('#ag-hechos').on('click', '.ag-ok, .ag-no', function () {
        var $c = $(this).closest('.ag-hecho'), ok = $(this).hasClass('ag-ok');
        $c.find('button').prop('disabled', true);
        // Se manda el texto del textarea: si el experto lo corrigió, vale el suyo.
        $.post(BASE + 'entrevista_validar', {
            hecho_id: $c.data('hecho'),
            aprobado: ok ? 'true' : 'false',
            contenido: ok ? $c.find('textarea').val() : ''
        }).done(function () {
            $c.removeClass('ag-listo ag-fuera').addClass(ok ? 'ag-listo' : 'ag-fuera');
            $c.find('.ag-hecho-estado').text(ok ? '✓ Aprobado' : 'Descartado');
            $c.find('textarea').prop('readonly', true);
            if (ok) { aprobados++; } else { descartados++; }
            contarRevisados();
        }).fail(function () {
            $c.find('button').prop('disabled', false);
            mensaje('No se pudo guardar. Probá de nuevo.');
        });
    });

    $('#ag-cerrar-sesion').on('click', function () {
        var pendientes = totalHechos - aprobados - descartados;
        $.post(BASE + 'entrevista_cerrar', { sesion_id: sesion }).always(function () {
            sesion = null;
            $('#ag-charla').empty();
            $('#ag-fin-avatar').html(TZAgente.avatar(FAUSTINO, 'despedida', true));
            $('#ag-fin-texto').text(
                (aprobados === 1 ? 'Quedó 1 cosa aprobada. Un curador la revisa antes de que los agentes la usen.' :
                 aprobados ? 'Quedaron ' + aprobados + ' cosas aprobadas. Un curador las revisa antes de que los agentes las usen.' :
                 'No quedó nada aprobado esta vez.') +
                (pendientes > 0 ? ' Dejaste ' + pendientes + ' sin revisar: no se usan.' : ''));
            paso('fin');
            estado('despedida');
            $('#ag-ent-sub').text('Te hago preguntas sobre lo que sabés para que no se pierda.');
        });
    });

    $('#ag-otro-tema').on('click', function () {
        paso('tema');
        estado('saludo');
        $('#ag-ent-sub').text('Te hago preguntas sobre lo que sabés para que no se pierda. Elegí un tema para empezar.');
        cargarTemas();
    });

    cargarExpertos();
    cargarTemas();
})();
</script>
