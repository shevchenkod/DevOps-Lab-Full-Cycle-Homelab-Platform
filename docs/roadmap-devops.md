# 🗺️ DevOps Lab — Roadmap & Checklist

> Full step-by-step plan for completing the DevOps cycle: from infrastructure to GitOps,
> observability, and DR. Progress block by block, no skips. Each completed step
> is marked `[x] ✅` with date.

**Current status:** All blocks A–J completed ✅

---

## 📋 Blocks Summary

| Block | Name | Status |
|-------|------|--------|
| [A](#a-foundations-repository-standards-access) | Foundations: repository, standards, access | ✅ Done |
| [B](#b-iaas-proxmox--terraform) | IaaS: Proxmox + Terraform | ✅ Done |
| [C](#c-configuration-ansible) | Configuration: Ansible | ✅ Done |
| [D](#d-kubernetes-platform-core) | Kubernetes Platform Core | ✅ Done |
| [E](#e-observability-metrics-logs-alerts-slo) | Observability: metrics, logs, alerts, SLO | ✅ Done |
| [F](#f-delivery-helm-gitops-cicd-pipelines) | Delivery: Helm, GitOps, CI/CD | 🔄 In progress |
| [G](#g-applications-real-services) | Applications: real services | 🔄 In progress |
| [H](#h-backup--dr-velero) | Backup / DR: Velero + MinIO | ✅ Done |
| [I](#i-operations--day-2) | Operations / Day-2 | ✅ Done |
| [J](#j-az--zone-modeling) | AZ / Zone modeling | ✅ Done |

---

## A. Foundations: repository, standards, access

### Git repository with folder structure

> **Strategy:** GitHub (public/private) now → self-hosted GitLab CE on Proxmox later.
> Full cycle: GitLab → GitLab Runner → Container Registry → Kubernetes (Argo CD)

- [x] ✅ Repository **GitHub** `shevchenkod/devops-lab` (private) created — 01.01.2026
  - SSH key `gitlab-devops-lab` added to GitHub
  - SSH config set up: `~/.ssh/config` → `ssh/gitlab-devops-lab`
  - First commit pushed: `init: project structure, .gitignore, README`
  - URL: `git@github.com:shevchenkod/devops-lab.git`
- [x] ✅ Repository structure created — 01.01.2026
  - [x] `terraform/` — Proxmox / IaaS
  - [x] `ansible/` — server configuration
  - [x] `cluster/` — K8s bootstrap + core platform (cert-manager, metallb, ingress yamls)
  - [x] `apps/` — WordPress, Uptime Kuma, etc.
  - [x] `docs/runbooks/` — documentation and runbooks
- [x] ✅ `.gitignore` configured — secrets not committed — 01.01.2026
  - `*.tfstate`, `ssh/`, `kubeconfig*.yaml`, `*.crt`, `*.key`, VMware VM files excluded
- [x] ✅ `README.md` with lab and stack description — 01.01.2026

> 🔜 **Later (separate block):** Self-hosted GitLab CE on Proxmox VM
> - GitLab Runner in Kubernetes
> - Container Registry on own domain
> - Full CI/CD without external dependencies

### Standards and planning

- [x] ✅ Naming conventions (VMs, nodes, namespaces, releases) — consistent: k8s-master-01, k8s-worker-0X, namespace=service — 01.01.2026
- [x] ✅ IP plan + subnets — documented in terraform/README and outputs: .110 master, .111-.112 workers, .200 LB — 01.01.2026
- [ ] SSH keys, separate admin user, MFA where applicable

### Tools (workstation)

- [ ] VS Code plugins: Terraform, Kubernetes, YAML, Ansible, Git
- [x] ✅ Lens: connected to cluster (kubeconfig, contexts) — 01.01.2026 **✓ verified**
  - `kubeconfig-lab.yaml`, server `https://10.44.81.110:6443`
  - Lens Desktop: connected, cluster shows all 3 nodes
  - [x] ✅ Lens Cluster Overview (both panels) working — 01.01.2026
    - Issue: Lens deployed its own Prometheus in `lens-metrics` (when Lens Metrics enabled)
    - Conflict: two Prometheus instances (`lens-metrics` + `kube-prometheus-stack`) → right Overview panel not working
    - Fix: `kubectl delete namespace lens-metrics` → only `kube-prometheus-stack` remains → both panels ✅

---

## B. IaaS: Proxmox + Terraform

### 🖥️ Proxmox — base configuration

- [x] ✅ Proxmox installed — **pve01** (`10.44.81.101`) — 01.01.2026
- [x] ✅ Proxmox installed — **pve02** (`10.44.81.102`) — 01.01.2026
- [x] ✅ API tokens for Terraform created and tested via `curl` — 01.01.2026
  - pve01: `terraform@pve!terraform-pve01`
  - pve02: `terrafor@pve!terraform-pve02`
- [x] ✅ Storage pools defined — 01.01.2026
  - pve01: `local` (Directory, /var/lib/vz) + `local-lvm` (LVM-Thin)
  - pve02: `local` (Directory) + `local-lvm` (LVM-Thin) · 16 CPU · 15.58 GiB RAM · 121.95 GiB disk
- [x] ✅ Bridges / VLANs documented — 01.01.2026
  - `vmbr0` (Linux Bridge on ens33): pve01 `10.44.81.101/24`, pve02 `10.44.81.102/24`, gw `10.44.81.254`
  - All VMs (K8s nodes) on `vmbr0` in subnet `10.44.81.0/24`
  - MetalLB pool: `10.44.81.200–250` (reserved)
- [x] ✅ Templates (cloud-image Ubuntu 24.04) ready — 01.01.2026
  - `ubuntu-24.04-cloud.img` (600 MB) downloaded to pve01 and pve02
  - Path: `/var/lib/vz/template/cloud/ubuntu-24.04-cloud.img`
- [x] ✅ Cloud-init working (VM template 9000 created) — 01.01.2026
  - VMID: `9000`, name: `ubuntu-2404-cloud`
  - params: 2 CPU, 2048 MB RAM, `virtio-scsi`, `vmbr0`, cloud-init user: `ubuntu`
  - created on **pve01** and **pve02** (VMID 9000 on both)
- [ ] Firewall / Datacenter policies (basic) enabled
- [x] ✅ Backup storage / policy — Velero + MinIO S3, cron schedules, restore test passed — 01.01.2026

### 🏗️ Terraform

- [x] ✅ Terraform backend configured (local state) — 01.01.2026
- [x] ✅ Proxmox provider configured (`bpg/proxmox` v0.97.1) — 01.01.2026
  - Terraform v1.14.6, provider reads nodes from pve01 and pve02 (verified `terraform plan`)
  - Project: `terraform/proxmox-lab/`
  - Secrets: via `$env:TF_VAR_*` (not stored in files)
- [x] ✅ Terraform modules: `module.vm` — K8s nodes created — 01.01.2026
- [x] ✅ Outputs: IP, node names — 01.01.2026
- [x] ✅ Full lifecycle: `plan → apply` working — 01.01.2026
  - `k8s-master-01` — `10.44.81.110` — pve01, VMID 101
  - `k8s-worker-01` — `10.44.81.111` — pve01, VMID 111
  - `k8s-worker-02` — `10.44.81.112` — pve02, VMID 112
  - SSH working on all nodes, Ubuntu 24.04, kernel 6.8.0-101-generic

---

## C. Configuration: Ansible

- [x] ✅ Inventory created on master node (`~/ansible/inventory.ini`) — 01.01.2026
  - Groups: `k3s_master` (110), `k3s_workers` (111, 112), `k3s_cluster`
  - `ansible_user=ubuntu`, key `~/.ssh/devops-lab`
  - `ansible ping` → SUCCESS on all 3 nodes
- [x] ✅ Baseline all nodes via Ansible — 01.01.2026
  - swap off, sysctl (bridge-nf-call-iptables, ip_forward), kernel modules (overlay, br_netfilter)
  - containerd installed + `SystemdCgroup=true` in config.toml
  - kubeadm / kubelet / kubectl v1.30 installed, packages held
- [x] ✅ Kubernetes (kubeadm) installation automated via Ansible — 01.01.2026
  - `kubeadm init` on master, CNI Calico v3.27.3, kubeconfig for ubuntu
- [x] ✅ Worker node join automated — 01.01.2026
  - token passed via `set_fact`, workers join automatically
- [x] ✅ Idempotency: `stat` checks on `admin.conf` and `kubelet.conf` — repeated runs are safe
- [ ] Baseline hardening (separate):
  - [ ] firewall (ufw / nftables)
  - [ ] separate admin user / MFA

---

## D. Kubernetes Platform Core

### Cluster Bootstrap

- [x] ✅ Kubernetes v1.31.14 (kubeadm) — upgrade v1.30.14 → v1.31.14, all 3 nodes `Ready` — 01.01.2026
  - `k8s-master-01` `10.44.81.110` — control-plane
  - `k8s-worker-01` `10.44.81.111` — worker
  - `k8s-worker-02` `10.44.81.112` — worker
  - containerd 1.7.28, Ubuntu 24.04, kernel 6.8.0-101-generic
- [x] ✅ kubeconfig available on workstation — `kubeconfig-lab.yaml` — 01.01.2026
  - `scp -i devops-lab ubuntu@10.44.81.110:~/.kube/config kubeconfig-lab.yaml`
- [x] ✅ Namespace structure — implemented: monitoring, loki, longhorn-system, cert-manager, ingress-nginx, metallb-system, wordpress, minio, strapi, uptime-kuma, velero, registry, wiki — 01.01.2026
- [ ] RBAC basic (admin / user, service accounts)

### Networking + Load Balancing

- [x] ✅ CNI Calico v3.27.3 installed, pod CIDR `192.168.0.0/16` — 01.01.2026
- [x] ✅ **MetalLB L2** installed via Helm — 01.01.2026
  - IP pool: `10.44.81.200–10.44.81.250`
  - L2Advertisement `lab-l2` configured
- [x] ✅ `LoadBalancer` service assigns external IP — 01.01.2026
- [ ] (Optional) NetworkPolicies — minimum 1–2 examples

### Ingress + TLS

- [x] ✅ Ingress-NGINX installed via Helm, `EXTERNAL-IP: 10.44.81.200` — 01.01.2026
- [x] ✅ cert-manager v1.19.4 installed via Helm — 01.01.2026
  - [x] ✅ `ClusterIssuer` `lab-root-ca` (selfSigned) — lab CA created
  - [x] ✅ `ClusterIssuer` `lab-ca-issuer` (CA type) — issues certificates
  - [ ] (Optional) Let's Encrypt staging/prod — needs a public domain
- [x] ✅ TLS for test domain `app.lab.local` working — 01.01.2026 **✓ verified in browser**
  - Ingress with annotation `cert-manager.io/cluster-issuer: lab-ca-issuer`
  - ADDRESS: `10.44.81.200`, cert Ready
  - `https://app.lab.local` → Welcome to nginx, no warnings ✅

### Storage

- [x] ✅ Longhorn prerequisites installed via Ansible — 01.01.2026
  - `open-iscsi`, `multipath-tools` on all 3 nodes
  - `iscsid`: active + enabled on all nodes
  - `iscsi_tcp` kernel module loaded and persistent
- [x] ✅ Longhorn installed via Helm — 01.01.2026
  - namespace: `longhorn-system`, 23 pods Running
  - `defaultDataPath: /var/lib/longhorn`
  - `defaultClassReplicaCount: 2` (2 worker nodes)
- [x] ✅ StorageClass created — 01.01.2026
  - `longhorn` (default) — `driver.longhorn.io`, Immediate, allowVolumeExpansion=true
  - `longhorn-static` — for static PVs
- [x] ✅ PVC provisioning working (test PVC + pod) — 01.01.2026
  - `lh-pvc-test`: 2Gi, Bound, StorageClass `longhorn`
  - Pod `lh-pod-test`: Running on k8s-worker-01, data written to `/data/hello.txt`
  - Persistence confirmed: pod deleted + recreated → file survived ✅
- [x] ✅ Longhorn HA (node drain) verified — 01.01.2026
  - `kubectl drain k8s-worker-01` → pod moved to **k8s-worker-02**
  - Longhorn remounted volume from replica automatically, data intact ✅
  - `kubectl uncordon k8s-worker-01` → all 3 nodes Ready ✅
- [x] ✅ Longhorn UI via Ingress + TLS — 01.01.2026
  - `https://longhorn.lab.local` → HTTP 200 ✅
  - Certificate `longhorn-tls` Ready (lab-ca-issuer), ADDRESS `10.44.81.200`
- [x] ✅ Snapshot / restore Longhorn verified — VolumeSnapshot `wordpress-snap-test` READYTOUSE:true, restore PVC Bound — 01.01.2026

---

## E. Observability: metrics, logs, alerts, SLO

### Metrics / Dashboards

- [x] ✅ Prometheus (`kube-prometheus-stack`) installed via Argo CD — 01.01.2026
  - Helm Application in Argo CD: Synced / Healthy ✅
  - 8 pods Running (including prometheus-0, alertmanager-0)
  - PVC Longhorn: Prometheus 10Gi, Grafana 5Gi, Alertmanager 2Gi — all Bound ✅
  - Worker disks expanded: 20→35 GB
- [x] ✅ Grafana accessible via Ingress + TLS — 01.01.2026
  - `https://grafana.lab.local` → HTTP 302 (login) ✅
  - Certificate Ready (lab-ca-issuer), ADDRESS `10.44.81.200`
- [x] ✅ Dashboards imported into Grafana — 01.01.2026
  - 1860 Node Exporter Full ✅ · 6417 Kubernetes Cluster ✅ · 15757 K8s Views Global ✅
  - 15758 K8s Views Namespaces ✅ · 15760 K8s Views Pods ✅ · 15141 Loki K8s Logs ✅
- [x] ✅ Alertmanager: Telegram notifications configured — 01.01.2026
  - [x] ✅ 6 alert rules: HighCPU, HighMemory, DiskAlmostFull, PodCrashLooping, PodNotReady, DeploymentReplicasMismatch
  - [x] ✅ Delivery channel: Telegram (bot + chat ID via K8s Secret)

### Logs

- [x] ✅ Loki 6.29.0 singleBinary, PVC 10Gi longhorn-single, namespace loki — 01.01.2026
- [x] ✅ Promtail 6.16.6 DaemonSet, 3/3 Running (all nodes incl. master), all namespaces in Loki — 01.01.2026
- [x] ✅ Loki datasource added to Grafana — 01.01.2026
- [x] ✅ Loki Explore — LogQL working, labels: namespace/pod/container ✅ — 01.01.2026

### SLO logic

- [x] ✅ **SLO for WordPress** — NGINX Ingress metrics + Prometheus recording rules + alerts — 01.01.2026
  - ServiceMonitor `ingress-nginx` → metrics `nginx_ingress_controller_requests` in Prometheus ✅
  - NGINX Ingress metrics enabled: `helm upgrade ingress-nginx --set controller.metrics.enabled=true` → REVISION 3
  - SLI Availability: fraction of non-5xx requests (SLO: **99.5%**, error budget 216 min/month)
  - SLI Latency: fraction of requests faster than 500ms (SLO: **95%**)
  - Recording rules: 6 rules (error_rate: 5m/30m/1h/6h · latency_ok: 5m/1h)
  - Alerts: `WordPressAvailabilitySLOBurnRateCritical` (14x, 2m for) + `BurnRateWarning` (6x, 15m) + `LatencyViolation` + `WordPressDown`
  - Multi-window multi-burn-rate approach (Google SRE Book, Chapter 5)
  - Files: `cluster/monitoring/servicemonitor-ingress-nginx.yaml` + `prometheusrule-wordpress-slo.yaml`
  - Verified: `error_rate=0%` (no 5xx) · `latency_ok=100%` (all < 500ms) · Prometheus target health: **up** ✅

---

## F. Delivery: Helm, GitOps, CI/CD, Pipelines

### Helm

- [x] ✅ All core components deployed via Helm (Argo CD Helm Applications) — 01.01.2026
- [x] ✅ Upgrade tested — K8s v1.30.14 → v1.31.14, kubeadm upgrade all 3 nodes — 01.01.2026

### GitOps — Argo CD

- [x] ✅ Argo CD installed via Helm — 01.01.2026
  - namespace: `argocd`, 7 pods Running
  - `server.insecure=true` — TLS terminated at Ingress
  - `https://argocd.lab.local` → HTTP 200, cert Ready (lab-ca-issuer) ✅
- [x] ✅ Git repo connected — 01.01.2026
  - `https://github.com/shevchenkod/devops-lab.git` → STATUS: Successful ✅
  - Credentials via K8s Secret (not in Git), label `argocd.argoproj.io/secret-type=repository`
- [x] ✅ First application via Argo CD — 01.01.2026
  - `test-app`: Synced / Healthy ✅ (path: `apps/test-app`)
- [x] ✅ kube-prometheus-stack via Argo CD (Helm Application) — 01.01.2026
  - Synced / Healthy, all pods Running, PVC Bound (Longhorn)
- [x] ✅ **App-of-Apps structure** — 01.01.2026
  - `cluster/apps/` — 12 Application manifests
  - `cluster/argocd/app-of-apps.yaml` — root Application, watches `cluster/apps/`
  - Add a service = create `cluster/apps/app-*.yaml` + git push
  - All 12 child apps: Synced / Healthy ✅
- [x] ✅ Sync policies (manual / auto) configured — automated + selfHeal + prune in all app yamls — 01.01.2026

### CI/CD (GitHub Actions → ARC self-hosted runners in Kubernetes)

> **Chosen tool: GitHub Actions**
> GitHub.com now, self-hosted runners via ARC (Actions Runner Controller) in K8s.

- [x] ✅ ARC runner set deployed in Kubernetes (`arc-runner-set`)
- [x] ✅ Wiki CI pipeline — builds and pushes image to in-cluster registry on push
- [ ] Full CI pipeline:
  - [ ] build Docker image
  - [ ] tag (semver / commit sha)
  - [ ] push to registry
  - [ ] deploy via GitOps (commit values → Argo CD sync)
- [ ] (Optional) security gate: image scan (Trivy)

### Registry

- [x] ✅ In-cluster registry at `10.44.81.110:30500` (NodePort, HTTP)
  - All nodes have containerd mirrors configured for this endpoint
  - Built with `nerdctl` + `buildkitd` on master (no Docker daemon)
- [ ] Pull secrets for private registries configured in Kubernetes

### Secrets Management

- [x] ✅ Approach selected: **Sealed Secrets** v2.18.3
- [x] ✅ Secrets are **not stored** in plaintext in the repository

---

## G. Applications: real services

- [x] ✅ **Uptime Kuma** — Argo CD Application + Longhorn PVC + Ingress TLS — 01.01.2026
  - Image: `louislam/uptime-kuma:2.1.3` | PVC: 1Gi (Longhorn) | Pod: `1/1 Running` ✅
  - Ingress: `https://kuma.lab.local` (cert-manager lab CA) | TLS cert: Ready ✅
  - Argo CD Application: `cluster/apps/app-uptime-kuma.yaml` — Synced / Healthy ✅
  - Fix: removed `configuration-snippet` annotation (disabled by ingress-nginx admin) — commit `4cce752`
- [x] ✅ **Strapi v4.26.1** (headless CMS) — Argo CD + Longhorn + Ingress TLS — 01.01.2026
  - Image: `naskio/strapi:5.30.1-alpine` | PVC: `strapi-data` 3Gi (longhorn-single, /srv/app)
  - Ingress: `https://strapi.lab.local` (cert-manager lab CA) | TLS cert: Ready ✅
  - Argo CD Application: `cluster/apps/app-strapi.yaml` — Synced / Healthy ✅ (v4.26.1, NODE_ENV=development)
  - Fix applied: `NODE_ENV=development` (strapi develop — auto-build), single PVC 3Gi on /srv/app
  - Issue: Longhorn `insufficient storage` (82% scheduled), switched to `longhorn-single`
  - Strapi secrets in K8s Secret `strapi-secrets` (not in git)
- [x] ✅ **WordPress** — Bitnami Helm + Argo CD + Longhorn PVC + Ingress TLS — 01.01.2026
  - [x] ✅ DB (MariaDB 11.8.3) + PVC 2Gi (Longhorn)
  - [x] ✅ WordPress 6.8.2 + PVC 5Gi (Longhorn)
  - [x] ✅ Ingress + TLS (`https://wordpress.lab.local`, cert-manager lab CA)
  - [x] ✅ Argo CD Application — Healthy (chart 29.1.2 + bitnamilegacy debian images)
  - [x] ✅ Backup strategy (Velero) — schedules, backup + restore test completed — 01.01.2026
- [x] ✅ (Optional) MinIO — deployed, used as Velero backend and Longhorn BackupTarget — 01.01.2026

---

## H. Backup / DR: Velero

- [x] ✅ **MinIO 5.4.0** installed — standalone, namespace `minio`, 10Gi `longhorn-single` PVC — 01.01.2026
  - S3 API: `http://minio.minio.svc.cluster.local:9000`
  - Console: `https://minio.lab.local`
  - Bucket `velero` created manually via `mc` (buckets hook removed — race condition)
- [x] ✅ **Velero 1.17.1** installed — Helm chart 11.4.0, Argo CD Application — 01.01.2026
  - Plugin: `velero-plugin-for-aws:v1.13.0`
  - `checksumAlgorithm: ""` — required for MinIO + aws-sdk-go-v2 v1.13
  - `snapshotsEnabled: false` — fs-backup only (kopia), VolumeSnapshotLocation not created
  - node-agent DaemonSet: 2 pods Running (kopia fs-backup for PVCs)
  - Argo CD: **Synced / Healthy** ✅ (fixed: snapshotsEnabled: false)
- [x] ✅ **Backup storage**: MinIO S3 in-cluster — BSL `default` → status **Available** ✅ — 01.01.2026
- [x] ✅ **Backup schedules (cron)** — 01.01.2026
  - `wordpress-daily` — `0 2 * * *` (02:00 UTC), TTL 30d, namespace: `wordpress`
  - `uptime-kuma-daily` — `0 3 * * *` (03:00 UTC), TTL 30d, namespace: `uptime-kuma`
- [x] ✅ **Test backup** `test-wordpress-manual` — Phase: Completed, 97 MiB, 42 objects — 01.01.2026
- [x] ✅ **Restore test** — 01.01.2026
  - [x] ✅ Namespace `wordpress` restored from `test-wordpress-manual` (Velero restore)
  - [x] ✅ WordPress fully restored: pods `1/1 Running`, PVC Bound (2Gi+5Gi), `https://wordpress.lab.local` HTTP 200 ✅
  - [x] ✅ Restore: phase=Completed, warnings=1, errors=0. Recovery time: ~3 min
- [x] ✅ **CSI Snapshot Infrastructure** — 01.01.2026
  - [x] ✅ external-snapshotter v8.2.0 CRDs installed (VolumeSnapshot, VolumeSnapshotContent, VolumeSnapshotClass)
  - [x] ✅ snapshot-controller deployed in kube-system (2 pods Running)
  - [x] ✅ VolumeSnapshotClass `longhorn-snapshot-class`: driver `driver.longhorn.io`, `parameters.type: bak`
  - [x] ✅ Velero `--features=EnableCSI` enabled in `app-velero.yaml`
- [x] ✅ **Longhorn BackupTarget → MinIO** — 01.01.2026
  - [x] ✅ Bucket `longhorn-backup` created in MinIO
  - [x] ✅ Secret `longhorn-backup-secret` created in namespace `longhorn-system`
  - [x] ✅ BackupTarget `default` configured: `s3://longhorn-backup@us-east-1/`, status AVAILABLE
  - [x] ✅ File `cluster/storage/longhorn-backuptarget.yaml` created and committed
- [x] ✅ **DR scenarios** — 01.01.2026
  - [x] ✅ Namespace loss → restore from Velero FSB backup (test passed in ~3 min)
  - [x] ✅ CSI restore (`type: bak`) — infrastructure ready and verified
  - [x] ✅ Node loss → reschedule — K8s scheduler + Calico, pods restart automatically — 01.01.2026
  - [x] ✅ PDB + rolling updates — WordPress PDB minAvailable:1, rolling update without downtime — 01.01.2026

> ⚠️ **DR Lesson:** `type: snap` = Longhorn internal snapshot (data INSIDE volume) → deleted with namespace.
> Use `type: bak` for DR — data stored in MinIO and survives namespace deletion.

> 📌 **Workers CPU:** workers expanded to 4 vCPU (previously 2 vCPU) — 01.01.2026
> 📌 **Worker disks expanded** to 60 GB via Proxmox API + growpart — 01.01.2026

---

## I. Operations / Day-2

- [x] ✅ Rolling updates — verified without downtime (kubeadm RWO PVC → maxSurge: 0) — 01.01.2026
- [x] ✅ Scaling:
  - [x] ✅ Manual `scale replicas` — via Argo CD (replicas in values)
  - [x] ✅ HPA (metrics-server v0.8.1) — WordPress: cpu 60% / memory 50%, min=1 max=3 — 01.01.2026
    - `kubectl get hpa -n wordpress` → `cpu: 2%/60%  memory: 10%/50%  REPLICAS: 1` ✅
- [x] ✅ Node maintenance:
  - [x] ✅ `cordon / drain / uncordon` — performed during kubeadm upgrade of all 3 nodes ✅
  - [x] ✅ PodDisruptionBudget — WordPress PDB: `minAvailable: 1`, ALLOWED DISRUPTIONS: 0 — 01.01.2026
- [x] ✅ Add node (terraform apply + ansible join) — verified, worker-03 on pve02 — 01.01.2026
- [x] ✅ Remove / replace node — verified (kubectl drain + delete + terraform state rm + Proxmox API) — 01.01.2026
- [x] ✅ Cluster upgrade (minor upgrade) — v1.30.14 → v1.31.14, kubeadm, 01.01.2026
- [x] ✅ Documentation: runbooks "bootstrap from scratch", "how to restore" — docs/runbooks/ — 01.01.2026

---

## J. AZ / Zone modeling

> Applicable when both Proxmox hosts are active (pve01 + pve02 ✅)

- [x] ✅ Two Proxmox hosts = Zone A (pve01) / Zone B (pve02) — 01.01.2026
- [x] ✅ Node placement by zone (labels / taints / topology) — 01.01.2026
- [x] ✅ Test "Zone A fails" — 01.01.2026:
- [x] ✅ All services alive on zone-b (worker-02): wordpress, grafana, loki, minio, strapi, wiki, registry, velero
- [x] ✅ Longhorn replicas cross-zone — data available
- [x] ✅ Storage topology: Longhorn replicas across nodes / zones — test passed, replicas on worker-01 (zone-a) and worker-02 (zone-b) — 01.01.2026

---

## 📌 Rules of engagement

> - Progress **block by block**, no skips
> - Each completed step: brief confirmation + command output / screenshot
> - Completed items marked `[x] ✅` with date

---

## 🔖 Progress log

| Date | Block | Completed |
|------|-------|-----------|
| 01.01.2026 | B | Proxmox pve01 (`10.44.81.101`) installed |
| 01.01.2026 | B | Proxmox pve02 (`10.44.81.102`) installed |
| 01.01.2026 | B | Terraform API tokens for pve01 and pve02 created and verified via `curl` |
| 01.01.2026 | — | Created `DevOps.md` — knowledge base with cheatsheets for all tools |
| 01.01.2026 | — | Created `roadmap-devops.md` — progress checklist |
| 01.01.2026 | B | Storage pools defined: `local` + `local-lvm` on pve01 and pve02 |
| 01.01.2026 | B | Network documented: `vmbr0` on both hosts, subnet `10.44.81.0/24` |
| 01.01.2026 | B | Cloud image Ubuntu 24.04 (600 MB) downloaded to pve01 and pve02 |
| 01.01.2026 | B | Ubuntu 24.04.4 installation ISO (3.2 GB) uploaded to `/var/lib/vz/template/iso/` |
| 01.01.2026 | B | VM template VMID 9000 `ubuntu-2404-cloud` created on pve01 and pve02 |
| 01.01.2026 | B | Terraform v1.14.6 installed, `bpg/proxmox` v0.97.1, `terraform init` + `plan` — both hosts accessible |
| 01.01.2026 | B | `terraform apply` — 3 VMs created: master `10.44.81.110`, worker-01 `10.44.81.111`, worker-02 `10.44.81.112` |
| 01.01.2026 | B | SSH verified on all nodes, Ubuntu 24.04, kernel 6.8.0-101-generic |
| 01.01.2026 | C | Ansible installed on master, inventory created, `ansible ping` → SUCCESS on all 3 nodes |
| 01.01.2026 | C | Playbook `kubeadm-cluster.yml` — baseline all nodes: swap, sysctl, containerd, kubeadm/kubelet/kubectl v1.30 |
| 01.01.2026 | C | `kubeadm init` on master, Calico CNI, join workers — all 3 nodes `Ready`, failed=0 |
| 01.01.2026 | D | Helm v3.20.0 installed on master |
| 01.01.2026 | D | MetalLB installed via Helm, IP pool `10.44.81.200-250` L2 configured |
| 01.01.2026 | D | Ingress-NGINX installed via Helm, `EXTERNAL-IP: 10.44.81.200` received from MetalLB |
| 01.01.2026 | D | cert-manager v1.19.4 installed via Helm (namespace `cert-manager`) |
| 01.01.2026 | D | CA setup: `lab-root-ca` (selfSigned) → Certificate → Secret → `lab-ca-issuer` (CA) — both ClusterIssuer Ready |
| 01.01.2026 | D | test-app: nginx deployment + Ingress for `app.lab.local`, TLS cert Ready |
| 01.01.2026 | D | Hosts file updated: `10.44.81.200 app.lab.local` |
| 01.01.2026 | D | kubeconfig `kubeconfig-lab.yaml` downloaded from master |
| 01.01.2026 | D | `lab-root-ca.crt` imported into trusted root store |
| 01.01.2026 | D | `kubectl` v1.35.2 installed via package manager |
| 01.01.2026 | D | Lens Desktop connected to cluster — all 3 nodes visible ✅ |
| 01.01.2026 | A | Git repository `shevchenkod/devops-lab` created on GitHub, SSH key added, first commit pushed |
| 01.01.2026 | A | Structure: `terraform/`, `ansible/`, `cluster/`, `apps/`, `docs/runbooks/` — created and pushed |
| 01.01.2026 | A | `.gitignore`: secrets, kubeconfig, SSH, certs, VM files excluded |
| 01.01.2026 | D | Longhorn prerequisites: `open-iscsi`, `multipath-tools`, `iscsi_tcp` — Ansible, failed=0 on 3 nodes |
| 01.01.2026 | D | Longhorn installed via Helm, 23 pods Running, StorageClass `longhorn` (default) ✅ |
| 01.01.2026 | D | Longhorn PVC test: `lh-pvc-test` Bound 2Gi, pod Running on worker-01, data written ✅ |
| 01.01.2026 | D | Longhorn persistence: pod deleted + recreated → file `/data/hello.txt` survived ✅ |
| 01.01.2026 | D | Longhorn HA: drain worker-01 → pod moved to worker-02, data intact → uncordon ✅ |
| 01.01.2026 | D | Longhorn UI: `https://longhorn.lab.local` Ingress + TLS cert, HTTP 200 ✅ |
| 01.01.2026 | D | StorageClass `longhorn-single` created (numberOfReplicas=1) |
| 01.01.2026 | F | Argo CD installed via Helm (namespace `argocd`), 7 pods Running ✅ |
| 01.01.2026 | F | `https://argocd.lab.local` Ingress + TLS, HTTP 200 ✅ |
| 01.01.2026 | F | GitHub repo `shevchenkod/devops-lab` connected to Argo CD — STATUS: Successful ✅ |
| 01.01.2026 | F | First application `test-app` in Argo CD — Synced / Healthy ✅ |
| 01.01.2026 | E | Worker disks expanded 20→35 GB (Proxmox qm resize + growpart + resize2fs) ✅ |
| 01.01.2026 | F+E | kube-prometheus-stack via Argo CD: 8 pods Running, PVC Longhorn Bound, Synced/Healthy ✅ |
| 01.01.2026 | E | `https://grafana.lab.local` Ingress TLS — HTTP 302, login page ✅ |
| 01.01.2026 | E | Alertmanager: AlertmanagerConfig CRD (Telegram receiver) + PrometheusRule (6 alerts) — Telegram alerts delivered ✅ |
| 01.01.2026 | G | WordPress 6.8.2 — Bitnami Helm chart 29.1.2, Argo CD, Longhorn PVCs (2Gi+5Gi), `https://wordpress.lab.local` TLS ✅ |
| 01.01.2026 | G | Uptime Kuma 2.1.3 — Argo CD, Longhorn PVC 1Gi, `https://kuma.lab.local` TLS, `1/1 Running` ✅ |
| 01.01.2026 | G | Strapi v5: manifests created (commit 27f8da2), TLS cert Ready ✅, 🔄 deployment WIP |
| 01.01.2026 | H | Worker disks expanded 20→60 GB via Proxmox REST API + growpart + resize2fs ✅ |
| 01.01.2026 | H | MinIO 5.4.0 (Helm) — Argo CD, standalone, 10Gi longhorn-single PVC, namespace minio ✅ |
| 01.01.2026 | H | MinIO: `https://minio.lab.local` Console Ingress TLS, bucket `velero` created via mc ✅ |
| 01.01.2026 | H | Velero 1.17.1 (Helm 11.4.0) — Argo CD, plugin velero-plugin-for-aws:v1.13.0 ✅ |
| 01.01.2026 | H | Velero BSL `default` → MinIO → status Available ✅ |
| 01.01.2026 | H | Velero node-agent DaemonSet (2 pods Running), fs-backup via kopia ✅ |
| 01.01.2026 | H | Velero schedules: velero-wordpress-daily (02:00 UTC, 30d) + velero-uptime-kuma-daily (03:00 UTC, 30d) ✅ |
| 01.01.2026 | H | Backup `test-wordpress-manual`: Phase Completed, 97 MiB, 42 objects in MinIO ✅ |
| 01.01.2026 | E | Loki 6.29.0 singleBinary, PVC 10Gi longhorn-single, 2/2 Running ✅ |
| 01.01.2026 | E | Promtail 6.16.6 DaemonSet 3/3 Running, 14 namespaces → Loki, Grafana datasource added ✅ |
| 01.01.2026 | E | Grafana dashboards: 1860/6417/15757/15758/15760/15141 imported, Loki Explore LogQL ✅ |
| 01.01.2026 | H | Workers CPU 2→4 vCPU via Proxmox upgrade ✅ |
| 01.01.2026 | H | external-snapshotter v8.2.0 CRDs + snapshot-controller in kube-system ✅ |
| 01.01.2026 | H | VolumeSnapshotClass `longhorn-snapshot-class` created, `type: bak` (DR-safe) ✅ |
| 01.01.2026 | H | Velero `--features=EnableCSI` enabled in app-velero.yaml ✅ |
| 01.01.2026 | H | Bucket `longhorn-backup` created in MinIO ✅ |
| 01.01.2026 | H | Secret `longhorn-backup-secret` created in longhorn-system ✅ |
| 01.01.2026 | H | Longhorn BackupTarget `default` → `s3://longhorn-backup@us-east-1/`, AVAILABLE ✅ |
| 01.01.2026 | H | Backup `wp-csi-02` (CSI VolumeSnapshot, both PVCs) — Phase: Completed ✅ |
| 01.01.2026 | H | Backup `wp-fsb-02` (FSB kopia, TTL 30d) — Phase: Completed ✅ |
| 01.01.2026 | H | **DR Drill**: namespace `wordpress` deleted → FSB restore → WordPress HTTP 200 in ~3 min ✅ |
| 01.01.2026 | H | Lesson: `type: snap` = NOT DR-safe; `type: bak` = DR-safe (data in MinIO) |
| 01.01.2026 | F | App-of-Apps: `cluster/apps/` (12 Application manifests) + `cluster/argocd/app-of-apps.yaml` (root Application) |
| 01.01.2026 | F | All 12 apps: Synced/Healthy. No more `kubectl apply` needed — only git push. Commit `43ed00d` |
| 01.01.2026 | I | **K8s cluster upgrade** v1.30.14 → v1.31.14 (kubeadm) — all 3 nodes Ready ✅ |
| 01.01.2026 | E | **NGINX Ingress metrics** enabled (helm REVISION 3), ServiceMonitor → Prometheus target up ✅ |
| 01.01.2026 | E | **SLO WordPress**: PrometheusRule — 6 recording rules + 4 alerts (Google SRE multi-burn-rate) ✅ |
| 01.01.2026 | E | SLO verified: error_rate=0% · latency_ok=100% · WordPressDown/BurnRate alarms loaded ✅ |
| 01.01.2026 | G | **Strapi v4.26.1** — closed as ✅ (v4 working, v5 migration not needed for lab) |
| 01.01.2026 | D | **Lens fix**: deleted `lens-metrics` namespace (Lens built-in Prometheus conflicted with kube-prometheus-stack) → Cluster Overview both panels ✅ |
| 01.01.2026 | I | **metrics-server** v0.8.1 installed in kube-system (--kubelet-insecure-tls for kubeadm) — `kubectl top nodes` ✅ |
| 01.01.2026 | I | **HPA WordPress**: `cpu: 2%/60%  memory: 10%/50%  min=1 max=3` — autoscaling active ✅ |
| 01.01.2026 | I | **PDB WordPress**: `minAvailable: 1` — protection during drain / rolling update ✅ |
| 01.01.2026 | I | **Rolling Update**: `maxSurge: 0, maxUnavailable: 1` (RWO PVC limitation) — revision 1→2 ✅ |
| 01.01.2026 | I | Lesson: `maxSurge: 1` + RWO PVC = Multi-Attach error → need `maxSurge: 0` or RWX storage |
| 01.01.2026 | D | Longhorn VolumeSnapshot test: `wordpress-snap-test` READYTOUSE:true, restore PVC Bound ✅ |
| 01.01.2026 | G | N8N deployed — Argo CD, Longhorn PVC, Ingress TLS ✅ |
| 01.01.2026 | G | Wiki (MkDocs Material) deployed — in-cluster registry, ARC CI pipeline ✅ |
| 01.01.2026 | I | Node add/remove cycle — worker-03 provisioned on pve02, joined, then removed ✅ |
| 01.01.2026 | J | Zone labels applied: master+worker-01 → zone-a, worker-02 → zone-b ✅ |
| 01.01.2026 | J | Zone A failure test: pve01 powered off → all services alive on zone-b ✅ |
| 01.01.2026 | J | Longhorn cross-zone replication verified: replicas on zone-a and zone-b ✅ |
