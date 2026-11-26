"""La carga de conocimiento aguanta que el servicio rechace un lote entero.

Pasó al preparar la prueba manual (2026-11-26): el modelo gratuito de
vectores respondió 422 a un lote de 32 fragmentos de la ayuda de Almacenes,
y cada fragmento por separado entraba bien.
"""
from __future__ import annotations

import pytest

from agente.ingesta import _embeber
from agente.llm import LLMError


class LLMQueRechazaLotes:
    def __init__(self, max_lote: int, fallan: set[str] = frozenset()):
        self.max_lote, self.fallan, self.llamadas = max_lote, fallan, []

    async def embeddings(self, textos):
        self.llamadas.append(len(textos))
        if len(textos) > self.max_lote or self.fallan & set(textos):
            raise LLMError("OpenRouter respondio 422", 422, {})
        return [[float(len(t))] for t in textos]


async def test_un_lote_rechazado_se_parte_y_entra_entero_y_en_orden():
    llm = LLMQueRechazaLotes(max_lote=5)
    textos = [f"t{i}" * (i + 1) for i in range(12)]
    vectores = await _embeber(llm, textos)
    assert vectores == [[float(len(t))] for t in textos]


async def test_un_fragmento_que_siempre_falla_se_saltea_despues_de_reintentar():
    """El 422 fue «content safety screening» sobre una tabla de variables de
    remitos: un falso positivo del servicio que no tiene que frenar la carga."""
    llm = LLMQueRechazaLotes(max_lote=32, fallan={"malo"})
    assert await _embeber(llm, ["bueno", "malo"]) == [[5.0], None]
    assert llm.llamadas == [2, 1, 1, 1]


async def test_la_carga_saltea_el_fragmento_rechazado_y_avisa(capsys):
    from agente.fuentes import Pieza
    from agente.ingesta import _vectores
    llm = LLMQueRechazaLotes(max_lote=32, fallan={"malo"})
    piezas = [Pieza(texto=t, modulo="general", metadata={}) for t in ("uno", "malo", "dos")]
    lotes = [x async for x in _vectores(llm, piezas)]
    assert [[p.texto for p in lote] for lote, _ in lotes] == [["uno", "dos"]]
    assert "se saltea" in capsys.readouterr().err


async def test_una_clave_invalida_no_se_reintenta():
    class SinClave:
        llamadas = 0

        async def embeddings(self, textos):
            SinClave.llamadas += 1
            raise LLMError("OpenRouter respondio 401", 401, {})

    with pytest.raises(LLMError):
        await _embeber(SinClave(), ["a", "b", "c"])
    assert SinClave.llamadas == 1


async def test_si_el_servicio_pide_esperar_espera_y_sigue(monkeypatch):
    import agente.ingesta as ing
    esperas = []

    async def dormir(seg):
        esperas.append(seg)
    monkeypatch.setattr(ing.asyncio, "sleep", dormir)

    class Apurado:
        veces = 0

        async def embeddings(self, textos):
            Apurado.veces += 1
            if Apurado.veces < 3:
                raise LLMError("OpenRouter respondio 429", 429, {})
            return [[1.0] for _ in textos]

    assert await _embeber(Apurado(), ["a", "b"]) == [[1.0], [1.0]]
    assert esperas == [30, 60]
