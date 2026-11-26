# Pirkai · Guía 05 — Verificación después del despliegue

## Objetivo

Lista de control para dar por bueno el dominio Pirkai en un ambiente: que con `demo.pirkai.net` (o
`app.pirkai.net`) se vea Pirkai y todo funcione, y que con el dominio de Trazalog **nada haya cambiado**.
Para quien despliegue y para Rodolfo al aprobar el pase a producción. Se hace después de la
[guía 04](pirkai-04-configuracion-post-despliegue.md). **No** prueba AssetPlanner, mails, ayuda ni
agentes, que quedan con Trazalog por decisión de alcance ([REQ-019](../../requerimientos/REQ-019-marca-por-dominio.md)).

Anotá el resultado de cada punto (✅ / ❌ + captura) en el pedido de cambio o el issue.

---

## A. Con el dominio de Pirkai

**Dónde:** navegador en ventana privada (para no arrastrar sesiones), `https://demo.pirkai.net/`.

| # | Qué hacer | Qué tiene que pasar |
|---|---|---|
| A1 | Abrir `https://demo.pirkai.net/` | Lleva al ingreso, con candado, logo de Pirkai, colores de Pirkai y pestaña "pirkai.net". La dirección sigue en `demo.pirkai.net` |
| A2 | Ingresar con un usuario de prueba | Entra a Tools **sin salir de** `demo.pirkai.net`. Si el usuario tiene varias empresas, la pantalla de selección también se ve con Pirkai |
| A3 | Mirar la pantalla principal | Pestaña "PIRKAI.NET", logo de Pirkai en la barra superior, barra y menú con los colores de Pirkai, pie "pirkai.net" |
| A4 | Abrir 4 o 5 pantallas del menú (almacenes, mantenimiento, tareas, tablero) | Funcionan igual que en Trazalog. Anotar cualquier pantalla con rojo de Trazalog o la palabra "Trazalog" (va a la Etapa B) |
| A5 | Abrir "Versión" en el pie | El texto legal dice "pirkai.net" |
| A6 | Imprimir un remito o una entrega de materiales de una empresa **sin** logo propio | El título de la impresión dice "PIRKAI.NET" y el logo es el de Pirkai |
| A7 | Cerrar sesión | Vuelve al ingreso de `demo.pirkai.net`, con Pirkai |
| A8 | "Olvidé mi contraseña" | Pantalla con Pirkai. (El mail que llega es de Trazalog: esperado) |
| A9 | Registración (si está habilitada en el ingreso) | Pantallas con logo y textos de Pirkai |
| A10 | Dejar la sesión inactiva hasta que venza (o borrar la cookie `ci_session`) y tocar el menú | Lleva al ingreso de `demo.pirkai.net` |

Búsqueda rápida de textos: en la pantalla principal, `Ctrl+U` (ver código fuente) y buscar `trazalog`.
Las únicas apariciones esperadas son rutas internas de archivos (`imagenes/trazalog/...`) y la clase CSS
`trazalog`; ningún texto visible.

## B. Con el dominio de Trazalog (no tiene que haber cambiado nada)

**Dónde:** otra ventana privada, `https://demo.cloudtrazalog.com/traz-tools/`.

| # | Qué hacer | Qué tiene que pasar |
|---|---|---|
| B1 | Ingresar, recorrer las mismas pantallas de A4 e imprimir lo mismo de A6 | Todo igual que antes del despliegue: logo, rojo, "TRAZALOG TOOLS" en impresiones |
| B2 | `Ctrl+U` en la pantalla principal | No aparece `data-marca`, ni `marca.css`, ni `marca.js` |
| B3 | Cerrar sesión y volver a entrar | Siempre dentro de `demo.cloudtrazalog.com` |

**Dónde:** terminal de tu computadora, en la carpeta `doctest` del repositorio `traz-tools`. Prueba
automática de regresión contra el dominio de Trazalog (DocTest, perfil de DEMO):

```bash
npm run doctest -- regresion --entorno demo
```

Tiene que dar el mismo resultado que la última corrida antes del despliegue.

## C. Agente de IA (que el emisor de tokens no cambió)

**Dónde:** terminal de tu computadora.

```bash
curl -s https://demo.cloudtrazalog.com/traz-comp-dnato/oauth/.well-known/oauth-authorization-server \
  | grep -o '"issuer":"[^"]*"'
```

Tiene que mostrar el mismo valor que antes (el que se copió en la guía 04, paso 4). Si hay un agente
conectado al MCP de DEMO, hacerle una consulta: tiene que responder como siempre.

## D. Servidor

**Dónde:** sesión SSH al servidor (guía 00, paso 1).

```bash
sudo tail -n 50 /var/log/httpd/pirkai_ssl_error_log
ls -t /var/www/html/traz-tools/application/logs/ | head -1
```

Abrí el último log de Tools que muestra el segundo comando y buscá errores nuevos con:

```bash
grep -n -i "error" /var/www/html/traz-tools/application/logs/ARCHIVO | tail -20
```

(Reemplazá `ARCHIVO` por el nombre que mostró `ls`.) No tiene que haber errores que mencionen `marca`.

## Resultado

- Todo ✅ en DEMO → se puede pedir a Rodolfo el pase a producción: guías 01 a 05 con `app.pirkai.net`.
- Algún ❌ en **B** o **C** → vuelta atrás inmediata (guía 04, "Vuelta atrás") y avisar.
- ❌ en **A** → anotar y decidir con Rodolfo si bloquea o va a la Etapa B.
