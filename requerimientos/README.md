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
| Borrador | Escrito por adelantado, o con dudas por contestar o casos por validar. Pablo no arranca: lo puede leer, no planificar ni programar |
| Listo para Pablo | Casos validados y unidos a `develop`. Pablo puede armar el plan |
| En construcción | Plan aprobado; Pablo programando |
| Hecho | Desplegado en DEMO y verificado con DocTest |

## Lista

| REQ | Qué | Origen | Estado |
|---|---|---|---|
| [REQ-001](REQ-001-administracion-analisis.md) | Módulo Administración — análisis inicial: qué se reutiliza de DNATO, impacto en el agente (MCP) y en Tools, cómo se arma el módulo. Sin código | Replanteo de Rodolfo sobre la especificación DNATO v3 0.5.2 | Hecho: análisis unido a `develop` el 2026-11-05 (#607) |

## Módulo Administración (DNATO v3): de la especificación a los requerimientos

La especificación DNATO v3 (`doc/v3/dnato/`) proponía construir sobre el DNATO actual. Rodolfo la
replanteó (2026-11-03): se arma un **módulo nuevo dentro de Tools**, `traz-comp-adm`, que usa las mismas tablas (más lo
que haga falta agregar), copia la registración y el ingreso tal cual, tiene pantallas hechas de cero con datos por
DataServices, y deja a DNATO funcionando en paralelo y para lo que necesita el agente. Las cuatro reglas
completas están en [REQ-001](REQ-001-administracion-analisis.md).

De la especificación se usa el **qué** (requisitos, casos de prueba, maquetas, reglas de negocio); el
**cómo** sale del análisis de REQ-001. Los requerimientos se pueden escribir por adelantado, en
Borrador, pero a Pablo se le pasan de a uno y cada uno se revisa con lo aprendido en el anterior
(guía, sección 2.3). Orden propuesto (los números se confirman al escribirlos):

| REQ | Qué | Bloqueado por |
|---|---|---|
| REQ-001 | Análisis inicial | — |
| REQ-002 | Esqueleto del módulo `traz-comp-adm` (Rodolfo crea antes el repositorio): dentro de Tools, con sesión, permiso por pantalla, protección contra envíos falsificados y empresa tomada de la sesión desde el primer día | REQ-001 aprobado |
| REQ-003 | Registración e ingreso copiados tal cual, en paralelo con DNATO; las pruebas DNATO-UC-001 a 008 pasan contra la copia | REQ-002 |
| REQ-004 en adelante | Pantallas nuevas, siguiendo las entregas E1 a E12 de `doc/v3/dnato/PROMPT_CLI_DNATO_V3_BUILD.md` (planes, usuarios y roles, menús, cuota del agente, cargas masivas, formularios) | REQ-002 y el orden que proponga REQ-001 |

**Objetivo futuro**, sin fecha: cuando el módulo ande bien, redirigir las direcciones de DNATO al
módulo, migrar también la identidad del agente y **apagar DNATO**.

Fuera de esta lista, y no asignado a Pablo: lo de identidad que necesita reunión de arquitectura
(cambio de empresa en Tools C-1, dirección de retorno de OAuth C-3, definición única de administrador
C-5) y los secretos del repositorio de DNATO (C-7, infraestructura).

Los casos DNATO-UC-001 a 028 del catálogo describen **cómo funciona DNATO hoy** (se relevaron en
agosto de 2026 para las pruebas de regresión de producción). No son el diseño del módulo nuevo.
