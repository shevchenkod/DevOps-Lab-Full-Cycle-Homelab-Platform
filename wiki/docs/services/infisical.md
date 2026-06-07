# 🔑 Infisical

Infisical — open-source secrets management platform with Web UI, CLI, and API.

## Overview

| Property | Value |
|----------|-------|
| Namespace | `infisical` |
| URL | https://infisical.lab.local |
| Backend | PostgreSQL (bundled) |
| Status | ✅ Running |

## Operations

```bash
# Check pods
kubectl get pods -n infisical

# Logs
kubectl logs -n infisical -l app=infisical --tail=50
```

## Known Issue — Ingress Webhook

Infisical bundles its own nginx ingress controller. Its `ValidatingWebhookConfiguration`
(`infisical-ingress-nginx-admission`) by default intercepts **all** cluster ingresses.

**Fix** — restrict webhook to `infisical` namespace only:

```bash
kubectl patch validatingwebhookconfiguration infisical-ingress-nginx-admission \
  --type=json \
  -p '[{"op":"add","path":"/webhooks/0/namespaceSelector","value":{"matchExpressions":[{"key":"kubernetes.io/metadata.name","operator":"In","values":["infisical"]}]}}]'
```

!!! warning
    This patch is reset on every ArgoCD sync that restores the webhook configuration.
    Re-apply after each sync if ingress operations start failing cluster-wide.
