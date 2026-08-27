# Investigación: Necesidades de Proveedores de Servicios Mineros
## Insumo para el backlog de Trazalog Tools v3

> Documento generado el 22 de marzo de 2026 a partir de investigación de mercado, análisis de mejores prácticas internacionales en mantenimiento minero, y contexto específico del ecosistema minero de San Juan, Argentina.

---

## 1. El contexto macro: San Juan como polo minero

### Proyectos confirmados y en pipeline

San Juan se está posicionando como el principal polo cuprífero de Argentina. Los proyectos activos y aprobados bajo el RIGI representan una masa crítica sin precedentes:

| Proyecto | Mineral | Inversión (USD) | Estado | Fase de construcción |
|---|---|---|---|---|
| **Josemaría / Filo del Sol (Vicuña)** | Cobre, oro, plata | ~10.000 M | RIGI aprobado (BHP + Lundin Mining) | Josemaría proyecta inicio producción ~2030. Construcción masiva 2027-2028 |
| **Los Azules** | Cobre | 2.672 M | RIGI aprobado (McEwen Copper) | Construcción arranca 2026, fase masiva 2027-2028. Primera producción ~2029 |
| **Gualcamayo** | Oro, plata | 665 M | RIGI aprobado | Extensión de vida de mina |
| **Veladero (ampliación)** | Oro | 380 M | RIGI aprobado (Barrick) | En operación, ampliación en curso |
| **El Pachón** | Cobre, molibdeno | 8.500-10.500 M | Pre-factibilidad (Glencore) | Pendiente |
| **Altar** | Cobre | Por definir | Evaluación económica preliminar (Aldebaran) | 48 años de vida minera estimada |

**Dato clave:** Solo Los Azules se comprometió a destinar el 61,1% de su presupuesto de construcción y operación a proveedores locales, superando ampliamente el 20% exigido por la normativa RIGI. Esto confirma que habrá demanda real de proveedores sanjuaninos.

**Implicancia para Trazalog:** La ventana de oportunidad es 2026-2027. Los proveedores locales que no estén profesionalizados cuando arranque la construcción masiva, perderán frente a empresas chilenas o peruanas con certificaciones y sistemas.

### El ecosistema de proveedores en San Juan

Las cámaras activas (CAPRIMSA, CAPRESMI, CAPEMISA) están acompañando a proveedores locales, pero las PyMEs enfrentan déficits concretos:

- **Documentación desordenada**: balances, seguros, antecedentes HSE no están al día
- **Falta de certificaciones ISO**: la mayoría no tiene 9001, 14001 ni 45001
- **Gestión artesanal**: Excel, cuadernos, WhatsApp como herramientas principales
- **Sin capacidad de reportar a operadoras**: las mineras exigen informes de cumplimiento, KPIs, trazabilidad — los proveedores no pueden generarlos
- **Sin registro en plataformas**: RUPE, RFPM (Registro Federal de Proveedores Mineros) son requisitos que muchos no tienen

El Gobierno Nacional lanzó el Registro Federal de Proveedores Mineros (RFPM) como herramienta digital para visibilizar a proveedores. Esto indica que el mercado se está formalizando y digitalizando.

---

## 2. Necesidades operativas de un proveedor de mantenimiento minero

Basado en la investigación de mejores prácticas internacionales y el análisis del sector, estas son las necesidades concretas agrupadas por área:

### 2.1. Gestión de equipos y activos

Un proveedor de servicios mecánicos para mina gestiona una flota de equipos propios (herramientas, vehículos, instrumentos de medición) y además interviene sobre equipos de la minera (excavadoras, camiones, chancadoras, bombas, cintas transportadoras).

**Necesidades específicas:**
- Catálogo de activos propios con estado, ubicación, disponibilidad y certificación vigente
- Registro de los equipos del cliente (la minera) sobre los que se realizan intervenciones
- Jerarquía de equipos: sistema → subsistema → componente
- Criticidad de cada equipo (A/B/C) para priorizar intervenciones
- Historial completo de intervenciones por equipo
- Documentación técnica asociada (manuales, planos, fichas técnicas)

**✅ Lo que Trazalog ya cubre:**
- ✅ Catálogo de equipos con código, estado, criticidad, disponibilidad
- ✅ Jerarquía: Empresa → Sucursal → Área → Sector → Equipo → Componente
- ✅ Historial completo de intervenciones por equipo
- ✅ Asignación de equipos a clientes

**❌ Lo que falta:**
- ❌ Distinción explícita entre "equipo propio del proveedor" y "equipo del cliente (la minera)" — hoy todos los equipos se gestionan igual, sin ese flag
- ❌ Repositorio de documentación técnica asociada al equipo (manuales, planos, fichas) — se podría resolver con el módulo de formularios/archivos adjuntos

### 2.2. Órdenes de trabajo y mantenimiento

El core del negocio. El proveedor recibe solicitudes de la minera, las ejecuta, y debe reportar qué hizo, con qué recursos, en cuánto tiempo.

**Necesidades específicas:**
- Recepción de solicitudes de servicio de la minera
- Creación de OTs correctivas (emergencia), preventivas (programadas), y predictivas (basadas en condición)
- Asignación a técnicos con control de habilitaciones y certificaciones
- Registro de tiempos: inicio, pausa, fin, tiempos de espera (repuestos, permisos)
- Registro de materiales/repuestos consumidos por OT
- Firma digital o validación del supervisor de la minera
- Cierre de OT con observaciones y fotos

**Benchmarks de la industria:**
- Ratio preventivo/correctivo objetivo: 70/30 o mejor (la mayoría de las PyMEs están en 30/70)
- Porcentaje de mantenimiento planificado (PMP) world-class: >85%
- Compliance de mantenimiento preventivo: >95%
- Wrench time (tiempo productivo del técnico): >40%

**✅ Lo que Trazalog ya cubre:**
- ✅ OTs correctivas (emergencia), preventivas (programadas) y predictivas (basadas en condición)
- ✅ Timestamps completos del ciclo: solicitud → asignación → inicio → fin
- ✅ Tiempo del operario por tarea
- ✅ Consumo de materiales/repuestos por OT (contra almacén legacy de Asset Planner)
- ✅ Asignación a técnicos
- ✅ Cierre con observaciones

**❌ Lo que falta (funcional):**
- ❌ Firma digital o validación del supervisor de la minera al cerrar la OT
- ❌ Control de habilitaciones del técnico asignado (verificar que tiene las certificaciones vigentes antes de asignarle la tarea)

**⚠️ Gap técnico:**
- ⚠️ La mayoría de estas capacidades no están expuestas como APIs WSO2 — la lógica existe en los models de CodeIgniter pero no es consumible externamente por el MCP
- ⚠️ El consumo de materiales funciona contra el almacén legacy (sin multi-depósito). Para clientes nuevos se resuelve onboardeando en traz-comp-almacenes; la unificación definitiva queda para v3.1/v4

### 2.3. KPIs y métricas de rendimiento

Las mineras exigen a sus contratistas reportar métricas de rendimiento. Un proveedor que no puede generar estos reportes queda en desventaja competitiva.

**KPIs críticos para un proveedor de mantenimiento minero:**

| KPI | Qué mide | Fórmula | Benchmark World-Class |
|---|---|---|---|
| **Disponibilidad** | Qué porcentaje del tiempo el equipo estuvo disponible para operar (no en reparación ni parado por falla) | (Horas operativas / Horas totales) × 100 | >92% |
| **MTBF** (Mean Time Between Failures) | Cuántas horas en promedio funciona un equipo antes de que falle. Más alto = más confiable | Horas operativas totales / Número de fallas | >800 hs (excavadoras) |
| **MTTR** (Mean Time To Repair) | Cuántas horas en promedio tarda reparar un equipo después de una falla. Más bajo = más eficiente el equipo de mantenimiento | Tiempo total de reparación / Número de reparaciones | <6 horas |
| **MTTF** (Mean Time To Failure) | Similar a MTBF pero para equipos que no se reparan (se reemplazan). Cuánto dura un componente antes de fallar | Horas operativas totales / Número de fallas | Varía por componente |
| **OEE** (Overall Equipment Effectiveness) | Métrica integral que combina: ¿estuvo disponible? ¿funcionó a la velocidad esperada? ¿produjo con calidad? Un OEE de 85% es world-class; 60% es el promedio | Disponibilidad × Performance × Calidad | >85% |
| **PMP** (Planned Maintenance %) | Qué porcentaje del trabajo de mantenimiento fue planificado vs. reactivo (apagar incendios). Si el PMP es bajo, significa que el equipo vive reparando emergencias en vez de previniendo | (Horas mant. planificado / Horas mant. total) × 100 | >85% |
| **PM Compliance** | De todos los mantenimientos preventivos que estaban programados, ¿cuántos se hicieron a tiempo? Si es bajo, el plan de mantenimiento existe en papel pero no se cumple | (PMs completados a tiempo / PMs programados) × 100 | >95% |
| **MC/RAV** (Maint. Cost / Replacement Asset Value) | Cuánto cuesta mantener un equipo por año comparado con comprarlo nuevo. Si supera el 6%, probablemente conviene reemplazarlo | Costo mant. anual / Valor de reposición del activo | 2-6% |
| **Backlog** | Cuántas semanas de trabajo pendiente tiene el equipo de mantenimiento. Muy alto = sobrecargados, muy bajo = quizás sobra gente o no se están registrando los trabajos | Horas pendientes / Horas disponibles de mano de obra | 2-4 semanas |
| **Confiabilidad** | Probabilidad de que un equipo funcione sin falla durante un período dado. Se calcula con distribuciones estadísticas (Weibull, exponencial) sobre el historial de fallas | Varía (exponencial, Weibull) | >90% |

**✅ Lo que Trazalog ya cubre (Asset Planner dashboard):**
- ✅ Disponibilidad (%) — gráfico mensual con meta configurable
- ✅ Ratio de Mantenimiento — donut: Correctivo Urgente / Preventivo / Backlog
- ✅ Equipos Operativos (%) — Activos vs. En Reparación
- ✅ MTBF (hs) — gráfico mensual
- ✅ MTTR (hs) — gráfico mensual
- ✅ MTTF (hs) — gráfico mensual
- ✅ Índice de Confiabilidad (%) — gráfico mensual
- ✅ Filtros por Grupo, Sector, Equipo y rango de fechas

**❌ Lo que falta:**
- ❌ OEE (requiere datos de performance y calidad además de disponibilidad)
- ❌ PM Compliance (% de preventivos completados a tiempo vs. programados) — calculable con datos existentes
- ❌ MC/RAV (costo de mantenimiento vs. valor de reposición) — requiere cargar valores de reposición de activos
- ❌ Backlog en semanas (horas pendientes / horas disponibles de mano de obra)

**⚠️ Gap técnico:**
- ⚠️ Los KPIs se calculan en el frontend PHP (KoolReport) — no están expuestos como APIs. Para el MCP hay dos caminos: crear APIs que repliquen la lógica, o permitir SQL directo read-only

### 2.4. Gestión de repuestos y spare parts

En minería, quedarse sin un repuesto crítico es catastrófico. Las minas están en zonas remotas (en San Juan, a horas de cualquier centro urbano, muchas veces a más de 3.500 metros de altitud), los lead times son largos (un repuesto importado puede tardar semanas o meses), y el costo de un equipo parado puede ser de decenas de miles de dólares por hora. Para un proveedor de mantenimiento, no tener el repuesto que necesita para reparar el equipo de la minera significa incumplir el contrato.

**Necesidades específicas (con explicación detallada):**

**Puntos de pedido dinámicos:** Un punto de pedido es la cantidad mínima de stock que, al ser alcanzada, dispara una orden de compra. Hoy la mayoría de los sistemas (incluyendo Trazalog) permiten configurar un punto de pedido estático — por ejemplo, "cuando el stock de filtros de aceite baje de 10 unidades, avisar". El problema es que ese número fijo no considera que en temporada alta de producción se consumen 15 filtros por semana y en temporada baja solo 3. Un punto de pedido dinámico se recalcula automáticamente basado en la velocidad de consumo real de los últimos X días. Si el consumo se acelera, el punto sube; si baja, el punto baja. Esto evita tanto el stockout (quedarse sin stock) como el sobrestock (tener capital inmovilizado en repuestos que no se usan).

**Clasificación de criticidad de repuestos:** No todos los repuestos son igual de importantes. Una clasificación típica en minería es:
- **Críticos (A):** Si falta, el equipo se para y no hay alternativa. Ejemplo: bomba hidráulica principal de una excavadora. Se debe tener siempre en stock, aunque sea caro. Suelen ser pocos ítems pero de alto valor.
- **Esenciales (B):** Si falta, el equipo puede funcionar de forma degradada o hay un workaround temporal. Ejemplo: sensor de temperatura de un motor — se puede operar monitoreando manualmente por un tiempo corto. Se gestiona con punto de pedido estándar.
- **Consumibles (C):** Se usan frecuentemente y son de bajo valor unitario. Ejemplo: filtros, lubricantes, juntas, tornillería. Se gestionan por cantidad mínima y se compran en lote.

Esta clasificación determina la estrategia de inventario: los críticos se stockean siempre, los esenciales se reponen por consumo, los consumibles se compran en volumen. Sin esta clasificación, el proveedor tiende a stockear de más en todo (capital atado) o de menos en lo crítico (riesgo de parada).

**Consumo histórico por equipo y por tipo de intervención:** Saber que "en los últimos 6 meses, la excavadora CAT-320 consumió 8 filtros hidráulicos, 12 litros de aceite y 2 correas cada vez que se le hizo el PM de 500 horas". Esto permite predecir qué se va a necesitar cuando venga el próximo PM de esa excavadora. Sin este dato, el técnico llega a hacer el mantenimiento y descubre que falta un repuesto — perdiendo horas o días.

**Alertas de stock bajo con lead time considerado:** Una alerta que diga "tenés 5 filtros y el punto de pedido es 10" es útil pero incompleta. Si el proveedor del filtro tarda 3 días en entregar, quizás con 5 alcanza. Pero si tarda 45 días (porque es un repuesto importado desde Japón), con 5 unidades ya estás en zona de riesgo. La alerta con lead time dice: "al ritmo actual de consumo, te quedás sin stock en 12 días, pero el proveedor tarda 45 días en entregar — tenés que pedir AHORA". Es la diferencia entre una alerta informativa y una alerta accionable.

**Visibilidad multi-almacén (depósito central vs. depósito en obra/mina):** Un proveedor de mantenimiento minero suele tener un depósito central en la ciudad (San Juan) y un depósito más chico en la obra o cerca de la mina. Necesita ver el stock consolidado de ambos: "tengo 3 filtros en San Juan y 2 en la mina, total 5". Y también necesita saber dónde está cada repuesto para decidir si manda uno de San Juan a la mina o compra uno nuevo.

**Trazabilidad de cada repuesto consumido:** Saber que el filtro hidráulico lote #2847 se usó en la OT #1234, en la excavadora CAT-320, el día 15/03, instalado por el técnico Juan Pérez. Esto es crítico para: garantía del repuesto (si falla, se puede rastrear el lote), auditoría de costos (cuánto se gastó en mantener cada equipo), y compliance (la minera puede pedir esta información).

**Detección de repuestos duplicados:** El mismo repuesto puede estar cargado en el sistema con distintos códigos porque vino de distintos proveedores. Ejemplo: "Filtro hidráulico Donaldson P502563" y "Filtro aceite hid. DON-P502563" son el mismo ítem pero figuran como dos artículos distintos. Esto genera errores de stock (el sistema dice que hay 0 del primero y 5 del segundo, cuando en realidad son lo mismo) y compras duplicadas.

**Proyección de necesidades basada en plan de mantenimiento futuro:** Si el plan de mantenimiento preventivo dice que el mes que viene hay 4 PMs de 500 horas y 2 PMs de 1.000 horas programados, y cada PM tiene una lista de materiales estándar (bill of materials), el sistema puede calcular automáticamente qué repuestos se van a necesitar y compararlo con el stock actual. Resultado: "Para cubrir los PMs de abril necesitás comprar: 8 filtros hidráulicos, 24 litros de aceite, 4 correas. Hoy tenés 3 filtros, 10 litros y 0 correas — pedí ya las correas porque el lead time del proveedor es de 20 días."

**✅ Lo que Trazalog ya cubre:**
- ✅ Stock con múltiples depósitos, lotes y movimientos (traz-comp-almacenes)
- ✅ Trazabilidad por QR de artículos
- ✅ Consumo de materiales por OT (Asset Planner, contra almacén legacy)
- ✅ Visibilidad multi-almacén / multi-depósito (solo en traz-comp-almacenes)

**❌ Lo que falta (oportunidades para la capa IA/MCP):**
- ❌ Puntos de pedido dinámicos (recalculados por velocidad de consumo)
- ❌ Clasificación de criticidad de repuestos (A/B/C)
- ❌ Alertas de stock bajo con lead time del proveedor considerado
- ❌ Detección de repuestos duplicados (mismo ítem con distintos códigos)
- ❌ Proyección de necesidades basada en plan de PM futuro (bill of materials × PMs programados vs. stock actual)

> 💡 **Nota importante:** Varios de estos "faltantes" no requieren cambios en el sistema base — son inteligencia que la capa de IA/MCP puede calcular encima de los datos existentes. Por ejemplo, la proyección de necesidades cruza datos del plan de PM (Asset Planner) con stock actual (Almacenes) — exactamente el tipo de consulta que el MCP puede resolver sin tocar el código del ERP.

### 2.5. Seguridad, salud y medio ambiente (HSE)

Es el área más regulada y más sensible. Las mineras evalúan a sus proveedores primero por HSE y después por todo lo demás. Un incidente de seguridad puede cerrar una operación completa, y la minera responsabiliza al contratista. Un proveedor con mal historial de seguridad directamente no entra a licitar.

**Necesidades específicas (con explicación detallada):**

**Registro de incidentes y near-misses:** Un incidente es algo que ya pasó (un accidente, una lesión, un derrame). Un near-miss (o "casi-accidente") es algo que casi pasó pero no se concretó — por ejemplo, un objeto que cayó cerca de un trabajador pero no lo golpeó. Las mineras exigen que ambos se registren formalmente porque los near-misses son predictores de accidentes futuros. Un proveedor que reporta muchos near-misses paradójicamente demuestra buena cultura de seguridad (significa que su gente está atenta y reporta), mientras que uno que no reporta ninguno probablemente está ocultando información.

**Control de habilitaciones y certificaciones del personal:** Cada persona que entra a una mina necesita tener habilitaciones vigentes: carnet de conducir especial para vehículos pesados (si aplica), capacitaciones de seguridad minera completadas (en Argentina las regulaciones provinciales exigen cursos específicos), ART (Aseguradora de Riesgos del Trabajo) vigente, exámenes médicos pre-ocupacionales al día. Si un técnico entra a la mina con una certificación vencida, el proveedor puede recibir una sanción o incluso perder el contrato. El sistema necesita alertar antes de que una habilitación venza.

**Checklist de seguridad pre-tarea (inspecciones pre-turno):** Antes de arrancar cualquier trabajo en una mina, el técnico debe completar un checklist de seguridad: ¿el área está despejada? ¿se bloquearon las fuentes de energía (lockout/tagout)? ¿se tiene el EPP correcto? ¿se identificaron los riesgos? Esto es obligatorio y auditable. Si hubo un accidente y no hay checklist firmado, la responsabilidad legal recae sobre el proveedor.

**Registro de elementos de protección personal (EPP) entregados:** Casco, guantes, lentes de seguridad, protección auditiva, botas con puntera de acero, arnés (para trabajo en altura), etc. El proveedor debe poder demostrar que entregó el EPP correcto a cada trabajador, con fecha y firma. En una auditoría, si no hay registro de entrega de EPP y hubo un accidente, es falta grave.

**Indicadores de seguridad:**
- **LTIFR (Lost Time Injury Frequency Rate):** Frecuencia de accidentes que causaron pérdida de días de trabajo. Se calcula como (número de accidentes con tiempo perdido × 1.000.000) / horas totales trabajadas. Un LTIFR bajo indica buena gestión de seguridad. Las mineras top exigen LTIFR < 1.0 a sus contratistas.
- **Near-miss rate:** Cantidad de near-misses reportados por período. Se espera que sea mayor que cero (cultura de reporte), pero con tendencia descendente (las acciones correctivas funcionan).

**Documentación lista para auditorías (ISO 45001):** Todo lo anterior debe estar documentado, ser trazable y estar disponible para cuando la minera o un auditor externo lo pida. No alcanza con "hacerlo" — hay que poder demostrarlo con registros.

**✅ Lo que Trazalog ya cubre (via módulo de Procesos BPM):**
- ✅ Motor de workflows con Bonita BPM — permite modelar cualquier flujo de negocio
- ✅ Bandejas de entrada por rol — cada persona ve solo sus tareas pendientes
- ✅ Formularios dinámicos por paso — captura de datos estructurada en cada etapa del proceso
- ✅ Pantallas custom cuando se necesite algo específico
- ✅ Audit trail completo — quién hizo qué, cuándo, con qué datos
- ✅ Trazabilidad por QR — para asociar checklists a equipos o ubicaciones

**❌ Lo que falta (diseño, no infraestructura):**
- ❌ Templates de flujos HSE pre-diseñados para minería (reporte de incidentes → investigación → acción correctiva → seguimiento)
- ❌ Template de checklist de seguridad pre-turno adaptado a minería
- ❌ Template de registro de entrega de EPP con firma
- ❌ Panel de control de habilitaciones del personal con alertas de vencimiento
- ❌ Dashboard de indicadores HSE (LTIFR, near-miss rate)

> 💡 **Nota importante:** No es necesario construir un "módulo HSE" desde cero. La infraestructura del módulo de Procesos ya resuelve el 80% — lo que falta es diseñar los flujos específicos como templates reutilizables para el sector minero. Esto puede hacerse como servicio de implementación por cliente, o como templates pre-armados incluidos en la oferta freemium.

### 2.6. Compliance y certificaciones ISO

Sin certificaciones, un proveedor no puede competir cuando las operadoras exijan estándares internacionales.

**ISO relevantes para proveedores de servicios mineros:**

| ISO | Qué exige en la práctica | Por qué importa para un proveedor minero de San Juan |
|---|---|---|
| **ISO 9001:2015** (Gestión de calidad) | Que tengas procesos documentados para lo que hacés (cómo recibís un pedido, cómo ejecutás un mantenimiento, cómo entregás un informe), que los sigas consistentemente, y que midas si funcionan bien. No exige procesos complicados — exige que los que tengas estén escritos y se cumplan. | Es la certificación "base". Muchas mineras la piden como requisito mínimo para licitar. Un proveedor sin ISO 9001 compite en desventaja frente a uno que la tiene, especialmente contra empresas chilenas que ya la tienen. |
| **ISO 14001:2015** (Gestión ambiental) | Que identifiques cómo tu operación impacta el ambiente (residuos, emisiones, consumo de recursos) y tengas un plan para minimizarlo. Incluye manejo de residuos peligrosos (aceites usados, solventes, filtros contaminados — comunes en mantenimiento mecánico). | Las mineras bajo RIGI tienen compromisos ambientales fuertes. Extienden esa exigencia a sus contratistas. El módulo RESI de Trazalog (gestión de residuos) ya cubre parte de esto. |
| **ISO 45001:2018** (Seguridad y salud) | Que tengas un sistema para identificar peligros, evaluar riesgos, y tomar acciones para prevenir accidentes. Incluye: reporte de incidentes, investigación de causas, acciones correctivas, capacitación, checklists de seguridad, entrega de EPP documentada. | Es la primera barrera de entrada en minería. Sin evidencia de gestión de seguridad, no entrás a la mina. Es la ISO que más urgentemente necesitan los proveedores sanjuaninos. |
| **ISO 55001** (Gestión de activos) | Que gestiones tus activos (equipos, herramientas, vehículos) con un enfoque de ciclo de vida: desde que los comprás hasta que los retirás, optimizando costo, rendimiento y riesgo. | Diferencial para un proveedor de mantenimiento: demuestra que no solo "arregla máquinas" sino que gestiona activos de forma profesional. Asset Planner de Trazalog cubre gran parte de esto. |
| **ISO 50001:2018** (Gestión energética) | Que midas tu consumo de energía y tengas un plan para reducirlo. | Menos urgente para un proveedor pequeño, pero relevante si la minera tiene metas de carbono neutralidad y las extiende a contratistas. |

**✅ Lo que Trazalog ya cubre para certificación ISO:**
- ✅ Procesos definidos formalmente en BPM (Bonita) — lo que el auditor llama "procedimientos documentados"
- ✅ Evidencia de ejecución de cada paso — formularios completados, timestamps, usuario responsable
- ✅ Audit trail completo — quién hizo qué, cuándo, con qué datos
- ✅ Trazabilidad por QR — vincula registros a activos físicos
- ✅ Gestión de residuos (módulo RESI) — cubre parte de ISO 14001
- ✅ Gestión de activos (Asset Planner) — cubre parte de ISO 55001

**❌ Lo que falta:**
- ❌ Templates de procesos BPM pre-diseñados para los flujos ISO más comunes en minería:
  - ISO 9001: flujo de gestión de OTs con aprobaciones y control de calidad
  - ISO 45001: flujo de reporte de incidentes → investigación → acción correctiva
  - ISO 14001: ya parcialmente cubierto con RESI, falta empaquetado
- ❌ "Kit de certificación" como producto comercial — documentación, checklist de cumplimiento, mapeo ISO ↔ funcionalidades de Trazalog

> 💡 **Oportunidad comercial:** Trazalog le da al proveedor el 70-80% de la infraestructura que un auditor ISO va a pedir. Posicionar como: *"Con Trazalog tenés la plataforma de gestión que respalda tu certificación ISO — tus procesos quedan documentados, ejecutados y trazados automáticamente."* Esto convierte a Trazalog en un **acelerador de certificación**, no solo en un software de gestión.

### 2.7. Reportes a la operadora minera

El proveedor no trabaja para sí mismo — trabaja para la minera. Y la minera exige informes periódicos.

**Reportes típicos que una minera exige a un contratista de mantenimiento:**
- Informe semanal/mensual de gestión: OTs completadas, pendientes, KPIs
- Informe de disponibilidad de equipos intervenidos
- Registro de horas-hombre por equipo y por tipo de trabajo
- Consumo de repuestos y materiales con costos
- Informe de incidentes HSE
- Evidencia de cumplimiento de plan de mantenimiento preventivo
- Documentación de capacitaciones realizadas al personal

**✅ Lo que Trazalog ya cubre:**
- ✅ Motor de reportes (KoolReport) con datos de producción
- ✅ Los datos para generar todos estos informes ya existen en el sistema (OTs, tiempos, KPIs, equipos)

**❌ Lo que falta:**
- ❌ Los reportes actuales no están orientados al formato que la minera pide — son reportes internos, no informes para el cliente
- ❌ No hay un "generador de informe para la minera" con un click o una consulta
- ❌ Los informes no se exportan en formatos profesionales listos para enviar

> 💡 **Oportunidad estrella para el MCP:** Este es probablemente el feature con mayor wow-factor. El proveedor le dice a la IA: *"Armame el informe semanal para Barrick"* y la IA cruza OTs completadas, horas-hombre, repuestos consumidos, KPIs de disponibilidad, y genera un borrador profesional listo para enviar. Hoy el proveedor arma esto a mano en Word/Excel en 2-3 horas. Con el MCP lo tiene en 30 segundos.

---

## 3. Mapeo: Necesidades del sector vs. Capacidades actuales de Trazalog

| Necesidad | Módulo actual | Estado | Gap |
|---|---|---|---|
| Catálogo de activos con criticidad | Asset Planner | ✅ Maduro | Falta distinción equipo propio vs. del cliente |
| OTs correctivas/preventivas/predictivas | Asset Planner | ✅ Maduro | Ciclo completo con timestamps, consumo de materiales (contra ALM legacy). Gap: falta firma/validación del cliente, y faltan APIs WSO2 para exponer vía MCP |
| Stock de repuestos | Almacenes (traz-comp) + Almacén legacy (Asset Planner) | ⚠️ Duplicado | Dos almacenes no integrados. MVP: fuentes separadas. Clientes nuevos van directo a traz-comp-almacenes. Unificación en v4 |
| Trazabilidad QR | Códigos/QR | ✅ Funcional | Listo para uso en minería |
| BPM / Workflows | BPM (Bonita) | ✅ Funcional | Podría modelar flujos de aprobación de OTs |
| Formularios dinámicos | Formularios | ✅ Funcional | Base para checklists de seguridad |
| KPIs de mantenimiento | Asset Planner (dashboard) | ✅ Maduro | Ya calcula Disponibilidad, MTBF, MTTR, MTTF, Confiabilidad, ratio Preventivo/Correctivo/Backlog, Equipos Operativos. Solo faltan OEE y PM Compliance (calculables con datos existentes) |
| HSE (incidentes, habilitaciones, EPP) | Procesos (BPM) + Formularios | ✅ Infraestructura lista | Falta diseñar templates de flujos HSE específicos para minería (incidentes, inspecciones pre-turno, EPP) |
| Certificaciones ISO (trazabilidad para auditoría) | Procesos (BPM) + Audit trail + QR + RESI | ✅ Fortaleza subestimada | Falta "empaquetado" comercial: templates de procesos ISO pre-diseñados para minería |
| Reportes para la minera | KoolReport | ⚠️ Parcial | No están orientados al formato que pide la minera |
| Gestión multi-sitio / multi-cliente | Multi-empresa | ✅ Funcional | Adaptar para modelo proveedor → múltiples mineras |

---

## 4. Oportunidades de alto valor para la capa MCP / IA

Basado en las necesidades identificadas, estos son los casos de uso donde la IA puede dar valor inmediato a un proveedor de mantenimiento minero, ordenados por impacto estimado:

### Impacto ALTO (resuelve dolor diario)

1. **"¿Qué equipos tienen preventivo vencido?"** — Consulta que el jefe de mantenimiento hace todos los días. Hoy revisa planilla o sistema. Con MCP, lo pregunta y obtiene respuesta instantánea con prioridad por criticidad.

2. **"Armame el informe semanal para la minera"** — El proveedor pierde horas armando el informe que la minera exige. La IA cruza OTs, horas-hombre, repuestos, KPIs y genera un borrador listo para enviar.

3. **"¿Qué repuestos necesito comprar para cubrir los PMs del próximo mes?"** — Cruza plan de mantenimiento + stock actual + consumo histórico. Evita el stockout que para una máquina.

4. **"¿Cuál es mi ratio preventivo/correctivo?"** — KPI que las mineras preguntan. Si el proveedor no lo sabe, pierde credibilidad. La IA lo calcula en tiempo real.

### Impacto MEDIO (mejora gestión estratégica)

5. **"¿Qué equipos son los más problemáticos?"** — Top N de equipos por cantidad de correctivos, costo de mantenimiento, tiempo fuera de servicio. Permite priorizar inversión.

6. **"Detectá puntos de pedido que necesitan ajustarse"** — Compara punto de pedido configurado vs. consumo real y alerta si hay riesgo de stockout o sobrestock.

7. **"¿Tengo técnicos con habilitaciones por vencer?"** — Alertas de certificaciones que se vencen antes de que la minera audite.

8. **"¿Cuánto estoy gastando en mantenimiento por equipo?"** — MC/RAV por activo para decidir si reparar o reemplazar.

### Impacto FUTURO (requiere más datos)

9. **Mantenimiento predictivo real** — Cuando haya suficiente historial de lecturas y fallas, predecir cuándo va a fallar un equipo.

10. **Benchmarking entre clientes** — Comparar rendimiento de equipos similares entre distintas operaciones (requiere volumen de clientes).

---

## 5. Recomendaciones para el backlog v3

### Para el MVP (3-4 meses):
- El MCP debe exponer como mínimo: equipos, OTs, preventivos, stock, historial, y KPIs (disponibilidad, MTBF, MTTR, ratio prev/correc)
- Los prompt templates deben estar orientados a los 4 casos de impacto ALTO
- El "informe para la minera" generado por IA es probablemente el feature con mayor wow-factor para vender

### Para la segunda ola:
- Módulo HSE básico (incidentes + habilitaciones) como diferencial competitivo
- Templates de compliance ISO como gancho de adquisición ("con Trazalog tenés el 70% de lo que necesitás para certificar ISO 9001")
- Agentes proactivos que alerten antes de que la minera pregunte

### Consideración técnica:

**Prerequisito #1 — Generación de APIs WSO2 para Asset Planner:**
Asset Planner tiene la lógica de negocio completa en los models de CodeIgniter (queries para equipos, OTs, preventivos, predictivos, lecturas, KPIs, consumo de materiales, etc.), pero la mayoría no está expuesta como APIs WSO2. Algunas APIs ya se generaron, pero la cobertura es parcial. Antes de construir el MCP, hay que:
1. Relevar los models de CodeIgniter de Asset Planner para identificar todos los queries relevantes
2. Mapear qué APIs WSO2 ya existen y qué datos exponen
3. Generar las APIs faltantes en WSO2, priorizando: equipos/activos, OTs (CRUD + estados), preventivos (programación + vencimientos), historial de intervenciones, y KPIs (disponibilidad, MTBF, MTTR, MTTF, confiabilidad, ratio prev/correc)
4. Para traz-comp-almacenes: relevar APIs existentes (probablemente más completas por estar ya migrado a Tools)

**Prerequisito #2 — Decisión arquitectónica: APIs vs SQL directo:**
Para datos CRUD (listar equipos, consultar OTs, ver stock) las APIs WSO2 son el camino natural — ya existe la capa y mantiene la seguridad y segregación por empresa. Para KPIs calculados y cruces de datos complejos, evaluar si conviene que el MCP ejecute queries SQL directas al modelo de datos. Ventaja del SQL directo: más rápido de implementar, no requiere replicar lógica de cálculo en una API. Desventaja: acopla el MCP al esquema de base de datos interno, cualquier cambio de modelo rompe el MCP. Recomendación: usar APIs para CRUD y SQL directo (read-only, con usuario de base de datos restringido) para KPIs y consultas analíticas complejas.

### ⚠️ Deuda técnica crítica: Almacenes duplicados (Asset Planner vs. traz-comp-almacenes)

**Situación actual:** Existen dos módulos de almacén independientes. `traz-comp-almacenes` es el módulo migrado a Tools, con soporte multi-empresa, multi-establecimiento, multi-depósito y lotes. Asset Planner tiene su propio almacén legacy (versión original, sin multi-establecimiento ni multi-depósito). Los datos no están integrados entre ambos.

**Impacto en el MCP:** Cuando la IA necesite cruzar datos de mantenimiento (OTs, preventivos, equipos — que viven en Asset Planner) con datos de inventario de repuestos, necesita saber de qué almacén tirar. Si el MCP consulta el almacén de Asset Planner, obtiene datos incompletos y sin las capacidades avanzadas de traz-comp-almacenes. Si consulta traz-comp-almacenes, los repuestos podrían no estar ahí si el cliente cargó todo en Asset Planner.

**Decisión para el MVP:** No migrar. En su lugar, adoptar una estrategia de **fuentes separadas**: el MCP consulta Asset Planner para todo lo referido a mantenimiento (equipos, OTs, preventivos, predictivos, lecturas, KPIs) y consulta traz-comp-almacenes para todo lo referido a inventario (stock, artículos, depósitos, movimientos, puntos de pedido). Este modelo ya está validado en producción: Tierra Capayán opera con Asset Planner por un lado y traz-comp-almacenes por otro, sin integración entre ambos, y funciona. Los clientes nuevos (como el primer proveedor minero) se onboardean directamente en traz-comp-almacenes para su stock de repuestos, evitando la duplicación desde el inicio.

**Riesgos de esta decisión:**
- Los cruces automáticos "consumo de repuesto por OT" no funcionarán nativamente si el cliente usa almacenes distintos para cada sistema. Estos cruces requerirán lógica custom en el MCP o intervención manual.
- Si se suman más clientes que ya usan Asset Planner con su almacén propio, la deuda crece.

**Recomendación post-MVP — Paso intermedio (v3.1): Integración vía APIs sin migración completa:**
Antes de migrar todo Asset Planner a Tools, un paso intermedio más ágil sería hacer que Asset Planner consuma traz-comp-almacenes vía APIs para el manejo de stock de repuestos. Esto requiere:
1. Migrar los datos del ALM legacy que funciona dentro de Asset Planner al modelo de traz-comp-almacenes
2. Modificar Asset Planner para que las operaciones de stock (consulta, consumo por OT, movimientos) llamen a las APIs de traz-comp-almacenes en lugar de su almacén interno
3. Mantener el resto de Asset Planner (equipos, OTs, preventivos, KPIs) funcionando como está

**Recomendación post-MVP — Paso completo (v4): Migración de Asset Planner a Tools:**
1. Mapear las entidades de almacén de Asset Planner al modelo de traz-comp-almacenes (si no se hizo en v3.1)
2. Migrar el resto de entidades de Asset Planner a la estructura de traz-tools
3. Reapuntar las referencias de Asset Planner (OTs, preventivos, backlog) al almacén unificado
4. Deprecar el almacén legacy de Asset Planner y el proyecto separado

Esta unificación es un prerequisito para que los features de IA de mayor valor (recomendación de compra de repuestos basada en plan de PM, detección de puntos de pedido, proyección de necesidades) funcionen con datos integrados en clientes existentes.

---

*Investigación realizada: 22 de marzo de 2026*
*Fuentes: Tractian, MaintainX, Accruent, DimoMaint, Opsima, CAPRIMSA, Acero y Roca, Infobae, Gobierno de San Juan, Fundar, entre otras.*
