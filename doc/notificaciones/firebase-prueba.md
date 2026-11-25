# Proyecto de Firebase para pruebas de avisos

## Objetivo

Estos son los pasos para crear un proyecto de Firebase **solo para pruebas**. Sirve para probar los avisos al celular sin usar el proyecto de producción (`traz-prod-assetplanner`). Lo sigue el PM una sola vez, antes de la primera prueba de avisos en el servidor de Google. No cubre la instalación de los avisos: eso está en [`instalacion-avisos.md`](instalacion-avisos.md).

**Tiempo:** unos 10 minutos. **Costo:** cero. El plan gratuito de Firebase (Spark) incluye los avisos sin límite.

---

## 1. Crear el proyecto

**Dónde:** navegador, en <https://console.firebase.google.com>, con tu cuenta de Google.

1. Tocá **Crear un proyecto**.
2. Ponele de nombre `trazalog-pruebas`. Si ese nombre está tomado, Firebase le agrega un número; anotá el nombre final.
3. Cuando te ofrezca Google Analytics, **desactivalo**. No hace falta.
4. Tocá **Crear proyecto** y esperá a que termine.

## 2. Registrar Tools como app web

**Dónde:** la misma consola, dentro del proyecto nuevo.

1. En la pantalla principal del proyecto, tocá el ícono **`</>`** (Web).
2. De apodo poné `Tools pruebas`. **No** marques "Firebase Hosting".
3. Tocá **Registrar app**.
4. Te muestra un bloque que empieza con `const firebaseConfig = {`. **Copiá ese bloque entero** a un archivo de texto en tu máquina, por ejemplo `~/firebase-prueba/config-web.txt`. Esta configuración es pública: es la que se usa en el navegador.

## 3. Sacar la clave pública de los avisos web

**Dónde:** la misma consola → ⚙️ (al lado de "Descripción general del proyecto") → **Configuración del proyecto** → pestaña **Cloud Messaging**.

1. Bajá hasta **Configuración web** → **Certificados de push web**.
2. Tocá **Generar par de claves**.
3. Copiá la clave que aparece (una cadena larga que empieza con `B`) al mismo archivo `~/firebase-prueba/config-web.txt`. También es pública.

## 4. Bajar la clave del servidor (esta sí es secreta)

**Dónde:** la misma consola → ⚙️ → **Configuración del proyecto** → pestaña **Cuentas de servicio**.

1. Tocá **Generar nueva clave privada** y confirmá.
2. Se baja un archivo `.json`. Guardalo como `~/firebase-prueba/cuenta-servicio.json`.

⚠️ **Este archivo es una contraseña.** No lo pegues en el chat, no lo subas al repositorio y no lo mandes por mail. Con decirme que está en esa carpeta alcanza: lo uso desde ahí y en el servidor queda fuera del repositorio.

## 5. Avisarme

**Dónde:** el chat con Claude Code.

Decime algo así: "listo, está en `~/firebase-prueba`". Con eso:

- pongo la configuración web y la clave pública en Tools, para la prueba;
- preparo el conector para que lea la cuenta de servicio desde el servidor y no desde el código. Hoy la de producción está escrita en el código del conector, y es una de las credenciales expuestas.

---

## Para borrarlo después

**Dónde:** la consola de Firebase → ⚙️ → **Configuración del proyecto** → pestaña **General** → abajo de todo, **Borrar proyecto**. No afecta en nada a producción.
