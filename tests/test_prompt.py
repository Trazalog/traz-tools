"""El system prompt: que se limpie bien y que los pendientes queden visibles."""
from __future__ import annotations

from pathlib import Path

from agente.prompt import cargar, limpiar, pendientes

RAIZ = Path(__file__).resolve().parent.parent
PROMPT = RAIZ / "prompts" / "agente-minero.md"


def test_el_prompt_existe():
    assert PROMPT.exists(), "Falta prompts/agente-minero.md"


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
    assert "Agente Minero" in limpio
    assert "Cuando no sabés" in limpio
    assert "Seguridad" in limpio
    # La regla que ordena las tres fuentes es el corazon del prompt.
    assert "Conocimiento" in limpio and "Memoria" in limpio


def test_se_detectan_los_bloques_sin_definir():
    """Mientras el PM no los complete, tienen que ser detectables.

    Es lo que hace que /salud avise en vez de que alguien salga a produccion
    con los textos de ejemplo puestos.
    """
    sin_definir = pendientes(cargar(PROMPT))
    letras = {p.split(")")[0].lstrip("(") for p in sin_definir}
    assert letras == {"A", "B", "C", "D", "E", "F"}, (
        f"Se esperaban los seis bloques A-F; se encontraron: {sin_definir}"
    )


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
