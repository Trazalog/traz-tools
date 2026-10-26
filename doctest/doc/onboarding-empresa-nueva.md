# Onboarding de una empresa nueva en AssetPlanner (full seed)

## Objetivo

Guía **autocontenida** para dejar operativa una empresa **recién registrada** en AssetPlanner:
qué datos maestros cargar, **en qué orden** (hay dependencias), en qué pantalla y con qué campos,
hasta poder recorrer el ciclo de una Orden de Trabajo con herramientas y pañol (maqueta F3-F6).
Está escrita para que **una persona o un agente de IA** acompañe a un cliente nuevo en su primer
arranque, cuando la empresa está **vacía** (sin equipos, herramientas, artículos ni OTs).

Cada paso dice **dónde** se ejecuta (menú y URL dentro de AssetPlanner) y qué campos pide. No cubre
el alta de la empresa en sí (eso es la registración de Trazalog, previa a esta guía) ni la
administración avanzada. El circuito automatizado equivalente vive en
`doctest/tests/e2e/flows/` (spec `CICLO-UC-001`), que ejecuta y captura este mismo recorrido.

> **Dónde se opera todo:** AssetPlanner — `https://<host>/tools/traz-prod-assetplanner` —
> con el usuario **administrador** de la empresa (el correo con que se registró). Verificado en DEMO:
> ese admin entra a AssetPlanner y tiene en el menú Mantenimiento, Pañol y Almacenes.

---

## Orden de carga (por dependencias)

```
Maestros base (Equipo los exige, y están vacíos al empezar):
  área · proceso · criticidad · etapa · grupo · marca
        └── Equipo  (Mantenimiento → Equipos)
Pañol:
  marca · depósito ── Herramienta (Pañol → Herramientas)
                        └── Salida de Herramientas (Pañol → Salida Herramientas)  → asocia la OT (F6)
Almacén:
  unidad de medida ── Artículo (Almacenes → Artículos)
                        └── Stock (Almacenes → Stock) → Entrega (F4)
Ciclo:
  Equipo ── Solicitud de Servicio (Mantenimiento → Solicitud de Servicio)
              └── Orden de Trabajo → Informe de Servicio (F3 texto libre, F4 entregas, F5 herramientas usadas)
```

---

## Pasos

<!-- Se completa a medida que se releva/automatiza cada flujo. -->

### 1. Maestros base para el Equipo

**Dónde:** AssetPlanner → menú **Mantenimiento → Equipos** (`/Equipo`) → botón **Agregar**
(abre el formulario de alta de equipo).

Al abrir el alta, los combos **Área, Proceso, Criticidad, Etapa, Grupo, Marca** están **vacíos**
(empresa nueva). Cada uno tiene al lado un botón **Agregar** que abre un modal chico para crearlo
sin salir de la pantalla:

| Combo | Botón | Qué se escribe | Queda en |
|---|---|---|---|
| Área | Agregar (área) | Nombre o descripción (ej. *Área Minería*) | tabla `area` |
| Proceso | Agregar (proceso) | Nombre o descripción (ej. *Molienda*) | tabla `proceso` |
| Criticidad | Agregar (criticidad) | Descripción (ej. *Alta*) | — |
| Etapa | Agregar (etapa) | Descripción (ej. *Operación*) | — |
| Grupo | Agregar (grupo) | Descripción (ej. *Bombas*) | — |
| Marca | Agregar (marca) | Descripción de la marca (ej. *ACME*) | tabla `marcasequipos` |

Al guardar cada modal, el valor queda **seleccionado** en su combo. Hacé esto una vez; después
quedan disponibles para todos los equipos. **Marca es opcional** para dar de alta el equipo.

### 2. Equipo

**Dónde:** el mismo formulario de **Mantenimiento → Equipos → Agregar**, una vez creados los maestros.

Campos a completar:

| Campo | Ejemplo | Obligatorio |
|---|---|---|
| Código | `EQ-001` | sí (identifica el equipo) |
| Descripción | Bomba centrífuga 100HP | sí |
| Número de serie | `SN-0001` | — |
| Ubicación | Planta 1 | — |
| Fecha de ingreso / garantía | 2026-01-10 / 2027-01-10 | — |
| Área / Proceso / Criticidad / Etapa / Grupo | los creados en el paso 1 | sí |
| Marca | la creada en el paso 1 | opcional |

**Guardar.** El sistema confirma *"Guardado exitoso de nuevo equipo"*. Con un equipo ya se puede
pedir un servicio (paso 6).

> Automatización: `flows/seed-asset.ts → seedEquipo()` crea los maestros y el equipo por los mismos
> endpoints que usa la UI (`Equipo/agregar_*` y `Equipo/guardar_equipo`).

### 3. Herramienta (Pañol)

**Dónde:** AssetPlanner → **Pañol → Herramientas** (`/Herramienta`) → botón **Agregar**.

Campos: **Código** (ej. `HRR-001`), **Descripción** (ej. Taladro percutor), **Modelo** (ej. TP-500),
**Marca** (combo — usa las mismas marcas que el equipo, `marcasequipos`; si está vacío, cargá una) y
**Depósito** (combo). **Guardar**.

> Notas verificadas en DEMO (2026-10-26) — anotar como hallazgos:
> - Una empresa recién registrada **no trae ningún depósito/pañol** (`getdeposito` → "nada"). La
>   herramienta se puede crear igual (depósito opcional), pero para la **salida de herramientas**
>   (vale, paso 4) conviene tener un depósito. _(Falta relevar dónde se crea el depósito.)_
> - El **código de equipo** se valida único **global** (no por empresa): usar códigos irrepetibles.
>
> Automatización: `flows/seed-asset.ts → seedHerramienta()` (endpoint `Herramienta/agregar_herramienta`).

### 4. Salida de Herramienta / vale (Pañol) — asocia la OT (F6)
_(pendiente)_

### 5. Artículo y Stock (Almacenes)
_(pendiente)_

### 6. Solicitud de Servicio → Orden de Trabajo
_(pendiente)_

### 7. Informe de Servicio: F3 (texto libre), F4 (entregas), F5 (herramientas usadas)
_(pendiente)_
