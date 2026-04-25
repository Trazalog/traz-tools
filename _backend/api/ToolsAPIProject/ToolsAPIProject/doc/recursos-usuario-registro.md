# Recursos `toolsCOREAPI`: registro en dos pasos

Ubicación de artefactos:

- API: `src/main/wso2mi/artifacts/apis/toolsCOREAPI.xml`
- Data service: `src/main/wso2mi/artifacts/data-services/COREDataService.dbs`

## Requisitos cubiertos

| Requisito | Implementación |
|-----------|----------------|
| POST `/usuario` sin cambios | No se modificó el recurso existente. |
| Recurso 1: usuario + token sin contraseña (solo PostgreSQL) | `POST /tools/core/usuario/registro` → DS `POST /usuario/registro` + `POST /registro/token`. |
| Token generado en PHP | El cliente envía `token` (30 caracteres); la API solo persiste en `seg.tokens`. |
| Recurso 2: BPM + AssetPlanner | `POST /tools/core/usuario/bpm-asset` → GET `usernick`, BPM `POST /bpm/users`, DS `assetuser/add` con `password_md5`. |

## Contratos

### `POST /usuario/registro`

```json
{
  "usuario": {
    "firstname": "...",
    "lastname": "...",
    "email": "...",
    "telefono": "",
    "reg_pais_id": "",
    "reg_razon_social": "",
    "role": "",
    "status": "",
    "banned_users": "",
    "usernick": ""
  },
  "token": "30_caracteres_generados_en_php"
}
```

Respuesta: `{ "respuesta": { "resultado": "ok", "usr_id": "..." } }`

En PHP: `token_completo = token + usr_id` (compatible con `isTokenValid`).

### `POST /usuario/bpm-asset`

```json
{
  "bpmSession": "...",
  "usuario": {
    "email": "...",
    "password": "texto_plano_para_bpm",
    "password_md5": "hash_md5_para_assetplanner",
    "firstname": "...",
    "lastname": "..."
  }
}
```

El `usernick` se obtiene con `GET .../COREDataService/usuario/usernick/{email}`.

Respuesta: `{ "respuesta": { "resultado": "ok" } }`

## Data service (PostgreSQL)

- Nuevo: `setUsuarioRegistro` — INSERT en `seg.users` sin password.
- Nuevo: `insertTokenRegistro` — INSERT en `seg.tokens`.
- Nuevo: `getUsernickByEmail` + `GET /usuario/usernick/{email}`.
