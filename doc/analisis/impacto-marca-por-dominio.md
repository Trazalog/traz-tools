# Análisis de impacto — Marca por dominio (REQ-019)

## Objetivo

Análisis de impacto que pide `CLAUDE.md` antes de tocar el núcleo productivo, para el trabajo de
[REQ-019](../../requerimientos/REQ-019-marca-por-dominio.md) (entrar por `app.pirkai.net` y ver Pirkai).
Lo aprueba Rodolfo antes de unir el pedido de cambio. **No** explica el diseño completo
([ADR-015](../adr/ADR-015-marca-por-dominio.md)) ni los pasos de servidor (`doc/infra/pirkai-0*.md`).

| Campo | Valor |
|---|---|
| Fecha | 2026-11-26 |
| Ramas | `feat/marca-por-dominio-pirkai` en `traz-tools` y en `traz-comp-dnato`, desde `develop` |
| Estado | Pendiente de aprobación de Rodolfo |

---

## 1. Comparación contra producción (`master`)

| Objeto del núcleo | `master` vs `develop` | Comentario |
|---|---|---|
| Tools `application/views/layout/Admin.php` | Iguales | El cambio parte de lo que corre en producción |
| Tools `application/config/config.php` | Iguales (`"http://"` fijo en la línea 26) | Los servidores tienen su propia copia, restaurada en cada despliegue |
| Tools `application/config/constants.php` | `develop` agrega 8 líneas ajenas a este trabajo; `DNATO` igual | Ídem: copia propia por servidor |
| Tools `application/controllers/Dash.php` | `develop` agrega el contexto del módulo Administración (REQ-004) | Este cambio no toca esa parte |
| DNATO `Main.php` | `develop` agrega 22 líneas ajenas a este trabajo | Los 5 puntos que se tocan son iguales en las dos ramas |
| DNATO `jwt.php`, `header.php`, `login.php` | Iguales | — |

Ninguno de los objetos tocados tiene hoy un problema conocido: se asume que **funcionan en producción** y
el cambio está armado para no alterar ese funcionamiento.

## 2. Qué cambia y quién lo consume

| Cambio | Quién lo consume | Con el dominio de Trazalog | Con un dominio de Pirkai |
|---|---|---|---|
| Helper `marca` autocargado (Tools y DNATO) | Todo pedido de las dos aplicaciones | Funciones que devuelven el valor de respaldo. Se agrega la lectura de un archivo chico por pedido | Devuelven los valores de Pirkai |
| `Admin.php` (plantilla de Tools) | Todas las pantallas de Tools | **HTML idéntico** (verificado contra `develop` con datos de prueba, ignorando espacios) | Título, skin, colores, pie, texto legal, scripts de marca |
| `Dash.php` | Barra superior y tablero del administrador | Siguen leyendo `core.tablas` | Logo y texto de la marca |
| `constants.php` de Tools (`DNATO`) | Unos 15 `redirect(DNATO...)` repartidos en controllers y helpers | Dirección intacta | Ingreso por el mismo dominio |
| `config.php` de Tools (`https`) | `base_url()` en todo Tools | En el servidor no cambia nada (el despliegue restaura la copia del servidor). En instalaciones nuevas, `https` se detecta en vez de forzar `http` | Ídem |
| DNATO `Main.php` (`DE`, `DS`, logo, título) | Ingreso, salida, recupero de clave, selección de empresa | Direcciones y logos intactos | Vuelve a Tools por el mismo dominio |
| DNATO `jwt.php` | Emisión de tokens del agente (MCP) | Sin cambios (mismo orden de precedencia) | Si no hay emisor configurado, se deriva de la constante fija `DNATO`, no del dominio |
| DNATO vistas de ingreso y registración | Ingreso, registración, recupero de clave | Textos e imágenes intactos | Textos, logo y colores de la marca |

**No se toca**: base de datos, DataServices, APIs y sequences de WSO2, Bonita, `traz-comp-formularios`,
ningún módulo con repositorio propio.

## 3. Qué se podría romper y cómo se evita

| Riesgo | Cómo se evita |
|---|---|
| Que Trazalog cambie de aspecto o de comportamiento | Toda llamada usa el valor de hoy como respaldo; con un dominio fuera de la lista no se carga ni una hoja ni un script extra. Comparación de la página generada contra `develop`: idéntica |
| Error fatal si `constants.php` del servidor llama a `marca_url_host()` y el código desplegado es viejo | La guía 04 manda editar `constants.php` **después** de desplegar y validar con `php -l`. Vuelta atrás: restaurar el respaldo |
| Que el emisor del token del agente cambie según el dominio | Guía 04: fijar `DNATO_OAUTH_ISSUER` (o confirmar `DNATO_ISSUER`) antes de abrir el dominio; además, la salvaguarda en `jwt.php` |
| Que un dominio no previsto muestre otra marca | Lista cerrada, comparación exacta del dominio (un dominio que solo *contiene* `pirkai.net` muestra Trazalog, verificado) |
| Sintaxis no compatible con PHP 5.6 (destino de DEMO) | `phpcs` con PHPCompatibility 5.6 sobre todos los archivos tocados: sin errores |
| El cambio de `https` en `config.php` de Tools | No llega a los servidores por sí solo (copia propia restaurada); la guía 00 releva el valor actual y la 04 lo cambia solo si sigue en `http` |
| Que `marca.js` cambie logos propios de una empresa | Solo reemplaza la imagen `imagenes/trazalog/logo_trazalog.png` (logo por defecto). Los logos de cada empresa no se tocan |

## 4. Por qué lo que hay hoy quedó así

- `base_url` con `"http://"` fijo es la línea original de CodeIgniter adaptada; DNATO ya la había
  reemplazado por detección de `https` para poder usar túneles y proxies.
- `DNATO`, `DE` y `DS` son absolutas porque Tools y DNATO son aplicaciones separadas en el mismo servidor;
  nunca hubo más de un dominio por instalación.
- El logo de la barra sale de `core.tablas` sin empresa porque es configuración del sitio, no de cada
  cliente. Se respeta: Pirkai lo pisa solo cuando corresponde.

## 5. Prueba antes de desplegar

1. Local con los dos dominios (`trazalog.local` y `pirkai.local`), recorrido de la guía 05.
2. DEMO con `demo.pirkai.net`, recorrido completo de la guía 05 y prueba DocTest de regresión contra el
   dominio de Trazalog.
3. Producción solo con aprobación explícita.
