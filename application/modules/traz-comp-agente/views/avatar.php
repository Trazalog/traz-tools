<?php defined('BASEPATH') or exit('No direct script access allowed'); ?>
<!--
  Componente de avatar de los agentes (AGENTE-ID-05).

  Lo usan el panel de Quirqui, el chat de pagina y (mas adelante) las pantallas
  de Kuntur y de Faustino. Define una sola vez, en toda la pagina, el objeto
  global TZAgente:

      TZAgente.avatar(agente, estado, grande)  -> HTML del avatar
      TZAgente.estado(elemento, estado)        -> cambia el estado de un avatar ya pintado

  `agente` es lo que devuelve GET /agentes: {clave, nombre, avatar}.
  Estados: saludo, escuchando, pensando, hablando, alerta, despedida
  (doc/agente/identidad.md).

  IMAGENES: si existe assets/agentes/<avatar>/<estado>.webp se muestra esa
  imagen. Mientras no existan (las genera AGENTE-ID-03, con la ficha de los
  personajes aprobada por el PM), se muestra un circulo con la inicial. Es a
  proposito: el componente tiene que funcionar sin imagenes.

  ANIMACION: por CSS sobre la imagen fija (respirar, balanceo, latido de
  alerta). Sin video: pesa nada y anda en cualquier celular.
-->
<style>
.tzag { position: relative; display: inline-flex; align-items: center; justify-content: center;
        width: 32px; height: 32px; flex-shrink: 0; }
.tzag.tzag-grande { width: 54px; height: 54px; }
.tzag .tzag-img, .tzag .tzag-ini { width: 100%; height: 100%; border-radius: 50%; }
.tzag .tzag-img { object-fit: cover; background: #fff; }
.tzag .tzag-ini { display: none; align-items: center; justify-content: center; color: #fff;
                  font-weight: bold; background: var(--tzag-color, #3c8dbc); }
.tzag.tzag-sin-imagen .tzag-img { display: none; }
.tzag.tzag-sin-imagen .tzag-ini { display: flex; }
.tzag.tzag-grande .tzag-ini { font-size: 22px; }
/* Un color por agente, mientras no haya arte. Se reemplaza con los colores de la marca. */
.tzag[data-agente="quirqui"]  { --tzag-color: #3c8dbc; }
.tzag[data-agente="kuntur"]   { --tzag-color: #343a40; }
.tzag[data-agente="faustino"] { --tzag-color: #8a5a2b; }

@keyframes tzag-respira { 0%,100% { transform: scale(1); } 50% { transform: scale(1.05); } }
@keyframes tzag-balanceo { 0%,100% { transform: rotate(-4deg); } 50% { transform: rotate(4deg); } }
@keyframes tzag-latido { 0%,100% { box-shadow: 0 0 0 0 rgba(221,75,57,.55); }
                         50% { box-shadow: 0 0 0 8px rgba(221,75,57,0); } }
.tzag > * { animation: tzag-respira 4s ease-in-out infinite; }
.tzag[data-estado="pensando"] > * { animation: tzag-balanceo 1.2s ease-in-out infinite; }
.tzag[data-estado="hablando"] > * { animation: tzag-respira 0.8s ease-in-out infinite; }
.tzag[data-estado="alerta"]   > * { animation: tzag-latido 1.2s ease-out infinite; }
/* Quien pide menos movimiento, no lo recibe. */
@media (prefers-reduced-motion: reduce) { .tzag > * { animation: none !important; } }
</style>

<script>
window.TZAgente = window.TZAgente || (function () {
    var BASE = '<?= base_url() ?>assets/agentes/';
    var ESTADOS = ['saludo', 'escuchando', 'pensando', 'hablando', 'alerta', 'despedida'];

    function esc(t) { return String(t == null ? '' : t).replace(/[&<>"']/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function valido(e) { return ESTADOS.indexOf(e) >= 0 ? e : 'saludo'; }
    // La clave sale del servidor, pero termina en una URL y en un atributo.
    function limpia(c) { return String(c || '').replace(/[^a-z0-9_-]/g, ''); }

    function avatar(agente, estado, grande) {
        var clave = limpia(agente && (agente.avatar || agente.clave)) || 'agente';
        var nombre = (agente && agente.nombre) || 'Agente';
        estado = valido(estado);
        return '<span class="tzag tzag-sin-imagen' + (grande ? ' tzag-grande' : '') + '" ' +
               'data-agente="' + esc(clave) + '" data-estado="' + estado + '" title="' + esc(nombre) + '">' +
                 '<img class="tzag-img" alt="" src="' + BASE + clave + '/' + estado + '.webp" ' +
                      'onload="this.parentNode.classList.remove(\'tzag-sin-imagen\')" ' +
                      'onerror="this.parentNode.classList.add(\'tzag-sin-imagen\')">' +
                 '<span class="tzag-ini">' + esc(nombre.charAt(0).toUpperCase()) + '</span>' +
               '</span>';
    }

    // Cambia el estado de un avatar ya pintado (y recarga la imagen de ese estado).
    function estadoDe(el, estado) {
        var $a = window.jQuery ? window.jQuery(el) : null;
        if (!$a || !$a.length) { return; }
        estado = valido(estado);
        $a.attr('data-estado', estado);
        var clave = $a.attr('data-agente');
        $a.find('.tzag-img').attr('src', BASE + clave + '/' + estado + '.webp');
    }

    return { avatar: avatar, estado: estadoDe, ESTADOS: ESTADOS };
})();
</script>
