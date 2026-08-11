#!/usr/bin/env bash
# ============================================================================
# manual-a-pdf.sh — convierte un manual .md a PDF listo para compartir.
#
# Usa pandoc (md -> html) + Google Chrome headless (html -> pdf). Chrome
# ejecuta JavaScript, asi que los diagramas Mermaid se renderizan como
# corresponde; pandoc solo no puede hacerlo.
#
# USO (en la maquina local, dentro del repo):
#     bash scripts/dev/manual-a-pdf.sh
#     bash scripts/dev/manual-a-pdf.sh doc/manuales/otro-doc.md
#
# El PDF queda junto al .md, con el mismo nombre.
# ============================================================================

set -euo pipefail

MD="${1:-doc/manuales/conectar-claude-a-trazalog.md}"
[ -f "$MD" ] || { echo "ERROR: no existe $MD"; exit 1; }

DIR="$(cd "$(dirname "$MD")" && pwd)"
BASE="$(basename "${MD%.md}")"
HTML="$DIR/$BASE.html"
PDF="$DIR/$BASE.pdf"

command -v pandoc >/dev/null || { echo "ERROR: falta pandoc"; exit 1; }
CHROME="$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)"
[ -n "$CHROME" ] || { echo "ERROR: falta Chrome/Chromium"; exit 1; }

# --- avisar si faltan las capturas referenciadas ---------------------------
FALTAN=0
while read -r img; do
  [ -z "$img" ] && continue
  [ -f "$DIR/$img" ] || { echo "  AVISO: falta la imagen $img"; FALTAN=$((FALTAN+1)); }
done < <(grep -oE '\]\(([^)]*\.(png|jpg|jpeg|svg))\)' "$MD" | sed -E 's/^\]\((.*)\)$/\1/')
[ "$FALTAN" -gt 0 ] && echo "  -> el PDF se genera igual, pero esas imagenes van a salir en blanco."

# --- md -> html ------------------------------------------------------------
# Los bloques ```mermaid se convierten a <pre class="mermaid"> para que los
# tome mermaid.js en el navegador.
pandoc "$MD" -f gfm -t html5 --standalone --metadata title="$BASE" -o "$HTML.tmp"

python3 - "$HTML.tmp" "$HTML" <<'PYEOF'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
h = open(src, encoding='utf-8').read()
h = re.sub(r'<pre class="mermaid"><code>(.*?)</code></pre>',
           lambda m: '<pre class="mermaid">' + m.group(1)
                       .replace('&quot;','"').replace('&lt;','<')
                       .replace('&gt;','>').replace('&amp;','&') + '</pre>',
           h, flags=re.S)
h = re.sub(r'<div class="sourceCode"[^>]*id="cb\d+"[^>]*data-org="mermaid".*?</div>', '', h, flags=re.S)

estilo = """
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script>mermaid.initialize({startOnLoad:true, theme:'neutral',
  flowchart:{useMaxWidth:true, htmlLabels:true}});</script>
<style>
  @page { size: A4; margin: 18mm 16mm; }
  body { font-family: -apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
         font-size: 11pt; line-height: 1.55; color: #1a1a1a; max-width: 100%; margin: 0; }
  h1 { font-size: 22pt; border-bottom: 3px solid #2563eb; padding-bottom: .3em; color:#1e3a8a; }
  h2 { font-size: 15pt; margin-top: 1.6em; color:#1e3a8a; page-break-after: avoid; }
  h3 { font-size: 12.5pt; margin-top: 1.2em; page-break-after: avoid; }
  table { border-collapse: collapse; width: 100%; margin: 1em 0; font-size: 10pt;
          page-break-inside: avoid; }
  th, td { border: 1px solid #cbd5e1; padding: .5em .7em; text-align: left; vertical-align: top; }
  th { background: #eff6ff; font-weight: 600; }
  code { background: #f1f5f9; padding: .12em .4em; border-radius: 3px;
         font-size: .9em; word-break: break-all; }
  pre code { display:block; padding:.8em; }
  blockquote { border-left: 4px solid #2563eb; background: #eff6ff; margin: 1em 0;
               padding: .7em 1em; page-break-inside: avoid; }
  blockquote p { margin: .3em 0; }
  img { max-width: 100%; height: auto; border: 1px solid #cbd5e1; border-radius: 6px;
        margin: 1em 0; page-break-inside: avoid; display:block; }
  .mermaid { text-align: center; margin: 1.4em 0; page-break-inside: avoid; }
  hr { border: none; border-top: 1px solid #e2e8f0; margin: 1.8em 0; }
  ul, ol { padding-left: 1.4em; }
  li { margin: .25em 0; }
  h2, h3, table, blockquote, img { break-inside: avoid; }
</style>
"""
h = h.replace('</head>', estilo + '</head>')
open(dst, 'w', encoding='utf-8').write(h)
PYEOF
rm -f "$HTML.tmp"

# --- html -> pdf -----------------------------------------------------------
# --virtual-time-budget le da tiempo a mermaid.js a dibujar los diagramas.
"$CHROME" --headless --disable-gpu --no-sandbox \
  --run-all-compositor-stages-before-draw \
  --virtual-time-budget=12000 \
  --print-to-pdf="$PDF" --no-pdf-header-footer \
  "file://$HTML" >/dev/null 2>&1

if [ -f "$PDF" ]; then
  echo "PDF generado: $PDF  ($(du -h "$PDF" | cut -f1))"
  echo "HTML intermedio: $HTML  (se puede borrar)"
else
  echo "ERROR: no se genero el PDF. Probar abriendo $HTML en el navegador e imprimir a PDF."
  exit 1
fi
