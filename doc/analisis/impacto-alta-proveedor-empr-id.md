# Análisis de impacto — El alta de proveedor tira 500 (empr_id: número vs STRING)

## Objetivo

Qué es: el análisis de impacto del **500 al crear un proveedor** en Tools, con la causa raíz
confirmada y una propuesta de fix mínima, para que el PM la **apruebe antes** de tocar nada.
Para quién: Rodolfo (PM), como paso obligatorio previo a modificar código core.
Cuándo leerlo: antes de decidir si se arregla el alta de proveedor y cómo.
Qué NO cubre: no propone tocar el DataService `setProveedor` (es idéntico a producción) ni el
helper `empresa()` (uso transversal). Tampoco cubre el circuito de entrega en sí —ese test ya está
escrito (`doctest/tests/e2e/specs/alm/ALM-UC-010.entrega-materiales.spec.ts`) y sólo está bloqueado
por esto.

---

## Metadata

- **Fecha:** 2026-09-12
- **Rama de trabajo:** `feat/alm-entrega-h070-resuelto`
- **Clase de riesgo:** 🟡 (toca un controller core de producción; **no** toca schema, DataService,
  Bonita ni identidad)
- **Entorno donde se reprodujo:** DEMO (`demo.cloudtrazalog.com`), empresa de prueba "DocTest
  Empresa SA", usuario `almacen@doctest-empresa.com`
- **Estado:** esperando aprobación del PM. **No se modificó ningún archivo.**

---

## 1. Síntoma (evidencia)

Al crear un proveedor desde **Configuración → Proveedores → Agregar**, el POST a
`core/Proveedor/guardarProveedor` responde:

```
HTTP 500 Internal Server Error
{"Fault":{"faultcode":"soapenv:Server",
  "faultstring":"Value type miss match, Expected value type - 'string', but found - 'NUMBER'",
  "detail":""}}
```

El proveedor **no se inserta** (la grilla queda en "Ningún dato disponible"). Reproducido de forma
consistente, con y sin país/provincia/localidad cargados.

Payload que sale de PHP (capturado en vivo), ya con la cabecera `Content-Type: application/json`:

```json
{"_post_proveedor":{"nombre":"...","cuit":"...","domicilio":"...","telefono":"2644000000",
  "email":"...","pais":"paisesArgentina","estado":"...","localidad":"...","empr_id":5}}
```

El único valor **numérico** del payload es `empr_id` (todos los demás son strings del formulario).

---

## 2. Causa raíz (confirmada, no asumida)

1. `application/controllers/core/Proveedor.php:76` arma el alta con
   `$valor['empr_id'] = empresa();`. `empresa()` (`application/helpers/sesion_helper.php:224`)
   devuelve `session->userdata('empr_id')` **tal cual está en la sesión**: en esta empresa es un
   **entero**.
2. El modelo `application/models/core/Proveedores.php:guardarProveedor()` manda el payload por
   `application/libraries/REST.php:callApi()`, que hace `json_encode($data)` con
   `Content-Type: application/json`. Como `empr_id` es un entero PHP, viaja como **número JSON**.
3. El DataService `setProveedor` (`_backend/.../data-services/ALMDataService.dbs`, query id
   `setProveedor`) declara `<param name="empr_id" sqlType="STRING"/>` y recién en el SQL hace
   `cast(:empr_id as integer)`. WSO2 DSS valida el tipo **antes** del SQL: número JSON contra un
   parámetro STRING → **"Expected string, found NUMBER"** → 500.

### Por qué el alta de artículo sí funciona (y esto engaña)

El alta de artículo (`traz-comp-almacenes/models/Articulos.php:guardar()`) hace un
**`$this->db->insert('alm.alm_articulos', $data)`** — un INSERT directo a Postgres desde PHP, que
**no pasa por WSO2** y por lo tanto **no valida tipos**. Por eso el número no molesta ahí. El alta de
proveedor, en cambio, sí pasa por el DataService, donde la validación de tipos es estricta.

> Es decir: **no es un problema del DataService ni del tipo del parámetro** —el patrón
> `empr_id STRING` + `cast(... as integer)` es el mismo en los **43** parámetros `empr_id` del
> ALMDataService y en `setArticulo`—. Es que el alta de proveedor manda `empr_id` como número y las
> demás operaciones que van por DSS lo mandan como string (o no van por DSS).

---

## 3. Verificación contra master (regla del PM)

El query `setProveedor` es **byte-idéntico en `origin/master` (producción)** y en
develop/develop-v3/la rama actual (mismo SQL, mismo `empr_id sqlType="STRING"`). Conclusión: **no es
algo que se haya roto por una modificación reciente al DataService**, y por eso **no se lo toca**.

Reconciliación con "en producción funciona": el mismo código PHP corre en producción, así que el
alta de proveedor **tira el mismo 500 cuando la sesión tiene `empr_id` numérico**. Que en producción
no se haya notado se explica porque: (a) los proveedores se cargan por esa pantalla muy de vez en
cuando, y/o (b) en las empresas viejas el `empr_id` de sesión pudo quedar guardado como string. El
fix propuesto es seguro en ambos casos (ver §5).

---

## 4. Alcance — a quién afecta

- **Afecta:** cualquier alta de proveedor (`core/Proveedor/guardarProveedor`) hecha desde una sesión
  cuyo `empr_id` sea numérico. No es exclusivo del test: es toda la operación.
- **Bug latente idéntico:** `core/Proveedor.php:137` (`guardarDeposito`) también hace
  `$data['empr_id'] = empresa();` y va por DSS → mismo 500 si se agrega un depósito por esa pantalla.
  (Hoy el depósito lo crea el alta de empresa, DNATO-UC-004, por otro camino, así que no salta
  siempre.)
- **No afecta:** la edición de proveedor (`guardarEdicionProveedor`) — ahí el `empr_id` está
  comentado y no se manda.
- **Único caller de `POST /proveedores`:** el modelo `Proveedores::guardarProveedor()`. No hay otro
  consumidor que dependa de que `empr_id` viaje como número.

---

## 5. Opciones de fix (con blast radius)

### Opción 1 — Castear `empr_id` a string en el controller (RECOMENDADA)

`application/controllers/core/Proveedor.php`
- línea 76: `$valor['empr_id'] = (string) empresa();`
- línea 137 (mismo bug latente, por consistencia): `$data['empr_id'] = (string) empresa();`

- **Qué cambia:** el payload manda `"empr_id":"5"` (string), que el parámetro STRING acepta; el SQL
  sigue haciendo `cast(:empr_id as integer)`. Queda igual que el resto de los inserts que van por DSS.
- **Blast radius:** SOLO el alta de proveedor (y de depósito). No toca el DataService compartido, ni
  `empresa()`, ni `REST.php`, ni ningún otro módulo.
- **Riesgo:** mínimo. `(string)` es idempotente: si en algún entorno `empr_id` ya fuese string, no
  cambia nada.
- **Despliegue:** sólo frontend PHP (Tools). **No** requiere redeploy del DataService/CAR.

### Opción 2 — Cambiar el parámetro a INTEGER en el DataService

`setProveedor`: `<param name="empr_id" sqlType="STRING"/>` → `sqlType="INTEGER"`.

- **Contra:** es un artefacto **core, compartido y desplegado** (idéntico a master); rompe la
  consistencia con los otros 42 `empr_id` STRING; si algún día otro caller manda `empr_id` como
  string fallaría; y obliga a **redeploy del DataService**. Mayor superficie de riesgo y operación
  para el mismo resultado.

### Opción 3 — No tocar código, sembrar proveedores por fuera

No arregla el bug, sólo evita el síntoma en el test. Descartada como solución (sí sirve como
workaround temporal si se quiere correr el test antes del fix).

**Recomendación: Opción 1.** Es el cambio más chico, local, y alinea el alta de proveedor con el
contrato que ya usan las demás operaciones vía DSS.

---

## 6. Plan de verificación (post-aprobación)

1. Aplicar Opción 1 en una rama `fix/...` y PR a `develop` (v2).
2. Desplegar sólo el PHP en DEMO.
3. Crear un proveedor por la pantalla → esperado: **HTTP 200** y el proveedor aparece en la lista.
4. Correr el ciclo autónomo: `cd doctest && npm run test:ciclo -- --grep @ALM-UC-010` → esperado:
   preparación (proveedor + recepción → stock), pedido, aprobación y las dos entregas en verde.
5. Regresión: `npm run test:all` no debería moverse (81 passed / 2 flaky / 1 skipped).

## 7. Rollback

Revertir la(s) línea(s) del controller. Sin migración, sin cambio de datos, sin redeploy de
DataService: el rollback es inmediato y sin efectos residuales.

---

## 8. Hallazgos relacionados (para registrar, fuera de este fix)

- **`Articulos::guardar()` hace INSERT directo a Postgres desde PHP**, saltándose WSO2. Va contra la
  convención del proyecto ("Sin direct DB queries desde PHP — todos los datos van por WSO2 MI").
  Explica por qué el alta de artículo no valida tipos. No se toca acá; queda anotado.
- **`guardarDeposito` comparte el bug** de `empr_id` numérico (incluido en la Opción 1 por
  consistencia).
