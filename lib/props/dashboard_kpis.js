/**
 * Tablero del Administrador — carga y dibujo de KPIs.
 * Lee de la caché (kpi.cache) via Dash/kpi/<nombre> (ToolsKPIDataService). NUNCA del dato vivo.
 * Renderer de gráficos propio (canvas), sin dependencias: barras horizontales + dona.
 * Ver doc/analisis/dashboard-administrador-landing.md (Fase 2).
 */
var TZDash = (function () {
  'use strict';

  function fitCanvas(cv) {
    var dpr = window.devicePixelRatio || 1;
    var r = cv.getBoundingClientRect();
    var w = r.width || cv.parentNode.clientWidth || 300;
    var h = r.height || cv.parentNode.clientHeight || 200;
    cv.width = Math.round(w * dpr);
    cv.height = Math.round(h * dpr);
    var ctx = cv.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { ctx: ctx, w: w, h: h };
  }

  // Barras horizontales: items = [{label, value}]
  function drawBars(cv, items, color) {
    var d = fitCanvas(cv), ctx = d.ctx, W = d.w, H = d.h;
    ctx.clearRect(0, 0, W, H);
    if (!items || !items.length) { emptyMsg(ctx, W, H); return; }
    items = items.slice(0, 6);
    var max = Math.max.apply(null, items.map(function (i) { return i.value; })) || 1;
    var padL = Math.min(150, Math.round(W * 0.42)), padR = 42, padT = 6, padB = 6;
    var gap = 8, n = items.length;
    var bh = Math.max(10, (H - padT - padB - gap * (n - 1)) / n);
    ctx.font = '12px "Segoe UI",Roboto,Arial,sans-serif';
    ctx.textBaseline = 'middle';
    for (var i = 0; i < n; i++) {
      var y = padT + i * (bh + gap);
      var bw = Math.round((W - padL - padR) * (items[i].value / max));
      // etiqueta
      ctx.fillStyle = '#4a5568'; ctx.textAlign = 'right';
      ctx.fillText(trunc(items[i].label, 22), padL - 8, y + bh / 2);
      // barra
      roundRect(ctx, padL, y, Math.max(bw, 2), bh, 5); ctx.fillStyle = color; ctx.fill();
      // valor
      ctx.fillStyle = '#1a202c'; ctx.textAlign = 'left';
      ctx.fillText(String(items[i].value), padL + Math.max(bw, 2) + 8, y + bh / 2);
    }
  }

  // Dona: segments = [{label, value, color}], center = {big, small}
  function drawDoughnut(cv, segments, center) {
    var d = fitCanvas(cv), ctx = d.ctx, W = d.w, H = d.h;
    ctx.clearRect(0, 0, W, H);
    var total = segments.reduce(function (s, x) { return s + (x.value || 0); }, 0);
    var cx = W / 2, cy = H / 2, r = Math.min(W, H) / 2 - 8, rin = r * 0.68;
    if (total <= 0) { emptyMsg(ctx, W, H); return; }
    var a0 = -Math.PI / 2;
    for (var i = 0; i < segments.length; i++) {
      var a1 = a0 + (segments[i].value / total) * Math.PI * 2;
      ctx.beginPath(); ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, r, a0, a1); ctx.closePath();
      ctx.fillStyle = segments[i].color; ctx.fill();
      a0 = a1;
    }
    // agujero
    ctx.beginPath(); ctx.arc(cx, cy, rin, 0, Math.PI * 2);
    ctx.fillStyle = getGround(); ctx.fill();
    // centro
    if (center) {
      ctx.textAlign = 'center';
      ctx.fillStyle = '#1a202c';
      ctx.font = '700 30px "Segoe UI",Roboto,Arial,sans-serif';
      ctx.fillText(String(center.big), cx, cy - 4);
      ctx.fillStyle = '#718096';
      ctx.font = '12px "Segoe UI",Roboto,Arial,sans-serif';
      ctx.fillText(center.small || '', cx, cy + 18);
    }
  }

  function roundRect(ctx, x, y, w, h, r) {
    r = Math.min(r, h / 2, w / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
  }
  function trunc(s, n) { s = String(s == null ? '' : s); return s.length > n ? s.slice(0, n - 1) + '…' : s; }
  function getGround() {
    var c = document.querySelector('.tzdash .tz-card');
    return c ? getComputedStyle(c).backgroundColor || '#fff' : '#fff';
  }
  function emptyMsg(ctx, W, H) {
    ctx.fillStyle = '#a0aec0'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = '13px "Segoe UI",Roboto,Arial,sans-serif';
    ctx.fillText('Sin datos', W / 2, H / 2);
  }

  // Adapta el valor_json crudo de cada KPI a lo que dibuja el gráfico.
  function render(box, chart, valor, vjson) {
    var cv = box.querySelector('canvas');
    var color = box.getAttribute('data-color') || '#2b6cb0';
    var nombre = box.getAttribute('data-kpi');
    var foot = box.querySelector('.tz-kpi-foot .tz-foot-info');
    if (!cv) return;

    if (chart === 'bar') {
      var items = (vjson || []).map(function (r) {
        return { label: (r.deposito || r.establecimiento || ''), value: Number(r.criticos || 0) };
      }).sort(function (a, b) { return b.value - a.value; });
      drawBars(cv, items, color);
      if (foot) foot.textContent = items.length + ' depósito(s) · ' + (valor || 0) + ' crítico(s)';
      box._detail = items.map(function (r, i) {
        var o = vjson[i] || {};
        return [o.establecimiento || '—', o.deposito || '—', r.value];
      });
      box._detailCols = ['Establecimiento', 'Depósito', 'Críticos'];
    } else if (chart === 'doughnut') {
      var segs, center;
      if (nombre === 'getDisponibilidad' || nombre === 'man_disponibilidad') {
        var disp = Number((vjson && vjson.disponibilidad != null) ? vjson.disponibilidad : (valor || 0));
        segs = [{ label: 'Disponible', value: disp, color: color },
                { label: 'No disponible', value: Math.max(100 - disp, 0), color: '#e2e8f0' }];
        center = { big: disp + '%', small: 'disponibilidad' };
        if (foot) foot.textContent = (vjson && vjson.periodo) ? vjson.periodo : 'Últimos 12 meses';
        box._detail = [['Disponibilidad', disp + '%'], ['No disponible', (Math.round((100 - disp) * 100) / 100) + '%']];
        box._detailCols = ['Métrica', 'Valor'];
        drawDoughnut(cv, segs, center);
        return;
      }
      if (nombre === 'her_transito') {
        var t = Number((vjson && vjson.total) || 0), en = Number((vjson && vjson.en_transito) || 0);
        segs = [{ label: 'En tránsito', value: en, color: color },
                { label: 'En depósito', value: Math.max(t - en, 0), color: '#e6ddd4' }];
        center = { big: en + (t ? ' / ' + t : ''), small: 'en tránsito' };
        if (foot) foot.textContent = t ? (Math.round(en / t * 1000) / 10) + '% del parque' : '—';
        box._detail = [['En tránsito', en], ['En depósito', Math.max(t - en, 0)], ['Total', t]];
      } else {
        var se = Number((vjson && vjson.sin_entregar) || valor || 0), re = Number((vjson && vjson.recibidos) || 0);
        segs = [{ label: 'Sin entregar', value: se, color: color },
                { label: 'Recibidos', value: re, color: '#dbe5f0' }];
        center = { big: se, small: 'pendientes' };
        if (foot) foot.textContent = re + ' entregado(s)';
        box._detail = [['Sin entregar', se], ['Recibidos', re]];
      }
      box._detailCols = ['Estado', 'Cantidad'];
      drawDoughnut(cv, segs, center);
    }
  }

  function fetchOne(box, base) {
    var nombre = box.getAttribute('data-kpi');
    var fuente = box.getAttribute('data-fuente') || 'tools';
    // MAN lee de la caché de AssetPlanner (endpoint distinto); el resto, de la caché Postgres.
    var ruta = (fuente === 'man') ? 'Dash/kpiMan/' : 'Dash/kpi/';
    box.classList.add('tz-loading');
    $.getJSON(base + ruta + encodeURIComponent(nombre))
      .done(function (data) {
        box.classList.remove('tz-loading');
        // respuesta vacía (endpoint sin dato / empresa sin vínculo): mostrar "No disponible"
        if (!data || (data.valor === undefined && data.valor_json === undefined)) {
          box.classList.add('tz-error'); return;
        }
        box.classList.remove('tz-error');
        render(box, box.getAttribute('data-chart'), data.valor, data.valor_json);
        var st = box.querySelector('.tz-kpi-updated');
        if (st && data.calculado_en) st.textContent = 'act. ' + data.calculado_en;
      })
      .fail(function () { box.classList.remove('tz-loading'); box.classList.add('tz-error'); });
  }

  function toggleDetail(box) {
    var panel = box.querySelector('.tz-kpi-detail');
    if (!panel || !box._detail) return;
    if (panel.hasAttribute('hidden')) {
      var cols = box._detailCols || [], rows = box._detail || [];
      var html = '<table><thead><tr>' + cols.map(function (c) { return '<th>' + c + '</th>'; }).join('') + '</tr></thead><tbody>';
      html += rows.map(function (r) { return '<tr>' + r.map(function (c) { return '<td>' + c + '</td>'; }).join('') + '</tr>'; }).join('');
      html += '</tbody></table>';
      panel.innerHTML = html; panel.removeAttribute('hidden');
    } else { panel.setAttribute('hidden', ''); }
  }

  // ---- Reordenamiento por drag & drop (nativo, sin dependencias) ----
  function orderKey(emprId) { return 'tzdash_kpi_order_' + (emprId || 'x'); }

  function saveOrder(cont, emprId) {
    try {
      var order = [];
      cont.querySelectorAll('.tz-kpi-col .tz-kpi[data-kpi]').forEach(function (b) {
        order.push(b.getAttribute('data-kpi'));
      });
      localStorage.setItem(orderKey(emprId), JSON.stringify(order));
    } catch (e) { /* localStorage no disponible: se ignora */ }
  }

  function applySavedOrder(cont, emprId) {
    var saved;
    try { saved = JSON.parse(localStorage.getItem(orderKey(emprId)) || '[]'); } catch (e) { return; }
    if (!saved || !saved.length) return;
    saved.forEach(function (nombre) {
      var cols = cont.querySelectorAll('.tz-kpi-col');
      for (var i = 0; i < cols.length; i++) {
        var b = cols[i].querySelector('.tz-kpi[data-kpi]');
        if (b && b.getAttribute('data-kpi') === nombre) { cont.appendChild(cols[i]); break; }
      }
    });
  }

  function redrawAll(cont, base) {
    cont.querySelectorAll('.tz-kpi[data-kpi]').forEach(function (b) { fetchOne(b, base); });
  }

  function enableDrag(cont, base, emprId) {
    var dragged = null;
    function clearMarks() {
      cont.querySelectorAll('.tz-kpi-col').forEach(function (c) {
        c.classList.remove('tz-over-before', 'tz-over-after');
      });
    }
    cont.querySelectorAll('.tz-kpi-col').forEach(function (col) {
      col.setAttribute('draggable', 'true');
      col.addEventListener('dragstart', function (e) {
        dragged = col; col.classList.add('tz-dragging');
        if (e.dataTransfer) { e.dataTransfer.effectAllowed = 'move'; try { e.dataTransfer.setData('text/plain', ''); } catch (_) {} }
      });
      col.addEventListener('dragend', function () {
        if (dragged) dragged.classList.remove('tz-dragging');
        dragged = null; clearMarks();
      });
      col.addEventListener('dragover', function (e) {
        e.preventDefault();
        if (!dragged || dragged === col) return;
        var r = col.getBoundingClientRect();
        var before = e.clientX < r.left + r.width / 2;
        col.classList.toggle('tz-over-before', before);
        col.classList.toggle('tz-over-after', !before);
      });
      col.addEventListener('dragleave', function () { col.classList.remove('tz-over-before', 'tz-over-after'); });
      col.addEventListener('drop', function (e) {
        e.preventDefault();
        if (!dragged || dragged === col) return;
        var r = col.getBoundingClientRect();
        var before = e.clientX < r.left + r.width / 2;
        cont.insertBefore(dragged, before ? col : col.nextSibling);
        clearMarks();
        saveOrder(cont, emprId);
        redrawAll(cont, base); // el canvas puede blanquearse al mover el nodo: se re-dibuja
      });
    });
  }

  var timers = [];
  function init(base, emprId) {
    timers.forEach(clearInterval); timers = [];
    var cont = document.querySelector('.tzdash .tz-kpis');
    if (!cont) return;
    applySavedOrder(cont, emprId);
    var boxes = cont.querySelectorAll('.tz-kpi[data-kpi]');
    boxes.forEach(function (box) {
      fetchOne(box, base);
      var ref = parseInt(box.getAttribute('data-refresh'), 10) || 0;
      if (ref > 0) timers.push(setInterval(function () { fetchOne(box, base); }, ref * 1000));
      var drill = box.querySelector('.tz-kpi-drill');
      if (drill) drill.addEventListener('click', function (e) { e.preventDefault(); toggleDetail(box); });
    });
    enableDrag(cont, base, emprId);
    // redibuja al cambiar tamaño (canvas es sensible al ancho)
    var rt;
    window.addEventListener('resize', function () {
      clearTimeout(rt); rt = setTimeout(function () { redrawAll(cont, base); }, 300);
    });
  }

  return { init: init };
})();
