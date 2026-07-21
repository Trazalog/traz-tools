# deploy/gcp/

Scripts de instalación **nativa** (sin Docker) del stack WSO2 en la VM de GCP
del early adopter minero. Implementa [ADR-011](../../doc/adr/ADR-011-gcp-deployment.md).

Documentación completa (sizing, justificación, checklist para Rodolfo en la
consola de GCP): [`doc/v3/deployment-gcp.md`](../../doc/v3/deployment-gcp.md).

## Convención de esta carpeta

`deploy/<proveedor>/` para artefactos de despliegue ejecutables sobre
infraestructura real (scripts, unidades systemd, config de reverse proxy).
Se diferencia de `doc/infra/` (documentación de procedimientos) y de
`scripts/dev/` (scripts de setup de DEV/testing). Si en el futuro se agrega
otro proveedor o topología, va en `deploy/<nuevo-proveedor>/`, no acá adentro.

## Orden de ejecución (en la VM GCP, no localmente)

```bash
cp .env.example .env
# completar .env con los valores reales (PostgreSQL externa, dominio, etc.)

sudo ./install-apim.sh
sudo ./install-mi.sh
sudo ./setup-reverse-proxy.sh

sudo systemctl start wso2am
sudo systemctl start wso2mi
```

## Qué NO hacen estos scripts

- No descargan los `.zip` de WSO2 (requieren cuenta en wso2.com — descarga manual).
- No configuran identidad/JWT/Key Manager (ADR-008/ADR-009) — es clase 🔴, deuda
  aparte antes de dar de alta al primer cliente.
- No migran las DataServices de negocio del MI de MySQL a PostgreSQL — trabajo
  en curso aparte (`doc/identity/dataservices-remediation-phase-a.md`).
- No crean la VM, la IP estática, el DNS, ni las reglas de firewall — eso lo
  hace Rodolfo en su consola de GCP (checklist en `deployment-gcp.md`).
