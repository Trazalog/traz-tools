# Lanzamiento automático de OTs de Mantenimiento — cron del SO

## Objetivo

Qué es: cómo se lanza solo, cerca de su fecha, el caso de Bonita de las OTs preventivas y predictivas que se programaron "sin lanzar"
(MIG-8), y cómo se configura el margen de días. Para quién: quien opere los servidores de tools (prod/demo) o toque esa corrida. Cuándo
leerlo: antes de instalar o cambiar el cron, o si una OT no se lanzó. Qué NO cubre: el diseño funcional (ver
[`MIGRACION-ASSETPLANNER.md`](../migracion/MIGRACION-ASSETPLANNER.md), MIG-8) ni el cron de los KPIs
([`kpi-cron-refresh.md`](kpi-cron-refresh.md)).

---

Estado: implementado y probado en desarrollo (2026-10-31); **no instalado** en prod ni demo.

## Cómo funciona

1. Al programar un preventivo o predictivo, la API crea todas las órdenes y lanza ahora solo las que caen dentro del margen de días.
   Las demás quedan **programadas sin lanzar**: estado `PL`, tipo 3 o 5 y `case_id = 0` en `orden_trabajo`. (Las órdenes viejas sin caso
   tienen `case_id` NULL y no se tocan.)
2. Una vez por día el cron ejecuta `Lanzamiento/ejecutar`: busca las empresas con órdenes sin lanzar, calcula el margen de cada una y
   le pide a `toolsMANAPI` (`POST /tools/man/plan/lanzar-pendientes`) que lance las que están dentro del margen o ya pasaron.
3. Una orden que falla (por ejemplo, Bonita caído) queda sin lanzar y se reintenta en la corrida siguiente.
4. El botón **Lanzar** de la lista de Órdenes de Trabajo hace lo mismo para una sola orden, cuando se quiere adelantar.

Sin sesión de Bonita (la corrida automática no tiene usuario) `bpmAPICallTemplate` entra con el usuario de servicio de `bpmconf.xml`;
el caso queda iniciado por ese usuario.

## Margen de días

| Fuente | Valor |
|---|---|
| Lista de valores (`core.tablas`, tabla `configuraciones`) | Días en `valor2` (entero de 0 a 365). `valor` = `man_dias_lanzamiento` vale para todas las empresas; `valor` = `man_dias_lanzamiento_<id de empresa de tools>` vale solo para esa empresa y pisa al general |
| Si no hay fila válida | `MAN_DIAS_LANZAMIENTO` en `application/config/constants.php` (7 días) |

La empresa va dentro del `valor` porque la clave de la fila (`tabl_id`) se arma con tabla + valor: no puede haber dos filas con el mismo valor.

Ejemplo para dar 10 días a la empresa 181 (ejecutar en la consola SQL de la base `trazalog_tools`; el `tabl_id` lo reemplaza el sistema):

```sql
INSERT INTO core.tablas (tabl_id, tabla, valor, valor2, descripcion)
VALUES ('x', 'configuraciones', 'man_dias_lanzamiento_181', '10',
        'Días de anticipación para lanzar OTs preventivas y predictivas');
```

## Instalación del cron

Dónde: en el servidor de tools, como el usuario que corre Apache/PHP. Una vez por día a las 05:30:

```cron
30 5 * * * cd /ruta/a/traz-tools && php index.php traz-tools-man/Lanzamiento/ejecutar >> /var/log/man_lanzamiento.log 2>&1
```

Desde la línea de comandos PHP avisa `Undefined array key "HTTP_HOST"` (viene de `application/config/config.php`, que arma la dirección base con el navegador); es solo una advertencia y no afecta la corrida. Cada corrida imprime una línea por empresa (`lanzadas`, `fallidas` con los números de orden) y el total. El detalle de cada falla queda
en el log de CodeIgniter con la marca `#TRAZA | TRAZ-TOOLS-MAN | Lanzamiento`.

## Limitaciones conocidas

- La API lanza hasta 200 órdenes por pedido; el programa repite hasta 5 pasadas por empresa.
- Si el botón y el cron lanzan la misma orden al mismo tiempo podría abrirse dos veces el caso (ventana de milisegundos, sin guarda).
