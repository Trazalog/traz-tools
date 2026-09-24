<?php defined('BASEPATH') OR exit('No direct script access allowed');
/**
 * Tablero / Landing del Administrador (v2.5).
 * Fragmento cargado dentro de #content via linkTo() (AJAX). CSS scopeado en .tzdash.
 * Ver doc/analisis/dashboard-administrador-landing.md
 * Datos que espera: nombre_usuario, fecha_hoy, welcome_msg, nombre_empresa, logo_empresa,
 * cantidad_usuarios, tipo_suscripcion, modulos[], actividad[], kpis[].
 */
?>
<style>
.tzdash{--tz-ink:#1a202c;--tz-slate:#4a5568;--tz-muted:#718096;--tz-ground:#f4f6f9;
  --tz-card:#ffffff;--tz-border:#e6eaf0;--tz-brand:#2b6cb0;--tz-brand-soft:#ebf2fb;
  color:var(--tz-slate);font-family:"Segoe UI",Roboto,Helvetica,Arial,sans-serif;padding:4px 2px 18px;}
.tzdash *{box-sizing:border-box;}
.tzdash .tz-hero{display:grid;grid-template-columns:1.4fr .9fr;gap:16px;margin-bottom:16px;}
@media(max-width:900px){.tzdash .tz-hero{grid-template-columns:1fr;}}
.tzdash .tz-card{background:var(--tz-card);border:1px solid var(--tz-border);border-radius:14px;
  box-shadow:0 1px 2px rgba(16,24,40,.04),0 1px 3px rgba(16,24,40,.06);}
.tzdash .tz-welcome{padding:22px 24px;display:flex;flex-direction:column;justify-content:center;
  background:linear-gradient(135deg,#2b6cb0 0%,#1f4e8c 100%);color:#fff;border:none;}
.tzdash .tz-welcome .tz-date{font-size:12px;letter-spacing:.06em;text-transform:uppercase;opacity:.85;}
.tzdash .tz-welcome h2{margin:6px 0 4px;font-size:26px;font-weight:700;line-height:1.15;color:#fff;}
.tzdash .tz-welcome p{margin:0;font-size:14px;opacity:.92;max-width:46ch;}
.tzdash .tz-company{padding:18px 20px;display:flex;align-items:center;gap:16px;}
.tzdash .tz-company .tz-logo{width:56px;height:56px;border-radius:12px;object-fit:contain;
  background:var(--tz-brand-soft);padding:6px;flex:none;}
.tzdash .tz-company .tz-logo-ph{width:56px;height:56px;border-radius:12px;background:var(--tz-brand-soft);
  display:flex;align-items:center;justify-content:center;color:var(--tz-brand);font-size:22px;font-weight:800;flex:none;}
.tzdash .tz-company .tz-cname{font-size:19px;font-weight:700;color:var(--tz-ink);line-height:1.2;}
.tzdash .tz-pill{display:inline-flex;align-items:center;gap:6px;font-size:11px;font-weight:700;
  letter-spacing:.04em;text-transform:uppercase;padding:3px 10px;border-radius:999px;
  background:var(--tz-brand-soft);color:var(--tz-brand);margin-top:6px;}
.tzdash .tz-metrics{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:16px;}
@media(max-width:700px){.tzdash .tz-metrics{grid-template-columns:1fr;}}
.tzdash .tz-metric{padding:16px 18px;}
.tzdash .tz-metric .tz-label{font-size:11px;text-transform:uppercase;letter-spacing:.06em;color:var(--tz-muted);font-weight:600;}
.tzdash .tz-metric .tz-value{font-size:30px;font-weight:800;color:var(--tz-ink);line-height:1;margin-top:8px;
  font-variant-numeric:tabular-nums;}
.tzdash .tz-metric .tz-sub{font-size:12px;color:var(--tz-muted);margin-top:4px;}
.tzdash .tz-mods{display:flex;gap:10px;flex-wrap:wrap;margin-top:10px;}
.tzdash .tz-mod{display:flex;align-items:center;gap:8px;padding:8px 12px;border-radius:10px;
  border:1px solid var(--tz-border);background:#fbfcfe;}
.tzdash .tz-mod .tz-chip{width:34px;height:34px;border-radius:8px;color:#fff;font-weight:800;font-size:12px;
  display:flex;align-items:center;justify-content:center;flex:none;}
.tzdash .tz-mod .tz-mname{font-size:13px;font-weight:700;color:var(--tz-ink);line-height:1.1;}
.tzdash .tz-mod .tz-mstate{font-size:11px;color:#2f855a;}
.tzdash .tz-timeline{list-style:none;margin:8px 0 0;padding:0;}
.tzdash .tz-timeline li{font-size:12px;color:var(--tz-slate);padding:4px 0 4px 16px;position:relative;}
.tzdash .tz-timeline li:before{content:"";position:absolute;left:0;top:9px;width:7px;height:7px;border-radius:50%;background:var(--tz-brand);}
.tzdash .tz-section-title{font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;
  color:var(--tz-muted);margin:6px 4px 12px;}
.tzdash .tz-kpis{display:flex;flex-wrap:wrap;gap:16px;margin:0 -8px;}
.tzdash .tz-kpi-col{padding:0 8px;}
.tzdash .tz-kpi{position:relative;overflow:hidden;}
.tzdash .tz-kpi .tz-kpi-head{display:flex;align-items:center;gap:8px;padding:14px 16px 10px;}
.tzdash .tz-kpi .tz-kpi-accent{width:4px;align-self:stretch;border-radius:3px;}
.tzdash .tz-kpi .tz-kpi-title{font-size:14px;font-weight:700;color:var(--tz-ink);}
.tzdash .tz-kpi .tz-kpi-tag{font-size:10px;font-weight:700;color:#fff;border-radius:6px;padding:2px 7px;margin-left:auto;}
.tzdash .tz-kpi .tz-kpi-body{padding:0 16px 8px;position:relative;}
.tzdash .tz-kpi .tz-kpi-body canvas{width:100%;height:100%;display:block;}
.tzdash .tz-kpi.tz-loading .tz-kpi-body:after{content:"Cargando…";position:absolute;inset:0;
  display:flex;align-items:center;justify-content:center;color:var(--tz-muted);font-size:12px;
  background:rgba(255,255,255,.6);}
.tzdash .tz-kpi.tz-error .tz-kpi-body:after{content:"No disponible";position:absolute;inset:0;
  display:flex;align-items:center;justify-content:center;color:#c05621;font-size:12px;}
.tzdash .tz-kpi-foot{display:flex;align-items:center;justify-content:space-between;gap:8px;
  padding:8px 16px 14px;font-size:12px;color:var(--tz-muted);}
.tzdash .tz-kpi-foot .tz-kpi-drill{color:var(--tz-brand);font-weight:600;cursor:pointer;white-space:nowrap;}
.tzdash .tz-kpi-updated{font-size:10px;color:#a0aec0;}
.tzdash .tz-kpi-detail{border-top:1px solid var(--tz-border);padding:8px 16px 14px;}
.tzdash .tz-kpi-detail table{width:100%;border-collapse:collapse;font-size:12px;}
.tzdash .tz-kpi-detail th{text-align:left;color:var(--tz-muted);font-weight:600;padding:4px 6px;border-bottom:1px solid var(--tz-border);}
.tzdash .tz-kpi-detail td{padding:4px 6px;color:var(--tz-ink);border-bottom:1px solid #f0f2f6;}
.tzdash .tz-kpi-na{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;
  height:100%;min-height:150px;color:var(--tz-muted);text-align:center;padding:0 12px;
  background:repeating-linear-gradient(115deg,#f6f7f9,#f6f7f9 12px,#eef1f6 12px,#eef1f6 24px);border-radius:10px;}
.tzdash .tz-kpi-na b{color:var(--tz-slate);font-size:13px;}
.tzdash .tz-kpi-na span{font-size:11px;}
</style>

<div class="tzdash">

  <!-- ===== SECTOR A: SUSCRIPCIÓN ===== -->
  <div class="tz-hero">
    <div class="tz-card tz-welcome">
      <div class="tz-date"><?php echo htmlspecialchars($fecha_hoy, ENT_QUOTES, 'UTF-8'); ?></div>
      <h2>Hola, <?php echo htmlspecialchars($nombre_usuario, ENT_QUOTES, 'UTF-8'); ?></h2>
      <p><?php echo htmlspecialchars($welcome_msg, ENT_QUOTES, 'UTF-8'); ?></p>
    </div>
    <div class="tz-card tz-company">
      <?php if(!empty($logo_empresa)): ?>
        <img class="tz-logo" src="<?php echo base_url().$logo_empresa; ?>" alt="logo">
      <?php else: ?>
        <div class="tz-logo-ph"><?php echo strtoupper(mb_substr($nombre_empresa,0,1,'UTF-8')); ?></div>
      <?php endif; ?>
      <div>
        <div class="tz-cname"><?php echo htmlspecialchars($nombre_empresa, ENT_QUOTES, 'UTF-8'); ?></div>
        <span class="tz-pill"><i class="fa fa-star"></i> <?php echo htmlspecialchars($tipo_suscripcion, ENT_QUOTES, 'UTF-8'); ?></span>
      </div>
    </div>
  </div>

  <div class="tz-metrics">
    <div class="tz-card tz-metric">
      <div class="tz-label">Usuarios generados</div>
      <div class="tz-value"><?php echo ($cantidad_usuarios === null) ? '&mdash;' : (int) $cantidad_usuarios; ?></div>
      <div class="tz-sub"><?php echo ($cantidad_usuarios === null) ? 'No disponible' : 'en tu empresa'; ?></div>
    </div>
    <div class="tz-card tz-metric">
      <div class="tz-label">Suscripción</div>
      <div class="tz-value" style="font-size:22px;"><?php echo htmlspecialchars($tipo_suscripcion, ENT_QUOTES, 'UTF-8'); ?></div>
      <div class="tz-sub">Plan actual de tu cuenta</div>
    </div>
    <div class="tz-card tz-metric">
      <div class="tz-label">Módulos habilitados</div>
      <div class="tz-mods">
        <?php foreach($modulos as $m): ?>
          <div class="tz-mod" title="<?php echo htmlspecialchars($m['nombre'], ENT_QUOTES, 'UTF-8'); ?>">
            <div class="tz-chip" style="background:<?php echo $m['color']; ?>"><?php echo $m['cod']; ?></div>
            <div>
              <div class="tz-mname"><?php echo htmlspecialchars($m['nombre'], ENT_QUOTES, 'UTF-8'); ?></div>
              <div class="tz-mstate"><?php echo htmlspecialchars($m['estado'], ENT_QUOTES, 'UTF-8'); ?></div>
            </div>
          </div>
        <?php endforeach; ?>
      </div>
    </div>
  </div>

  <!-- ===== SECTOR B: KPIs (scaffolding Fase 1) ===== -->
  <div class="tz-section-title">Indicadores de tu operación</div>
  <div class="tz-kpis">
    <?php foreach($kpis as $k): $fuente = isset($k['fuente']) ? $k['fuente'] : 'tools'; ?>
      <div class="tz-kpi-col col-lg-<?php echo (int) $k['ancho']; ?> col-md-6 col-12">
        <div class="tz-card tz-kpi" data-kpi="<?php echo htmlspecialchars($k['kpi_nombre'], ENT_QUOTES, 'UTF-8'); ?>"
             data-fuente="<?php echo htmlspecialchars($fuente, ENT_QUOTES, 'UTF-8'); ?>"
             data-refresh="<?php echo (int) $k['refresh_seg']; ?>"
             data-chart="<?php echo htmlspecialchars($k['chart'], ENT_QUOTES, 'UTF-8'); ?>"
             data-color="<?php echo htmlspecialchars($k['color'], ENT_QUOTES, 'UTF-8'); ?>">
          <div class="tz-kpi-head">
            <div class="tz-kpi-accent" style="background:<?php echo $k['color']; ?>"></div>
            <div class="tz-kpi-title"><?php echo htmlspecialchars($k['titulo'], ENT_QUOTES, 'UTF-8'); ?></div>
            <div class="tz-kpi-tag" style="background:<?php echo $k['color']; ?>"><?php echo htmlspecialchars($k['modulo'], ENT_QUOTES, 'UTF-8'); ?></div>
          </div>
          <div class="tz-kpi-body" style="height:<?php echo (int) $k['alto']; ?>px;">
            <?php if($fuente === 'tools'): ?>
              <canvas></canvas>
            <?php else: ?>
              <div class="tz-kpi-na">
                <b>Disponible próximamente</b>
                <span>Este indicador lee de la caché de AssetPlanner (Mantenimiento).</span>
              </div>
            <?php endif; ?>
          </div>
          <?php if($fuente === 'tools'): ?>
          <div class="tz-kpi-foot">
            <span class="tz-foot-info">&mdash;</span>
            <span>
              <span class="tz-kpi-updated"></span>
              <a class="tz-kpi-drill">Ver detalle &rarr;</a>
            </span>
          </div>
          <div class="tz-kpi-detail" hidden></div>
          <?php endif; ?>
        </div>
      </div>
    <?php endforeach; ?>
  </div>

</div>

<script>
(function(){
  var base = '<?php echo base_url(); ?>';
  function go(){ if(window.TZDash){ TZDash.init(base); } }
  if(window.TZDash){ go(); }
  else{ $.getScript(base + 'lib/props/dashboard_kpis.js').done(go); }
})();
</script>
