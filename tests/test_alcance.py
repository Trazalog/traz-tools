"""El agente cubre DOS areas: mantenimiento y almacenes.

Correccion de alcance del 2026-09-02. El prompt y las tools se habian escrito
pensando solo en mantenimiento, pero la capa MCP expone las dos: 11 tools man_*
y 9 alm_*. Estos tests evitan que el sesgo vuelva.

Panol y Tareas quedan para una version posterior; cuando existan sus tools, hay
que sumarlas aca.
"""
from __future__ import annotations

from pathlib import Path

import pytest

from agente.mcp_client import _RUTAS_DEV, _TOOLS_DEV
from agente.prompt import cargar

RAIZ = Path(__file__).resolve().parent.parent
PROMPT = RAIZ / "prompts" / "agente-minero.md"


def test_el_prompt_nombra_las_dos_areas():
    """Si el prompt solo habla de mantenimiento, el agente ignora almacenes."""
    p = cargar(PROMPT).lower()
    assert "mantenimiento" in p
    assert "almacenes" in p, "El prompt tiene que declarar Almacenes como area propia"
    # Los conceptos concretos de almacenes, no solo la palabra.
    for termino in ("stock", "dep", "vencimiento", "materiales"):
        assert termino in p, f"El prompt no menciona '{termino}', propio de almacenes"


def test_el_prompt_pide_cruzar_las_areas():
    """Lo mas valioso del agente esta en el cruce, no en cada area por separado.

    Una OT que no se puede ejecutar porque falta el repuesto es un problema de
    las dos a la vez.
    """
    p = cargar(PROMPT).lower()
    assert "cruz" in p, "El prompt tiene que decir explicitamente que cruce las areas"


def test_hay_tools_de_las_dos_areas():
    nombres = [t["function"]["name"] for t in _TOOLS_DEV]
    man = [n for n in nombres if n.startswith("man_")]
    alm = [n for n in nombres if n.startswith("alm_")]
    assert man, "Faltan tools de mantenimiento"
    assert alm, "Faltan tools de almacenes: el agente no podria responder sobre stock"


def test_las_tools_de_almacenes_cubren_lo_esencial():
    """Stock, vencimientos y pedidos son las tres que mas se van a usar."""
    nombres = {t["function"]["name"] for t in _TOOLS_DEV}
    for tool in ("alm_get_stock", "alm_get_vencimientos", "alm_get_pedidos_materiales"):
        assert tool in nombres, f"Falta {tool}"


def test_toda_tool_declarada_tiene_ruta():
    """Una tool sin ruta se declara al modelo y despues falla al llamarla."""
    for t in _TOOLS_DEV:
        nombre = t["function"]["name"]
        assert nombre in _RUTAS_DEV, f"{nombre} se declara pero no tiene ruta REST"


def test_toda_tool_tiene_descripcion_util():
    """La descripcion es lo unico que el modelo lee para decidir si la llama."""
    for t in _TOOLS_DEV:
        d = t["function"]["description"]
        assert len(d) > 30, f"{t['function']['name']} tiene una descripcion muy vaga: {d!r}"


@pytest.mark.parametrize("modulo", ["man", "alm", "general"])
def test_la_ingesta_acepta_los_tres_modulos(modulo):
    """Se puede ingestar conocimiento de cualquiera de las dos areas."""
    from agente.ingesta import main
    with pytest.raises(SystemExit) as e:
        main(["--modulo", modulo, "--dry-run"])
    # Falla por falta de archivos, no por el modulo: el argumento es valido.
    assert e.value.code == 2


def test_la_ingesta_rechaza_un_modulo_inventado():
    from agente.ingesta import main
    with pytest.raises(SystemExit):
        main(["archivo.md", "--modulo", "panol", "--dry-run"])
