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
| [REQ-001](REQ-001-administracion-analisis.md) | Módulo Administración — análisis inicial: qué se reutiliza de DNATO, impacto en el agente (MCP) y en Tools, cómo se arma el módulo. Sin código | Replanteo de Rodolfo sobre la especificación DNATO v3 0.5.2 | Listo para Pablo |
| [REQ-002](REQ-002-administracion-esqueleto.md) | Módulo Administración — esqueleto con seguridad incluida: módulo montado en Tools, Portal y Consola vacíos, control de sesión y permisos solo dentro del módulo, protección de envíos. Casos ADM-UC-001 a 003 | Análisis de REQ-001 (#607) | Listo para Pablo al unirse a `develop` (casos validados el 2026-11-10); falta crear el repositorio `traz-comp-adm` |
| [REQ-003](REQ-003-administracion-identidad.md) | Módulo Administración — Registración e ingreso copiados tal cual, en paralelo con DNATO. Casos ADM-UC-010 a 029 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-004](REQ-004-administracion-base-y-atributos.md) | Módulo Administración — Lo que faltó de la base (superusuario, administrador único, botón "Mi empresa" en Tools) y atributos y entidades nuevas. Entrega E0 y E1 de la especificación. Casos ADM-UC-030 a 049 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-005](REQ-005-administracion-catalogo-y-planes.md) | Módulo Administración — Catálogo y planes en la Consola. Entrega E2 de la especificación. Casos ADM-UC-050 a 069 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-006](REQ-006-administracion-funcionalidades.md) | Módulo Administración — Funcionalidades activas de la empresa. Entrega E3 de la especificación. Casos ADM-UC-070 a 089 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-007](REQ-007-administracion-usuarios-roles-perfil.md) | Módulo Administración — Usuarios, roles y perfil en el Portal. Entrega E4 de la especificación. Casos ADM-UC-090 a 109 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-008](REQ-008-administracion-consola-empresas.md) | Módulo Administración — Empresas, registros y usuarios en la Consola. Entrega E5 de la especificación. Casos ADM-UC-110 a 129 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-009](REQ-009-administracion-menus.md) | Módulo Administración — Menús por rol o por persona. Entrega E6 de la especificación. Casos ADM-UC-130 a 149 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-010](REQ-010-administracion-plan-y-pedidos.md) | Módulo Administración — Plan y pedidos, y "Elegí tu plan" en el registro. Entrega E7 de la especificación. Casos ADM-UC-150 a 169 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-011](REQ-011-administracion-cuota-agente.md) | Módulo Administración — Cuota del agente de IA (el freno en WSO2 va aparte). Entrega E8 de la especificación. Casos ADM-UC-170 a 189 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-012](REQ-012-administracion-visibilidad.md) | Módulo Administración — Funcionalidades de otro plan: vista de presentación y "Me interesa". Entrega E9 de la especificación. Casos ADM-UC-190 a 209 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-013](REQ-013-administracion-actividad-y-auditoria.md) | Módulo Administración — Actividad, auditoría e inicio del Portal. Entrega E10 de la especificación. Casos ADM-UC-210 a 229 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-014](REQ-014-administracion-cargas-masivas.md) | Módulo Administración — Cargas masivas. Entrega E11 de la especificación. Casos ADM-UC-230 a 249 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-015](REQ-015-administracion-formularios.md) | Módulo Administración — Formularios de la empresa (los cambios a `traz-comp-formularios` van aparte). Entrega E11b de la especificación. Casos ADM-UC-250 a 269 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-016](REQ-016-administracion-migracion-completa.md) | Módulo Administración — Migración completa. Entrega E12 de la especificación. Casos ADM-UC-270 a 289 | Especificación DNATO v3 y análisis de REQ-001 | Borrador, escrito por adelantado |
| [REQ-017](REQ-017-administracion-formularios-globales.md) | Formularios globales en Tools: los combos de tareas muestran los globales, el alta de empresa apunta a los globales en vez de copiarlos, y se pasan a globales solo los formularios que usa el alta. Casos ADM-UC-290 a 309 | Decisión de Rodolfo del 2026-11-10 sobre REQ-015 | Borrador, escrito por adelantado |
| REQ-018 | Corte final: redirigir DNATO al módulo y apagarlo. Necesita reunión de arquitectura, porque el token del agente lo emite DNATO | Propuesta de REQ-016 | Sin escribir |

## Módulo Administración (DNATO v3): de la especificación a los requerimientos

La especificación DNATO v3 (`doc/v3/dnato/`) proponía construir sobre el DNATO actual. Rodolfo la
replanteó (2026-11-03): se arma un **módulo nuevo dentro de Tools**, `traz-comp-adm`, que usa las mismas tablas (más lo
que haga falta agregar), copia la registración y el ingreso tal cual, tiene pantallas hechas de cero con datos por
DataServices, y deja a DNATO funcionando en paralelo y para lo que necesita el agente. Las cuatro reglas
completas están en [REQ-001](REQ-001-administracion-analisis.md).

De la especificación se usa el **qué** (requisitos, casos de prueba, maquetas, reglas de negocio); el
**cómo** sale del análisis de REQ-001. Cada requerimiento se escribe **cuando le toca**, con lo
aprendido en el anterior. Orden propuesto (los números se confirman al escribirlos):

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
