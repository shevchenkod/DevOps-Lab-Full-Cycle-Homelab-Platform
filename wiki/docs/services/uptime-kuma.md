# 🟢 Uptime Kuma — Availability Monitoring

> Uptime Kuma is a self-hosted alternative to Pingdom/UptimeRobot.
> Monitors HTTP/HTTPS, TCP, DNS, Ping endpoints and sends alerts to Telegram.

## Lab Configuration

| Parameter | Value |
|-----------|-------|
| Namespace | `uptime-kuma` |
| UI | [https://kuma.lab.local](https://kuma.lab.local) |
| Login | *(created on first login)* |
| Image | `louislam/uptime-kuma:2.1.3` |
| PVC | `uptime-kuma-data` — 1Gi (`longhorn`, 2 replicas) |
| Argo CD | `cluster/argocd/app-uptime-kuma.yaml` |
| Ingress | `10.44.81.200` → `kuma.lab.local` |
| TLS | cert-manager `lab-ca-issuer` → secret `uptime-kuma-tls` |
| Status | ✅ `1/1 Running` |

## Monitors (lab configuration)

| Service | URL / Host | Type | Interval |
|---------|-----------|------|---------|
| Argo CD | `https://argocd.lab.local` | HTTPS | 60s |
| Grafana | `https://grafana.lab.local` | HTTPS | 60s |
| WordPress | `https://wordpress.lab.local` | HTTPS | 60s |
| Strapi | `https://strapi.lab.local` | HTTPS | 60s |
| MinIO | `https://minio.lab.local` | HTTPS | 60s |
| Wiki | `https://wiki.lab.local` | HTTPS | 60s |
| N8N | `https://n8n.lab.local` | HTTPS | 60s |
| Kubernetes API | `10.44.81.110:6443` | TCP Port | 60s |
| Proxmox PVE-01 | `10.44.81.21:8006` | HTTPS | 120s |
| Proxmox PVE-02 | `10.44.81.22:8006` | HTTPS | 120s |

## WebSocket — Important for Ingress

Uptime Kuma uses WebSocket for real-time updates. Ingress requires:

```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
  nginx.ingress.kubernetes.io/upgrade: websocket
  nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

!!! warning "configuration-snippet is not allowed"
    Annotation `nginx.ingress.kubernetes.io/configuration-snippet` is **forbidden**
    by the default nginx ingress controller policy. Do not use it.

## Quick Commands

```powershell
# Status
kubectl get pods -n uptime-kuma
kubectl get pvc -n uptime-kuma
kubectl get ingress -n uptime-kuma

# Logs
kubectl logs -n uptime-kuma deployment/uptime-kuma --tail=50

# Restart
kubectl rollout restart deployment/uptime-kuma -n uptime-kuma
```

## Notes

- First launch: UI prompts to create an admin account (choose name/password)
- Data is stored in SQLite at `/app/data/kuma.db` on the PVC
- Status page: `https://kuma.lab.local/status` (public, no login required)
