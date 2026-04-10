# 🤖 N8N — Workflow Automation

> N8N is a self-hosted automation platform with support for 400+ integrations.
> In this lab it orchestrates a Telegram bot, Alertmanager alerts,
> daily cluster reports, and webhook-triggered K8s actions.

## Lab Configuration

| Parameter | Value |
|-----------|-------|
| Namespace | `n8n` |
| UI | [https://n8n.lab.local](https://n8n.lab.local) |
| Version | `2.10.2` |
| Image | `n8nio/n8n:2.10.2` |
| Database | SQLite (`/home/node/.n8n/database.sqlite`) |
| PVC | `n8n-data` — 2Gi (`longhorn`, 2 replicas) |
| Argo CD | `cluster/argocd/app-n8n.yaml` |
| Ingress | `10.44.81.200` → `n8n.lab.local` |
| TLS | cert-manager `lab-ca-issuer` → secret `n8n-tls` |
| Status | ✅ `1/1 Running` |

## Telegram Bot

| Parameter | Value |
|-----------|-------|
| Bot | `@smartitsupportbot` |
| Commands | `/status`, `/pods`, `/help` |
| Token | Encrypted in SealedSecret `n8n-telegram-secret` |
| chat_id | Stored in env var `N8N_TELEGRAM_CHAT_ID` |

## Workflows

| # | Name | Trigger | Purpose |
|---|------|---------|---------|
| 01 | 🔔 Alertmanager → Telegram | Webhook POST `/webhook/alertmanager` | Forwards Prometheus alerts to Telegram |
| 02 | 🤖 Telegram Bot (Polling) | Cron every minute | Polls Telegram getUpdates, responds to /status /pods /help |
| 03 | 📊 Daily Cluster Report | Cron `09:00` daily | Collects cluster state, sends report to Telegram |
| 04 | �� Webhook Cluster Actions | Webhook POST `/webhook/cluster-action` | Restarts deployment via HTTP request |

## Screenshots

### Dashboard — workflow list
![N8N Dashboard](../../assets/images/n8n/devops-lab-n8n-01.png)

### Workflow Editor (Telegram Bot)
![N8N Workflow Editor](../../assets/images/n8n/devops-lab-n8n-02.png)

### Executions — Event Log
![N8N Executions](../../assets/images/n8n/devops-lab-n8n-03.png)

## Key Environment Variables

```yaml
N8N_HOST: n8n.lab.local
N8N_PROTOCOL: https
WEBHOOK_URL: https://n8n.lab.local/
GENERIC_TIMEZONE: Europe/Kiev
N8N_PROXY_HOPS: "1"               # Behind nginx ingress
N8N_DIAGNOSTICS_ENABLED: "false"  # Disable PostHog telemetry
N8N_BLOCK_ENV_ACCESS_IN_NODE: "false"  # Allow env access in Code nodes
NODE_FUNCTION_ALLOW_BUILTIN: "https,fs,url,http"  # Built-in Node.js modules
```

## RBAC — K8s API Access

N8N uses ServiceAccount `n8n-sa` with a ClusterRole for reading nodes and pods:

```yaml
# apps/n8n/rbac.yaml
rules:
  - apiGroups: [""]
    resources: ["nodes", "pods", "namespaces"]
    verbs: ["get", "list"]
```

## Quick Commands

```powershell
# Status
kubectl get pods -n n8n
kubectl get pvc -n n8n

# Logs
kubectl logs -n n8n deployment/n8n --tail=50

# Restart
kubectl rollout restart deployment/n8n -n n8n
```

## Secrets (SealedSecrets)

| SealedSecret | Keys | Purpose |
|-------------|------|---------|
| `n8n-sealed-secret` | `N8N_ENCRYPTION_KEY`, `N8N_USER_MANAGEMENT_JWT_SECRET` | N8N data encryption |
| `n8n-telegram-secret` | `N8N_TELEGRAM_BOT_TOKEN` | Telegram Bot API token |
| `n8n-k8s-token` | `K8S_API_TOKEN` | ServiceAccount token for K8s API |

> ✅ All secrets encrypted via Sealed Secrets — safe to store in Git.

## Known Issues

| # | Issue | Cause | Resolution |
|---|-------|-------|-----------|
| 1 | `ERR_ERL_UNEXPECTED_X_FORWARDED_FOR` | N8N does not trust proxy | `N8N_PROXY_HOPS=1` |
| 2 | PostHog 504 errors in logs | Telemetry unreachable | `N8N_DIAGNOSTICS_ENABLED=false` |
| 3 | `access to env vars denied` in Code nodes | Default protection | `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` |
| 4 | `Credentials not found` for K8s HTTP nodes | Sealed secret not wired | Replace with Code nodes using `require("https")` |
