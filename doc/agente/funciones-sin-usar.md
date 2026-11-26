# Kuntur recomienda funciones de Tools que la empresa no usa

## Objetivo

Qué es: cómo decide Kuntur qué partes de Tools recomendarle al administrador porque su empresa no las usa (tarea AGENTE-CO-08), y cómo se cambia. Para quién: el PM y quien mantenga el motor de los agentes. Cuándo leerlo: antes de sumar una función al catálogo o de cambiar los valores por defecto. Qué NO cubre: el siguiente paso que propone Quirqui en cada pantalla ([`agente/sugerencias.py`](../../agente/sugerencias.py)) ni las metas de Kuntur ([`analisis-impacto-kpi-objetivos.md`](../historial/agente/analisis-impacto-kpi-objetivos.md)).

## Cómo funciona

- Cuando el administrador abre la pestaña de Kuntur en el panel, el panel pide `GET /kuntur/funciones` al motor (a través de `Agente/kuntur_funciones`). Solo responde a administradores (R1); para cualquier otro, Kuntur no existe.
- El motor consulta las tools de lectura con **el token del administrador** y aplica **reglas**, no el modelo: no gasta tokens y cada cifra sale de contar lo que devolvió una tool (R4).
- Muestra hasta 3, la más importante primero, cada una con la evidencia ("Tenés 12 equipos cargados y ningún plan preventivo"), por qué conviene, cómo hacerlo y el enlace a la ayuda.
- **Ver cómo** registra que le interesó. **No me interesa** la esconde para **toda la empresa** durante 30 días.
- La corrida queda registrada como de Kuntur (R8), con disparador `apertura_pantalla`.

## El catálogo (`agente/funciones.py`)

| Orden | Función | Se recomienda cuando | Tools |
|---|---|---|---|
| 1 | Metas | La empresa no tiene ninguna meta | `kpi_get_objetivos` |
| 2 | Preventivo | Hay equipos y ningún plan preventivo | `man_get_equipos`, `man_get_preventivos` |
| 3 | Punto de pedido | Hay artículos y ninguno tiene punto de pedido | `alm_get_stock` |
| 4 | Certificaciones | Hay herramientas y ninguna certificación | `pan_get_herramientas`, `pan_get_certificaciones` |
| 5 | Movimientos de stock | Hay artículos y no aparece ningún movimiento | `alm_get_stock`, `alm_get_movimientos` |
| 6 | Depósitos | No hay ningún depósito | `alm_get_depositos` |
| 7 | Pañol | No hay ninguna herramienta | `pan_get_herramientas` |

Reglas de prudencia:
- **Si una tool falla, no se recomienda** lo que dependía de ella: "no pude leer" no es "no lo usás".
- Si la empresa ya declaró en la entrevista de Kuntur qué módulos usa, **solo se recomienda dentro de esos módulos**. Las metas se recomiendan siempre.
- Las tools de movimientos pueden traer solo un período reciente; por eso el texto dice "no aparece ningún movimiento", no "nunca hubo".

## Cómo se cambia

- **Valores por defecto** (variables del motor, en el `.env` del orquestador): `AGENTE_FUNCIONES_MAX` (3) y `AGENTE_FUNCIONES_SILENCIO_DIAS` (30). Los propuso Claude Code; el PM no los fijó.
- **Sumar una función**: una regla y una fila en `CATALOGO` de `agente/funciones.py`, con su test en `tests/test_funciones.py`. Solo con tools de lectura que ya estén en la lista blanca de Kuntur.
- **Base**: `db/agente/030-funciones-sin-usar.sql` habilita el tipo `funcion_sin_usar` en `agente.propuesta` (se reutiliza la tabla del siguiente paso de Quirqui).
