<?php defined('BASEPATH') or exit('No direct script access allowed'); ?>
<div class="content-wrapper">
  <section class="content-header"><h1>Agente Minero</h1></section>
  <section class="content">
    <div class="callout callout-danger">
      <h4>No se pudo conectar con el agente</h4>
      <p><?= html_escape($mensaje) ?></p>
    </div>
    <a href="<?= base_url() . AGE ?>agente/conectar" class="btn btn-primary">Reintentar</a>
    <a href="<?= base_url() ?>Dash" class="btn btn-default">Volver</a>
  </section>
</div>
