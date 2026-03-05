# 🚀 DevOps Lab — Reference Guide & Lessons Learned

> Operational reference document capturing lessons learned, key commands,
> architecture decisions, and configuration patterns from building a full
> homelab DevOps platform from bare metal to production-grade GitOps.

---

## 📋 Contents

- [🚨 Lessons Learned (31 entries)](#-lessons-learned)
- [🗺️ Technology Map](#️-technology-map)
- [🖥️ Infrastructure Quick Reference](#️-infrastructure-quick-reference)
- [☸️ Key Kubectl Commands](#️-key-kubectl-commands)
- [🔄 GitOps Conventions](#-gitops-conventions)
- [🔒 Secrets Management](#-secrets-management)
- [📦 Storage Reference](#-storage-reference)
- [🌐 Ingress Conventions](#-ingress-conventions)
- [📊 Observability Stack](#-observability-stack)

---

## 🚨 Lessons Learned

> Real-world problems encountered while building this platform.
> Each entry = a specific issue hit in practice, with root cause and fix.

### Summary Table

| # | Topic | Problem | Fix |
|---|-------|---------|-----|
| 1 | Velero + MinIO | `InvalidChecksum` / `SignatureDoesNotMatch` | `checksumAlgorithm: ""` in BSL config |
| 2 | Longhorn CSI snapshots | `type: snap` deleted with volume — not DR-safe | Always use `type: bak` for DR |
| 3 | Longhorn BackupTarget | UI config not persisted after restart | Use `BackupTarget` CRD, not UI |
| 4 | external-snapshotter | `VolumeSnapshotClass` not found | Apply CRDs before controller, correct order matters |
| 5 | Ingress-NGINX snippets | `configuration-snippet` silently ignored | Use standard annotations instead of snippets |
| 6 | containerd cgroup | Nodes `NotReady`, kubelet crash-loops | Set `SystemdCgroup = true` on all nodes |
| 7 | Longhorn prerequisites | PVC stuck in `ContainerCreating` | `open-iscsi` + `iscsi_tcp` module on every node |
| 8 | Longhorn disk pressure | PVC fails with `insufficient storage` | `storageOverProvisioningPercentage: 200` |
| 9 | Argo CD App-of-Apps | Manually applied `Application` unmanaged by Argo | Add `app-*.yaml` to `cluster/apps/` — never `kubectl apply` direct |
| 10 | MetalLB + BGP | Speaker pods pending | Use L2 mode for homelabs |
| 11 | cert-manager CA | TLS cert not trusted in browser | Import root CA into system/browser trust store |
| 12 | Sealed Secrets rotation | Old sealed secrets undecryptable after key rotation | Back up the sealing key periodically |
| 13 | Argo CD values drift | Helm values ignored after in-cluster edits | Never edit Helm releases directly; all values via `valuesObject:` in Application |
| 14 | RWO PVC + Rolling Update | `Multi-Attach` error during deploy | Use `maxSurge: 0` or `Recreate` strategy for RWO volumes |
| 15 | N8N + SQLite | Two pods competing for DB file | Set `strategy: Recreate` for single-writer apps |
| 16 | Strapi v5 | NPM registry breaking changes broke install | Locked to Strapi v4; v5 migration deferred |
| 17 | WordPress bitnami images | `bitnami/wordpress` removed from DockerHub | Switch to `bitnamilegacy` repository (official Bitnami legacy) |
| 18 | WordPress BSI/Photon images | Incompatible with non-FIPS Ubuntu kernel | Use `debian-12` tag from `bitnamilegacy` |
| 19 | Helm StatefulSet immutability | `mariadb` StatefulSet upgrade fails | Ignore auto-added fields via `ignoreDifferences:` in Application |
| 20 | Promtail CRI parsing | Logs not appearing in Loki | Set `pipeline_stages: [{cri: {}}]` for k8s pod logs |
| 21 | Loki storage schema | Queries return empty after schema migration | Set correct `store: tsdb`, `object_store: filesystem` for Loki 3.x |
| 22 | Grafana datasource provisioning | Dashboards show "datasource not found" | Use `uid: loki` in provisioning to match dashboard JSON references |
| 23 | kube-prometheus-stack upgrades | CRD update fails due to size limits | Apply CRDs with `kubectl replace --force-conflicts` before Helm upgrade |
| 24 | VolumeSnapshot CSI | Snapshot creation hangs indefinitely | Ensure `VolumeSnapshotClass` has `deletionPolicy: Retain` for backups |
| 25 | Velero `snapshotsEnabled` | CRD validation error on install | Set `snapshotsEnabled: false` when no CSI snapshot provider |
| 26 | Longhorn replica anti-affinity | Both replicas on same node | Set `numberOfReplicas: 2` with zone labels on nodes |
| 27 | Node zone labels | Pods not spreading across zones | Apply `topology.kubernetes.io/zone` label on nodes manually |
| 28 | ARC self-hosted runners | Workflow triggers not firing | Ensure `ACTIONS_RUNNER_CONTROLLER_MANAGER_LEADER_ELECTION_ID` is set |
| 29 | Registry insecure HTTP | Image pull fails with TLS errors | Configure containerd mirror for `10.44.81.110:30500` on all nodes |
| 30 | nerdctl + k8s.io namespace | Images not visible to containerd | Always build with `--namespace k8s.io` |
| 31 | Argo CD self-heal loop | Application constantly resyncing | Check for runtime-injected fields not in Git; use `ignoreDifferences:` |

---

### Selected Details

#### 1. Velero + MinIO — `checksumAlgorithm` is mandatory

`velero-plugin-for-aws` v1.13.0+ (uses aws-sdk-go-v2) adds `x-amz-checksum-*`
headers that MinIO does not understand, causing `InvalidChecksum` errors.

```yaml
# In Velero Application valuesObject
configuration:
  backupStorageLocation:
    - config:
        checksumAlgorithm: ""   # ← REQUIRED for MinIO
```

#### 2. Longhorn CSI — `type: snap` vs `type: bak`

| Parameter | `type: snap` | `type: bak` |
|-----------|-------------|-------------|
| Data location | Inside Longhorn volume (in cluster) | External BackupTarget (MinIO/S3) |
| Survives namespace deletion? | ❌ NO — deleted with volume | ✅ YES |
| DR-safe? | ❌ NO | ✅ YES |
| Requires BackupTarget? | No | **Yes** |

**Always use `type: bak`** for any backup intended for disaster recovery.

```yaml
# cluster/storage/longhorn-volumesnapshotclass.yaml
parameters:
  type: bak   # ← DR-safe: data goes to MinIO via BackupTarget
```

#### 9. Argo CD App-of-Apps — the golden rule

**Never** `kubectl apply` individual Application manifests directly.
Always add `app-<name>.yaml` to `cluster/apps/` and `git push`.

```
cluster/argocd/app-of-apps.yaml      ← watches cluster/apps/
cluster/apps/app-<name>.yaml         ← one per service
apps/<name>/                         ← actual manifests
```

Direct `kubectl apply` of an Application bypasses the App-of-Apps and creates
an unmanaged resource that Argo CD will not prune or heal automatically.

#### 14. RWO PVC + Rolling Update

ReadWriteOnce PVCs can only be mounted by one node at a time. A standard
`RollingUpdate` with `maxSurge: 1` creates a new pod before terminating the old
one — both try to mount the same PVC → `Multi-Attach error`.

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0        # terminate old pod first
    maxUnavailable: 1  # brief ~10-30s gap during deploy
```

For zero-downtime: use RWX storage or `strategy: Recreate`.

---

## 🗺️ Technology Map

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| Hypervisor | Proxmox VE | 8.x | 2 hosts, bare metal |
| IaC | Terraform | 1.9.x | `proxmox-telmate` provider |
| Configuration | Ansible | 2.16.x | kubeadm cluster bootstrap |
| Container Runtime | containerd | 1.7.x | `SystemdCgroup = true` required |
| Kubernetes | K8s via kubeadm | v1.31 | 3 nodes (1 master + 2 workers) |
| GitOps | Argo CD | 2.14.x | App-of-Apps pattern, 17 apps |
| Ingress | ingress-nginx | 4.12.x | MetalLB L2, IP `10.44.81.200` |
| TLS | cert-manager | 1.17.x | Internal CA `lab-ca-issuer` |
| Storage | Longhorn | 1.7.x | `longhorn` (2 replicas), `longhorn-single` (1) |
| Secrets | Sealed Secrets | v0.27.x | `kubeseal` CLI |
| Metrics | kube-prometheus-stack | 69.x | Prometheus + Grafana |
| Logs | Loki + Promtail | 3.x / 6.x | `singleBinary` mode |
| Backup | Velero + MinIO | 1.17.x | FSB via kopia, S3-compatible |
| Registry | Distribution (CNCF) | 3.x | NodePort 30500, HTTP |
| CI/CD | GitHub Actions + ARC | - | Self-hosted runners in K8s |
| Dashboards | Grafana | 11.x | 3 custom dashboards via ConfigMap sidecar |

---

## 🖥️ Infrastructure Quick Reference

| Role | Hostname | IP | vCPU | RAM | PVE Host |
|------|----------|----|------|-----|----------|
| Control Plane | k8s-master-01 | 10.44.81.110 | 4 | 8GB | pve01 (zone-a) |
| Worker | k8s-worker-01 | 10.44.81.111 | 4 | 8GB | pve01 (zone-a) |
| Worker | k8s-worker-02 | 10.44.81.112 | 4 | 8GB | pve02 (zone-b) |

- **Network:** `10.44.81.0/24`
- **MetalLB pool:** `10.44.81.200–250`
- **Ingress IP:** `10.44.81.200`
- **In-cluster registry:** `10.44.81.110:30500` (HTTP, insecure)
- **DNS:** `*.lab.local` → `10.44.81.200` (local hosts/DNS)

---

## ☸️ Key Kubectl Commands

```bash
# Set kubeconfig (Windows PowerShell)
$env:KUBECONFIG = 'H:\DEVOPS-LAB\kubeconfig-lab.yaml'

# Check all Argo CD applications
kubectl get application -n argocd

# Force Argo CD refresh
kubectl annotate application <name> -n argocd argocd.argoproj.io/refresh=normal

# Check Velero backup status
kubectl get backup.velero.io -n velero
kubectl get backupstoragelocation -n velero

# Trigger Velero backup manually
kubectl create backup <name> --include-namespaces=<ns> -n velero

# Check Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check Longhorn BackupTarget
kubectl get backuptargets.longhorn.io -n longhorn-system

# Rollout restart
kubectl rollout restart deployment/<name> -n <ns>

# SSH to master (build node)
ssh -i H:\DEVOPS-LAB\ssh\devops-lab ubuntu@10.44.81.110

# Build and push image (on master, no Docker)
sudo nerdctl --namespace k8s.io build -t 10.44.81.110:30500/<name>:latest .
sudo nerdctl --namespace k8s.io push --insecure-registry 10.44.81.110:30500/<name>:latest
```

---

## 🔄 GitOps Conventions

**The only workflow:**
1. Edit manifest files locally
2. `git push` to main branch
3. Argo CD syncs automatically (polls every 3 minutes or via webhook)

**Adding a new application:**
```
1. Create apps/<name>/  with Deployment, Service, Ingress, PVC manifests
2. Create cluster/apps/app-<name>.yaml  (Application CRD)
3. git push
4. Argo CD App-of-Apps detects new app-<name>.yaml and deploys it
```

**Helm apps** (monitoring, velero, minio) embed `valuesObject:` directly inside
`cluster/apps/app-<name>.yaml` — no separate values files.

---

## 🔒 Secrets Management

All secrets use **Sealed Secrets** (controller in `kube-system`).

```bash
# Seal a secret
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --dry-run=client -o yaml \
  | kubeseal \
    --controller-name=sealed-secrets-controller \
    --controller-namespace=kube-system \
  | kubectl apply -f -
```

- SealedSecret manifests are safe to commit to Git
- Stored in `cluster/secrets/` or alongside app manifests
- **Never commit plain `Secret` objects**

---

## 📦 Storage Reference

| StorageClass | Replicas | Use case |
|---|---|---|
| `longhorn` | 2 (cross-node) | Stateful HA apps (WordPress, Prometheus, Grafana, Loki) |
| `longhorn-single` | 1 | MinIO (manages own redundancy), performance-sensitive |

**VolumeSnapshot for DR:**
```yaml
# Always use type: bak — not type: snap
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: longhorn-snapshot-class
driver: driver.longhorn.io
deletionPolicy: Retain
parameters:
  type: bak   # ← DR-safe, goes to BackupTarget (MinIO)
```

**Longhorn BackupTarget (CRD, not UI):**
```yaml
apiVersion: longhorn.io/v1beta2
kind: BackupTarget
metadata:
  name: default
  namespace: longhorn-system
spec:
  backupTargetURL: "s3://longhorn-backup@us-east-1/"
  credentialSecret: "longhorn-backup-secret"
  pollInterval: "5m0s"
```

---

## 🌐 Ingress Conventions

All Ingress resources follow this pattern:

```yaml
annotations:
  cert-manager.io/cluster-issuer: lab-ca-issuer   # always this issuer
  # WebSocket apps (e.g., Uptime Kuma):
  nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
  nginx.ingress.kubernetes.io/upgrade: websocket
ingressClassName: nginx
```

- TLS: all services exposed via HTTPS with internal CA
- Domain pattern: `<service>.lab.local`
- **Do not** use `configuration-snippet` annotation (blocked by default in ingress-nginx for security)

---

## 📊 Observability Stack

| Component | Endpoint | Notes |
|-----------|----------|-------|
| Grafana | https://grafana.lab.local | Dashboards: K8s cluster, Node Exporter, Loki logs |
| Prometheus | https://prometheus.lab.local | Scrapes kube-state-metrics, node-exporter, nginx |
| Alertmanager | https://alertmanager.lab.local | Sends alerts to Telegram via N8N webhook |
| Loki | Internal service | `singleBinary` mode, Longhorn PVC for storage |
| Promtail | DaemonSet | Reads `/var/log/pods` from all nodes via CRI pipeline |

**SLO monitoring for WordPress:**
- Availability SLO: 99.5% (30-day window)
- Latency SLO: 95% requests < 500ms
- Multi-window burn-rate alerts (1h+5m critical, 6h+30m warning)
- Recording rules: `job:wordpress_request_*:ratio_rate{5m,30m,1h,6h}`

**Grafana dashboards** are provisioned via ConfigMap sidecar:
```yaml
# ConfigMap label required for auto-discovery
labels:
  grafana_dashboard: "1"
```

---

## 📝 Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| GitOps engine | Argo CD App-of-Apps | Single root app manages all child apps; easy to add/remove services |
| Secret management | Sealed Secrets | Git-native; no external vault dependency for a homelab |
| Storage | Longhorn | Native K8s CSI, web UI, backup to MinIO, zone-aware replication |
| Image builds | nerdctl + buildkitd | No Docker daemon required; works with containerd directly |
| Ingress | ingress-nginx + MetalLB L2 | Simple L2 announcement; no BGP needed for a /24 home network |
| TLS | cert-manager + internal CA | All HTTPS internally; import root CA once into trust stores |
| Backup | Velero + MinIO (FSB) | S3-compatible object storage on-prem; file-system backup via kopia |
| Monitoring | kube-prometheus-stack | Community-standard Helm chart; includes Prometheus, Grafana, Alertmanager |

---

*Last updated: 2026 | See [wiki/](../wiki/) for detailed per-service documentation.*