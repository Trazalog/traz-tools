# ngrok — Setup y tunnel MCP para testing con Claude

Procedimiento para exponer el WSO2 API Gateway local a internet usando ngrok,
permitiendo que Claude.ai invoque el servidor MCP de Trazalog en desarrollo.

---

## 1. Instalación (Ubuntu 24)

Se usa el repositorio oficial de ngrok vía apt:

```bash
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null

echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list

sudo apt update && sudo apt install ngrok
```

Versión instalada: **3.39.1**

---

## 2. Autenticación

Registrarse en [ngrok.com](https://ngrok.com) y obtener el authtoken desde el dashboard.
Configurarlo una sola vez:

```bash
ngrok config add-authtoken <TOKEN>
```

El token queda guardado en `~/.config/ngrok/ngrok.yml`.

---

## 3. Lanzar el tunnel al WSO2 Gateway (puerto 8243)

Con WSO2 API Manager corriendo localmente:

```bash
ngrok http 8243
```

Salida esperada (ejemplo del smoke test ejecutado 2026-05-16):

```
Session Status    online
Region            South America (sa)
Web Interface     http://127.0.0.1:4040
Forwarding        https://129e-200-114-96-54.ngrok-free.app -> https://localhost:8243
```

La URL pública (`https://<id>.ngrok-free.app`) es la que se usa como base para el
conector MCP en Claude.ai.

La región South America (sa) se elige automáticamente por geolocalización — no
requiere configuración adicional.

---

## 4. Limitaciones del plan free

| Limitación | Detalle |
|---|---|
| URL efímera | La URL pública cambia cada vez que se reinicia ngrok |
| Sin dominios fijos | El plan pago permite dominios estáticos |
| Conexiones simultáneas | 1 tunnel activo por cuenta en el plan free |

**Workaround para la URL cambiante**: cada vez que se reinicie ngrok, copiar la nueva
URL y actualizar el custom connector en Claude.ai:

> Settings → Connectors → (seleccionar el conector existente) → editar URL

El **dashboard local** en `http://127.0.0.1:4040` muestra todos los requests que
pasan por el tunnel en tiempo real — indispensable para debug de llamadas MCP.

---

## 5. Agregar el custom connector en Claude.ai (E0-INF-12)

Una vez que ngrok está activo y WSO2 está corriendo:

1. Copiar la URL del tunnel desde la salida de ngrok (ej: `https://129e-200-114-96-54.ngrok-free.app`)
2. Abrir Claude.ai → **Settings** → **Connectors** → **Add custom connector**
3. Completar la URL del endpoint MCP:
   ```
   https://<url-ngrok>/mcp
   ```
4. Guardar y verificar que Claude detecta las herramientas expuestas por el servidor MCP

> **Nota**: el path `/mcp` corresponde al endpoint configurado en WSO2 APIM para el
> servidor MCP de Trazalog. Verificar en el API Publisher que el contexto de la API
> coincide antes de registrar el conector.
