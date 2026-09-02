<?php defined('BASEPATH') or exit('No direct script access allowed'); ?>
<!--
  Feedback negativo agrupado. Es el tablero del ciclo de mejora: ver
  doc/agente/feedback.md para que hacer con cada caso.
-->
<div class="content-wrapper">
  <section class="content-header">
    <h1>Agente Minero <small>feedback a revisar</small></h1>
  </section>

  <section class="content">
    <?php if (!empty($feedback['error'])): ?>
      <div class="callout callout-warning">
        <p>No se pudo leer el feedback: <?= html_escape($feedback['error']) ?></p>
      </div>
    <?php endif; ?>

    <div class="row">
      <div class="col-md-4">
        <div class="box box-solid">
          <div class="box-header with-border"><h3 class="box-title">Por motivo</h3></div>
          <div class="box-body">
            <?php if (empty($feedback['resumen'])): ?>
              <p class="text-muted">Sin feedback negativo pendiente. Buena señal.</p>
            <?php else: ?>
              <table class="table table-condensed">
                <tbody>
                <?php foreach ($feedback['resumen'] as $r): ?>
                  <tr>
                    <td><?= html_escape($r['motivo']) ?></td>
                    <td class="text-right"><strong><?= (int) $r['cantidad'] ?></strong></td>
                  </tr>
                <?php endforeach; ?>
                </tbody>
              </table>
            <?php endif; ?>
          </div>
        </div>
      </div>

      <div class="col-md-8">
        <div class="box box-solid">
          <div class="box-header with-border"><h3 class="box-title">Casos</h3></div>
          <div class="box-body">
            <?php if (empty($feedback['detalle'])): ?>
              <p class="text-muted">Nada pendiente de revisar.</p>
            <?php else: ?>
              <?php foreach ($feedback['detalle'] as $d): ?>
                <div class="ag-caso">
                  <p class="ag-pregunta"><strong><?= html_escape($d['pregunta']) ?></strong></p>
                  <p class="ag-respuesta"><?= html_escape($d['respuesta']) ?></p>
                  <?php if (!empty($d['comentario'])): ?>
                    <p class="ag-comentario-usuario">Comentó: <em><?= html_escape($d['comentario']) ?></em></p>
                  <?php endif; ?>
                  <p class="ag-meta">
                    <?= (int) $d['cant_fragmentos'] ?> fragmento(s) ·
                    <?= (int) $d['cant_tools'] ?> tool(s) ·
                    <?= html_escape($d['modelo']) ?>
                    <?php if ((int) $d['cant_fragmentos'] === 0): ?>
                      <span class="label label-warning">hueco de conocimiento</span>
                    <?php endif; ?>
                    <?php if (!empty($d['error'])): ?>
                      <span class="label label-danger">con error</span>
                    <?php endif; ?>
                  </p>
                </div>
              <?php endforeach; ?>
            <?php endif; ?>
          </div>
        </div>
      </div>
    </div>
  </section>
</div>

<style>
.ag-caso { border-bottom: 1px solid #eee; padding: 12px 0; }
.ag-caso:last-child { border-bottom: none; }
.ag-caso .ag-respuesta { color: #555; white-space: pre-wrap; }
.ag-caso .ag-comentario-usuario { color: #8a6d3b; }
.ag-caso .ag-meta { font-size: 12px; color: #999; margin-bottom: 0; }
</style>
