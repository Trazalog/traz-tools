# Trazalog Tools — Contexto para Brainstorming v3

> Este documento es el insumo base para el brainstorming de la versión 3 de la suite Trazalog Tools.
> Fue generado en marzo de 2026 a partir del análisis del código fuente y entrevistas con el fundador.

---

## ¿Qué es Trazalog Tools?

Trazalog Tools es una suite de software de gestión industrial orientada a **PyMEs argentinas** de sectores como mantenimiento industrial, agroindustria, gestión de residuos y oil & gas. Su propuesta de valor central es:

> **Llevar software del mismo nivel técnico que los grandes ERPs de multinacionales a las PyMEs argentinas, a un costo que una PyME pueda pagar.**

Las PyMEs objetivo en su mayoría carecen de software para la gestión de producción y mantenimiento, o usan Excel/procesos manuales. Trazalog les ofrece capacidades simplificadas (acordes a su operatoria), pero con la solidez arquitectónica de soluciones enterprise.

---

## Clientes actuales (2026)

| Cliente | Sector | Observaciones |
|---|---|---|
| [Tierra Capayán](https://tierracapayan.com.ar/) | Agroindustria / Bodega | Cliente activo |
| [Yudica](https://yudica.com/) | Industria | Cliente activo |
| [Ingeniería Matheusa](http://www.ingenieriamatheusa.com.ar/) | Ingeniería / Servicios | Cliente activo |

### Clientes históricos (perdidos ~2023-2024)

Lacoste, Motores Balderramo, Kolormax, Bodegas Borbore, Agroallium.

**Contexto de pérdida:** El cambio de gobierno en Argentina en 2023 orientó la economía hacia la minería y alejó el foco de la industria manufacturera y agroindustria, provocando el cierre o achicamiento de la mayoría de las empresas clientes.

**Aprendizaje estratégico:** La base de clientes es vulnerable a ciclos macroeconómicos argentinos. Una v3 debería considerar diversificación geográfica o hacia sectores más resilientes.

---

## Competencia

| Competidor | Tipo | Observaciones |
|---|---|---|
| [Consuman CMMS](https://consuman.com) | CMMS (mantenimiento) | Software argentino, enfocado en mantenimiento |
| [Finneg ERP](https://finneg.com/ar/) | ERP PyME | ERP argentino de alcance más amplio |
| ERPs internacionales (SAP B1, Odoo) | ERP completo | Fuera del rango de precio de la mayoría de las PyMEs objetivo |
| Excel / procesos manuales | No-software | El "competidor" más frecuente en la realidad |

**Ventaja diferencial de Trazalog:** Cubre el nicho intermedio entre "Excel y nada" y "ERP grande caro", con foco en trazabilidad operativa (QR, BPM, formularios dinámicos) que Consuman y Finneg no cubren de la misma forma.

---

## Capacidades actuales (v2)

### Módulos en producción

#### Componentes compartidos (usados por todos los módulos)

| Módulo | Función |
|---|---|
| **Almacenes** | Gestión de inventario: artículos, depósitos, stock, lotes, múltiples almacenes por empresa |
| **BPM** | Integración con Bonita BPM: bandeja de tareas, asignación, historial, comentarios, timeline |
| **Formularios** | Motor de formularios dinámicos: plantillas reutilizables, captura de datos, carga de archivos |
| **Códigos / QR** | Generación de QR y códigos de barras para activos, paquetes, contenedores, tareas |
| **PAN (Pañol)** | Gestión de herramientas y equipos: inventario de herramientas, ubicaciones, marcas |
| **Calendario** | Programación de tareas con soporte de jornada laboral (horarios de trabajo, días hábiles) |
| **Tareas Estándar** | Órdenes de trabajo genéricas: plantillas, asignación de usuarios, planning, sectores |
| **Notificaciones** | Push notifications vía Firebase al app móvil Flutter *(menos probado)* |

#### Herramientas funcionales

| Módulo | Función |
|---|---|
| **Mantenimiento / Asset Planner** | Ver sección completa abajo |
| **Residuos (RESI)** | Gestión completa de residuos: órdenes de transporte, contenedores, circuitos, zonas, incidentes, pesaje |

#### Módulos cliente-específicos

| Módulo | Cliente | Función |
|---|---|---|
| **DDPE Pro** | DDPE | Inspecciones ambientales, actas de notificación, control de ingreso por barrera |
| **SEIN Pantallazo** | SEIN | Cotizaciones y gestión de pedidos de trabajo |
| **YUDI Processing** | Yudica | Flujo de procesamiento con tracking QR por etapa |
| **Trazasoft** | — | Trazabilidad de recipientes de transporte, fórmulas/recetas de productos |

### Capacidades transversales

- **Multi-empresa:** Toda la data está segmentada por empresa (`empr_id`)
- **Workflows BPM:** Procesos de negocio con asignación de tareas y permisos (Bonita BPM)
- **Trazabilidad por QR:** Activos, contenedores y tareas se rastrean con códigos QR a lo largo de flujos
- **Notificaciones push:** Firebase → app Flutter
- **Reportes:** Motor KoolReport para analytics (tonelaje, incidentes, pesos, métricas de transporte)
- **App móvil:** Flutter con notificaciones push y escaneo de QR
- **Integración con balanza:** Lectura de peso en tiempo real (módulo RESI)
- **Integración con Tango ERP:** Sincronización de datos vía Siddhi Streaming Integrator
- **Integraciones WhatsApp:** Conector para envío de mensajes
- **Audit trail:** Comentarios, timelines y logging de actividad de usuario en todos los procesos

### Stack tecnológico actual

| Capa | Tecnología |
|---|---|
| Frontend web | CodeIgniter 3 (PHP), HMVC, Bootstrap |
| API / Integración | WSO2 Micro Integrator (XML/DSS) |
| BPM | Bonita BPM |
| Base de datos | MySQL/MariaDB (via WSO2 Data Services) |
| Streaming | WSO2 Siddhi (Streaming Integrator) |
| Mobile | Flutter |
| Notificaciones | Firebase Cloud Messaging |
| Reportes | KoolReport (PHP) |

---

## Asset Planner — Módulo de Mantenimiento Industrial (proyecto separado)

> **Estado:** Proyecto legado independiente (`traz-prod-assetplanner`), aún no migrado a la estructura de traz-tools. La migración estaba en curso pero se pausó por restricciones de presupuesto. Está planificada para la **versión 4**. Se incluye aquí porque representa la capacidad de mantenimiento más completa de la suite.

Es el módulo más maduro y complejo de toda la suite: **61 controladores, 59 modelos, 226 vistas**. Cubre el ciclo de vida completo de activos industriales.

### Entidades principales

- **Equipos** — catálogo de activos industriales con código, criticidad, estado (activo/inactivo/retirado), disponibilidad
- **Órdenes de Trabajo** — solicitudes de servicio y mantenimiento asignadas a equipos
- **Preventivos** — planes de mantenimiento preventivo por tiempo o uso (intervalos configurables)
- **Predictivos** — mantenimiento basado en condición: lecturas de sensores/medidores que disparan alertas
- **Correctivos** — reparaciones de emergencia / no planificadas
- **Backlog** — cola de trabajos pendientes priorizados a nivel de componente
- **Componentes y Sistemas** — jerarquía dentro de cada equipo
- **Lecturas** — historial de mediciones de equipos para monitoreo de condición

### Capacidades funcionales

| Área | Capacidades |
|---|---|
| **Gestión de activos** | Catálogo completo con ubicación, área, sector, criticidad, cliente asignado, disponibilidad |
| **Mantenimiento preventivo** | Programación por tiempo/uso, biblioteca de tareas estándar reutilizables con subtareas |
| **Mantenimiento predictivo** | Lecturas de condición con umbrales de alerta (amarillo/rojo), análisis de tendencia histórica |
| **Mantenimiento correctivo** | Órdenes de emergencia, seguimiento de tiempos de respuesta |
| **Backlog** | Cola priorizada de trabajos pendientes con asignación de materiales y herramientas |
| **Calendario visual** | Vista mensual/anual unificada: preventivos, predictivos, correctivos y alertas de disponibilidad |
| **KPIs y reportes** | Disponibilidad de equipos (últimos 12 meses), tiempos de respuesta, producción, estado por equipo |
| **Inventario y supply chain** | Depósitos con GPS, pedidos de insumos, artículos/repuestos, proveedores, contratistas, remitos |
| **BPM** | Integración con Bonita BPM para flujos de solicitud y aprobación de mantenimiento |

### Estructura organizacional soportada

`Empresa → Sucursal → Área → Sector → Equipo → Componente`

Multi-empresa, multi-sucursal, con control de acceso por roles y grupos.

### Stack tecnológico

Mismo stack que traz-tools (CodeIgniter 3, PHP, MySQL, AdminLTE, KoolReport, Bonita BPM), pero como proyecto independiente sin la capa WSO2 MI.

---

## Dolores y limitaciones conocidas de v2

1. **Escalabilidad:** Algunas funcionalidades están "verdes" — funcionan bien con volúmenes pequeños de datos pero fallan con alto volumen. No han sido stress-testeadas.

2. **Módulos poco maduros:** Tareas Estándar y Notificaciones son los menos probados en producción.

3. **Stack técnico legacy:** CodeIgniter 3 es un framework PHP antiguo (sin soporte activo desde 2022). WSO2 MI con XML es verboso y difícil de mantener.

4. **Módulos cliente-específicos:** Los módulos `ddpe-tools-pro`, `sein-tools-almpantar`, `yudi-tools-almproc` son personalizaciones hardcodeadas, no un sistema de configuración/extensión. Dificulta escalar a nuevos clientes.

5. **Asset Planner no integrado:** El módulo de mantenimiento más completo (Asset Planner) vive en un proyecto separado, con su propia base de código y sin la capa WSO2 MI. Los clientes que necesiten mantenimiento + traz-tools deben operar dos sistemas distintos.

5. **UX/UI:** La interfaz es funcional pero no moderna. Compite visualmente en desventaja frente a SaaS modernos.

6. **Vulnerabilidad de mercado:** Base de clientes pequeña y concentrada en un sector afectado por ciclos macroeconómicos argentinos.


---

## Oportunidades estratégicas para v3

*(Esta sección es el punto de partida del brainstorming — ampliar en el proyecto web)*

- Modernización del stack técnico (¿migración a framework moderno? ¿API-first? ¿SaaS multi-tenant?)
- Hardening de escalabilidad en módulos core
- UX/UI renovada para competir con soluciones SaaS modernas
- Sistema de extensión/configuración para clientes (en lugar de módulos hardcodeados)
- Expansión sectorial o geográfica para reducir dependencia del mercado industrial argentino
- Inteligencia: dashboards ejecutivos, alertas inteligentes, análisis predictivo de mantenimiento
- Integración nativa con más ERPs argentinos (Tango, Colppy, etc.)
- Certificaciones / compliance (ISO 9001, gestión ambiental) como diferencial

---

*Generado: marzo 2026 | Repositorio: traz-tools | Rama: rruiz*
