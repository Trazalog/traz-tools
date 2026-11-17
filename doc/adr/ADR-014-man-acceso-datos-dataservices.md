# ADR-014 — MAN accede a `assetv2` solo por DataServices

- **Estado:** Aceptado (PM, 2026-10-27). La decisión de fondo (A1) la tomó el PM el 2026-10-26; las reglas técnicas las propuso Claude Code y el PM las aprobó el 2026-10-27, agregando la regla 4
- **Fecha:** 2026-10-27
- **Contexto de decisión:** Decisión del PM 2026-10-26 (A1 de `doc/migracion/MIGRACION-ASSETPLANNER.md` §4). A2 y A3 los resolvió el PM el 2026-10-27
- **Relacionado:** ADR-003 (mapeo PHP→WSO2), ADR-009 (identidad `X-JWT-Assertion`), ADR-012 (patrón BPM + rollback de `create_ot`), ADR-013 (fachada MCP)

---

## Contexto

La migración de AssetPlanner a tools (`doc/migracion/MIGRACION-ASSETPLANNER.md`) lleva el núcleo de
mantenimiento al submódulo `traz-tools-man` (**MAN**). Los datos siguen en la MariaDB `assetv2`,
sin migración (decisión del PM, 2026-08-12).

El fork de 2024 accedía a esa base de forma directa: `$this->assetDB =
$this->load->database('asset_db', TRUE)` en los 13 models (unos 1.730 accesos), más 62 usos de
`$this->db` en controllers que apuntan a la base equivocada (en tools, `default` es PostgreSQL).
Además, cerca de 12 `insert_id()` leen el id de otra conexión.

Eso contradice la regla de `CLAUDE.md`: la lógica de negocio va en las APIs y no en los
controllers, y PHP no hace consultas directas a la base. También deja a MAN fuera de los canales
nuevos (MCP), que solo ven lo que exponen los DataServices.

## Decisión

**MAN no accede a ninguna base de datos.** Todo dato de `assetv2` pasa por `MANDataService` (y
`MANEquiposDataService`). Los datos de tools pasan por los DataServices que ya existen (`ALM`, `PAN`,
`CORE`). Los models de MAN conservan su firma y el formato de salida de cada método, y por dentro
llaman por REST con `wso2()`. Así los controllers no cambian. La conversión es parte de portar cada
archivo: no hay un estado intermedio "anda con `assetDB`".

**Fuente única de los artefactos WSO2 (A3, PM 2026-10-27):** la fuente de `toolsMANAPI`,
`MANDataService`, `COREDataService` y `ALMDataService` es la de traz-tools
(`_backend/api/ToolsAPIProject/`). Las copias que mantiene asset en su `_backend/api/` dejan de
editarse y se retiran. Toda query nueva o corregida para MAN entra a tools.

### Reglas técnicas

| # | Regla | Cómo |
|---|---|---|
| 1 | **Ids generados.** Todo insert cuyo id se usa después lo devuelve el DataService en la respuesta. Nada de `insert_id()` | La query del `.dbs` lleva `returnGeneratedKeys="true"` y `keyColumns="<pk>"` y devuelve el id en el JSON, igual que `ALMDataService.setNotaPedido`. El model devuelve ese id donde antes devolvía `insert_id()` |
| 2 | **Varias escrituras que deben ser atómicas y no dependen entre sí** van en **un solo** `request_box` | El boxcarring (`enableBoxcarring="true"`, ya activo en `MANDataService`) ejecuta las operaciones del box en una sola transacción. En PHP se usa `requestBox()` de `wso2_helper.php`. **No** sirve cuando un paso necesita el id que generó otro: ese caso es la regla 3 |
| 3 | **Operaciones encadenadas o que tocan varios subsistemas** (crear OT + caso Bonita, pedido + Bonita, generar una serie de OTs) **son un recurso de `toolsMANAPI`**, no una secuencia de llamadas desde PHP | Una sequence del MI que encadena los pasos y, si uno falla, **compensa** lo ya hecho (DELETE), con el mismo patrón que `create_ot` (ADR-012). PHP envía los datos y el API decide qué significan (`CLAUDE.md`). Los pasos de una sequence son transacciones separadas: la atomicidad la da la compensación, no la base |
| 4 | **Las APIs se construyen con los componentes propios de WSO2** (mediadores nativos: `call`, `payloadFactory`, `property`, `filter`, `switch`, `iterate`/`foreach`, plantillas y sequences reutilizables), **no con código JavaScript** (`script` mediator) | Agregada por el PM el 2026-10-27. El `script` se usa **solo si no queda otra**, y en ese caso el PR explica por qué ningún componente nativo alcanza. Motivo: lo nativo es declarativo, se lee y se mantiene en la misma herramienta, y no esconde lógica de negocio en fragmentos de código |

**Bonita al crear una OT (A2, PM 2026-10-27):** se replica la coreografía de asset tal cual. Si el
lanzamiento del caso falla, la OT se borra (hoy en `controllers/Calendario.php:354-359` de asset).
Los nombres de actividad se mantienen como están. Cambiar esto queda para MIG-8, que separa
"programar" de "lanzar". La regla 3 deja esos dos pasos separados dentro de la operación, para que
MIG-8 pueda diferir el lanzamiento sin reescribirla.

**Identidad:** este ADR no cambia el mecanismo. Desde el frontend, MAN envía el `empr_id` de la
sesión (`empresa()`), como hacen hoy los models de tools y la capa de integración de asset. Para
MCP rige ADR-009: el `empr_id` sale del `X-JWT-Assertion` y nunca lo pone el agente. **Toda query
nueva de `MANDataService` filtra por `empr_id`.** Es la regla que evita repetir T1 (fuga entre
empresas, `models/Equipos.php:830` de asset).

**Compatibilidad:** las queries se **agregan** a los `.dbs`. Las que ya consumen asset, v2 o MCP no
se modifican (§3.1 del plan).

## Consecuencias

- Cada método de model que se porta necesita su query en `MANDataService`, y esa query se prueba con
  `curl` contra el EI de DEV antes de que el PHP la use. Es el grueso del trabajo de MIG-1 (riesgo
  R9 del plan).
- El checklist 0b del CI de `traz-tools-man` (`.ci/checklist-0b.sh`) hace cumplir este ADR: cero
  `$this->db` y cero `assetDB` en los archivos portados.
- Cuando termine la migración (MIG-6), se borra `$db['asset_db']` del `application/config/database.php`
  de tools.
- `AssetPlannerDataSource` pasa a ser el único camino a `assetv2` desde tools. Hay que verificar que
  escribe en TEST y PROD, no solo en DEV (MIG-0, punto 6). Hoy su `url` está fija a la MariaDB de
  DEV en el repo, y el valor de cada ambiente lo pone `deploymcp.sh` al desplegar, con el
  `deploy/gcp/.env.car` de ese servidor (`MY_HOST`, `MY_PORT`, `MY_DB`).
- Las operaciones de la regla 3 quedan disponibles también como tools MCP, sin reimplementarlas
  (ADR-013).

## Alternativas descartadas

- **Acceso directo con `$db['asset_db']`** (el plan de agosto). Es más rápido de portar, pero deja la
  lógica en PHP, fuera del alcance de MCP. Además obliga a hacer la conversión dos veces.
- **Stored procedures en `assetv2`** para las operaciones encadenadas. Violan el freeze del esquema
  de `assetv2` mientras asset siga en producción, y no resuelven la parte de Bonita.
- **Encadenar llamadas desde el model PHP** (insert → leer id → siguiente insert). Deja la operación
  sin compensación si falla a mitad de camino, y la lógica en el lugar equivocado.

## Preguntas abiertas (a resolver en implementación, no bloquean el ADR)

- Verificar con la primera query de MIG-1 que `returnGeneratedKeys` funciona con el driver MySQL de
  `AssetPlannerDataSource` (`com.mysql.cj.jdbc.Driver`). En tools solo está probado con PostgreSQL.
- Si una operación de la regla 3 necesita lanzar N casos de Bonita (la serie de OTs de MIG-4), hay
  que definir el límite de iteraciones y el comportamiento ante una falla parcial (T3). Se resuelve
  en el diseño de MIG-4.
