# 🔐 Block K — Security & Identity Platform

**Status: ✅ Complete — 07.06.2026**

---

## What Was Built

| Component | URL | Status |
|-----------|-----|--------|
| HashiCorp Vault v1.19 | https://vault.lab.local | ✅ |
| Infisical | https://infisical.lab.local | ✅ |
| Logto (SSO / OIDC) | https://logto.lab.local | ✅ |
| OPA Gatekeeper v3.18 | https://opa.lab.local/metrics | ✅ |
| External Secrets Operator | ClusterSecretStore vault-backend | ✅ |

Total ArgoCD applications after Block K: **23** (up from 20)

---

## HashiCorp Vault

Standalone Vault with Raft storage. Vault Agent Injector for auto-inject into pods.
External Secrets Operator syncs Vault → K8s Secrets via `ClusterSecretStore vault-backend`.

**Key lesson**: Vault re-seals on every pod restart (Shamir's Secret Sharing, threshold 2/3).
Manual unseal required. **Next step**: configure Transit Auto-Unseal.

See: [Vault service page](../services/vault.md)

---

## Infisical

Open-source secrets management platform with Web UI. PostgreSQL backend.

**Key lesson**: Infisical's bundled nginx controller registers a `ValidatingWebhookConfiguration`
that intercepts ALL cluster ingresses by default. Must restrict with `namespaceSelector`.

See: [Infisical service page](../services/infisical.md)

---

## Logto

Open-source identity platform (SSO / OIDC / OAuth2). PostgreSQL + PVC 4Gi Longhorn.
Idempotent init container: `db seed` skips gracefully if already seeded, then runs `db alteration deploy`.

See: [Logto service page](../services/logto.md)

---

## OPA Gatekeeper

Kubernetes admission controller. Policy-as-code enforcement for all cluster resources.
Metrics exposed at `opa.lab.local/metrics`.

See: [OPA Gatekeeper service page](../services/gatekeeper.md)

---

## Longhorn Tuning

During Block K, Longhorn over-provisioning was increased to **400%** (from 100%)
and minimum available storage set to **5%** (from 25%) to prevent PVC scheduling
failures on constrained nodes.

---

## Uptime Kuma Monitoring

All 14 services now monitored with correct group structure:

| Group | Services |
|-------|---------|
| **Platform** | ArgoCD, Longhorn, MinIO Console, Uptime Kuma, Vault, Logto, OPA Gatekeeper |
| **Monitoring** | Grafana, Prometheus, Alertmanager |
| **Applications** | WordPress, Strapi, N8N, Wiki, Infisical |
