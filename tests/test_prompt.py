"""El system prompt: que se limpie bien y que los pendientes queden visibles."""
from __future__ import annotations

from pathlib import Path

from agente.prompt import cargar, limpiar, pendientes

RAIZ = Path(__file__).resolve().parent.parent
PROMPT = RAIZ / "prompts" / "quirqui.md"


def test_el_prompt_existe():
    assert PROMPT.exists(), "Falta prompts/quirqui.md"


def test_los_comentarios_no_le_llegan_al_modelo():
    """Los comentarios HTML explican cosas a quien edita, no al agente.

    Si se filtraran, el modelo leeria instrucciones como "reemplazalo" y
    "POR QUE NO LO DECIDO YO", que no tienen nada que ver con su tarea.
    """
    limpio = cargar(PROMPT)
    assert "<!--" not in limpio
    assert "-->" not in limpio
    assert "QUE ESTAS DECIDIENDO" not in limpio
    assert "EJEMPLO (reemplazalo)" not in limpio


def test_el_contenido_real_sobrevive_a_la_limpieza():
    limpio = cargar(PROMPT)
    assert "Quirqui" in limpio
    assert "Cuando no sabés" in limpio
    assert "Seguridad" in limpio
    # La regla que ordena las tres fuentes es el corazon del prompt.
    assert "Conocimiento" in limpio and "Memoria" in limpio


def test_quirqui_y_kuntur_ya_no_tienen_bloques_sin_definir():
    """Los bloques A-F se completaron el 2026-11-22 (pendientes de revisión del PM)."""
    assert pendientes(cargar(PROMPT)) == []
    assert pendientes(cargar(PROMPT.parent / "kuntur.md")) == []


def test_un_prompt_completo_no_reporta_pendientes():
    """El dia que se completen, la lista tiene que quedar vacia."""
    completo = limpiar("""
    # Prompt
    Sos un asistente. Hablá de vos. No inventes datos.
    """)
    assert pendientes(completo) == []


def test_se_relee_cuando_cambia_el_archivo(tmp_path):
    p = tmp_path / "prompt.md"
    p.write_text("version uno", encoding="utf-8")
    assert cargar(p) == "version uno"

    import os
    import time
    time.sleep(0.01)
    p.write_text("version dos", encoding="utf-8")
    os.utime(p, None)
    assert cargar(p) == "version dos", "El prompt tiene que recargarse sin reiniciar"


# ------------------------------------------- Gate 2 (AGENTE-M-07), textos del PM
import re  # noqa: E402

import pytest  # noqa: E402

# Frases de cada bloque del PM (2026-11-24) que tienen que llegarle al modelo tal cual.
TEXTOS_PM = {
    "quirqui.md": ["sos Quirqui, el asistente del sistema para mantenimiento y almacenes",
                   "Las advertencias de seguridad no se recortan por brevedad",
                   "Hablá en el español del país del usuario"],
    "kuntur.md": ["sos Kuntur, el coach del sistema para quien administra la empresa",
                  "Cerrá con un plan de no más de tres pasos",
                  "Si te preguntan cómo se usa una pantalla o cómo se hace una tarea, decí que eso lo responde Quirqui"],
    "faustino.md": ["sos Faustino, el entrevistador del sistema",
                    "No imites ni cites a ninguna persona real",
                    "marcalo para que una persona lo revise"],
}


@pytest.mark.parametrize("archivo", sorted(TEXTOS_PM))
def test_los_textos_del_pm_le_llegan_al_modelo(archivo):
    texto = cargar(RAIZ / "prompts" / archivo)
    for frase in TEXTOS_PM[archivo]:
        assert frase in texto, f"{archivo}: falta «{frase}»"


@pytest.mark.parametrize("archivo", sorted(TEXTOS_PM))
def test_los_agentes_no_nombran_la_marca(archivo):
    """Bloque (A) de los tres: «Nunca nombres la marca del sistema»."""
    assert not re.search(r"trazalog", cargar(RAIZ / "prompts" / archivo), re.I)
    # El voseo solo aparece en la regla del país (bloque D y su respaldo), no fijo.
    texto = (cargar(RAIZ / "prompts" / archivo).replace("de vos donde se habla de vos", "")
             .replace("hablá de vos: hoy quienes usan el sistema son de Argentina", ""))
    assert "de vos" not in texto
