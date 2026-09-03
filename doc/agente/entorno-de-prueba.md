# Agente Minero — cómo probarlo en el entorno local

## Objetivo

Instrucciones para **entrar al chat del agente y probarlo de punta a punta** en la máquina de desarrollo: qué URL usar, con qué usuario, y qué hacer si algo no responde. Está escrito para seguirse sin conocer el historial: cada paso dice dónde se ejecuta.

**Qué NO cubre:** no explica cómo está construido (`doc/agente/arquitectura.md`) ni cómo se configura el orquestador (`doc/agente/operacion.md`).

---

## ⚠️ Entrá por `traz-comp.local`, no por `localhost`

Es lo primero y lo que más confunde. XAMPP tiene dos cosas distintas:

| URL | A dónde va | Sirve para el agente |
|---|---|---|
| `http://localhost/` | `/opt/lampp/htdocs` — el htdocs de XAMPP | ❌ da 403 |
| **`http://traz-comp.local/`** | `/mnt/win/dev/git` — donde están los proyectos | ✅ |

El vhost está en `/opt/lampp/etc/extra/httpd-vhosts.conf` y `traz-comp.local` ya resuelve por `/etc/hosts`. **No hay que configurar nada**, solo usar la URL correcta.

> **Ojo con la constante `DNATO`.** Vale `http://localhost/traz-comp-dnato/`, que en este entorno no funciona: por eso el login de Tools redirige a una URL que da 403. El módulo del agente no depende de esa constante — deriva la URL de Dnato **del host por el que entró el usuario**, así que funciona por cualquiera de los dos. El resto de Tools sí arrastra el desajuste.

---

## Las URLs

| Qué | URL |
|---|---|
| Tools | `http://traz-comp.local/traz-tools/` |
| Dnato | `http://traz-comp.local/traz-comp-dnato/` |
| **Chat del agente** | `http://traz-comp.local/traz-tools/traz-comp-agente/agente` |
| Panel de feedback | `http://traz-comp.local/traz-tools/traz-comp-agente/agente/admin` |
| Estado del orquestador | `http://traz-comp.local/traz-tools/traz-comp-agente/agente/salud` |
| Orquestador (directo) | `http://127.0.0.1:8099` |
| Bonita | `http://10.142.0.13:8080/bonita` |

---

## El usuario de prueba

Creado el 2026-09-02 para probar el agente. **Las credenciales están en `~/.agente-minero.env`** (permisos 600, fuera del repo), junto a las de la base.

| Dato | Valor |
|---|---|
| Empresa | `AGENTE MINERO TEST` |
| `empr_id` | **191** |
| Email | `agente.minero.test@trazalog.local` |
| Nick (BPM) | `agenteminero` |
| Perfil | Administrador |

### Qué se creó, exactamente

El alta por el formulario web **no funciona en este entorno**: el registro va por WSO2 (`toolsCOREAPI` → `POST /usuario/registro`) y el MI local responde `The endpoint reference (EPR) for the Operation not found`. Así que se crearon los registros a mano, replicando lo que hace el alta:

| Dónde | Qué |
|---|---|
| `core.empresas` (PostgreSQL `tools_prod_t`) | La empresa, `empr_id` 191 |
| `seg.users` | El usuario, con la contraseña hasheada **por la propia librería `Password` de Dnato** (PBKDF2 `sha256:1000:salt:hash`) |
| `seg.memberships_users` | El vínculo usuario ↔ empresa. Es lo que resuelve el `empr_id` de la sesión |
| Bonita (`API/identity/user`) | El usuario `agenteminero`, id 1901 |

**El de Bonita no es opcional:** el login de Dnato valida contra Bonita y falla con `NO HAY USUARIO EN BPM CON EL NICK` si no está. Fue lo último que faltaba para que el login pasara.

Para dar de baja todo esto: borrar el usuario de Bonita, y las filas de `seg.memberships_users`, `seg.users` y `core.empresas`.

---

## Probarlo, paso a paso

Todo desde **el navegador**, salvo el primer paso.

**1. Levantar el orquestador** — en la terminal, desde la raíz del repo:

```
./agente/dev.sh
```

**2. Entrar al chat:**

```
http://traz-comp.local/traz-tools/traz-comp-agente/agente
```

**3. Loguearse** con el usuario de prueba, si Tools pide sesión.

**4. La primera vez, el chat te manda a Dnato y vuelve solo.** No te va a pedir credenciales de nuevo: como Tools y Dnato comparten la sesión, el `authorize` la reconoce y devuelve el código de una. Si te pide login otra vez, es que entraste por un host distinto al de la sesión.

**5. Preguntale algo.** La vista trae cuatro ejemplos clickeables, dos de mantenimiento y dos de almacenes.

### Qué esperar

Con una `OPENROUTER_API_KEY` real, el agente responde. **Sin ella responde "no pude responder ahora mismo por un problema técnico"** — que es el comportamiento correcto: degrada con un mensaje entendible y deja el error real en la base:

```
psql -h 127.0.0.1 -U postgres -d agente_minero -c "SELECT fec_alta, empr_id, left(pregunta,50), error FROM agente.interaccion ORDER BY fec_alta DESC LIMIT 5;"
```

---

## Lo que ya está verificado

Circuito completo, el 2026-09-02, con este usuario:

| Paso | Resultado |
|---|---|
| Login en Dnato | ✅ `sesión abierta. email=agente.minero.test@trazalog.local empr_id=191` |
| `/oauth/authorize` con la sesión | ✅ devuelve el `code` **sin pedir credenciales** |
| Canje del `code` | ✅ JWT con `empr_id: 191`, `sub: agenteminero`, TTL 24 h |
| Consulta al orquestador con ese JWT | ✅ aceptado; la interacción quedó registrada **con `empr_id` 191 derivado del token** |

Lo único que falta para una respuesta real es una `OPENROUTER_API_KEY` válida en el `.env`.

---

## Si algo no anda

| Síntoma | Causa | Qué hacer |
|---|---|---|
| 403 en todo | Entraste por `localhost` | Usá `traz-comp.local` |
| El login vuelve al login | El usuario no existe en Bonita | Buscar `NO HAY USUARIO EN BPM` en `traz-comp-dnato/application/logs/` |
| "Sesión Existente" y no entra | Cookie de una sesión anterior | Borrar cookies del sitio |
| El chat pide reconectar siempre | El host del OAuth no es el de la sesión | Entrá y quedate en `traz-comp.local` |
| El chat dice que el agente no está disponible | El orquestador no corre | `./agente/dev.sh`, y mirar `/agente/salud` |
| El registro web falla con 500 | El MI local no tiene `/usuario/registro` | Es del entorno, no del agente. Crear el usuario a mano como se documentó arriba |
