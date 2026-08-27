# Testing Workflow — MCP Trazalog v3

Flujo de testing en dos etapas para tools MCP expuestas via WSO2 APIM 4.6.0.

---

## Las dos etapas

### Etapa 1 — MCP Inspector (testing técnico local)

**Cuándo usarlo:** validar schemas JSON-RPC, contratos de tools y respuestas del servidor
*antes* de involucrar a Claude. No requiere internet ni cuenta Claude Pro.

```bash
npx @modelcontextprotocol/inspector
```

UI disponible en: http://localhost:6274

**Qué valida:**
- Estructura de `tools/list`
- Parámetros y tipos de datos
- Error handling

**Cuándo está completo:** todas las tools responden con schema correcto en Inspector.

---

### Etapa 2 — Claude.ai con ngrok (testing semántico end-to-end)

**Cuándo usarlo:** después de pasar Etapa 1. Valida que Claude entiende las descripciones
de las tools y las invoca correctamente en contexto real.

**Requisitos:** Claude Pro activo + ngrok corriendo + WSO2 APIM levantado.

**Tunnel ngrok (crítico — WSO2 usa HTTPS en puerto 8243):**

```bash
# CORRECTO
ngrok http https://localhost:8243

# INCORRECTO — rompe el handshake SSL
ngrok http 8243
```

**Configurar connector en Claude.ai:**
Settings → Connectors → Add custom connector → URL: `https://<id>.ngrok-free.app`

> **Plan free:** la URL ngrok cambia en cada reinicio. Actualizar el connector en Claude.ai
> cada vez que se reinicie ngrok.

**Qué valida:**
- Semántica de las tool descriptions
- Comportamiento de Claude al invocar tools
- Respuestas en lenguaje natural

---

## Cuándo usar cada etapa

| Situación | Etapa |
|---|---|
| Crear una tool nueva | Etapa 1 primero, luego Etapa 2 |
| Cambiar parámetros de una tool existente | Etapa 1 |
| Cambiar la descripción semántica de una tool | Etapa 2 |
| Debugging de error JSON-RPC | Etapa 1 |
| Validar que Claude invoca la tool correcta ante una pregunta | Etapa 2 |
| Antes de hacer PR de una tool nueva | Ambas etapas |

---

## Checklist antes de cerrar un issue de tool MCP

- [ ] Tool pasa Etapa 1: MCP Inspector devuelve schema correcto
- [ ] Tool tiene annotation correcta (`readOnlyHint` o `destructiveHint`) — ver [`doc/mcp/tool-annotations-standard.md`](../mcp/tool-annotations-standard.md)
- [ ] Tool pasa Etapa 2: Claude la invoca correctamente con una pregunta en lenguaje natural
- [ ] Tool result < 25.000 tokens
- [ ] Timeout < 5 minutos
