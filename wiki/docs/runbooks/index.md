# 📖 Runbooks — Quick Reference

Cheat sheets and quick commands for daily work with the lab.

## ⚡ Session Startup Checklist

```powershell
# 1. Set KUBECONFIG
$env:KUBECONFIG = "H:\DEVOPS-LAB\kubeconfig-lab.yaml"

# 2. Check cluster
kubectl get nodes -o wide
kubectl get pods -A | Where-Object { $_ -notmatch "Running|Completed" }

# 3. Check Argo CD
kubectl get applications -n argocd
```

---

## 🔑 SSH Access

```powershell
$KEY = "H:\DEVOPS-LAB\ssh\devops-lab"

# Master
ssh -i $KEY ubuntu@10.44.81.110

# Worker-01
ssh -i $KEY ubuntu@10.44.81.111

# Worker-02
ssh -i $KEY ubuntu@10.44.81.112

# Proxmox (key-based SSH)
ssh root@10.44.81.101
```

!!! note "Credentials"
    All node credentials are documented in SECURITY.md (not committed to this repo).
    SSH access to nodes uses key-based authentication only.

---

## ☸️ kubectl — Common Commands

```bash
# Pods with wide output (node, IP)
kubectl get pods -n <ns> -o wide

# Logs with follow
kubectl logs -n <ns> <pod> -f --tail=100

# Exec into container
kubectl exec -it -n <ns> <pod> -- /bin/sh
kubectl exec -it -n <ns> <pod> -c <container> -- /bin/bash

# Describe (events, conditions)
kubectl describe pod -n <ns> <pod>
kubectl describe node <node-name>

# Restart deployment
kubectl rollout restart deployment/<name> -n <ns>
kubectl rollout status deployment/<name> -n <ns>

# Scale down/up
kubectl scale deployment <name> -n <ns> --replicas=0
kubectl scale deployment <name> -n <ns> --replicas=1

# Port-forward
kubectl port-forward -n <ns> svc/<svc> 8080:80

# Copy file from pod
kubectl cp -n <ns> <pod>:/path/to/file ./local-file

# Apply manifest
kubectl apply -f manifest.yaml
kubectl delete -f manifest.yaml

# Patch (force Argo CD sync)
kubectl patch application <app> -n argocd \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}' --type=merge
```

---

## ⛵ Helm — Common Commands

```bash
# List releases
helm list -A

# Release status
helm status <release> -n <namespace>

# Upgrade with values
helm upgrade <release> <chart> -n <namespace> -f values.yaml

# Rollback
helm rollback <release> <revision> -n <namespace>

# History
helm history <release> -n <namespace>

# Uninstall
helm uninstall <release> -n <namespace>
```

---

## 🐳 nerdctl — Image Builds (on master)

!!! info "containerd versions"
    Master uses containerd **2.2.1** (new v3 config format).
    Registry configured via `/etc/containerd/certs.d/10.44.81.110:30500/hosts.toml`.
    Workers use containerd **1.7.28** (old config.toml with mirrors).

```bash
# SSH to master
ssh -i H:\DEVOPS-LAB\ssh\devops-lab ubuntu@10.44.81.110

# Build
sudo nerdctl --namespace k8s.io build -t 10.44.81.110:30500/<image>:latest .

# Push
sudo nerdctl --namespace k8s.io push --insecure-registry 10.44.81.110:30500/<image>:latest

# List images
sudo nerdctl --namespace k8s.io images

# Registry catalog
curl http://10.44.81.110:30500/v2/_catalog
```

---

## 💾 Velero

```bash
# List backups
velero backup get
velero backup create manual-backup --wait

# Restore
velero restore create --from-backup <backup-name> --wait

# Schedules
velero schedule get
```

---

## 📌 URLs & Ports

### Web Interfaces (HTTPS via Ingress 10.44.81.200)

| Service | URL | Namespace |
|---------|-----|-----------|
| 📖 Wiki | [https://wiki.lab.local](https://wiki.lab.local) | `wiki` |
| 🚀 Argo CD | [https://argocd.lab.local](https://argocd.lab.local) | `argocd` |
| 📊 Grafana | [https://grafana.lab.local](https://grafana.lab.local) | `monitoring` |
| ⚠️ Uptime Kuma | [https://kuma.lab.local](https://kuma.lab.local) | `uptime-kuma` |
| 📁 MinIO Console | [https://minio.lab.local](https://minio.lab.local) | `minio` |
| 🗄️ Longhorn UI | [https://longhorn.lab.local](https://longhorn.lab.local) | `longhorn-system` |
| 📝 WordPress | [https://wordpress.lab.local](https://wordpress.lab.local) | `wordpress` |
| ⚡ Strapi | [https://strapi.lab.local](https://strapi.lab.local) | `strapi` |
| 🤖 N8N | [https://n8n.lab.local](https://n8n.lab.local) | `n8n` |
| 🧪 Test App | [https://app.lab.local](https://app.lab.local) | `default` |

### Direct Ports

| Port | Service | Protocol |
|------|---------|----------|
| 22 | SSH (all nodes) | TCP |
| 80/443 | Ingress (MetalLB 10.44.81.200) | TCP |
| 6443 | K8s API Server | TCP |
| 8006 | Proxmox Web UI | HTTPS |
| 30500 | In-cluster Registry (NodePort) | HTTP |

---

## 🆘 Troubleshooting

```bash
# Pod not starting
kubectl describe pod -n <ns> <pod>
kubectl get events -n <ns> --sort-by='.lastTimestamp'

# Image pull failure
kubectl describe pod -n <ns> <pod> | grep -A5 "Events"
# Check registry: curl http://10.44.81.110:30500/v2/_catalog

# PVC stuck in Pending
kubectl describe pvc -n <ns> <pvc-name>
kubectl get storageclass

# Certificate not issuing
kubectl describe certificate -n <ns> <cert>
kubectl describe certificaterequest -n <ns>
kubectl logs -n cert-manager deployment/cert-manager --tail=50

# Ingress not working
kubectl get ingress -A
kubectl describe ingress -n <ns> <ingress>
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50

# containerd issues
sudo systemctl status containerd
sudo journalctl -u containerd -n 50
```
