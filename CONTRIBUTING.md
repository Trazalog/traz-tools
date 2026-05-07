# Contributing to Trazalog Tools

## Flujo de trabajo general

Las contribuciones se hacen via Pull Request. Antes de abrir un PR:
- Asegurate de que tu branch esté actualizado con la rama base correspondiente.
- Verificá que los criterios de aceptación del issue estén cumplidos.
- Usá el template de PR provisto en `.github/pull_request_template.md`.

---

## Trabajo en v3

Trazalog Tools está en desarrollo activo de su versión 3 (capa MCP + migración de stack).
**Las dos líneas de desarrollo conviven en el mismo repo con ramas separadas.**

| Tipo de cambio | Rama base del PR |
|---|---|
| Feature o mejora de v3 | `develop-v3` |
| Fix o soporte de v2 | `develop` |
| Hotfix de producción | `master` |

### Reglas de branching para v3

- Partí siempre de `develop-v3` para crear tu feature branch: `git checkout -b feature/<id> origin/develop-v3`
- Nombrá el branch con el ID del task: `feature/e7-mcp-01`, `fix/v3-alm-sync`, etc.
- Nunca hagas merge manual de `develop` a `develop-v3` — eso lo hace el proceso E7-CICD-06 semanalmente.
- Nunca hagas merge de `develop-v3` a `develop` antes del cutover final.

### Sincronización v2 → v3

La rama `develop` se sincroniza a `develop-v3` semanalmente (proceso E7-CICD-06).
Esto propaga fixes de v2 al codebase de v3. Ver `doc/v3/TRAZALOG_v3_CICD_STRATEGY.md` sección 2 para detalles.

---

## Convenciones de código

- **PHP**: PSR-12. Sin direct DB queries desde PHP — toda la capa de datos va por WSO2 MI.
- **APIs**: URLs en kebab-case, JSON keys en snake_case.
- **Base de datos**: nombres de tablas y columnas en snake_case.
- **Logging**: `log_message('DEBUG', '#TRAZA | <MODULO> | <Clase> | <metodo>() ...')`.
- Ver `CLAUDE.md` para el stack completo y convenciones detalladas.

---

## Proceso de revisión

1. Abrí el PR con el template completo.
2. Al menos un revisor debe aprobar antes del merge.
3. CI debe pasar (cuando esté configurado).
4. El merge lo hace el revisor o el autor si tiene permisos y el revisor lo aprobó.
