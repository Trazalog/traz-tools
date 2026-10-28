"""Componente de avatar de los agentes (AGENTE-ID-05).

El componente es JavaScript dentro de una vista PHP. Se renderiza con un
arnes (sin CodeIgniter) y se ejecuta en Node. Se saltea si no hay php o node.
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parent.parent
ARNES = RAIZ / "tests" / "agente" / "render_vista.php"

pytestmark = pytest.mark.skipif(not (shutil.which("php") and shutil.which("node")),
                                reason="Hace falta php y node")


def _renderizar(vista: str, tmp_path: Path) -> list[Path]:
    prefijo = str(tmp_path / vista) + "_"
    n = int(subprocess.run(["php", str(ARNES), str(RAIZ), vista, prefijo],
                           capture_output=True, text=True, check=True).stdout)
    return [Path(f"{prefijo}{i}.js") for i in range(n)]


def _node(js: str) -> subprocess.CompletedProcess:
    return subprocess.run(["node", "-e", js], capture_output=True, text=True)


def test_los_scripts_del_panel_son_javascript_valido(tmp_path):
    scripts = _renderizar("panel", tmp_path)
    assert len(scripts) == 2, "avatar (global) + panel"
    for s in scripts:
        r = subprocess.run(["node", "--check", str(s)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr


def test_el_componente_se_define_una_sola_vez(tmp_path):
    avatar = _renderizar("avatar", tmp_path)[0]
    r = _node(f"""
      global.window = {{}}; const vm = require('vm'), fs = require('fs');
      const src = fs.readFileSync({str(avatar)!r}, 'utf8');
      vm.runInThisContext(src); const primero = window.TZAgente;
      vm.runInThisContext(src);
      process.exit(window.TZAgente === primero ? 0 : 1);""")
    assert r.returncode == 0, "Incluirlo dos veces no puede pisar el componente"


def test_el_avatar_pinta_estado_imagen_e_inicial(tmp_path):
    avatar = _renderizar("avatar", tmp_path)[0]
    r = _node(f"""
      global.window = {{}}; require('vm').runInThisContext(require('fs').readFileSync({str(avatar)!r}, 'utf8'));
      const T = window.TZAgente, a = require('assert');
      const h = T.avatar({{clave:'quirqui', nombre:'Quirqui', avatar:'quirqui'}}, 'pensando', true);
      a(h.includes('data-estado="pensando"') && h.includes('tzag-grande'));
      a(h.includes('/quirqui/pensando.webp') && h.includes('>Q<'));
      a(T.avatar({{avatar:'quirqui'}}, 'inventado').includes('data-estado="saludo"'));
      a.deepStrictEqual(T.ESTADOS, ['saludo','escuchando','pensando','hablando','alerta','despedida']);""")
    assert r.returncode == 0, r.stderr


def test_una_clave_o_un_nombre_maliciosos_no_llegan_al_html(tmp_path):
    """La clave termina en una URL y en un atributo; el nombre, en el HTML."""
    avatar = _renderizar("avatar", tmp_path)[0]
    r = _node(f"""
      global.window = {{}}; require('vm').runInThisContext(require('fs').readFileSync({str(avatar)!r}, 'utf8'));
      const mal = window.TZAgente.avatar({{avatar:'../../x"><script>', nombre:'<b>Hack</b>'}}, 'saludo');
      const a = require('assert');
      a(!mal.includes('<script>') && !mal.includes('<b>') && !mal.includes('..'));""")
    assert r.returncode == 0, r.stderr


def test_el_panel_no_tiene_el_nombre_fijo_en_los_textos_dinamicos(tmp_path):
    """El nombre sale de la configuracion de los agentes: las respuestas y el
    boton no pueden decir 'Quirqui' escrito a mano."""
    js = _renderizar("panel", tmp_path)[1].read_text(encoding="utf-8")
    assert "pintar('Quirqui'" not in js
    assert "agente.nombre" in js
