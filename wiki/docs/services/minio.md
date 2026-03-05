# 🪣 MinIO — S3-Compatible Object Storage

> MinIO is a self-hosted object storage service with full Amazon S3 API compatibility.
> In this lab it serves as the backend for Velero (Kubernetes backups) and Longhorn (DR volume backups),
> and as a standalone S3 service.

## Configuration

| Parameter | Value |
|-----------|-------|
| Namespace | `minio` |
| URL (Console) | [https://minio.lab.local](https://minio.lab.local) |
| Login | S3 credentials (lab admin) |
| Helm Chart | `minio/minio 5.4.0` |
| Image | `quay.io/minio/minio:RELEASE.2024-12-18T13-15-44Z` |
| Mode | Standalone |
| Storage | 10Gi PVC (`longhorn-single`) |
| API Port | `9000` (S3 API) |
| Console Port | `9001` (Web UI) |
| Argo CD | `cluster/argocd/app-minio.yaml` |
| Status | ✅ `1/1 Running` |

## Buckets

| Bucket | Purpose |
|--------|---------|
| `velero` | Kubernetes resource backups (Velero) |
| `longhorn-backup` | Longhorn PVC backups (type: `bak`, DR-safe) |

## S3 API — In-Cluster Access

MinIO is fully S3 API compatible. Internal cluster endpoint:

```
http://minio.minio.svc.cluster.local:9000
```

Creating buckets via `mc` (MinIO Client) inside a pod:

```bash
# Set alias
kubectl exec -n minio deploy/minio -- \
  mc alias set myminio http://localhost:9000 <access-key> <secret-key> --api s3v4

# Create bucket
kubectl exec -n minio deploy/minio -- mc mb myminio/my-bucket

# List buckets
kubectl exec -n minio deploy/minio -- mc ls myminio
```

## Prometheus Metrics

MinIO Console displays extended metrics (Usage / Traffic / Resources tabs)
when Prometheus is connected. Configured via environment variables in Helm values.

### Configuration (`cluster/argocd/app-minio.yaml`)

```yaml
environment:
  MINIO_PROMETHEUS_URL: "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
  MINIO_PROMETHEUS_JOB_ID: "minio"
  # ⚠️ JOB_ID must match the job label in Prometheus (see below)
```

### ServiceMonitor

Prometheus scrapes MinIO via ServiceMonitor (`cluster/minio/servicemonitor.yaml`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: minio
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  endpoints:
    - port: http
      path: /minio/v2/metrics/cluster
      interval: 30s
      scrapeTimeout: 10s
  namespaceSelector:
    matchNames:
      - minio
  selector:
    matchLabels:
      app: minio
      release: minio
      monitoring: "true"   # ← minio:9000 only, not minio-console:9001
```

!!! warning "job label must exactly match JOB_ID"
    Prometheus assigns the job label from `metadata.name` of the ServiceMonitor → `job=minio`.
    If `MINIO_PROMETHEUS_JOB_ID` does not match this value,
    the **Usage / Traffic / Resources** tabs in MinIO Console will be empty.

    | Parameter | Value |
    |-----------|-------|
    | ServiceMonitor name | `minio` |
    | Prometheus job label | `job=minio` |
    | `MINIO_PROMETHEUS_JOB_ID` | `"minio"` ✅ |

### Verify Prometheus Target

```powershell
$env:KUBECONFIG = "H:\DEVOPS-LAB\kubeconfig-lab.yaml"
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090 &
Start-Sleep 3
(Invoke-RestMethod "http://localhost:9090/api/v1/targets").data.activeTargets |
  Where-Object {$_.labels.job -eq "minio"} |
  Select-Object @{N="job";E={$_.labels.job}}, health, lastScrape
```

Expected result:
```
job   health lastScrape
---   ------ ----------
minio up     2026-03-01T...
```

## Logging

MinIO pod logs are automatically collected by **Promtail** (DaemonSet) and available in Grafana → Loki:

```logql
# Grafana → Explore → Loki
{namespace="minio"}
{namespace="minio"} |= "ERROR"
{namespace="minio"} | json
```

MinIO Console → **Logs** tab shows a real-time stream via WebSocket (requires
`nginx.ingress.kubernetes.io/proxy-http-version: "1.1"` annotation on the Ingress).

!!! info "Audit Logs"
    MinIO Console → **Audit** tab requires an HTTP webhook compatible with the Loki Push API format.
    MinIO sends raw JSON events; Loki expects `{"streams":[...]}` — the formats are incompatible.
    In this lab the Audit tab is not used; logs are available via Promtail → Loki → Grafana.

## Pod Monitoring

```powershell
$env:KUBECONFIG = "H:\DEVOPS-LAB\kubeconfig-lab.yaml"

# Status
kubectl get pods -n minio -o wide

# Logs
kubectl logs -n minio deployment/minio --tail=50

# Env vars (verify configuration)
kubectl exec -n minio deployment/minio -- env | Select-String "PROMETHEUS|MINIO"

# Metrics directly
kubectl port-forward -n minio svc/minio 9000:9000 &
Start-Sleep 2
Invoke-RestMethod "http://localhost:9000/minio/v2/metrics/cluster" | Select-Object -First 30
```

## Velero + MinIO

MinIO serves as the S3-compatible backend for Velero backup:

```yaml
# cluster/velero/values.yaml (excerpt)
configuration:
  backupStorageLocation:
    - provider: aws
      bucket: velero
      config:
        region: us-east-1
        s3ForcePathStyle: "true"
        s3Url: "http://minio.minio.svc.cluster.local:9000"
        checksumAlgorithm: ""   # ← REQUIRED for MinIO (see Lessons Learned #1)
```

## Longhorn BackupTarget

MinIO serves as the external BackupTarget for Longhorn DR:

```yaml
# cluster/storage/backup-target.yaml
spec:
  backupTargetURL: "s3://longhorn-backup@us-east-1/"
  credentialSecret: "longhorn-backup-secret"
```

The credential secret stores S3 access key, secret, and endpoint — sealed via Sealed Secrets, safe to commit.

---

## Screenshots

<figure markdown="span">
  ![MinIO Console — buckets and Overview](../assets/images/minio/devops-lab-minio-01.png){ loading=lazy }
  <figcaption>MinIO Console — S3 bucket list, Server Info (objects, capacity)</figcaption>
</figure>
