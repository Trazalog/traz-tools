-- Rollback de 035. Vuelve a poner la personalidad de 011, reabre los temas que
-- 035 descarto y deja la agenda como la dejan 010 y 034 (reaplicarlos despues).
-- Los temas nuevos de la tabla del PM que no tienen nada capturado se borran.
\set ON_ERROR_STOP on
BEGIN;
UPDATE agente.agente SET personalidad =
    'Sos Quirqui, un quirquincho que trabaja en la operacion, codo a codo con el '
    'equipo. Hablas en español argentino, de vos, calido y practico, con frases '
    'cortas. Siempre ofreces el siguiente paso concreto.' WHERE clave = 'quirqui';
UPDATE agente.agente SET personalidad =
    'Sos Kuntur, un condor que ve la operacion desde arriba y acompaña al '
    'administrador. Hablas en español argentino, de vos, directo y con datos, sin '
    'rodeos. Propones, nunca ordenas; y cuando algo no funciono, lo decis.' WHERE clave = 'kuntur';
UPDATE agente.agente SET personalidad =
    'Sos Faustino, un entrevistador con oficio de maestro: curioso, respetuoso y '
    'paciente. Hablas en español argentino, de vos. Repreguntas y pedis ejemplos '
    'concretos; nunca apuras ni completas lo que el experto no dijo.' WHERE clave = 'faustino';
UPDATE agente.tema SET nombre = 'Equipos móviles' WHERE nombre = 'Equipos móviles de mina' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Equipos móviles');
UPDATE agente.tema SET nombre = 'Bombeo mecánico y pozos' WHERE nombre = 'Aparatos de bombeo mecánico' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Bombeo mecánico y pozos');
UPDATE agente.tema SET nombre = 'Compresores' WHERE nombre = 'Compresión de gas' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Compresores');
UPDATE agente.tema SET nombre = 'Separadores, tanques y baterías' WHERE nombre = 'Plantas de tratamiento' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Separadores, tanques y baterías');
UPDATE agente.tema SET nombre = 'Integridad de ductos' WHERE nombre = 'Ductos y cañerías' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Integridad de ductos');
UPDATE agente.tema SET nombre = 'Líneas de transmisión y distribución' WHERE nombre = 'Líneas aéreas' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Líneas de transmisión y distribución');
UPDATE agente.tema SET nombre = 'Protecciones y maniobras' WHERE nombre = 'Protecciones y control' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Protecciones y maniobras');
UPDATE agente.tema SET nombre = 'Generación: grupos electrógenos y turbinas' WHERE nombre = 'Generación' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Generación: grupos electrógenos y turbinas');
UPDATE agente.tema SET nombre = 'Transformadores y subestaciones' WHERE nombre = 'Transformadores' AND NOT EXISTS (SELECT 1 FROM agente.tema WHERE nombre = 'Transformadores y subestaciones');
UPDATE agente.tema SET estado = 'pendiente' WHERE estado = 'descartado' AND nombre NOT IN ('Seguridad en tareas de mantenimiento', 'Normativa y cumplimiento', 'Documentación y auditorías', 'Planificación y programación', 'Diagnóstico de fallas', 'Lubricación', 'Bombeo e hidráulica', 'Mantenimiento predictivo', 'Sistemas eléctricos y de potencia', 'Flota y vehículos de apoyo', 'Repuestos críticos', 'Pedidos y reposición', 'Almacenamiento de sustancias peligrosas', 'Recepción y control de materiales', 'Trazabilidad de materiales', 'Pañol y herramientas', 'Chancado y molienda', 'Chancadoras', 'Molinos', 'Transporte de material', 'Cintas transportadoras', 'Equipos móviles de mina', 'Perforación', 'Planta de proceso', 'Relaves y manejo de agua', 'Neumáticos gigantes', 'Equipos de superficie de pozo', 'Aparatos de bombeo mecánico', 'Bombas electrosumergibles', 'Cabezas de pozo y válvulas', 'Compresión de gas', 'Ductos y cañerías', 'Plantas de tratamiento', 'Medición e instrumentación', 'Equipos de perforación y reparación de pozos', 'Subestaciones', 'Transformadores', 'Líneas aéreas', 'Protecciones y control', 'Redes subterráneas', 'Medición', 'Generación');
DELETE FROM agente.tema t
 WHERE t.nombre IN ('Seguridad en tareas de mantenimiento', 'Normativa y cumplimiento', 'Documentación y auditorías', 'Planificación y programación', 'Diagnóstico de fallas', 'Lubricación', 'Bombeo e hidráulica', 'Mantenimiento predictivo', 'Sistemas eléctricos y de potencia', 'Flota y vehículos de apoyo', 'Repuestos críticos', 'Pedidos y reposición', 'Almacenamiento de sustancias peligrosas', 'Recepción y control de materiales', 'Trazabilidad de materiales', 'Pañol y herramientas', 'Chancado y molienda', 'Chancadoras', 'Molinos', 'Transporte de material', 'Cintas transportadoras', 'Equipos móviles de mina', 'Perforación', 'Planta de proceso', 'Relaves y manejo de agua', 'Neumáticos gigantes', 'Equipos de superficie de pozo', 'Aparatos de bombeo mecánico', 'Bombas electrosumergibles', 'Cabezas de pozo y válvulas', 'Compresión de gas', 'Ductos y cañerías', 'Plantas de tratamiento', 'Medición e instrumentación', 'Equipos de perforación y reparación de pozos', 'Subestaciones', 'Transformadores', 'Líneas aéreas', 'Protecciones y control', 'Redes subterráneas', 'Medición', 'Generación')
   AND t.nombre NOT IN ('Chancado y molienda', 'Chancadoras', 'Molinos', 'Transporte de material', 'Cintas transportadoras', 'Bombeo e hidráulica', 'Sistemas eléctricos y de potencia', 'Lubricación', 'Mantenimiento predictivo', 'Planificación y programación', 'Diagnóstico de fallas', 'Repuestos críticos', 'Recepción y control de materiales', 'Almacenamiento de sustancias peligrosas', 'Trazabilidad de materiales', 'Pedidos y reposición', 'Seguridad en tareas de mantenimiento', 'Normativa y cumplimiento', 'Documentación y auditorías', 'Equipos móviles de mina', 'Aparatos de bombeo mecánico', 'Compresión de gas', 'Plantas de tratamiento', 'Ductos y cañerías', 'Líneas aéreas', 'Protecciones y control', 'Generación', 'Transformadores')
   AND NOT EXISTS (SELECT 1 FROM agente.sesion_entrevista s WHERE s.tema_id = t.tema_id)
   AND NOT EXISTS (SELECT 1 FROM agente.tema h WHERE h.tema_padre_id = t.tema_id);
DELETE FROM agente.schema_version WHERE script = '035-textos-pm';
COMMIT;
-- Despues: psql -f 010-seed-taxonomia.sql y psql -f 034-taxonomia-verticales.sql
-- para volver padres, descripciones y prioridades a como estaban.
