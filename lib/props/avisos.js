/*
 * La campanita de Tools (ADR-015). Markup en application/views/layout/perfil.php,
 * datos de index.php/Avisos/* (empresa y usuario salen de la sesion, no de aca).
 *
 *  - Cada minuto pide solo el numero de no leidos; la lista se trae al abrir.
 *  - Clic en un aviso: lo marca leido y, si tiene enlace, lo abre.
 *  - "Recibir avisos en este navegador": pide el permiso de push
 *    (window.TZAvisosPush, de firebase_config.js).
 *  - Al salir de Tools da de baja el navegador, para que no le sigan llegando
 *    los avisos del usuario que se fue.
 *  - Si la sesion vencio (401), deja de consultar: la campanita no mantiene
 *    viva la sesion.
 */
(function ($) {
    'use strict';

    var BASE = window.TZ_BASE_URL || '';
    var URL = BASE + 'index.php/Avisos/';
    var CADA_MS = 60000;
    var temporizador = null;
    var AGENTES = { quirqui: 1, kuntur: 1, faustino: 1 };

    function texto(s) {
        return $('<div>').text(s == null ? '' : String(s)).html();
    }

    function detener() {
        if (temporizador) { clearInterval(temporizador); temporizador = null; }
    }

    function pintarNumero(n) {
        var $n = $('#tz-avisos-numero');
        n = parseInt(n, 10) || 0;
        $n.text(n > 99 ? '99+' : n).toggle(n > 0);
        $('#tz-avisos-titulo').text(n === 0 ? 'No tenés avisos nuevos'
            : (n === 1 ? 'Tenés 1 aviso nuevo' : 'Tenés ' + n + ' avisos nuevos'));
    }

    function icono(a) {
        if (a.severidad === 'critica') { return 'fa-exclamation-circle text-red'; }
        if (a.severidad === 'aviso') { return 'fa-warning text-yellow'; }
        return 'fa-info-circle text-aqua';
    }

    function pintarLista(avisos) {
        var $ul = $('#tz-avisos-lista').empty();
        if (!avisos.length) {
            $ul.append('<li><a href="#" class="tz-aviso-vacio">Todavía no hay avisos.</a></li>');
            return;
        }
        $.each(avisos, function (_, a) {
            var firma = AGENTES[(a.emisor || '').toLowerCase()] ? ' <small class="text-muted">— ' + texto(a.emisor) + '</small>' : '';
            var $li = $('<li>').toggleClass('tz-aviso-leido', !!a.leido);
            $('<a href="#" class="tz-aviso">')
                .attr('data-id', a.aviso_id)
                .attr('data-enlace', a.enlace || '')
                .attr('title', a.cuerpo || '')
                .html('<i class="fa ' + icono(a) + '"></i> ' + texto(a.titulo) + firma
                    + '<br><small class="text-muted">' + texto(a.fec_alta) + '</small>')
                .appendTo($li);
            $ul.append($li);
        });
    }

    function manejarError(xhr) {
        if (xhr && xhr.status === 401) { detener(); }
    }

    function contar() {
        $.getJSON(URL + 'noLeidos').done(function (r) { pintarNumero(r.no_leidos); }).fail(manejarError);
    }

    function listar() {
        $.getJSON(URL + 'mios').done(function (r) {
            pintarNumero(r.no_leidos);
            pintarLista(r.avisos || []);
        }).fail(manejarError);
    }

    function pintarPush() {
        var p = window.TZAvisosPush;
        var $b = $('#tz-avisos-push');
        if (!p || !p.soportado) { $b.hide(); return; }
        if (p.permiso() === 'granted') { $b.hide(); return; }
        $b.show().text(p.permiso() === 'denied'
            ? 'El navegador tiene bloqueados los avisos de Tools'
            : 'Recibir avisos en este navegador');
    }

    $(document).on('click', '#tz-avisos-menu > a', function () {
        listar();
        pintarPush();
    });

    $(document).on('click', '#tz-avisos-lista .tz-aviso', function (e) {
        e.preventDefault();
        var id = $(this).data('id');
        var enlace = String($(this).data('enlace') || '');
        $.post(URL + 'leido/' + id).always(function () {
            contar();
            if (enlace) {
                // Solo https/http o una ruta de modulo de Tools (letras, numeros,
                // _ - / .): nada de javascript: ni otros esquemas.
                if (/^https?:\/\//i.test(enlace)) { window.open(enlace, '_blank', 'noopener'); }
                else if (/^[A-Za-z0-9_\-\/.]+$/.test(enlace) && typeof linkTo === 'function') {
                    linkTo(enlace.replace(/^\/+/, ''));
                }
            }
        });
    });

    $(document).on('click', '#tz-avisos-todos', function (e) {
        e.preventDefault();
        e.stopPropagation();
        $.post(URL + 'leidos').always(listar);
    });

    $(document).on('click', '#tz-avisos-push', function (e) {
        e.preventDefault();
        e.stopPropagation();
        var p = window.TZAvisosPush;
        if (!p || p.permiso() === 'denied') { return; }
        p.activar().then(pintarPush, pintarPush);
    });

    // Baja del navegador al salir. sendBeacon: el pedido sale aunque la pagina
    // ya se este yendo, y con la sesion todavia viva.
    $(document).on('click', 'a[href*="Login/log_out"]', function () {
        var token = null;
        try { token = localStorage.getItem('tz_avisos_token'); } catch (err) { token = null; }
        if (token && navigator.sendBeacon) {
            var datos = new FormData();
            datos.append('token', token);
            navigator.sendBeacon(URL + 'bajaDispositivo', datos);
            try { localStorage.removeItem('tz_avisos_token'); } catch (err) { /* nada */ }
        }
    });

    window.TZAvisos = { refrescar: contar };

    $(function () {
        if (!$('#tz-avisos-menu').length) { return; }
        contar();
        temporizador = setInterval(contar, CADA_MS);
    });
})(jQuery);
