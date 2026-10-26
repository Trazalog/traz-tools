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
_(pendiente de relevar — Mantenimiento → Equipos → Agregar: modales inline de área/proceso/criticidad/etapa/grupo/marca)_

### 2. Equipo
_(pendiente)_

### 3. Herramienta (Pañol)
_(pendiente)_

### 4. Salida de Herramienta / vale (Pañol) — asocia la OT (F6)
_(pendiente)_

### 5. Artículo y Stock (Almacenes)
_(pendiente)_

### 6. Solicitud de Servicio → Orden de Trabajo
_(pendiente)_

### 7. Informe de Servicio: F3 (texto libre), F4 (entregas), F5 (herramientas usadas)
_(pendiente)_
