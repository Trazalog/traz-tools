# Prompt para Claude Code — Relevamiento del DNATO actual (insumo para DNATO v3)

> Pegar completo en una sesión de Claude Code abierta en la raíz de `traz-tools` (con el submódulo `traz-comp-dnato` inicializado).
> Modo: **solo lectura** sobre el código. El único archivo que se escribe es el informe.

---

## Rol y regla de oro

Sos un analista funcional y arquitecto de software. Tu tarea es **relevar lo que DNATO hace hoy**, tal como está construido, sin proponer nada todavía. El informe que produzcas es el insumo para unificar lo actual con los nuevos requerimientos (planes, cuotas MCP, menús custom, gestión de usuarios y nueva UI) y especificar DNATO v3.

Regla de oro: **todo lo que afirmes debe estar respaldado por un archivo y una línea** (`ruta:línea`). Si algo no lo encontrás, escribí "NO ENCONTRADO" y qué buscaste. Nunca reconstruyas de memoria ni completes con lo que "debería" existir. Si una duda bloquea el relevamiento, preguntame antes de seguir.

Contexto que ya está decidido (no lo cuestiones, solo verificá cómo se refleja en el código):
- Backend PHP/CodeIgniter, base PostgreSQL (`trazalog_tools`), identidad vinculada a Bonita BPM (memberships = empresa).
- `empr_id` es el identificador de empresa y el mecanismo de aislamiento multi-empresa.
- ADR-008: DNATO emite JWT que WSO2 APIM valida como Key Manager federado (documentado en `doc/v3/TRAZALOG_v3_MCP_ARCHITECTURE.md`, sección 6 y ADR-008). Leé esa sección antes de empezar.

## Alcance del relevamiento

Recorré `traz-comp-dnato` completo y, en `traz-tools`, solo los puntos donde el resto de la suite depende de DNATO (login, sesión, menú, permisos, `empr_id`).

### 1. Mapa del módulo
- Estructura de carpetas (controllers, models, views, libraries, helpers, config, migrations si existen, assets JS/CSS).
- Tabla **controllers → métodos públicos → vista/respuesta → models usados**. Un renglón por método. Marcá cuáles responden HTML y cuáles JSON.
- Rutas (`config/routes.php`) y cualquier middleware/hook de CodeIgniter que intervenga (autenticación, filtros por empresa).

### 2. Modelo de datos que toca DNATO
- Lista de tablas y vistas que DNATO lee o escribe, con sus columnas principales y claves. Fuente: models, SQL embebido, migraciones, `database.php`.
- Marcá explícitamente las tablas de: usuarios, empresas, roles, permisos, menús/opciones, relación usuario-empresa, relación rol-menú, parámetros de sistema, auditoría/log (si existe).
- Cómo se vincula cada usuario con una o varias empresas (¿tabla propia?, ¿memberships de Bonita?, ¿ambas?). Diagrama Mermaid `erDiagram` con lo encontrado.

### 3. Identidad, sesión y aislamiento por empresa
- Flujo de login paso a paso: controller, validación de credenciales (¿contra qué?), cómo se resuelve `empr_id`, en qué variables de sesión queda, cómo se cambia de empresa (si se puede).
- Cómo se identifica al **súper usuario** hoy (¿flag en tabla?, ¿rol?, ¿lista fija?) y qué hace distinto el código cuando lo es. Listá cada `if` o condición donde aparece.
- Emisión y validación de JWT (ADR-008): dónde se firma, con qué algoritmo, qué claims lleva (confirmá si `empr_id` viaja como claim), endpoint JWKS si existe, duración y refresco.
- Auditá 5 models representativos (elegí 3 de DNATO y 2 del resto de traz-tools) y decí si **todas** sus consultas filtran por `empr_id`. Anotá excepciones: son riesgos de fuga entre empresas.

### 4. Capacidades funcionales actuales (inventario de casos de uso)
Para cada función que hoy existe, un renglón con este formato:

| CU | Nombre | Actor (admin empresa / súper usuario / usuario) | Pantalla o ruta | Controller::método | Tablas | Estado (completo / parcial / roto) | Evidencia |

Cubrí como mínimo: alta/baja/modificación de usuarios, asignación de roles, alta/edición de menús y asignación a roles, carga masiva de datos (qué entidades, formato de archivo, validaciones, qué pasa con errores), gestión de empresas (alta, edición, baja, ¿bloqueo?), gestión de roles, parámetros, cambio de contraseña, recuperación de contraseña, y cualquier otra cosa que encuentres.

Después marcá en una lista aparte lo que **no existe** aunque parezca que debería: validación de tope de usuarios, bloqueo/baneo rápido, menús custom por rol o usuario, planes, cuotas de uso, auditoría de cambios administrativos, estadísticas de uso.

### 5. Menú y permisos, en detalle
- Cómo se arma el menú que ve cada usuario: tablas, query, cache, orden, íconos. ¿Es por rol, por usuario, por empresa o combinación?
- Catálogo completo de opciones de menú existentes hoy (código, nombre, módulo al que pertenece, URL). Esta lista es la base del futuro "catálogo de funcionalidades" por plan.
- Dónde se valida el permiso: ¿solo al dibujar el menú o también en cada controller? Dá ejemplos con `ruta:línea`.

### 6. Interfaz de usuario actual
- Stack de frontend: motor de vistas, framework CSS y versión, librerías JS (jQuery, DataTables, Select2, etc.) con versión, layouts/templates maestros, cómo se incluyen los assets.
- Inventario de pantallas de DNATO con captura textual: qué muestra, qué acciones tiene, qué inconsistencias visuales o de interacción detectás (duplicaciones, estilos distintos entre pantallas, formularios sin validación, mensajes de error técnicos al usuario).
- Si hay más de un estilo o framework conviviendo, listalos: esto justifica el rediseño.

### 7. Integraciones y dependencias
- Llamadas a Bonita (REST, librería o BD directa), a WSO2, a correo (SMTP, librería), a otros módulos de traz-tools.
- Variables de entorno y archivos de configuración que DNATO necesita para arrancar.

### 8. Calidad y deuda técnica
- Tests existentes (PHPUnit, Hurl, Playwright, DocTest YAML) que cubran DNATO, con ruta.
- Código muerto, duplicado o comentado que detectes.
- Riesgos de seguridad evidentes (SQL concatenado, contraseñas en claro, falta de CSRF, validación solo en front). Sin explotarlos, solo señalarlos con `ruta:línea`.

## Entregable

Un único archivo: `doc/v3/dnato/DNATO_v2_RELEVAMIENTO.md` en `traz-tools`, con esta estructura:

1. Resumen ejecutivo (10 líneas): qué hace DNATO hoy, en qué estado está, los 5 hallazgos más importantes.
2. Secciones 1 a 8 de arriba, en ese orden, con tablas y diagramas Mermaid (`erDiagram` para datos, `sequenceDiagram` para login y emisión de JWT, `flowchart` para armado de menú).
3. "Lo que NO existe" (lista).
4. "Dudas para el PM" (lista numerada): todo lo que no pudiste resolver leyendo el código.
5. Anexo: inventario de archivos recorridos.

No escribas nada más en el repo. No modifiques código. No hagas commit: dejá el archivo en el working tree para que lo revise.

Al terminar, pegá en el chat el resumen ejecutivo y la lista de dudas.
