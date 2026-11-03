# Requerimientos

## Objetivo

Índice de los requerimientos que Rodolfo arma con Claude para que Pablo los construya con DeepSeek,
según [`doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md`](../doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md).
Se lee para saber qué requerimiento sigue y en qué estado está cada uno. **No** reemplaza a la
especificación de la que salen (está en `doc/v3/dnato/` para DNATO v3).

Cada requerimiento es un archivo `REQ-###-nombre-corto.md` en esta carpeta, más sus casos de uso en
`doctest/catalogo/<modulo>/`. Pablo deja su plan al lado, en `REQ-###-nombre-corto.plan.md`.

## Estados

| Estado | Qué significa |
|---|---|
| Borrador | Rodolfo todavía tiene dudas por contestar o casos por validar. Pablo no arranca |
| Listo para Pablo | Casos validados y unidos a `develop`. Pablo puede armar el plan |
| En construcción | Plan aprobado; Pablo programando |
| Hecho | Desplegado en DEMO y verificado con DocTest |

## Lista

| REQ | Qué | Origen | Estado |
|---|---|---|---|
| [REQ-001](REQ-001-dnato-e0-seguridad.md) | DNATO v3 — Base de seguridad (E0 recortado: correctivos C-2, C-4, C-6, C-8 + análisis de impacto en Tools) | Especificación DNATO v3 0.5.2 | Borrador |

## DNATO v3: de la especificación a los requerimientos

La especificación (`doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md`) divide la construcción en 13 entregas.
Cada entrega se convierte en uno o más requerimientos **cuando le toca**, no todas de una: así cada uno
se arma con lo que se aprendió en el anterior. Lo que sigue es la propuesta de orden; los números de
REQ se asignan al escribirlos.

| Entrega | Qué | Requerimiento | Bloqueada por |
|---|---|---|---|
| E0 (parte 1) | Seguridad: control central, CSRF, pertenencia, criterio membresía → empresa | REQ-001 | — |
| E0 (parte 2) | Layout del Portal y de la Consola, servicio "Contexto", capa de servicios, datos base de prueba | pendiente | REQ-001 |
| E0 (parte 3) | Definición única de administrador y súper usuario (C-5) | pendiente | Workshop 🔴 (ADR-016) |
| E1 | Atributos y entidades nuevas, auditoría, variables con historial, migraciones M-1, M-2, M-5 a M-7 | pendiente | E0; respuestas de `01` §10 |
| E2 a E12 | Catálogo y planes, funcionalidades, usuarios y roles, Consola, menús, plan y pedidos, cuota MCP, visibilidad, auditoría, cargas masivas, formularios, migración | pendiente | E1 |

Fuera de DNATO, y no asignado a Pablo todavía: los correctivos de identidad C-1 y C-3 (workshop 🔴),
los secretos del repo (C-7, infra) y las derivaciones en Tools que salgan del análisis de impacto
(tarea 0 de REQ-001).
