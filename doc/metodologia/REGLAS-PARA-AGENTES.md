# Reglas para cualquier agente de programación en este repo

## Objetivo

Reglas de trabajo que tiene que seguir **cualquier agente de IA que programe en `traz-tools`**
(DeepSeek, u otro) que no sea Claude Code: ramas, commits, pull requests, pruebas y qué partes del
sistema no se tocan sin aprobación. Lo lee el agente al arrancar: Pablo lo nombra una vez en las
instrucciones permanentes de su agente (ver `doc/metodologia/GUIA_REQUERIMIENTOS_CLAUDE_DEEPSEEK.md`,
sección 2.16). **No** reemplaza a `CLAUDE.md`,
que es la fuente original y tiene además contexto de arquitectura; si los dos se contradicen, manda
`CLAUDE.md` y hay que corregir este archivo.

> Si se cambia una regla de Git o de pull requests en `CLAUDE.md`, se cambia también acá, en el mismo
> pull request.

---

## 1. Ramas: nunca directo a las ramas de integración

- **PROHIBIDO** hacer commit o push directo a `develop`, `develop-v3`, `master` o `main`. Todo cambio
  entra por pull request.
- Si un push a una de esas ramas es rechazado, es lo correcto: **no** forzar (`--force`) ni intentar
  desactivar la protección. Mover los commits a una rama de trabajo y abrir pull request.
- **Rama base:** `develop` (es la que se despliega en DEMO), salvo que la tarea diga explícitamente
  `develop-v3`.
- **Una rama por requerimiento:** `feature/req-###-desc-corta`. Para trabajos sueltos:
  `<tipo>/<id>-<desc-corta>`, con tipo `feat`, `fix`, `docs`, `chore` o `refactor`.

Flujo:

```bash
git checkout develop && git pull origin develop
git checkout -b feature/req-###-desc-corta
# ... commits ...
git push origin feature/req-###-desc-corta
```

## 2. Commits

- Formato: `tipo(scope): descripción [ID]` — por ejemplo `feat(man): alta de equipo con componentes [REQ-012]`.
- Un commit por tarea del plan, **solo con DocTest en verde** (sección 4).
- Nunca commitear secretos: `.env`, `doctest/.env`, `doctest/entornos/*.json`, claves, tokens,
  contraseñas. Revisar `git status` antes de cada commit.
- **No hacer commit si el agente no lo tiene pedido**: lo decide Pablo después de ver las pruebas en
  verde.

## 3. Pull requests

- **Solo requerimientos en "Listo para Pablo".** El estado de cada uno está en
  `requerimientos/README.md`. Un requerimiento en **Borrador** se puede leer para entender hacia dónde
  va el trabajo, pero **no** se planifica ni se programa.
- **Uno por requerimiento**, a `develop`. Se abre **en borrador** con solo el plan
  (`requerimientos/REQ-###-….plan.md`) y no se programa hasta que Rodolfo deja el comentario
  **`✅ Plan aprobado`**. Con todas las tareas hechas, se pasa a "Ready for review".
- **Nunca unir (merge) un pull request** sin la aprobación explícita de Rodolfo (botón "Approve" en
  GitHub).
- Antes de pasarlo a listo:
  - DocTest en verde (sección 4);
  - sin marcadores de conflicto: `grep -rn "^<<<<<<<\|^=======\|^>>>>>>>" .`;
  - sin secretos en el diff;
  - si se tocó el proyecto de APIs: `cd _backend/api/ToolsAPIProject/ToolsAPIProject && ./mvnw clean install` en verde.
- Descripción, siempre con este formato:

```markdown
## Qué cambia
[1-2 líneas, en términos funcionales]

## Por qué
[requerimiento / issue / decisión que lo origina. Casos de uso: MAN-UC-###, ...]

## Cómo lo verifiqué
[salida REAL de npm run doctest -- --entorno local, pegada; build si aplica]

Closes #NNN
```

## 4. Pruebas: DocTest

- Se corre en `doctest/`: `npm run doctest -- --entorno local` **antes de cada commit**. La primera
  vez en la máquina: `npm run doctest -- casi-full --entorno local`.
- Cada tarea lleva su prueba, escrita contra un caso de uso **validado** del catálogo
  (`doctest/catalogo/`). Nada se escribe contra un caso en `borrador`.
- Los casos de uso los valida Rodolfo. Si falta uno, el agente redacta un borrador y **para**.
- Las pruebas **nunca** apuntan a producción.
- Si algo falla dos veces seguidas, **parar** y mostrar el error completo, sin seguir tocando.

## 5. Sistema productivo: lo que no se toca sin aprobación

v2 corre en producción. Antes de modificar el **núcleo**, el agente **para y pide aprobación a
Rodolfo** con un análisis de impacto (qué cambia, quién lo usa, qué se puede romper). Es núcleo:

- objetos de los esquemas `core` y de `dnato` (tablas, columnas, triggers, procedimientos);
- `application/config/constants.php` (de Tools o de cualquier submódulo);
- los DataServices (`.dbs`) y sus consultas;
- las APIs y sequences de WSO2 (`_backend/api/**`);
- los procesos de Bonita;
- el módulo de formularios (`traz-comp-formularios`) y el flujo de registración y login.

Primera hipótesis siempre: **"esto funciona en producción"**. Comparar contra `master` antes de
suponer que es un bug.

## 6. Reglas de código

- **Destino PHP 5.6:** nada de sintaxis de PHP 7 (sin `??`, sin tipos de retorno, sin tipos escalares
  en parámetros, sin `<=>`, sin clases anónimas).
- **Compatibilidad con v2:** solo cambios que agregan. Nunca cambiar lo que una API, una consulta o una
  función ya devuelve.
- **La lógica de negocio va en las APIs**, no en los controllers. PHP no consulta la base directo:
  todo pasa por WSO2 con `wso2($url, $method, $data)` de `wso2_helper.php`.
- PHP: PSR-12. APIs: URLs en kebab-case, claves JSON en snake_case. Base: tablas y columnas en snake_case.
- Log: `log_message('DEBUG', '#TRAZA | <MODULO> | <Clase> | <metodo>() ...')`.

## 7. Cuándo parar y preguntar

| Duda | Qué hace el agente |
|---|---|
| Técnica menor (dos formas válidas de hacer lo mismo) | Decide y lo anota en la descripción del pull request |
| Funcional o de negocio (cambia lo que ve o paga el usuario) | **Para** y pregunta, con opciones y recomendación |
| Arquitectura, o toca el núcleo (sección 5) | **Para**: necesita aprobación de Rodolfo |

Ante la duda de si algo es menor o funcional: preguntar.
