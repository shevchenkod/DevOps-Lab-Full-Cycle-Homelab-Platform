# 🔥 Prometheus

> Metrics and alerting. Time-series database with PromQL query language.

## Lab Configuration

| Parameter | Value |
|-----------|-------|
| Helm chart | `kube-prometheus-stack 82.4.3` |
| Namespace | `monitoring` |
| Argo CD | `cluster/apps/app-monitoring.yaml` |
| Prometheus UI | port-forward `svc/kube-prometheus-stack-prometheus 9090:9090` |

## Installation (kube-prometheus-stack)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f monitoring-values.yaml
```

## PromQL — Example Queries

```promql
# CPU load per node
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# HTTP requests per second
rate(http_requests_total[5m])

# Pod restart count
sum(kube_pod_container_status_restarts_total) by (namespace, pod)

# Availability (for SLO)
avg_over_time(up[30d]) * 100
```

## Alert Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
  namespace: monitoring
spec:
  groups:
    - name: my-app
      rules:
        - alert: HighCPU
          expr: cpu_usage > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High CPU on {{ $labels.instance }}"
            description: "CPU: {{ $value }}%"

        - alert: PodCrashLooping
          expr: rate(kube_pod_container_status_restarts_total[15m]) > 0.1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Pod {{ $labels.pod }} is CrashLooping"
```

## SLO Logic

```promql
# SLI: fraction of successful requests
sum(rate(http_requests_total{status!~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# SLO Target: 99.9%
# Error Budget over 30 days: 30 * 24 * 60 * 0.001 = 43.2 minutes
```
