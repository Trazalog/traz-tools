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
| [REQ-001](REQ-001-administracion-analisis.md) | Módulo Administración — análisis inicial: qué se reutiliza de DNATO, impacto en el agente (MCP) y en Tools, cómo se arma el módulo. Sin código | Replanteo de Rodolfo sobre la especificación DNATO v3 0.5.2 | Borrador |

## Módulo Administración (DNATO v3): de la especificación a los requerimientos

La especificación DNATO v3 (`doc/v3/dnato/`) proponía construir sobre el DNATO actual. Rodolfo la
replanteó (2026-11-03): se arma un **módulo nuevo dentro de Tools** que usa las mismas tablas (más lo
que haga falta agregar), copia la registración tal cual, tiene pantallas hechas de cero con datos por
DataServices, y deja a DNATO, si conviene, solo para lo que necesita el agente. Las cuatro reglas
completas están en [REQ-001](REQ-001-administracion-analisis.md).

De la especificación se usa el **qué** (requisitos, casos de prueba, maquetas, reglas de negocio); el
**cómo** sale del análisis de REQ-001. Cada requerimiento se escribe **cuando le toca**, con lo
aprendido en el anterior. Orden propuesto (los números se confirman al escribirlos):

| REQ | Qué | Bloqueado por |
|---|---|---|
| REQ-001 | Análisis inicial | Dudas de Rodolfo |
| REQ-002 | Esqueleto del módulo: dentro de Tools, con sesión, permiso por pantalla, protección contra envíos falsificados y empresa tomada de la sesión desde el primer día | REQ-001 aprobado |
| REQ-003 | Registración copiada tal cual; las pruebas DNATO-UC-001 a 005 pasan contra la copia | REQ-002 |
| REQ-004 en adelante | Pantallas nuevas, siguiendo las entregas E1 a E12 de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md` (planes, usuarios y roles, menús, cuota del agente, cargas masivas, formularios) | REQ-002 y el orden que proponga REQ-001 |

Fuera de esta lista, y no asignado a Pablo: lo de identidad que necesita reunión de arquitectura
(cambio de empresa en Tools C-1, dirección de retorno de OAuth C-3, definición única de administrador
C-5) y los secretos del repositorio de DNATO (C-7, infraestructura).

Los casos DNATO-UC-001 a 028 del catálogo describen **cómo funciona DNATO hoy** (se relevaron en
agosto de 2026 para las pruebas de regresión de producción). No son el diseño del módulo nuevo.
