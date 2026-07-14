#!/usr/bin/env bash
# ============================================================
# update-issues-defer-vm-test.sh
# Actualiza los issues afectados por la decisión de diferir
# E0-INF-02 (VM TEST) de Sprint 1 (M1) a Sprint 2 (M2).
#
# Decisión: todo el desarrollo inicial corre en workstation
# Ubuntu 24 DEV con MCP Inspector + ngrok. La VM TEST no se
# necesita hasta tener tools funcionando localmente (Sprint 2).
#
# Prerequisito: gh auth login con permisos de write.
# Uso: bash update-issues-defer-vm-test.sh
# ============================================================

set -euo pipefail

REPO="Trazalog/traz-tools"

echo "🔄 Aplicando decisión: diferir VM TEST al Sprint 2"
echo "   Repo: $REPO"
echo ""

# ── Buscar los números de issue por título ───────────────────
echo "🔍 Buscando issues por título..."

get_issue_number() {
  local title_fragment="$1"
  gh issue list --repo "$REPO" --search "$title_fragment" --json number,title \
    --jq ".[0].number" 2>/dev/null || echo ""
}

NUM_INF02=$(get_issue_number "E0-INF-02")
NUM_INF03=$(get_issue_number "E0-INF-03")
NUM_INF05=$(get_issue_number "E0-INF-05")

echo "   E0-INF-02 → issue #${NUM_INF02:-NO ENCONTRADO}"
echo "   E0-INF-03 → issue #${NUM_INF03:-NO ENCONTRADO}"
echo "   E0-INF-05 → issue #${NUM_INF05:-NO ENCONTRADO}"
echo ""

if [[ -z "$NUM_INF02" || -z "$NUM_INF03" || -z "$NUM_INF05" ]]; then
  echo "❌ No se encontraron todos los issues. Verificá que están creados y el repo es correcto."
  exit 1
fi

# ── E0-INF-02: Diferir a M2, bajar prioridad a Should have ──
echo "📝 Actualizando E0-INF-02 (#$NUM_INF02)..."
gh issue edit "$NUM_INF02" \
  --repo "$REPO" \
  --body "Como PM técnico, necesito provisionar una VM en GCP con OS soportado (Rocky Linux 9) para el ambiente TEST de v3, para poder validar el deploy antes de tocar PROD y ejecutar la suite de regresión Playwright contra v3.

> 📅 **Diferido a Sprint 2 (M2)** — Decisión 10/05/2026: durante el Sprint 1, todo el desarrollo y testing de tools MCP se realiza en la workstation Ubuntu 24 DEV usando MCP Inspector (Etapa 1) y ngrok + Claude.ai (Etapa 2). La VM TEST no es necesaria hasta tener tools funcionando localmente. Se evita gasto de GCP sin uso real.

## CRITERIOS DE ACEPTACIÓN
1. VM provisionada en GCP: Rocky Linux 9, 4 vCPU, 4GB RAM, 20GB disco
2. Acceso SSH configurado desde la workstation DEV
3. OpenVPN configurado (mismo patrón que VMs existentes)
4. DNS/URL staging-v3 asignada (ej: staging-v3.cloudtrazalog.com)
5. Firewall: puertos 22 (SSH), 443 (HTTPS), 9443 (WSO2 mgmt), 8243 (WSO2 gateway)
6. Ping exitoso desde workstation DEV a la VM TEST

## DEFINICIÓN DE LISTO
- [ ] VM accesible por SSH desde DEV
- [ ] OpenVPN configurado
- [ ] IP/hostname documentado y enviado al PM para registro de infraestructura
- [ ] Reviewed por PM

**Sprint:** Sprint 2 — M2 (diferido desde M1)
**Prioridad:** Should have (para Sprint 1) → Must have (para Sprint 2)
**Story Points:** 3
**Dependencias:** E0-INF-01"

echo "   ✅ E0-INF-02 actualizado (M1→M2, nota de decisión agregada)"

# ── E0-INF-03: Aclarar split DEV (M1) vs TEST (M2) ─────────
echo "📝 Actualizando E0-INF-03 (#$NUM_INF03)..."
gh issue edit "$NUM_INF03" \
  --repo "$REPO" \
  --body "Como PM técnico, necesito JDK 21 (Temurin OpenJDK) instalado en DEV y TEST de v3, porque WSO2 API Manager 4.6.0 requiere Java 21 según documentación oficial. Sin esto los issues E0-INF-04 (WSO2 en DEV) y E0-INF-05 (WSO2 en TEST) están bloqueados.

## Responsabilidades y timing

| Ambiente | Quién | Cuándo | Cómo |
|---|---|---|---|
| **DEV** (workstation Ubuntu 24) | **PM, manualmente** | **Sprint 1 (M1)** | Comandos directos en terminal |
| **TEST** (VM GCP Rocky Linux 9) | **Claude Code vía SSH** | **Sprint 2 (M2)** — después de E0-INF-02 | Prompt en Cursor |

> 📅 **Parte B (TEST) diferida a Sprint 2** — la VM TEST se provisiona en E0-INF-02 que se difirió a M2.

---

## Parte A — DEV (manual, Sprint 1)

\`\`\`bash
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/trusted.gpg.d/adoptium.asc
echo \"deb https://packages.adoptium.net/artifactory/deb \$(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt update && sudo apt install -y temurin-21-jdk
echo 'export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64' | sudo tee /etc/profile.d/jdk21.sh
echo 'export PATH=\$JAVA_HOME/bin:\$PATH' | sudo tee -a /etc/profile.d/jdk21.sh
source /etc/profile.d/jdk21.sh
java -version
\`\`\`

## Parte B — TEST (Claude Code vía SSH, Sprint 2)

Ver prompt completo en \`trazalog-v3-sprint-1-kickoff.md\` → sección E0-INF-03 Parte B.

---

## CRITERIOS DE ACEPTACIÓN
1. Temurin OpenJDK 21 instalado en DEV (Sprint 1) y TEST (Sprint 2)
2. \`JAVA_HOME\` persistente entre sesiones en ambos ambientes
3. \`java -version\` devuelve \`openjdk version \"21.x.x\"\`
4. \`doc/infra/jdk21-install.md\` commiteado (reutilizable para PROD en cutover)

## DEFINICIÓN DE LISTO
- [ ] JDK 21 validado en DEV — Sprint 1 (PM confirma manualmente)
- [ ] JDK 21 validado en TEST — Sprint 2 (vía SSH)
- [ ] \`JAVA_HOME\` persistente verificado en TEST (nueva sesión SSH)
- [ ] \`doc/infra/jdk21-install.md\` commiteado en develop-v3
- [ ] Reviewed por PM

**Sprint DEV:** Sprint 1 — M1 | **Sprint TEST:** Sprint 2 — M2
**Story Points:** 2 (1 por parte)
**Dependencias:** E0-INF-01 (Parte A DEV) / E0-INF-02 (Parte B TEST)"

echo "   ✅ E0-INF-03 actualizado (split M1/M2 clarificado)"

# ── E0-INF-05: Diferir a M2 ──────────────────────────────────
echo "📝 Actualizando E0-INF-05 (#$NUM_INF05)..."
gh issue edit "$NUM_INF05" \
  --repo "$REPO" \
  --body "Como PM técnico, necesito WSO2 API Manager 4.6.0 y PostgreSQL instalados en la VM TEST de v3, para poder validar el deploy de las APIs y del MCP Gateway en un ambiente equivalente a producción antes del cutover.

> 📅 **Diferido a Sprint 2 (M2)** — Depende de E0-INF-02 (VM TEST) que se difirió a Sprint 2. Durante el Sprint 1, WSO2 corre solo en DEV local para desarrollo con MCP Inspector y ngrok.

## CRITERIOS DE ACEPTACIÓN
1. WSO2 4.6.0 instalado en VM TEST (Rocky Linux 9) y accesible vía HTTPS
2. PostgreSQL instalado y configurado como BD de WSO2 en TEST (no H2)
3. Publisher, Developer Portal y Carbon Console accesibles en el hostname de TEST
4. MCP Gateway activo y respondiendo en el puerto 8243 de TEST
5. Smoke test: API hello-world publicada y consumida desde TEST
6. \`doc/infra/wso2-test-install.md\` con procedimiento completo

## DEFINICIÓN DE LISTO
- [ ] WSO2 accesible en TEST vía HTTPS
- [ ] PostgreSQL configurado como BD principal de WSO2
- [ ] Smoke test pasado
- [ ] \`doc/infra/wso2-test-install.md\` commiteado
- [ ] Reviewed por PM

**Sprint:** Sprint 2 — M2 (diferido desde M1)
**Story Points:** 5
**Dependencias:** E0-INF-02, E0-INF-03 (Parte B), E0-INF-04"

echo "   ✅ E0-INF-05 actualizado (M1→M2)"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ Issues actualizados exitosamente"
echo ""
echo "Resumen de cambios:"
echo "  E0-INF-02 (#$NUM_INF02): M1→M2 | Must have→Should have para S1 | nota de decisión agregada"
echo "  E0-INF-03 (#$NUM_INF03): split aclarado — Parte A DEV en M1 / Parte B TEST en M2"
echo "  E0-INF-05 (#$NUM_INF05): M1→M2 | depende de E0-INF-02"
echo ""
echo "Sprint 1 resultante: 23 SP (dentro de capacidad)"
echo "Sprint 2 adicional: E0-INF-02 (3SP) + E0-INF-03 Parte B (1SP) + E0-INF-05 (5SP) = 9SP adicionales"
echo "════════════════════════════════════════════════════════════"
