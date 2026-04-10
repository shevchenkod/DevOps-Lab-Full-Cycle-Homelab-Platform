## E. Observability: metrics, logs, alerts, SLO

### Metrics / Dashboards

- [x] ✅ Prometheus (`kube-prometheus-stack`) installed via Argo CD — 01.01.2026
  - Helm Application in Argo CD: Synced / Healthy ✅
  - 8 pods Running (including prometheus-0, alertmanager-0)
  - PVC Longhorn: Prometheus 10Gi, Grafana 5Gi, Alertmanager 2Gi — all Bound ✅
  - Worker disks expanded: 20→35 GB (actual free: 22G + 24G)
- [x] ✅ Grafana accessible via Ingress + TLS — 01.01.2026
  - `https://grafana.lab.local` → HTTP 302 (login) ✅
  - Login: local admin account
  - Certificate Ready (lab-ca-issuer), ADDRESS `10.44.81.200`
- [x] ✅ Dashboards: cluster / node / pods — Node Exporter Lab, K8s Cluster Lab, Loki Logs Lab — GitOps ConfigMaps, Argo CD `grafana-dashboards` Synced/Healthy — 01.01.2026
- [x] ✅ Alertmanager: Telegram notifications configured — 01.01.2026
  - [x] ✅ 6 alert rules: HighCPU, HighMemory, DiskAlmostFull, PodCrashLooping, PodNotReady, DeploymentReplicasMismatch
  - [x] ✅ Delivery channel: Telegram (bot + chat ID via K8s Secret)

### Logs

- [x] ✅ Loki 6.29.0 singleBinary, PVC 10Gi longhorn-single, namespace loki — 01.01.2026
- [x] ✅ Promtail 6.16.6 DaemonSet, 3/3 Running (all nodes incl. master), all namespaces → Loki — 01.01.2026
- [x] ✅ Loki datasource added to Grafana — 01.01.2026
- [ ] Log search in Grafana Explore — verify LogQL queries

### SLO Logic

- [x] ✅ Service defined: WordPress
- [x] ✅ SLI: uptime / latency / error rate — NGINX Ingress metrics, ServiceMonitor, recording rules (6)
- [x] ✅ SLO: 99.5% availability, P95 latency < 500ms — burn-rate alerts (4), error_rate=0%, latency_ok=100% — 01.01.2026
