-- =============================================================================
-- 035 - Textos y temas definidos por el PM (Gate 2, AGENTE-M-07)
-- =============================================================================
-- Idempotente. Rollback: 035-textos-pm.rollback.sql
--
-- Entregado por el PM el 2026-11-24 (insumos: bloques 1, 2, 4 y 5 del taller de
-- personajes). Este script:
--   * saca de la personalidad de los tres agentes el "español argentino, de vos":
--     ahora hablan el español del pais del usuario (bloque (D) de cada uno, que
--     esta en prompts/*.md);
--   * reemplaza la agenda de Faustino por la tabla del PM (bloque 2): 44 temas
--     por industria. Los temas viejos que el PM renombro conservan su id (y lo
--     ya capturado); los que no estan en su tabla quedan 'descartado' si
--     estaban pendientes (no se borran: lo capturado se conserva).
--
-- La prioridad de cada tema es la del PM ('seed') mas lo que ya hubiera sumado
-- el recalculo con datos reales (ots, huecos).
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- --------------------------------------------------------------- personalidad
UPDATE agente.agente SET personalidad =
    'Sos Quirqui, un quirquincho que trabaja en la operacion, codo a codo con el '
    'equipo. Calido y practico, con frases cortas. Siempre ofreces el siguiente paso concreto.'
 WHERE clave = 'quirqui';
UPDATE agente.agente SET personalidad =
    'Sos Kuntur, un condor que ve la operacion desde arriba y acompaña al '
    'administrador. Directo y con datos, sin rodeos. Propones, nunca ordenas; y '
    'cuando algo no funciono, lo decis.'
 WHERE clave = 'kuntur';
UPDATE agente.agente SET personalidad =
    'Sos Faustino, un entrevistador con oficio de maestro: curioso, respetuoso y '
    'paciente. Repreguntas y pedis ejemplos concretos; nunca apuras ni completas '
    'lo que el experto no dijo.'
 WHERE clave = 'faustino';

-- ------------------------------------------- temas que el PM renombro (mismo id)

UPDATE agente.tema SET nombre = 'Equipos móviles de mina', fec_mod = now()
 WHERE nombre = 'Equipos móviles' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Equipos móviles de mina');
UPDATE agente.tema SET nombre = 'Aparatos de bombeo mecánico', fec_mod = now()
 WHERE nombre = 'Bombeo mecánico y pozos' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Aparatos de bombeo mecánico');
UPDATE agente.tema SET nombre = 'Compresión de gas', fec_mod = now()
 WHERE nombre = 'Compresores' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Compresión de gas');
UPDATE agente.tema SET nombre = 'Plantas de tratamiento', fec_mod = now()
 WHERE nombre = 'Separadores, tanques y baterías' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Plantas de tratamiento');
UPDATE agente.tema SET nombre = 'Ductos y cañerías', fec_mod = now()
 WHERE nombre = 'Integridad de ductos' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Ductos y cañerías');
UPDATE agente.tema SET nombre = 'Líneas aéreas', fec_mod = now()
 WHERE nombre = 'Líneas de transmisión y distribución' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Líneas aéreas');
UPDATE agente.tema SET nombre = 'Protecciones y control', fec_mod = now()
 WHERE nombre = 'Protecciones y maniobras' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Protecciones y control');
UPDATE agente.tema SET nombre = 'Generación', fec_mod = now()
 WHERE nombre = 'Generación: grupos electrógenos y turbinas' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Generación');
UPDATE agente.tema SET nombre = 'Transformadores', fec_mod = now()
 WHERE nombre = 'Transformadores y subestaciones' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Transformadores');

-- --------------------------------------------- la tabla del PM, tal cual
-- upsert_tema(nombre, padre, descripcion, modulo, tipo_equipo, situacion, prioridad)
SELECT agente.upsert_tema('Seguridad en tareas de mantenimiento', NULL, 'Bloqueo de energías, permisos de trabajo y riesgos típicos de cada tarea', 'general', NULL, NULL, 95);
SELECT agente.upsert_tema('Normativa y cumplimiento', NULL, 'Exigencias legales y de los clientes que hay que cumplir y demostrar', 'general', NULL, NULL, 70);
SELECT agente.upsert_tema('Documentación y auditorías', NULL, 'Qué registros se llevan y cómo se preparan las auditorías', 'general', NULL, NULL, 60);
SELECT agente.upsert_tema('Planificación y programación', NULL, 'Cómo se arma el plan semanal y se priorizan las órdenes de trabajo', 'man', NULL, NULL, 80);
SELECT agente.upsert_tema('Diagnóstico de fallas', NULL, 'Cómo se busca la causa de una falla y qué señales la anticipan', 'man', NULL, NULL, 80);
SELECT agente.upsert_tema('Lubricación', NULL, 'Rutas, frecuencias, tipos de lubricante y errores comunes', 'man', NULL, NULL, 75);
SELECT agente.upsert_tema('Bombeo e hidráulica', NULL, 'Fallas y cuidados de bombas, sellos, mangueras y circuitos hidráulicos', 'man', 'bomba', NULL, 75);
SELECT agente.upsert_tema('Mantenimiento predictivo', NULL, 'Vibraciones, temperatura y análisis de aceite para anticipar fallas', 'man', NULL, NULL, 70);
SELECT agente.upsert_tema('Sistemas eléctricos y de potencia', NULL, 'Motores, tableros, arrancadores y puesta a tierra', 'man', 'motor eléctrico, tablero', NULL, 70);
SELECT agente.upsert_tema('Flota y vehículos de apoyo', NULL, 'Mantenimiento de vehículos livianos y equipos de apoyo', 'man', 'camioneta, grúa, hidroelevador', NULL, 65);
SELECT agente.upsert_tema('Repuestos críticos', NULL, 'Qué repuestos no pueden faltar y cómo se define el mínimo', 'alm', NULL, NULL, 80);
SELECT agente.upsert_tema('Pedidos y reposición', NULL, 'Cuándo y cuánto pedir, y cómo se sigue un pedido', 'alm', NULL, NULL, 75);
SELECT agente.upsert_tema('Almacenamiento de sustancias peligrosas', NULL, 'Separación, rotulado, contención y hojas de seguridad', 'alm', NULL, NULL, 75);
SELECT agente.upsert_tema('Recepción y control de materiales', NULL, 'Qué se revisa cuando llega un material y cómo se rechaza', 'alm', NULL, NULL, 70);
SELECT agente.upsert_tema('Trazabilidad de materiales', NULL, 'Lotes, vencimientos y seguimiento de dónde fue cada material', 'alm', NULL, NULL, 65);
SELECT agente.upsert_tema('Pañol y herramientas', NULL, 'Préstamos, devoluciones, calibración y certificaciones de herramientas', 'alm', 'herramienta', NULL, 65);
SELECT agente.upsert_tema('Chancado y molienda', NULL, 'Reducción de tamaño del mineral: equipos, desgastes y paradas', 'man', NULL, NULL, 85);
SELECT agente.upsert_tema('Transporte de material', NULL, 'Movimiento del mineral entre la mina y la planta', 'man', NULL, NULL, 80);
SELECT agente.upsert_tema('Perforación', NULL, 'Aceros de perforación, compresor de a bordo y sistema hidráulico', 'man', 'perforadora', NULL, 75);
SELECT agente.upsert_tema('Planta de proceso', NULL, 'Equipos de clasificación, flotación, espesado, filtrado y lixiviación', 'man', 'zaranda, celda de flotación, espesador, filtro', NULL, 75);
SELECT agente.upsert_tema('Relaves y manejo de agua', NULL, 'Bombeo de relaves, cañerías y recuperación de agua', 'man', 'bomba de pulpa, cañería', NULL, 30);
SELECT agente.upsert_tema('Neumáticos gigantes', NULL, 'Control de presión, rotación y cambio en camiones y cargadores', 'man', 'neumático', NULL, 25);
SELECT agente.upsert_tema('Equipos de superficie de pozo', NULL, 'Equipos que mantienen el pozo produciendo', 'man', NULL, NULL, 60);
SELECT agente.upsert_tema('Compresión de gas', NULL, 'Mantenimiento de compresores y de los motores que los mueven', 'man', 'compresor, motor a gas', NULL, 55);
SELECT agente.upsert_tema('Ductos y cañerías', NULL, 'Integridad, protección contra la corrosión y limpieza interna', 'man', 'ducto', NULL, 55);
SELECT agente.upsert_tema('Plantas de tratamiento', NULL, 'Separación de petróleo, gas y agua, y cuidado de tanques', 'man', 'separador, tanque, calentador', NULL, 50);
SELECT agente.upsert_tema('Medición e instrumentación', NULL, 'Calibración de medidores y prueba de válvulas de seguridad', 'man', 'caudalímetro, válvula de seguridad', NULL, 45);
SELECT agente.upsert_tema('Equipos de perforación y reparación de pozos', NULL, 'Mantenimiento de equipos de torre y sus componentes', 'man', 'equipo de torre', NULL, 25);
SELECT agente.upsert_tema('Subestaciones', NULL, 'Maniobras, mantenimiento de interruptores y celdas de media tensión', 'man', 'interruptor, seccionador, celda', NULL, 60);
SELECT agente.upsert_tema('Transformadores', NULL, 'Análisis de aceite, pérdidas, ensayos y recambio', 'man', 'transformador', NULL, 60);
SELECT agente.upsert_tema('Líneas aéreas', NULL, 'Recorridas, poda, cambio de aisladores y franja de servidumbre', 'man', 'poste, torre, conductor, aislador', NULL, 55);
SELECT agente.upsert_tema('Protecciones y control', NULL, 'Ensayo de relés, baterías y telecontrol', 'man', 'relé, banco de baterías', NULL, 50);
SELECT agente.upsert_tema('Redes subterráneas', NULL, 'Localización de fallas, empalmes y terminales', 'man', 'cable, empalme', NULL, 45);
SELECT agente.upsert_tema('Medición', NULL, 'Instalación, contraste y recambio de medidores', 'man', 'medidor', NULL, 40);
SELECT agente.upsert_tema('Generación', NULL, 'Limpieza de paneles, inversores y mantenimiento de grupos', 'man', 'parque solar, grupo electrógeno', NULL, 25);
SELECT agente.upsert_tema('Chancadoras', 'Chancado y molienda', 'Cambio de revestimientos, ajustes y fallas típicas', 'man', 'chancadora', NULL, 90);
SELECT agente.upsert_tema('Molinos', 'Chancado y molienda', 'Revestimientos, sistema de accionamiento y lubricación', 'man', 'molino', NULL, 85);
SELECT agente.upsert_tema('Cintas transportadoras', 'Transporte de material', 'Alineación, empalmes, rodillos y limpieza de la cinta', 'man', 'cinta transportadora', NULL, 85);
SELECT agente.upsert_tema('Equipos móviles de mina', 'Transporte de material', 'Mantenimiento de camiones, palas y cargadores de mina', 'man', 'camión, pala, cargador', NULL, 85);
SELECT agente.upsert_tema('Aparatos de bombeo mecánico', 'Equipos de superficie de pozo', 'Balanceo, caja reductora, correas y vástago', 'man', 'aparato de bombeo', NULL, 60);
SELECT agente.upsert_tema('Bombas electrosumergibles', 'Equipos de superficie de pozo', 'Tablero, variador y señales de falla del equipo de fondo', 'man', 'bomba electrosumergible', NULL, 50);
SELECT agente.upsert_tema('Cabezas de pozo y válvulas', 'Equipos de superficie de pozo', 'Pérdidas, engrase y prueba de válvulas', 'man', 'cabeza de pozo, válvula', NULL, 50);

-- Industria de cada tema (upsert_tema no la recibe).
UPDATE agente.tema SET vertical = 'general', fec_mod = now() WHERE nombre IN ('Seguridad en tareas de mantenimiento', 'Normativa y cumplimiento', 'Documentación y auditorías', 'Planificación y programación', 'Diagnóstico de fallas', 'Lubricación', 'Bombeo e hidráulica', 'Mantenimiento predictivo', 'Sistemas eléctricos y de potencia', 'Flota y vehículos de apoyo', 'Repuestos críticos', 'Pedidos y reposición', 'Almacenamiento de sustancias peligrosas', 'Recepción y control de materiales', 'Trazabilidad de materiales', 'Pañol y herramientas');
UPDATE agente.tema SET vertical = 'mineria', fec_mod = now() WHERE nombre IN ('Chancado y molienda', 'Transporte de material', 'Perforación', 'Planta de proceso', 'Relaves y manejo de agua', 'Neumáticos gigantes', 'Chancadoras', 'Molinos', 'Cintas transportadoras', 'Equipos móviles de mina');
UPDATE agente.tema SET vertical = 'oil_gas', fec_mod = now() WHERE nombre IN ('Equipos de superficie de pozo', 'Compresión de gas', 'Ductos y cañerías', 'Plantas de tratamiento', 'Medición e instrumentación', 'Equipos de perforación y reparación de pozos', 'Aparatos de bombeo mecánico', 'Bombas electrosumergibles', 'Cabezas de pozo y válvulas');
UPDATE agente.tema SET vertical = 'electricidad', fec_mod = now() WHERE nombre IN ('Subestaciones', 'Transformadores', 'Líneas aéreas', 'Protecciones y control', 'Redes subterráneas', 'Medición', 'Generación');

-- Prioridad: la del PM mas lo que ya sumaron los datos reales.
UPDATE agente.tema
   SET prioridad = round((origen_prioridad->>'seed')::numeric
                         + COALESCE((origen_prioridad->>'ots')::numeric, 0)
                         + COALESCE((origen_prioridad->>'huecos')::numeric, 0), 2),
       fec_mod = now()
 WHERE nombre IN ('Seguridad en tareas de mantenimiento', 'Normativa y cumplimiento', 'Documentación y auditorías', 'Planificación y programación', 'Diagnóstico de fallas', 'Lubricación', 'Bombeo e hidráulica', 'Mantenimiento predictivo', 'Sistemas eléctricos y de potencia', 'Flota y vehículos de apoyo', 'Repuestos críticos', 'Pedidos y reposición', 'Almacenamiento de sustancias peligrosas', 'Recepción y control de materiales', 'Trazabilidad de materiales', 'Pañol y herramientas', 'Chancado y molienda', 'Chancadoras', 'Molinos', 'Transporte de material', 'Cintas transportadoras', 'Equipos móviles de mina', 'Perforación', 'Planta de proceso', 'Relaves y manejo de agua', 'Neumáticos gigantes', 'Equipos de superficie de pozo', 'Aparatos de bombeo mecánico', 'Bombas electrosumergibles', 'Cabezas de pozo y válvulas', 'Compresión de gas', 'Ductos y cañerías', 'Plantas de tratamiento', 'Medición e instrumentación', 'Equipos de perforación y reparación de pozos', 'Subestaciones', 'Transformadores', 'Líneas aéreas', 'Protecciones y control', 'Redes subterráneas', 'Medición', 'Generación');

-- Lo que no esta en la tabla del PM: deja de preguntarse (no se borra).
UPDATE agente.tema SET estado = 'descartado', fec_mod = now()
 WHERE nombre NOT IN ('Seguridad en tareas de mantenimiento', 'Normativa y cumplimiento', 'Documentación y auditorías', 'Planificación y programación', 'Diagnóstico de fallas', 'Lubricación', 'Bombeo e hidráulica', 'Mantenimiento predictivo', 'Sistemas eléctricos y de potencia', 'Flota y vehículos de apoyo', 'Repuestos críticos', 'Pedidos y reposición', 'Almacenamiento de sustancias peligrosas', 'Recepción y control de materiales', 'Trazabilidad de materiales', 'Pañol y herramientas', 'Chancado y molienda', 'Chancadoras', 'Molinos', 'Transporte de material', 'Cintas transportadoras', 'Equipos móviles de mina', 'Perforación', 'Planta de proceso', 'Relaves y manejo de agua', 'Neumáticos gigantes', 'Equipos de superficie de pozo', 'Aparatos de bombeo mecánico', 'Bombas electrosumergibles', 'Cabezas de pozo y válvulas', 'Compresión de gas', 'Ductos y cañerías', 'Plantas de tratamiento', 'Medición e instrumentación', 'Equipos de perforación y reparación de pozos', 'Subestaciones', 'Transformadores', 'Líneas aéreas', 'Protecciones y control', 'Redes subterráneas', 'Medición', 'Generación') AND estado = 'pendiente';

INSERT INTO agente.schema_version (script, descripcion)
VALUES ('035-textos-pm', 'Personalidad sin "de vos" fijo y agenda de Faustino de la tabla del PM (44 temas por industria)')
ON CONFLICT (script) DO UPDATE SET aplicado_en = now();

COMMIT;
