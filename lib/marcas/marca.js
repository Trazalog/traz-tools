/*
 * Marca por dominio (REQ-019, ADR-015) — ajustes del lado del navegador.
 *
 * Se carga SOLO con una marca distinta de Trazalog (ver layout/Admin.php),
 * después de que el layout publica window.MARCA = {id, nombre,
 * titulo_impresion, logo_impresos}.
 *
 * Cubre, sin tocar los módulos con repositorio propio:
 *  1. El título fijo "TRAZALOG TOOLS" de las impresiones (printThis).
 *  2. El logo por defecto de Trazalog en remitos y vales
 *     (imagenes/trazalog/logo_trazalog.png). Los logos propios de cada
 *     empresa NO se tocan.
 *
 * Sin sintaxis moderna a propósito: corre en los mismos navegadores que el resto.
 */
(function (window, $) {
    'use strict';

    var MARCA = window.MARCA || {};
    var LOGO_TRAZALOG = 'imagenes/trazalog/logo_trazalog.png';
    var TITULO_TRAZALOG = /trazalog\s*tools/i;

    if (!$ || !MARCA.id) {
        return;
    }

    /* 1. Título de impresión */
    if (MARCA.titulo_impresion && $.fn.printThis) {
        var printOriginal = $.fn.printThis;
        $.fn.printThis = function (opciones) {
            if (opciones && typeof opciones.pageTitle === 'string' && TITULO_TRAZALOG.test(opciones.pageTitle)) {
                opciones.pageTitle = MARCA.titulo_impresion;
            }
            return printOriginal.apply(this, arguments);
        };
        $.fn.printThis.defaults = printOriginal.defaults;
    }

    /* 2. Logo por defecto en documentos */
    function reemplazarLogos(raiz) {
        if (!MARCA.logo_impresos) {
            return;
        }
        $(raiz).find('img').each(function () {
            var src = this.getAttribute('src') || '';
            if (src.indexOf(LOGO_TRAZALOG) !== -1) {
                this.setAttribute('src', MARCA.logo_impresos);
            }
        });
    }

    $(function () {
        reemplazarLogos(document.body);

        // Las pantallas se cargan por AJAX dentro de #content, y algunas
        // cambian el src del logo con JavaScript después de cargar: se
        // observa el documento y se corrige cada cambio.
        if (window.MutationObserver) {
            var observador = new window.MutationObserver(function (cambios) {
                for (var i = 0; i < cambios.length; i++) {
                    var c = cambios[i];
                    if (c.type === 'attributes' && c.target.tagName === 'IMG') {
                        var src = c.target.getAttribute('src') || '';
                        if (src.indexOf(LOGO_TRAZALOG) !== -1) {
                            c.target.setAttribute('src', MARCA.logo_impresos);
                        }
                    } else if (c.type === 'childList') {
                        for (var j = 0; j < c.addedNodes.length; j++) {
                            if (c.addedNodes[j].nodeType === 1) {
                                var nodo = c.addedNodes[j];
                                if (nodo.tagName === 'IMG') {
                                    reemplazarLogos(nodo.parentNode || nodo);
                                } else {
                                    reemplazarLogos(nodo);
                                }
                            }
                        }
                    }
                }
            });
            observador.observe(document.body, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['src']
            });
        }
    });
})(window, window.jQuery);
