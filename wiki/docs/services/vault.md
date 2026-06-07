# 🔐 HashiCorp Vault

HashiCorp Vault v1.19 — centralized secrets management with Web UI, Vault Agent Injector, and External Secrets Operator integration.

## Overview

| Property | Value |
|----------|-------|
| Version | v1.19 |
| Namespace | `vault` |
| URL | https://vault.lab.local |
| Storage | Longhorn PVC 10Gi |
| Mode | Standalone + Raft |
| Agent Injector | ✅ Enabled |
| ESO Integration | ✅ `ClusterSecretStore vault-backend` |

## Architecture

```
vault.lab.local
    └── ingress-nginx
        └── vault (svc :8200)
            └── vault-0 (pod)
                └── /vault/data (Raft, Longhorn 10Gi)
```

## Deployment

Deployed via Argo CD using multi-source Application (`cluster/apps/app-vault.yaml`):
- Source 1: `hashicorp/vault` Helm chart v0.32.0
- Source 2: `apps/vault/` — local ingress + TLS certificate

## Operations

```bash
# Check status
kubectl exec -n vault vault-0 -- vault status

# Unseal (required after every pod restart)
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>

# Login (root token)
kubectl exec -n vault vault-0 -- vault login <root_token>

# List all secrets
kubectl exec -n vault vault-0 -- vault secrets list
kubectl exec -n vault vault-0 -- vault kv list secret/
```

## ESO Integration

External Secrets Operator uses a `ClusterSecretStore` to sync Vault secrets → K8s Secrets:

```yaml
# Example ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: my-app-secret
  data:
    - secretKey: password
      remoteRef:
        key: secret/my-app
        property: password
```

## Vault Agent Injector

Auto-injects secrets into pods via annotations:

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-role"
  vault.hashicorp.com/agent-inject-secret-config: "secret/my-app"
```

## Known Issues

!!! warning "Re-seals on pod restart"
    Vault uses Shamir's Secret Sharing (3 key shares, threshold 2). After every pod restart,
    Vault re-seals and requires manual unseal with 2 of 3 keys.

    **Planned fix**: Configure Transit Auto-Unseal to eliminate manual unseal.
