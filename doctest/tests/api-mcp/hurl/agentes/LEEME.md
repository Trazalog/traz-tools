# Pruebas de la API de los agentes (Hurl) — tests/api-mcp/hurl/agentes/

## Objetivo

Explica cómo se corren las pruebas Hurl derivadas de los casos de uso de los agentes (`catalogo/age/AGE-UC-*.yaml`) contra el orquestador de los agentes. Está escrito para quien ejecuta las pruebas en su terminal. **No** cubre el diseño de los casos (vive en `catalogo/age/`), ni la suite del gateway MCP (los archivos de `tests/api-mcp/hurl/` fuera de esta carpeta), ni las pruebas de integración más amplias del orquestador (`tests/agente/orquestador.hurl`, desde la raíz del repositorio).

| Archivo | Casos | Qué verifica |
|---|---|---|
| `consulta.hurl` | AGE-UC-002, 005, 006 | Forma de la respuesta de una consulta, rechazo sin token o sin empresa, pregunta vacía |
| `feedback.hurl` | AGE-UC-007 | Calificar, cambiar de opinión con motivo y comentario, motivo inválido, aislamiento entre empresas |
| `kuntur_solo_admin.hurl` | AGE-UC-008 | Kuntur no existe para quien no es administrador (lista de agentes, consulta y configuración); sí para el administrador |
| `sugerencias.hurl` | AGE-UC-003 | Forma de las propuestas del siguiente paso y pantalla inválida rechazada |

## Requisitos

- Hurl instalado. **Dónde:** terminal local, parado en `doctest/`: `npm run hurl:install`.
- El orquestador de los agentes levantado. **Dónde:** terminal local, en la raíz del repositorio: `./agente/dev.sh` (ver `doc/agente/operacion.md`). Las consultas pueden fallar por falta de clave del modelo: las pruebas igual validan la forma de la respuesta.

## Correr

**Dónde:** terminal local, parado en `doctest/`. Copiar `tests/api-mcp/env/agentes-local.env.example` a `tests/api-mcp/env/agentes-local.env` (no se versiona) y ajustar si hace falta.

```bash
hurl --test --variables-file tests/api-mcp/env/agentes-local.env tests/api-mcp/hurl/agentes/*.hurl
```

Los tokens del ejemplo **no tienen firma válida**, a propósito: el orquestador no valida la firma (lo hace el gateway antes, ADR-009) y solo lee los datos del token. Por eso estas pruebas van **solo contra el orquestador local**, nunca contra un ambiente compartido ni contra producción.
