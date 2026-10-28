# ADR-015 — Mecanismo único de avisos de Tools (esquema `ntf`)

- **Estado:** Aceptado
- **Fecha:** 2026-10-28
- **Contexto de decisión:** pedido del PM ("traer el mecanismo de AssetPlanner como el mecanismo de Tools, mejorado; colas en MariaDB y en PostgreSQL; los agentes solo en PostgreSQL; minimizar objetos nuevos en MariaDB, que a futuro se quiere eliminar") y aprobación del diseño el mismo día
- **Relacionado:** ADR-009 (identidad por JWT), ADR-A6 (avisos de los agentes, Opción C de E0), ADR-A10 (token de máquina)
- **Diseño completo:** [`doc/notificaciones/diseno-avisos-tools.md`](../notificaciones/diseno-avisos-tools.md)

---

## Contexto

Había dos mecanismos de avisos y ninguno completo:

- **AssetPlanner** (MariaDB, en producción): triggers → `synch_notificacion_queue` → Siddhi → `FirebaseConnectorAPI` → Firebase. **Nunca marca "enviado"** (el `.siddhi` busca el id en la respuesta de Firebase, que no lo trae), no depura la cola, lleva el token del dispositivo dentro del aviso, la campanita filtra sin empresa, y el `.siddhi` de producción tiene credenciales de root en claro.
- **Los agentes** (PostgreSQL, rama `develop-v3.5`): una cola propia en la base del agente, con un transporte en borrador que reenviaba duplicados.

Tools no tenía campanita, y obtenía el token del navegador pero lo descartaba.

## Decisión

1. **PostgreSQL es la cola canónica de todo el sistema**, en la base de Tools (`trazalog_tools`), esquema **`ntf`** (tres letras, como el resto de los esquemas salvo `core`).
2. **Crear un aviso es una sola operación** (`ntf.publicar()`), expuesta por el API (WSO2 MI). La usan los módulos PHP, los agentes (con su token de máquina), Bonita y el puente de MariaDB.
3. **MariaDB queda solo como entrada, sin objetos nuevos.** Un puente Siddhi lee `synch_notificacion_queue` por `queue_id`, publica en `ntf` y marca `procesado` con la columna existente. Reemplaza al Siddhi actual de AssetPlanner. Se elimina cuando Mantenimiento migre a `traz-tools-man`.
4. **Un solo transporte de push** (Siddhi sobre `ntf`), que **toma** los envíos marcándolos en la misma sentencia (`FOR UPDATE SKIP LOCKED`): nunca manda dos veces. Credenciales por datasource del SI, nunca en el `.siddhi`.
5. **Depuración diaria**: envíos terminados a los 30 días, avisos leídos a los 90.
6. **`FirebaseConnectorAPI` devuelve el error real** (5xx si falla, 410 si el token ya no existe).
7. **La campanita va en el layout de Tools, para todos los usuarios.**
8. Las tablas de avisos del esquema `agente` (`notificacion`, `envio`, `dispositivo`, `destinatario_alerta`) **se reemplazan** por `ntf`.

## Por qué

- **Un emisor, una campanita, una cola**: dos mecanismos divergen y duplican push.
- **PostgreSQL** es donde va Tools; MariaDB se quiere apagar. Con MariaDB solo como entrada, apagarla es borrar el puente.
- **Publicar como operación del API** cumple "la lógica va en las APIs" (CLAUDE.md): un solo código para todos los canales.

## Consecuencias

- Hay que mantener el puente mientras exista AssetPlanner. Durante ese período, un aviso de AssetPlanner se marca leído por separado en cada aplicación.
- El esquema `ntf` tiene que correr en **PostgreSQL 11** (producción).
- El acceso es por DataServices con el `empr_id` del JWT (patrón de Tools), no por RLS.
