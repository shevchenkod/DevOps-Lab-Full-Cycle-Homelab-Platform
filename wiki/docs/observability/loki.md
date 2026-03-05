# 📋 Loki + Promtail

> Logs as Prometheus. Loki stores, Promtail collects, Grafana displays.

## Lab Configuration

| Parameter | Value |
|-----------|-------|
| Loki Helm chart | `grafana/loki 6.29.0` |
| Promtail Helm chart | `grafana/promtail 6.16.6` |
| Namespace | `loki` |
| Mode | singleBinary |
| Argo CD | `cluster/apps/app-loki.yaml` |

## Installation

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana/loki-stack \
  --namespace loki \
  --create-namespace \
  --set grafana.enabled=false \
  --set promtail.enabled=true
```

## LogQL — Example Queries

```logql
# All logs from a pod
{namespace="production", pod="my-app-xxx"}

# Filter by text
{namespace="production"} |= "ERROR"

# Regular expression
{namespace="production"} |~ "timeout|connection refused"

# Parse JSON
{namespace="production"} | json | level="error"

# Count errors over time
count_over_time({namespace="production"} |= "ERROR" [5m])
```

## Lab Queries

```logql
# All logs in a namespace
{namespace="minio"}

# Filter errors
{namespace="minio"} |= "ERROR"

# N8N logs
{namespace="n8n"}

# All cluster logs (all namespaces)
{namespace=~".+"}
```

## Promtail

Promtail runs as a DaemonSet — one pod per node, collecting logs from all containers and sending them to Loki.

```bash
# Check Promtail status
kubectl get pods -n loki -l app.kubernetes.io/name=promtail

# Promtail logs (for debugging)
kubectl logs -n loki -l app.kubernetes.io/name=promtail --tail=50
```
