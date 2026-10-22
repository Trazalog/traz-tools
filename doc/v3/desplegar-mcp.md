# Desplegar el MCP

## Objetivo

Cómo desplegar una actualización del MCP. Es **un comando, el mismo en todos los ambientes**: lo que
cambia de un servidor a otro vive en el `.env` de ese servidor, no en el procedimiento. Leelo cuando
haya que subir cambios al MCP — tools nuevas, queries, dataservices o sequences.

**No cubre** la instalación inicial de WSO2 ([`deployment-gcp.md`](deployment-gcp.md) §4) ni el
despliegue del frontend PHP, que va por `deploytools.sh`.

---

## El comando

💻 SSH a la VM del MCP, desde cualquier directorio:

```bash
sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/master
```

El único argumento es **la rama o el tag** a desplegar: `origin/master`, `origin/develop`,
`v2.5.1.17`… Si no le pasás nada, usa `origin/master`.

**Es el mismo comando en todos los ambientes, sin variantes.** No hay un argumento de ambiente
porque no hace falta: lo que diferencia un ambiente de otro —las bases, el Bonita— ya está en
`deploy/gcp/.env.car` de **ese** servidor. El servidor es el ambiente.

**No hay que editar ningún archivo del repo.** Las IPs y las credenciales salen del `.env` del
ambiente, y el script las aplica sobre una **copia** del proyecto: el checkout queda limpio
(`git status` sin cambios) y las credenciales nunca entran a git.

Antes de hacer nada, el script muestra **a dónde va a quedar apuntando el MCP** y pide confirmación:

```
  Este despliegue va a dejar el MCP leyendo:
    PostgreSQL  10.142.0.2:5434/trazalog_tools  (usuario postgres)
    MariaDB     10.142.0.2:3306/asp2tecn  (usuario root)
    Bonita      http://10.142.0.2:8080/bonita  (usuario admin)

  ¿Es correcto? [s/N]
```

Leé esas tres líneas. Es el único dato que, equivocado, **no falla**: las tools responden `200`, con
estructura correcta, y datos del ambiente de al lado.

---

## Qué hace

Siete pasos, en pantalla solo el avance; todo el detalle va al log.

| | |
|---|---|
| 1 | Verifica el entorno: el repo, el `.env` (permisos `600` y las 13 variables completas), el MI y las herramientas |
| 2 | `git fetch` + `git reset --hard` a la rama o tag que le pasaste |
| 3 | **Respalda el `.car` que está andando** en `~/ToolsAPIProject_1.0.0.car.antes-de-<fecha>` |
| 4 | Copia el proyecto a `~/.cache/traz-mcp-build/<fecha>`, le aplica el `.env` y buildea con Maven |
| 5 | **Verifica el `.car` antes de desplegarlo**: que tenga las tres URLs del `.env`, que el MI siga apuntándose a sí mismo en `localhost:8290`, y que no haya quedado ninguna IP de otro ambiente |
| 6 | Copia el `.car` a `carbonapps/`, reinicia el MI y espera a que responda |
| 7 | Verifica el `.car` ya instalado y que no haya errores de datasource en el log del MI |

Si algo falla antes del paso 6, **no se desplegó nada**. Termina en `DESPLIEGUE OK` o
`DESPLIEGUE CON N ERROR(ES)`, con el log y el respaldo:

```
----------------------------------------------------
  DESPLIEGUE OK
  revision               : a1b2c3d (origin/master)
  .env                   : /home/ruiz_rodolfo/git/traz-tools/deploy/gcp/.env.car
  operaciones MCP        : 25
  respaldo del anterior  : /home/ruiz_rodolfo/ToolsAPIProject_1.0.0.car.antes-de-20261020-143000
  log completo           : /home/ruiz_rodolfo/deploymcp-20261020-143000.log
----------------------------------------------------
```

Para probar sin desplegar —arma el `.car` y lo verifica, pero no toca el MI—:

```bash
SOLO_BUILD=1 sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/master
```

Y si alguna vez tenés que armar el `.car` para **otro** ambiente desde esta máquina, el segundo
argumento es la ruta de ese `.env`:

```bash
SOLO_BUILD=1 sh ~/git/traz-tools/scripts/deploy/deploymcp.sh origin/develop deploy/gcp/.env.car.demo
```

---

## Si hay que volver atrás

El `.car` es el único artefacto que cambia, así que el rollback no toca el APIM ni el DNS. Si hubo
errores, el script te imprime el comando exacto. Si no, es el respaldo del paso 3:

```bash
sudo cp ~/ToolsAPIProject_1.0.0.car.antes-de-<fecha> \
  /opt/wso2/wso2mi-4.5.0/repository/deployment/server/carbonapps/ToolsAPIProject_1.0.0.car && \
sudo systemctl restart wso2mi
```

---

## Cuando el despliegue trae operaciones MCP nuevas

El script despliega el MI, que es donde vive la lógica. Pero una **tool nueva** además tiene que
quedar publicada en el APIM, y eso no se puede automatizar.

El script lo detecta y te avisa al final, comparando el `.car` viejo con el nuevo:

```
  !! CAMBIO EL NUMERO DE OPERACIONES MCP: 24 -> 25
     Falta el paso del APIM, que no se puede automatizar:
     subir la OpenAPI y recrear el MCP Server.
```

Si ese aviso no aparece, no hay nada más que hacer. Si aparece, el procedimiento está en
[`../mcp/republicar-mcp-server.md`](../mcp/republicar-mcp-server.md) — son tres cosas: subir
`doc/api/trazalog-operaciones.yaml` en el Publisher, correr `scripts/dev/recrear-api-y-mcp.sh
--apply`, y recrear el MCP Server seleccionando las operaciones.

---

## La primera vez que apuntás un ambiente

Tres cosas, una sola vez por ambiente.

**1. El `.env`.** 💻 En la VM:

```bash
cd ~/git/traz-tools && \
cp deploy/gcp/.env.car.example deploy/gcp/.env.car && \
chmod 600 deploy/gcp/.env.car
```

El `.example` trae los dos juegos de valores conocidos —desarrollo y producción— con el de desarrollo
descomentado: dejás el bloque de **este** servidor y comentás el otro. Está gitignoreado
(`git check-ignore -v deploy/gcp/.env.car` lo confirma).

Las comillas son opcionales: el script lee el `.env` **como datos, no lo ejecuta**, así que una
password con `"`, `<`, `>`, `&`, `$` o espacios entra tal cual, sin escaparla.

**Por qué el `.env` pide también las credenciales de Bonita.** El MI entra a Bonita para crear
instancias de proceso, con el usuario de `bpmconf.xml`. De las 25 operaciones MCP **solo dos** lo
usan: `alm_crear_pedido_materiales` y `man_create_ot`. `bpmconf.xml` es un recurso de registry
(`/_system/config/tools`), pero a diferencia de v2 —donde `deploytools.sh` saltea el registry y los
valores se ponen una vez en el servidor— acá **lo escribe el `.car`**: está declarado en
`resources/artifact.xml` como `type="registry/resource"`, junto con `apiconfig.xml`, los dos `.js` y
la clave pública de Dnato. Por eso sus tres valores tienen que estar en el `.env`.

> 🔴 **Para producción faltan las tres passwords**: `PG_PASS`, `MY_PASS` y `BPM_PASS`. Las dos de
> base, pedilas a quien administre `vm-production-assetplanner-inst1`; la de Bonita, a quien
> administre Bonita de producción. El script se niega a buildear con una variable vacía, a propósito:
> con una password inventada el MI arranca igual y la tool devuelve vacío, que es el síntoma más
> difícil de diagnosticar.

**2. El firewall.** Las VMs tienen el tag `deny-ingress`, y en GCP **a igual prioridad el `deny`
gana**. Que la VM del MCP llegue hoy a un ambiente no implica que llegue al otro. 💻 En la VM del MCP,
con la IP del ambiente:

```bash
for p in 5434 3306 8080; do \
  timeout 5 bash -c "</dev/tcp/10.142.0.2/$p" 2>/dev/null \
  && echo "10.142.0.2:$p ABIERTO" || echo "10.142.0.2:$p CERRADO"; \
done
```

Los tres tienen que decir `ABIERTO`. ⌨️ Si falta alguno, en Cloud Shell:

```bash
gcloud compute firewall-rules create allow-bases-desde-mcp --network=default --direction=INGRESS --action=ALLOW --rules=tcp:5434,tcp:3306 --source-tags=mcp-gateway --target-tags=vm-prod --priority=900 --description="PostgreSQL 5434 y MariaDB 3306 de PROD desde mcp-trazalog"
```

> La prioridad `900` no es decorativa: con la default (1000) la regla se crea y **no habilita nada**,
> porque empata con el `deny-ingress`. Se corrige con
> `gcloud compute firewall-rules update allow-bases-desde-mcp --priority=900`.

**3. El issuer.** El MCP valida los tokens contra **un** Dnato, y tiene que ser el del mismo ambiente
que las bases. Son dos archivos de config del APIM, en la VM del MCP, y los dos tienen que decir el
mismo valor que el `DNATO_ISSUER` del `.htaccess` de ese Dnato:

```bash
sudo systemctl cat wso2am | grep -n "trazalog.dnato.oauth.url" && \
sudo grep -nA 6 "^\[\[apim.jwt.issuer\]\]" /opt/wso2/wso2am-4.6.0/repository/conf/deployment.toml
```

El primero se edita con `sudo systemctl edit --full wso2am` (dejando `trazalog.mcp.resource.url`
**como está**: el dominio del MCP no cambia), el segundo a mano, y después
`sudo systemctl daemon-reload && sudo systemctl restart wso2am`.

> ⚠️ Al cambiar el issuer **los tokens vigentes dejan de servir**: todo cliente ya conectado tiene
> que reconectar el conector en Claude. Avisalo antes.

---

## Lo que tiene que estar hecho en Dnato

Dnato emite los tokens, y de ahí sale el `empr_id` con el que filtran todas las tools. En el Dnato del
ambiente tiene que estar desplegado el tag **`v2.5.0.11` o posterior** —el primero con la pantalla de
selección de empresa del login OAuth— y su `application/config/database.php` tiene que apuntar a **la
misma base** que el `.env` del MCP, o el `empr_id` se resuelve contra otra base y las tools devuelven
datos de otra empresa sin un solo error en el log. En producción las dos cosas ya están, desde el 2026-10-20.

---

## Apéndice — Clonar la VM para un ambiente nuevo

El clon se hace de un snapshot del disco, así que **hereda el `.car` y la config tal como estén**.
⌨️ En Cloud Shell:

```bash
gcloud compute disks snapshot <disco-de-la-vm-mcp> --snapshot-names=mcp-snapshot-$(date +%Y%m%d) --zone=us-east1-b
```

```bash
gcloud compute addresses create mcp-demo-ip --region=us-east1 && \
gcloud compute disks create mcp-demo-disk --source-snapshot=mcp-snapshot-$(date +%Y%m%d) --zone=us-east1-b && \
gcloud compute instances create mcp-demo --zone=us-east1-b --machine-type=e2-medium --disk=name=mcp-demo-disk,boot=yes,auto-delete=yes --tags=<los-mismos-tags-de-red-de-la-vm-actual>
```

Los **tags de red** importan: las reglas de firewall se aplican por tag, y sin ellos la VM nueva no
habla con Dnato ni con la base. Copialos con
`gcloud compute instances describe mcp-trazalog --zone=us-east1-b --format="value(tags.items)"`.

Después, 💻 en la VM nueva, tres cosas:

1. **El dominio**, en los tres lugares que tienen que decir lo mismo: `MCP_DOMAIN` y
   `MCP_RESOURCE_URL` en `deploy/gcp/.env`, el `-Dtrazalog.mcp.resource.url` del `JAVA_OPTS` de
   `wso2am`, y el `https_endpoint` del `deployment.toml`. El PRM que consulta Claude no está
   hardcodeado: sale de esa system property, así que no hay que rebuildear nada.
2. **El issuer y el `.env`**, según "la primera vez que apuntás un ambiente".
3. 🔴 **Rehacer el `.env` con los valores de esta VM y correr el script** — es lo que la devuelve a
   su base. Hasta que el `DESPLIEGUE OK` lo confirme, esa VM **escribe en el ambiente del que se
   clonó**: el `.car` y el `.env` vienen heredados del snapshot.

Antes de apagarla, 🌐 que Let's Encrypt emita el certificado: Caddy lo pide la primera vez que el
dominio resuelve y le llega tráfico, así que si se apaga antes, el día que la prendas no vas a tener
TLS.

```bash
curl -s https://mcp-demo.cloudtrazalog.com/.well-known/oauth-protected-resource | python3 -m json.tool
```

El campo `resource` tiene que decir el dominio nuevo. Recién entonces:
`gcloud compute instances stop mcp-demo --zone=us-east1-b`.
