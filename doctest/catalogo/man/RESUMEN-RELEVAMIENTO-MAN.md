# Relevamiento de MAN — piloto de Alta de Equipos y Componentes

## Objetivo

Deja registro de cómo arrancó F2 (Mantenimiento / AssetPlanner): qué material previo había, qué se
relevó, **qué está bloqueado y por qué**, y las tres decisiones que hacen falta para seguir. Está
escrito para el PM. **No** es el catálogo —eso son los YAML de esta carpeta— ni el detalle de los
circuitos, que ya está relevado en el repo de asset (§1).

- **Fecha:** 2026-08-25 · **Fase:** DocTest F2 (issue #439)
- **Casos:** 6, todos en `borrador` — **ninguno verificado contra la pantalla real** (§3)

---

## 1. Lo primero: acá ya había trabajo hecho, y es bueno

Antes de relevar nada encontré, en la rama `develop-v3` del repo de asset, material que no conviene
duplicar:

| Qué | Dónde | Qué aporta |
|---|---|---|
| **Circuitos funcionales de MAN ↔ ALM ↔ PAN** | `doc/v3/circuitos-man-alm-pan.md` (310 líneas) | El mapa completo de los circuitos, con verificación en la base y diagramas. Excelente |
| **Casos de prueba MAN** | `doc/v3/casos-prueba-man.md` (104 líneas) | Un catálogo `CP-01`…`CP-3x` con precondición, pasos, resultado esperado y si está automatizado |
| **Suite E2E de Playwright** | `tests/e2e/` (6 specs + fixtures + README) | Automatiza parte de esos casos, sobre el requerimiento "asset consume el almacén de tools" |

Tres cosas que ese material ya deja establecidas, y que uso como base:

1. **Hay un solo motor de generación de OT** — `Calendario::guardar_agregar()`. Backlog, preventivo,
   predictivo y correctivo son el mismo circuito con distinta tabla de origen.
2. **El pedido de materiales es perezoso**: no nace del plan ni al vencer, sino **al abrir el modal
   de "Ejecutar OT"**. Se dispara a Bonita recién al ejecutarla.
3. **Materiales y herramientas son asimétricos.** Los materiales tienen circuito transaccional
   completo con descuento de stock; las herramientas **solo se declaran y se listan** — no hay
   pedido, ni entrega, ni devolución, ni stock de pañol.

Y un hallazgo funcional que ese doc ya registra y conviene no perder de vista: **el informe de
servicio muestra lo *pedido* rotulado como "Insumos Usados"**, no lo entregado ni lo consumido. Hay
un TODO en el código que lo admite.

---

## 2. Lo que releva este PR

El piloto que pide el issue #439: **el alta de equipos y componentes**. Seis casos:

| Caso | Título |
|---|---|
| MAN-UC-001 | Ver el listado de equipos |
| MAN-UC-002 | **Dar de alta un equipo** (el caso piloto) |
| MAN-UC-003 | Editar un equipo |
| MAN-UC-004 | Dar de baja un equipo |
| MAN-UC-005 | Dar de alta un componente |
| MAN-UC-006 | Asignar componentes a un equipo |

**Una buena noticia sobre las versiones:** el alta de equipos y componentes **no difiere entre
`develop` y `develop-v3`** del repo de asset — verificado con `git diff`. Así que este piloto no
depende de qué rama corra el DEMO, que es la duda que planteaste.

**Dos cosas que aparecieron al leer el código:**

- **Los catálogos se pueden crear desde el propio formulario.** Junto a cada desplegable del alta
  —área, proceso, criticidad, sector, grupo, cliente— hay un botón para agregar una opción nueva sin
  salir de la pantalla. Es distinto de ALM, donde hay que ir al ABM y volver, y vale la pena
  documentarlo en la ayuda.
- **Quedaron llamadas de depuración activas.** `dump()` no es un log: imprime un bloque HTML amarillo
  en la salida. Hay más de 15 llamadas activas en 8 archivos, y **una de ellas está dentro de
  `guardar_componente()`**, que es justo el alta del piloto. Donde la respuesta se consume por AJAX
  esperando JSON, ese HTML la corrompe. → issue **#486**.

---

## 3. Lo que está bloqueado

**No pude verificar ningún caso contra la pantalla real.** AssetPlanner **tiene su propio padrón de
usuarios y no comparte la sesión de Tools**: la app muestra su propio formulario de ingreso, y las
credenciales de Tools (`jperez@prueba.com`) devuelven *"Error! Revise los datos de acceso
ingresados"*. Los usuarios viven en la tabla `sisusers` de asset, no en `seg.users` de Dnato — el
README de la suite existente lo confirma, con sus variables `ASSET_USER` / `ASSET_PASS`.

Por eso los seis casos están relevados **del código y del manual legacy**, y cada uno lo dice en sus
dudas. No inventé lo que no pude ver.

Esto tiene además una consecuencia de diseño para DocTest: **MAN necesita su propia fixture de
sesión**, porque el `storageState` de Tools no le sirve. Es un cambio chico, pero hay que hacerlo
antes de escribir el primer test de MAN.

---

## 4. Las tres decisiones que hacen falta

### 4.1 Un usuario de AssetPlanner en el DEMO

Es lo único que bloquea. Con eso puedo verificar los seis casos, confirmar si el `dump()` rompe el
alta de componentes, y escribir los tests.

### 4.2 Qué versión describe el catálogo de MAN

Acá hay una diferencia con lo que pasa en `traz-tools`, y conviene decidirla explícitamente:

| | `traz-tools` | `traz-prod-assetplanner` |
|---|---|---|
| Relación entre ramas | `develop` **adelante** de `develop-v3` en 4 submódulos | `develop-v3` **adelante** de `develop` en 34 commits, y contiene todo lo de develop |
| Qué corre el DEMO | `develop` | `develop` (según tu indicación) |

O sea que en asset el DEMO corre la versión **anterior**: sin la migración a REST contra tools
(F3/F4/F5) y sin las mejoras M1 y M2. Los circuitos que documenta `circuitos-man-alm-pan.md` están
escritos sobre `develop-v3`.

**La pregunta:** ¿el catálogo de MAN describe lo que hoy usa el usuario (`develop`) o lo que va a ser
v3 (`develop-v3`, con almacén y pañol consumidos de tools)? Para el piloto no importa —son
idénticos—, pero para todo el resto del módulo sí.

**Mi recomendación:** describir `develop-v3`. Es a donde va el producto, la migración ya está hecha y
documentada, y un catálogo escrito sobre la versión vieja habría que rehacerlo en el cutover. Con la
salvedad de que los tests, hasta que exista un entorno con esa versión, no van a poder correr.

### 4.3 Qué hacemos con los `CP-XX` y la suite que ya existen

Tres caminos:

1. **Migrar los `CP-XX` al catálogo DocTest** y absorber la suite. Queda un solo lugar, un solo
   formato, y las ayudas de MAN salen del mismo catálogo. Es más trabajo de una vez.
2. **Dejarlos donde están y que DocTest cubra lo que ellos no cubren.** Menos trabajo ahora, pero dos
   catálogos de casos conviviendo — y la ayuda de usuario no sale de ninguno de los dos.
3. **Migrar solo los casos y dejar la suite donde está**, porque prueba el requerimiento de migración
   —que asset consuma el almacén de tools—, que es una preocupación distinta de la cobertura
   funcional del módulo.

**Mi recomendación: la 3.** Los `CP-XX` describen casuística funcional y encajan bien como casos del
catálogo; la suite de `tests/e2e/` de asset prueba una migración puntual, tiene su propio ciclo de
vida y no gana nada mudándose. Cuando esa migración esté cerrada, esa suite se puede retirar y lo que
quede vivo ya estará cubierto por DocTest.

---

## 5. Después de que decidas

Con el usuario de asset: verificar los seis casos en pantalla, confirmar el `dump()`, agregar la
fixture de sesión de MAN y escribir los tests. Con la decisión de versión y de los `CP-XX`: seguir el
relevamiento hacia los circuitos —plan de mantenimiento, OT, informe de servicio—, que es donde está
el grueso del módulo y donde el material previo ya hizo la mitad del trabajo.
