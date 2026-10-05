# JWT Keys Setup — Clave Pública RS256 de Dnato

**Tarea:** E9-IDENT-03  
**Fecha:** 2026-05

---

## Contexto

Dnato es el Identity Provider del ecosistema Trazalog v3. Emite JWTs firmados con RS256
(private key de Dnato) que WSO2 MI valida usando la clave pública correspondiente.
La clave privada **nunca** sale de Dnato. WSO2 MI solo necesita la clave pública.

---

## 1. Obtener la clave pública de Dnato

### Opción A — Endpoint JWKS (recomendado para Sprint 3+)

Dnato expone un endpoint JWKS (JSON Web Key Set) estándar:

```
GET https://<dnato-host>/.well-known/jwks.json
```

Respuesta esperada:
```json
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "dnato-prod-2026-01",
      "use": "sig",
      "alg": "RS256",
      "n": "<modulus-base64url>",
      "e": "AQAB"
    }
  ]
}
```

Para extraer el PEM desde el JWKS:
```bash
# Instalar jwks-to-pem si es necesario
npm install -g jwks-to-pem

# Exportar clave
curl -s https://<dnato-host>/.well-known/jwks.json | \
  python3 -c "
import json, sys
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicNumbers
import base64

jwks = json.load(sys.stdin)
key = jwks['keys'][0]

def b64url_decode(s):
    s += '=' * (-len(s) % 4)
    return base64.urlsafe_b64decode(s)

n = int.from_bytes(b64url_decode(key['n']), 'big')
e = int.from_bytes(b64url_decode(key['e']), 'big')

pub = RSAPublicNumbers(e, n).public_key()
pem = pub.public_key().public_bytes(
    serialization.Encoding.PEM,
    serialization.PublicFormat.SubjectPublicKeyInfo
)
sys.stdout.write(pem.decode())
"
```

### Opción B — PEM estático (MVP actual)

El equipo de Dnato entrega el archivo PEM por canal seguro (no email).
Formato esperado:

```
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA... (línea ~60 chars)
...
-----END PUBLIC KEY-----
```

---

## 2. Cargar la clave en WSO2 MI (opción B — estático)

### 2.1 Vía Maven / CAR deploy (recomendado en CI/CD)

1. Reemplazar el placeholder en el repo:

```
_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/resources/registry/conf/dnato-public-key.pem
```

2. Build y deploy del CAR:

```bash
cd _backend/api/ToolsAPIProject/ToolsAPIProject
./mvnw clean install
# Copiar .car a $WSO2MI_HOME/repository/deployment/server/carbonapps/
```

El CAR despliega la clave en el registry de WSO2 MI en:
```
/_system/config/identity/dnato-public-key.pem
```

### 2.2 Vía consola WSO2 (manual para emergencias)

1. Admin console → Registry → Browse → `/_system/config/identity/`
2. Crear recurso → tipo `text/plain` → nombre `dnato-public-key.pem`
3. Pegar el contenido del PEM (con headers `-----BEGIN/END PUBLIC KEY-----`)
4. Guardar

---

## 3. Verificar la clave cargada

En WSO2 MI con la propiedad de registry en una API de test:

```xml
<property name="test_key"
          expression="get-property('registry','conf:identity/dnato-public-key.pem')"
          scope="default" type="STRING"/>
<log level="custom">
    <property name="key_loaded" expression="get-property('test_key')"/>
</log>
```

La clave debe aparecer completa en los logs de WSO2 MI.

---

## 4. Rotación de claves (procedimiento manual — MVP)

1. Dnato genera nuevo par de claves RS256
2. Dnato comparte la nueva clave pública por canal seguro
3. Actualizar el archivo PEM en el repo (commit en `develop-v3`)
4. Build y deploy del CAR actualizado a staging, validar tests Hurl
5. Deploy a producción en ventana de mantenimiento
6. Verificar que tokens emitidos con la clave nueva funcionan
7. Dnato deja de emitir tokens con la clave vieja

**Sprint 3+:** Migrar a validación JWKS dinámica (opción A) para rotación sin deploy.

---

## 5. Seguridad

- La clave pública **puede** estar en git — no es un secreto
- La clave privada **nunca** debe tocar este repo ni WSO2 MI
- El archivo PEM en el registry de WSO2 es solo de lectura para el Gateway
- En producción, restringir el acceso al registry a admin únicamente
