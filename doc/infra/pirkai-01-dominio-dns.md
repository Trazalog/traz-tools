# Pirkai · Guía 01 — Registros del dominio `pirkai.net`

## Objetivo

Hacer que `demo.pirkai.net` y `app.pirkai.net` apunten a los servidores de DEMO y producción. Para quien
administre el dominio `pirkai.net` (hoy, Rodolfo). Se hace **antes de desplegar**, después de la
[guía 00](pirkai-00-relevamiento-servidor.md). **No** toca el correo del dominio, ni la dirección
principal `pirkai.net` / `www.pirkai.net` (quedan libres para un sitio institucional), ni los dominios
de Trazalog.

| Registro | Tipo | Valor | Tiempo de vida inicial |
|---|---|---|---|
| `demo.pirkai.net` | A | IP pública de DEMO (planilla, R1) | 300 segundos |
| `app.pirkai.net` | A | IP pública de producción (planilla, R1) | 300 segundos |

Se carga primero solo `demo`; `app` recién cuando DEMO quedó verificado con la guía 05.

---

## Pasos

### 1. Entrar al panel del dominio

**Dónde:** el panel web del proveedor donde está registrado `pirkai.net` (la sección suele llamarse
"DNS", "Zona DNS" o "Administrar registros").

Antes de cambiar nada, sacá una captura de pantalla de los registros actuales: es la vuelta atrás.

### 2. Crear el registro de DEMO

**Dónde:** panel del dominio.

- Tipo: **A**
- Nombre / host: `demo` (algunos paneles piden el nombre completo, `demo.pirkai.net`)
- Valor / apunta a: la IP pública de DEMO (R1)
- Tiempo de vida (TTL): **300** (5 minutos), para poder corregir rápido. Se sube después (guía 06).

No uses CNAME hacia `demo.cloudtrazalog.com`: funcionaría, pero ata el dominio de Pirkai a los registros
de Trazalog.

### 3. Si el panel tiene registros CAA

**Dónde:** panel del dominio.

Si existe algún registro **CAA** en `pirkai.net`, tiene que permitir a Let's Encrypt, o la guía 03 va a
fallar. Agregá (o confirmá) uno así:

- Tipo: **CAA** · Nombre: `@` · Valor: `0 issue "letsencrypt.org"`

Si no hay ningún registro CAA, no hagas nada: sin CAA, cualquier autoridad puede emitir.

### 4. Comprobar que el registro ya se ve

**Dónde:** terminal de tu computadora.

```bash
dig +short demo.pirkai.net A
dig +short demo.pirkai.net A @8.8.8.8
```

Las dos tienen que devolver la IP de DEMO. Puede tardar desde un par de minutos hasta lo que diga el
proveedor. Si `dig` no está instalado, sirve `nslookup demo.pirkai.net 8.8.8.8`.

### 5. Prueba de llegada al servidor

**Dónde:** terminal de tu computadora.

```bash
curl -sI http://demo.pirkai.net/ | head -3
```

Cualquier respuesta (aunque sea una página de Trazalog o un error 404) confirma que el dominio llega al
servidor. Si no responde, revisar el firewall (planilla, R8).

### 6. Producción

Repetir los pasos 2 a 5 con `app` y la IP de producción, **solo** cuando DEMO esté verificado.

## Vuelta atrás

**Dónde:** panel del dominio. Borrar el registro A creado. Con TTL de 300, en unos minutos el dominio
deja de llegar al servidor. No afecta a Trazalog.
