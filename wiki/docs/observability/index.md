# 📊 Observability — Monitoring, Logging, Alerting

> Full observability stack based on kube-prometheus-stack + Loki.

## Components

| Component | Version | URL | Status |
|-----------|---------|-----|--------|
| [Prometheus](prometheus.md) | kube-prometheus-stack 82.4.3 | — | ✅ |
| [Grafana](grafana.md) | bundled with kube-prometheus-stack | [grafana.lab.local](https://grafana.lab.local) | ✅ |
| [Loki + Promtail](loki.md) | 6.29.0 / 6.16.6 | — | ✅ |
| [Alertmanager](alertmanager.md) | bundled with kube-prometheus-stack | → Telegram | ✅ |
| Uptime Kuma | v2.1.3 | [kuma.lab.local](https://kuma.lab.local) | ✅ |

## Architecture

```
Kubernetes Nodes
  └── Promtail (DaemonSet) ──────────→ Loki (singleBinary)
                                              ↓
Node Exporter (DaemonSet) ──→ Prometheus ────→ Grafana Dashboards
kube-state-metrics ──────────↗               ↓
                                       Alertmanager → Telegram
```

## Grafana — Dashboards

Dashboards are deployed via GitOps as ConfigMaps in the `monitoring` namespace:

| Dashboard | ConfigMap | Status |
|-----------|-----------|--------|
| Node Exporter Lab | `grafana-dashboard-node-exporter.yaml` | ✅ |
| K8s Cluster Lab | `grafana-dashboard-k8s-cluster.yaml` | ✅ |
| Loki Logs Lab | `grafana-dashboard-loki-logs.yaml` | ✅ |
