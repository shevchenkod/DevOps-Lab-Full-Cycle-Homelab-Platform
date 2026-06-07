# 🪪 Logto — SSO / OIDC Provider

Logto — open-source identity platform. Provides SSO, OIDC, OAuth2, and user management.

## Overview

| Property | Value |
|----------|-------|
| Namespace | `logto` |
| URL | https://logto.lab.local |
| Admin Console | https://logto.lab.local/console |
| Backend | PostgreSQL (PVC 4Gi Longhorn) |
| Status | ✅ Running |

## Architecture

```
logto.lab.local
    └── ingress-nginx
        └── logto (svc :3001)
            └── logto pod
                └── logto-postgres (svc :5432)
                    └── PVC 4Gi (longhorn-1r)
```

## DB Init (Idempotent)

The init container runs on every pod start and is safe to re-run:

```bash
# Seeds DB if empty, skips gracefully if already seeded
node packages/cli/bin/logto.js db seed
# Then applies pending schema migrations
node packages/cli/bin/logto.js db alteration deploy latest
```

## Operations

```bash
# Check pods
kubectl get pods -n logto

# Logs
kubectl logs -n logto -l app=logto --tail=50
kubectl logs -n logto -l app=logto-postgres --tail=30
```

## Known Issue — Longhorn Stale Mount

If `logto-postgres` is stuck in `ContainerCreating` with error:
```
mount: /dev/longhorn/pvc-xxx already mounted or mount point busy
```

**Fix:**
```bash
# 1. Delete the VolumeAttachment
kubectl get volumeattachment | grep <pvc-id>
kubectl delete volumeattachment <va-name> --force --grace-period=0

# 2. Restart Longhorn CSI plugin on the affected node
kubectl delete pod -n longhorn-system -l app=longhorn-csi-plugin --field-selector spec.nodeName=<node>

# 3. Force delete stuck pods
kubectl delete pod -n logto <pod-name> --force --grace-period=0
```
