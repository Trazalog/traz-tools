<?php defined('BASEPATH') OR exit('No direct script access allowed');
/**
 * Metas sobre los KPIs (KPI-OBJ, ADR-A9). Se incluye dentro del Tablero del Administrador
 * (dashboard/admin_dashboard), así que hereda el CSS scopeado en .tzdash. Datos y acciones:
 * controllers/Objetivos.php, por lib/props/objetivos.js.
 */
?>
<style>
.tzdash .tz-metas{padding:16px 18px;margin-top:16px;}
.tzdash .tz-metas .tz-metas-tabla{overflow-x:auto;}
.tzdash .tz-metas table{width:100%;min-width:640px;border-collapse:collapse;font-size:13px;}
.tzdash .tz-metas th{font-size:11px;text-transform:uppercase;letter-spacing:.05em;color:var(--tz-muted);
  text-align:left;padding:6px 8px;border-bottom:1px solid var(--tz-border);font-weight:600;}
.tzdash .tz-metas td{padding:8px;border-bottom:1px solid var(--tz-border);vertical-align:middle;}
.tzdash .tz-metas .tz-ok{color:#2f855a;font-weight:700;}
.tzdash .tz-metas .tz-no{color:#c53030;font-weight:700;}
.tzdash .tz-metas .tz-sd{color:var(--tz-muted);}
.tzdash .tz-metas .tz-meta-form{display:grid;grid-template-columns:2fr 1.3fr 1fr 1.2fr 1.6fr auto;gap:8px;margin-top:14px;align-items:end;}
@media(max-width:900px){.tzdash .tz-metas .tz-meta-form{grid-template-columns:1fr 1fr;}}
.tzdash .tz-metas label{font-size:11px;color:var(--tz-muted);font-weight:600;display:block;margin-bottom:3px;}
.tzdash .tz-metas .form-control{height:32px;font-size:13px;}
.tzdash .tz-metas .tz-meta-msg{margin-top:8px;font-size:13px;}
.tzdash .tz-metas .tz-vacio{color:var(--tz-muted);font-size:13px;padding:6px 0;}
.tzdash .tz-metas .tz-kuntur{font-size:10px;font-weight:700;background:#edf2f7;color:#4a5568;border-radius:6px;padding:1px 6px;margin-left:6px;}
</style>

<div class="tz-section-title">Metas
  <span class="tz-reorder-hint">Qué valor tiene que alcanzar cada indicador y para cuándo</span>
</div>
<div class="tz-card tz-metas" id="tz-metas">
  <div id="tz-metas-cuerpo"><div class="tz-vacio">Cargando…</div></div>

  <form id="tz-meta-form" class="tz-meta-form" autocomplete="off">
    <div>
      <label for="tz-meta-kpi">Indicador</label>
      <select id="tz-meta-kpi" name="kpi" class="form-control" required></select>
    </div>
    <div>
      <label for="tz-meta-op">Tiene que quedar</label>
      <select id="tz-meta-op" name="operador" class="form-control">
        <option value=">=">igual o por encima de</option>
        <option value="<=">igual o por debajo de</option>
      </select>
    </div>
    <div>
      <label for="tz-meta-valor">Meta</label>
      <input id="tz-meta-valor" name="meta" class="form-control" inputmode="decimal" required>
    </div>
    <div>
      <label for="tz-meta-hasta">Para el</label>
      <input id="tz-meta-hasta" name="hasta" type="date" class="form-control" required>
    </div>
    <div>
      <label for="tz-meta-resp">Responsable</label>
      <input id="tz-meta-resp" name="responsable" class="form-control" maxlength="255" placeholder="Opcional">
    </div>
    <div>
      <button type="submit" class="btn btn-primary btn-sm">Agregar meta</button>
    </div>
  </form>
  <div class="tz-meta-msg" id="tz-meta-msg" hidden></div>
</div>

<script>
(function(){
  var base = '<?php echo base_url(); ?>';
  function go(){ if(window.TZMetas){ TZMetas.init(base); } }
  if(window.TZMetas){ go(); }
  else{ $.getScript(base + 'lib/props/objetivos.js').done(go); }
})();
</script>
