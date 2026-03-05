# 🗺️ DevOps Lab — Roadmap & Checklist

> Complete step-by-step plan for the full DevOps cycle: from infrastructure to GitOps, monitoring and DR.
> We move **block by block**, without skipping. Every completed step is marked `[x] ✅` with a date.

**Current status:** Blocks **A–J completed** ✅ — 01.01.2026 | **N8N v2.10.2 deployed** ✅ — 01.01.2026
GitHub Actions + ARC v0.13.1 ✅ | Sealed Secrets v2.18.3 ✅ | **17 Argo CD Apps** Synced/Healthy ✅

---

## 📋 Block Summary Table

| Block | Name | Status |
|-------|------|--------|
| [A](#a-foundations-repository-standards-access) | Foundations: repository, standards, access | ✅ Done |
| [B](#b-iaas-proxmox--terraform) | IaaS: Proxmox + Terraform | ✅ Done |
| [C](#c-configuration-ansible) | Configuration: Ansible | ✅ Done |
| [D](#d-kubernetes-platform-core) | Kubernetes Platform Core | ✅ Done |
| [E](#e-observability-metrics-logs-alerts-slo) | Observability: metrics, logs, alerts, SLO | ✅ Done |
| [F](#f-delivery-helm-gitops-cicd-pipelines) | Delivery: Helm, GitOps, CI/CD, Pipelines | ✅ Done |
| [G](#g-applications-real-world-services) | Applications: real-world services | ✅ Done |
| [H](#h-backup--dr-velero) | Backup / DR: Velero + MinIO | ✅ Done |
| [I](#i-operations--day-2) | Operations / Day-2 | ✅ Done |
| [J](#j-az--zone-simulation) | AZ / Zone simulation | ✅ Done |

---

## A. Foundations: repository, standards, access

### Git Repository with folder structure

> **Strategy:** GitHub now → self-hosted GitLab CE on Proxmox later.
> Full cycle: GitLab → GitLab Runner → Container Registry → Kubernetes (Argo CD)

- [x] ✅ Repository **GitHub** `shevchenkod/devops-lab` (private) created — 01.01.2026
  - SSH key `gitlab-devops-lab` added to GitHub (DEVOPS-LAB-PROXMOX)
  - SSH config configured: `~/.ssh/config` → `H:/DEVOPS-LAB/ssh/gitlab-devops-lab`
  - First commit pushed: `init: project structure, .gitignore, README`
  - URL: `git@github.com:shevchenkod/devops-lab.git`
- [x] ✅ Repository structure created — 01.01.2026
  - [x] `terraform/` — Proxmox / IaaS
  - [x] `ansible/` — server configuration
  - [x] `cluster/` — bootstrap k8s + core platform (cert-manager, metallb, ingress yamls)
  - [x] `apps/` — WordPress, Uptime Kuma, etc.
  - [x] `docs/runbooks/` — documentation and runbooks
- [x] ✅ `.gitignore` configured — secrets will not end up in the repo — 01.01.2026
  - `*.tfstate`, `ssh/`, `kubeconfig*.yaml`, `*.crt`, `*.key`, `PROXMOX01/`, `PROXMOX02/`, `*.vmdk`
- [x] ✅ `README.md` with lab and stack description — 01.01.2026

> 🔜 **Later (separate block):** Self-hosted GitLab CE on Proxmox VM
> - GitLab Runner in Kubernetes
> - Container Registry on own domain
> - Full CI/CD without external dependencies

### Standards and planning

- [ ] Naming conventions (VM, nodes, namespaces, releases)
- [ ] IP plan + subnets (mgmt / nodes / lb / dmz) + address table
- [ ] SSH keys, separate admin user, MFA where applicable

### Workstation tools

- [ ] VS Code plugins: Terraform, Kubernetes, YAML, Ansible, Git
- [x] ✅ Lens: cluster connection (kubeconfig, contexts) — 01.01.2026 **✓ verified**
  - `H:\DEVOPS-LAB\kubeconfig-lab.yaml`, server `https://10.44.81.110:6443`
  - Lens Desktop: connected, cluster shows all 3 nodes
  - Mobile (Lens Mobile / Kubenavigator): connected ✅

---

## B. IaaS: Proxmox + Terraform

### 🖥️ Proxmox — base setup

- [x] ✅ Proxmox installed — **pve01** (`10.44.81.101`) — 01.01.2026
- [x] ✅ Proxmox installed — **pve02** (`10.44.81.102`) — 01.01.2026
- [x] ✅ Terraform API tokens created and verified via `curl.exe` — 01.01.2026
  - pve01: `terraform@pve!terraform-pve01`
  - pve02: `terrafor@pve!terraform-pve02`
- [x] ✅ Storage pools defined — 01.01.2026
  - pve01: `local` (Directory, /var/lib/vz) + `local-lvm` (LVM-Thin)
  - pve02: `local` (Directory) + `local-lvm` (LVM-Thin) · 16 CPU · 15.58 GiB RAM · 121.95 GiB disk
- [x] ✅ Bridges / VLANs documented — 01.01.2026
  - `vmbr0` (Linux Bridge on ens33): pve01 `10.44.81.101/24`, pve02 `10.44.81.102/24`, gw `10.44.81.254`
  - All VMs (k8s nodes) will be on `vmbr0` in subnet `10.44.81.0/24`
  - MetalLB pool: `10.44.81.200–250` (reserved)
- [x] ✅ Templates (cloud-image Ubuntu 24.04) ready — 01.01.2026
  - `ubuntu-24.04-cloud.img` (600 MB) downloaded to pve01 and pve02
  - Path: `/var/lib/vz/template/cloud/ubuntu-24.04-cloud.img`
  - Installation ISO also uploaded: `/var/lib/vz/template/iso/ubuntu-24.04.4-live-server-amd64.iso`
- [x] ✅ Cloud-init works (VM template 9000 created) — 01.01.2026
  - VMID: `9000`, name: `ubuntu-2404-cloud`
  - Parameters: 2 CPU, 2048 MB RAM, `virtio-scsi`, `vmbr0`, cloud-init user: `ubuntu`/`ubuntu`
  - Created on **pve01** and **pve02** (VMID 9000 on both)
- [ ] Firewall / Datacenter policies (basic) enabled
- [ ] Backup storage / backup policy (basic)

### 🏗️ Terraform

- [x] ✅ Terraform backend configured (local state) — 01.01.2026
- [x] ✅ Proxmox provider configured (`bpg/proxmox` v0.97.1) — 01.01.2026
  - Terraform v1.14.6, provider reads nodes from pve01 and pve02 (verified `terraform plan`)
  - Project: `H:\DEVOPS-LAB\terraform\proxmox-lab\`
  - Secrets: via `$env:TF_VAR_*` (not stored in files)
- [x] ✅ Terraform modules: `module.vm` — k8s nodes created — 01.01.2026
- [x] ✅ Outputs: IP, node names — 01.01.2026
- [x] ✅ Full lifecycle: `plan → apply` works — 01.01.2026
  - `k8s-master-01` — `10.44.81.110` — pve01, VMID 101
  - `k8s-worker-01` — `10.44.81.111` — pve01, VMID 111
  - `k8s-worker-02` — `10.44.81.112` — pve02, VMID 112
  - SSH works on all nodes, Ubuntu 24.04, kernel 6.8.0-101-generic

---

## C. Configuration: Ansible

- [x] ✅ Inventory created on master node (`~/ansible/inventory.ini`) — 01.01.2026
  - Groups: `k3s_master` (110), `k3s_workers` (111, 112), `k3s_cluster`
  - `ansible_user=ubuntu`, key `~/.ssh/devops-lab`
  - `ansible ping` → SUCCESS on all 3 nodes
- [x] ✅ Baseline preparation of all nodes via Ansible — 01.01.2026
  - swap off, sysctl (bridge-nf-call-iptables, ip_forward), kernel modules (overlay, br_netfilter)
  - containerd installed + `SystemdCgroup=true` in config.toml
  - kubeadm / kubelet / kubectl v1.30 installed, packages held
- [x] ✅ Kubernetes installation (kubeadm) automated via Ansible — 01.01.2026
  - `kubeadm init` on master, CNI Calico v3.27.3, kubeconfig for ubuntu
- [x] ✅ Worker node join automated — 01.01.2026
  - token passed via `set_fact`, workers join automatically
- [x] ✅ Idempotency: `stat` checks on `admin.conf` and `kubelet.conf` — repeated run is safe
- [ ] Baseline hardening (separate):
  - [ ] firewall (ufw / nftables)
  - [ ] separate admin user / MFA

---

## D. Kubernetes Platform Core

### Cluster Bootstrap

- [x] ✅ Kubernetes v1.30.14 (kubeadm) — all 3 nodes `Ready` — 01.01.2026
  - `k8s-master-01` `10.44.81.110` — control-plane
  - `k8s-worker-01` `10.44.81.111` — worker
  - `k8s-worker-02` `10.44.81.112` — worker
  - containerd 1.7.28, Ubuntu 24.04, kernel 6.8.0-101-generic
- [x] ✅ kubeconfig available on PC — `H:\DEVOPS-LAB\kubeconfig-lab.yaml` — 01.01.2026
  - Instructions in DevOps.md → Lens section
  - `scp -i devops-lab ubuntu@10.44.81.110:~/.kube/config kubeconfig-lab.yaml`
- [ ] Namespace structure:
  - [ ] `platform` — ingress / cert / storage / monitoring
  - [ ] `apps` — application services
- [ ] RBAC basics (admin / user, service accounts)

### Networking + Load Balancing

- [x] ✅ CNI Calico v3.27.3 installed, pod CIDR `192.168.0.0/16` — 01.01.2026
- [x] ✅ **MetalLB L2** installed via Helm — 01.01.2026
  - IP pool: `10.44.81.200–10.44.81.250`
  - L2Advertisement `lab-l2` configured
- [x] ✅ `LoadBalancer` service receives external IP — 01.01.2026
- [ ] (Optional) NetworkPolicies — minimum 1–2 examples

### Ingress + TLS

- [x] ✅ Ingress-NGINX installed via Helm, `EXTERNAL-IP: 10.44.81.200` — 01.01.2026
- [x] ✅ cert-manager v1.19.4 installed via Helm — 01.01.2026
  - [x] ✅ `ClusterIssuer` `lab-root-ca` (selfSigned) — lab CA created
  - [x] ✅ `ClusterIssuer` `lab-ca-issuer` (CA type) — issues certificates
  - [ ] (Optional) Let's Encrypt staging/prod — public domain required
- [x] ✅ TLS for test domain `app.lab.local` works — 01.01.2026 **✓ verified in browser**
  - Ingress with annotation `cert-manager.io/cluster-issuer: lab-ca-issuer`
  - ADDRESS: `10.44.81.200`, cert Ready
  - hosts: `10.44.81.200   app.lab.local` added to Windows hosts
  - `https://app.lab.local` → Welcome to nginx, no warnings ✅

### Storage

- [x] ✅ Longhorn prerequisites installed via Ansible — 01.01.2026
  - `open-iscsi`, `multipath-tools` on all 3 nodes
  - `iscsid`: active + enabled on all nodes
  - `iscsi_tcp` kernel module loaded and persistent
- [x] ✅ Longhorn installed via Helm — 01.01.2026
  - namespace: `longhorn-system`, 23 pods Running
  - `defaultDataPath: /var/lib/longhorn`
  - `defaultClassReplicaCount: 2` (for 2 worker nodes)
- [x] ✅ StorageClass created — 01.01.2026
  - `longhorn` (default) — `driver.longhorn.io`, Immediate, allowVolumeExpansion=true
  - `longhorn-static` — for static PVs
- [x] ✅ PVC provisioning works (test PVC + pod) — 01.01.2026
  - `lh-pvc-test`: 2Gi, Bound, StorageClass `longhorn`
  - Pod `lh-pod-test`: Running on k8s-worker-01, data written `/data/hello.txt`
  - Persistence confirmed: pod deleted + recreated → file `Sat Feb 28 09:41:52 UTC 2026` preserved ✅
- [x] ✅ Longhorn HA (node drain) verified — 01.01.2026
  - `kubectl drain k8s-worker-01` → pod moved to **k8s-worker-02**
  - Longhorn re-mounted volume from replica automatically, data intact ✅
  - `kubectl uncordon k8s-worker-01` → all 3 nodes Ready ✅
- [x] ✅ Longhorn UI via Ingress + TLS — 01.01.2026
  - `https://longhorn.lab.local` → HTTP 200 ✅
  - Certificate `longhorn-tls` Ready (lab-ca-issuer), ADDRESS `10.44.81.200`
  - Windows hosts: `10.44.81.200 longhorn.lab.local` added
- [ ] Longhorn Snapshot / restore verified

---

## E. Observability: metrics, logs, alerts, SLO

### Metrics / Dashboards

- [x] ✅ Prometheus (`kube-prometheus-stack`) installed via Argo CD — 01.01.2026
  - Helm Application in Argo CD: Synced / Healthy ✅
  - 8 pods Running (including prometheus-0, alertmanager-0)
  - PVC Longhorn: Prometheus 10Gi, Grafana 5Gi, Alertmanager 2Gi — all Bound ✅
  - Worker disks expanded: 20→35 GB (actual free: 22G + 24G)
- [x] ✅ Grafana accessible via Ingress + TLS — 01.01.2026
  - `https://grafana.lab.local` → HTTP 302 (login) ✅
  - Login: `admin` / `DevOpsLab2026!`
  - Certificate Ready (lab-ca-issuer), ADDRESS `10.44.81.200`
- [x] ✅ Dashboards: cluster / node / pods — Node Exporter Lab, K8s Cluster Lab, Loki Logs Lab — GitOps ConfigMaps, Argo CD `grafana-dashboards` Synced/Healthy — 01.01.2026
- [x] ✅ Alertmanager: Telegram notifications configured — 01.01.2026
  - [x] ✅ 6 alert rules: HighCPU, HighMemory, DiskAlmostFull, PodCrashLooping, PodNotReady, DeploymentReplicasMismatch
  - [x] ✅ Delivery channel: Telegram (bot + chat ID via K8s Secret)

### Logs

- [x] ✅ Loki 6.29.0 singleBinary, PVC 10Gi longhorn-single, namespace loki — 01.01.2026
- [x] ✅ Promtail 6.16.6 DaemonSet, 3/3 Running (all nodes incl. master), all namespaces → Loki — 01.01.2026
- [x] ✅ Loki datasource added to Grafana — 01.01.2026
- [ ] Log search in Grafana Explore — verify LogQL queries *(open https://grafana.lab.local → Dashboards → Loki Logs Lab)*

### SLO logic

- [x] ✅ Service defined: WordPress
- [x] ✅ SLI: uptime / latency / error rate — NGINX Ingress metrics, ServiceMonitor, recording rules (6)
- [x] ✅ SLO: 99.5% availability, P95 latency < 500ms — burn-rate alerts (4), error_rate=0%, latency_ok=100% — 01.01.2026

---

## F. Delivery: Helm, GitOps, CI/CD, Pipelines

### Helm

- [ ] All core components installed via Helm (or helmfile)
- [ ] Upgrade / rollback tested

### GitOps — Argo CD

- [x] ✅ Argo CD installed via Helm — 01.01.2026
  - namespace: `argocd`, 7 pods Running
  - `server.insecure=true` — TLS terminated at Ingress
  - `https://argocd.lab.local` → HTTP 200, cert Ready (lab-ca-issuer) ✅
  - admin password: `DevOpsLab2026!` (initial, stored in DevOps.md)
- [x] ✅ Git repo connected — 01.01.2026
  - `https://github.com/shevchenkod/devops-lab.git` → STATUS: Successful ✅
  - Credentials via K8s Secret (not in Git), label `argocd.argoproj.io/secret-type=repository`
- [x] ✅ First application via Argo CD — 01.01.2026
  - `test-app`: Synced / Healthy ✅ (path: `apps/test-app`)
- [x] ✅ kube-prometheus-stack via Argo CD (Helm Application) — 01.01.2026
  - Synced / Healthy, all pods Running, PVC Bound (Longhorn)
- [x] ✅ App-of-Apps structure — `cluster/argocd/app-of-apps.yaml` watches `cluster/apps/` — 01.01.2026
- [x] ✅ Sync policies: automated (prune + selfHeal) for all apps — 01.01.2026
- [x] ✅ GitHub Actions + ARC v0.13.1: wiki-ci pipeline ✅ — 01.01.2026
- [x] ✅ Sealed Secrets v2.18.3: `kubeseal` workflow, sealed-secret for N8N ✅ — 01.01.2026

### CI/CD (GitHub Actions + ARC)

- [x] ✅ GitHub Actions workflow: `.github/workflows/wiki-ci.yml` — builds MkDocs, deploys to cluster — 01.01.2026
- [x] ✅ ARC (Actions Runner Controller) v0.13.1 — self-hosted runners in Kubernetes (`arc-runner-set`) — 01.01.2026
- [ ] Pipeline: build Docker image → tag → push to registry → GitOps deploy
- [ ] GitLab CI: self-hosted GitLab CE on Proxmox (future block)
- [ ] (Optional) Security gate: image scan (Trivy)

### Registry

- [x] ✅ In-cluster registry `registry:2` on NodePort 30500 — 01.01.2026
  - All nodes have containerd mirrors configured for `10.44.81.110:30500`
- [ ] Harbor: self-hosted registry with RBAC + Trivy scanning (backlog)

### Secrets Management

- [x] ✅ Sealed Secrets v2.18.3 — kubeseal workflow — 01.01.2026
- [x] ✅ Secrets **not stored** in plaintext in the repository ✅

---

## G. Applications: real-world services

- [x] ✅ **Uptime Kuma** — Argo CD Application + Longhorn PVC + Ingress TLS — 01.01.2026
  - Image: `louislam/uptime-kuma:2.1.3` | PVC: 1Gi (Longhorn) | Pod: `1/1 Running` ✅
  - Ingress: `https://kuma.lab.local` (cert-manager lab CA) | TLS cert: Ready ✅
  - Argo CD Application: `cluster/argocd/app-uptime-kuma.yaml` — Synced / Healthy ✅
  - Fix: `configuration-snippet` annotation removed (disabled by ingress admin) — commit `4cce752`
- [x] ✅ **Strapi v4.26.1** (headless CMS) — Argo CD + Longhorn + Ingress TLS — 01.01.2026
  - Image: `node:18-alpine` | PVC: `strapi-data` 3Gi (longhorn-single, /srv/app)
  - Ingress: `https://strapi.lab.local` (cert-manager lab CA) | TLS cert: Ready ✅
  - Argo CD Application: `cluster/argocd/app-strapi.yaml` — Synced / Healthy ✅
  - Bootstrap: initContainer — `npm install` + `NODE_ENV=production npm run build` (pre-build admin)
  - Main: `npm run start` (production) | `public/uploads` + `.tmp` created before early-exit
  - Deps: `react@^18`, `react-dom`, `react-router-dom@^5`, `styled-components@^5`
  - Strapi secrets in K8s Secret `strapi-secrets` (base64, not in git)
  - `/admin` HTTP 200 ✅ | Pod: `1/1 Running`, 0 restarts ✅
- [x] ✅ **WordPress** — Bitnami Helm + Argo CD + Longhorn PVC + Ingress TLS — 01.01.2026
  - [x] ✅ DB (MariaDB 11.8.3) + PVC 2Gi (Longhorn)
  - [x] ✅ WordPress 6.8.2 + PVC 5Gi (Longhorn)
  - [x] ✅ Ingress + TLS (`https://wordpress.lab.local`, cert-manager lab CA)
  - [x] ✅ Argo CD Application — Healthy (chart 29.1.2 + bitnamilegacy debian images)
  - [ ] Backup strategy (Velero / DB dump)
- [x] ✅ **N8N v2.10.2** — Workflow automation, Argo CD GitOps — 01.01.2026
  - [x] ✅ Namespace `n8n`, PVC `n8n-data` 5Gi Longhorn RWO
  - [x] ✅ Deployment: `n8nio/n8n:2.10.2`, strategy: Recreate, port 5678
  - [x] ✅ Env: `N8N_HOST=n8n.lab.local`, `DB_TYPE=sqlite`, `GENERIC_TIMEZONE=Europe/Kiev`
  - [x] ✅ Sealed Secrets: `N8N_ENCRYPTION_KEY` + `N8N_USER_MANAGEMENT_JWT_SECRET`
  - [x] ✅ Ingress: `https://n8n.lab.local`, cert-manager `lab-ca-issuer`, `proxy-body-size: 50m`
  - [x] ✅ `cluster/apps/app-n8n.yaml` — Argo CD Application: Synced / Healthy ✅
  - [x] ✅ Pod `1/1 Running` (k8s-worker-02), TLS cert Ready ✅
  - [x] ✅ `10.44.81.200 n8n.lab.local` added to Windows hosts ✅
- [ ] (Optional) MinIO, whoami, test APIs

---

## H. Backup / DR: Velero

- [x] ✅ **MinIO 5.4.0** installed — standalone, namespace `minio`, 10Gi `longhorn-single` PVC — 01.01.2026
  - S3 API: `http://minio.minio.svc.cluster.local:9000`
  - Console: `https://minio.lab.local` | `minioadmin` / `DevOpsLab2026!`
  - Bucket `velero` created manually via `mc` (buckets hook removed — race condition)
- [x] ✅ **Velero 1.17.1** installed — Helm chart 11.4.0, Argo CD Application — 01.01.2026
  - Plugin: `velero-plugin-for-aws:v1.13.0`
  - `checksumAlgorithm: ""` — mandatory for MinIO + aws-sdk-go-v2 v1.13
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
  - [x] ✅ WordPress fully restored: pods `1/1 Running`, PVC Bound (2Gi+5Gi), `https://wordpress.lab.local` HTTP 200, Title: "DevOps Lab" ✅
  - [x] ✅ Restore: phase=Completed, warnings=1, errors=0. Restore time: ~3 min
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
  - [ ] Node loss → reschedule (covered in Block J)
  - [ ] PDB + rolling updates (covered in Block I)

> ⚠️ **DR lesson:** `type: snap` = Longhorn internal snapshot (data INSIDE the volume) → deleted with namespace. Use `type: bak` for DR — data is stored in MinIO and survives deletion.
> 📌 **Workers CPU:** workers upgraded to 4 vCPU (previously 2 vCPU) — 01.01.2026
> 📌 **Worker disks expanded** to 60 GB via Proxmox API + growpart — 01.01.2026

---

## I. Operations / Day-2

- [x] ✅ Rolling updates — strategy maxSurge:0 + maxUnavailable:1 (see Lesson 29), 01.01.2026
- [x] ✅ Scaling:
  - [x] ✅ Manual `scale replicas` — verified
  - [x] ✅ HPA (metrics-server v0.8.1) — WordPress HPA (cpu/60%, mem/50%), 1–3 replicas, 01.01.2026
- [x] ✅ Node maintenance:
  - [x] ✅ `cordon / drain / uncordon` — works, verified in Block J
  - [x] ✅ PodDisruptionBudget — WordPress PDB minAvailable:1, 01.01.2026
- [x] ✅ Node addition (Terraform apply + Ansible join) — worker-03 created, joined cluster in ~15 min, 01.01.2026
- [x] ✅ Node removal — cordon + drain + delete + terraform destroy (via Proxmox API), 01.01.2026
- [x] ✅ Cluster upgrade (minor) — v1.30 → v1.31.14, 01.01.2026
- [x] ✅ Runbooks: `docs/runbooks/cluster-bootstrap.md` + `docs/runbooks/disaster-recovery.md` — 01.01.2026

---

## J. AZ / Zone simulation

> Relevant when both Proxmox hosts are active (pve01 + pve02 already exist ✅)

- [x] ✅ Two Proxmox hosts = Zone A (pve01) / Zone B (pve02)
- [x] ✅ Zone labels: `topology.kubernetes.io/zone` + `topology.kubernetes.io/region=proxmox-lab` — all 3 nodes, 01.01.2026
  - [x] ✅ master-01 + worker-01 → `zone-a` (pve01)
  - [x] ✅ worker-02 → `zone-b` (pve02)
- [x] ✅ "Zone A fails" test (cordon master-01 + worker-01):
  - [x] ✅ ALL services moved to worker-02 (zone-b): WordPress, Grafana, Loki, MinIO, Strapi, Wiki, Registry, Velero, ingress-nginx ✅
  - [x] ✅ uncordon — all 3 nodes Ready ✅
- [x] ✅ Storage topology: Longhorn replicas across zones — replicas on worker-01 (zone-a) + worker-02 (zone-b) ✅
- [x] ✅ `cluster/platform/node-labels.yaml` — documentation manifest created, 01.01.2026

---

## 📌 Rules of movement

> - We move **block by block**, without skipping
> - Each completed step: brief confirmation + command output / screenshot
> - Completed items are marked `[x] ✅` with a date

---

## 🔖 Progress Log

| Date | Block | Completed |
|------|-------|-----------|
| 01.01.2026 | B | Proxmox pve01 (`10.44.81.101`) installed |
| 01.01.2026 | B | Proxmox pve02 (`10.44.81.102`) installed |
| 01.01.2026 | B | Terraform API tokens for pve01 and pve02 created and verified via `curl.exe` |
| 01.01.2026 | — | `DevOps.md` created — knowledge base with cheat sheets for all tools |
| 01.01.2026 | — | `roadmap-devops.md` created — progress checklist |
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
| 01.01.2026 | D | CA setup: `lab-root-ca` (selfSigned) → Certificate → Secret → `lab-ca-issuer` (CA) — both ClusterIssuers Ready |
| 01.01.2026 | D | test-app: nginx deployment + Ingress for `app.lab.local`, TLS cert Ready |
| 01.01.2026 | D | Windows hosts: `10.44.81.200 app.lab.local` added |
| 01.01.2026 | D | kubeconfig `H:\DEVOPS-LAB\kubeconfig-lab.yaml` downloaded from master |
| 01.01.2026 | D | `lab-root-ca.crt` imported into Windows `Cert:\LocalMachine\Root` |
| 01.01.2026 | D | `kubectl` v1.35.2 installed on Windows via winget |
| 01.01.2026 | D | Lens Desktop connected to cluster — all 3 nodes visible ✅ |
| 01.01.2026 | D | Lens Mobile connection to cluster works ✅ |
| 01.01.2026 | A | Git repository `shevchenkod/devops-lab` created on GitHub, SSH key added, first commit pushed |
| 01.01.2026 | A | Structure: `terraform/`, `ansible/`, `cluster/`, `apps/`, `docs/runbooks/` — created and pushed |
| 01.01.2026 | A | `.gitignore`: secrets, kubeconfig, SSH, certs, VMware VM files excluded |
| 01.01.2026 | D | Longhorn prerequisites: `open-iscsi`, `multipath-tools`, `iscsi_tcp` — Ansible, failed=0 on 3 nodes |
| 01.01.2026 | D | Longhorn installed via Helm, 23 pods Running, StorageClass `longhorn` (default) ✅ |
| 01.01.2026 | D | Longhorn PVC test: `lh-pvc-test` Bound 2Gi, pod Running on worker-01, data written ✅ |
| 01.01.2026 | D | Longhorn persistence: pod deleted + recreated → file `/data/hello.txt` preserved ✅ |
| 01.01.2026 | D | Longhorn HA: drain worker-01 → pod moved to worker-02, data intact → uncordon ✅ |
| 01.01.2026 | D | Longhorn UI: `https://longhorn.lab.local` Ingress + TLS cert, HTTP 200 ✅ |
| 01.01.2026 | D | StorageClass `longhorn-single` created (numberOfReplicas=1) |
| 01.01.2026 | F | Argo CD installed via Helm (namespace `argocd`), 7 pods Running ✅ |
| 01.01.2026 | F | `https://argocd.lab.local` Ingress + TLS, HTTP 200 ✅ |
| 01.01.2026 | F | GitHub repo `shevchenkod/devops-lab` connected to Argo CD — STATUS: Successful ✅ |
| 01.01.2026 | F | First application `test-app` in Argo CD — Synced / Healthy ✅ |
| 01.01.2026 | E | Worker disks expanded 20→35 GB (Proxmox qm resize + growpart + resize2fs) ✅ |
| 01.01.2026 | F+E | kube-prometheus-stack via Argo CD: 8 pods Running, PVC Longhorn Bound, Synced/Healthy ✅ |
| 01.01.2026 | E | `https://grafana.lab.local` Ingress TLS — HTTP 302, admin/DevOpsLab2026! ✅ |
| 01.01.2026 | E | Alertmanager: AlertmanagerConfig CRD (Telegram receiver) + PrometheusRule (6 alerts) — Telegram alerts delivered ✅ |
| 01.01.2026 | G | WordPress 6.8.2 — Bitnami Helm chart 29.1.2, Argo CD, Longhorn PVCs (2Gi+5Gi), `https://wordpress.lab.local` TLS ✅ |
| 01.01.2026 | G | Uptime Kuma 2.1.3 — Argo CD, Longhorn PVC 1Gi, `https://kuma.lab.local` TLS, `1/1 Running` ✅ |
| 01.01.2026 | G | Strapi v5: manifests created (commit 27f8da2), TLS cert Ready ✅, deployment WIP |
| 01.01.2026 | G | Strapi **v4.26.1** — switched from v5 to v4 (stable), node:18-alpine, initContainer bootstrap, pre-build admin, `1/1 Running` 0 restarts, `/admin` HTTP 200 ✅ |
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
| 01.01.2026 | H | Commit `cf7e549` pushed: Longhorn BackupTarget + VolumeSnapshotClass type:bak |
| 01.01.2026 | E | Grafana dashboards: Node Exporter Lab, K8s Cluster Lab, Loki Logs Lab — GitOps ConfigMaps → Argo CD `grafana-dashboards` Synced/Healthy ✅ |
| 01.01.2026 | E | Sidecar loaded all 3 dashboards: loki-logs.json, node-exporter-full.json, k8s-cluster.json — Response 200 OK ✅ |
| 01.01.2026 | E | **Fix**: Loki Logs dashboard — `allValue: ".*"` → `".+"` (Loki: empty-compatible matcher error, commit `06ede01`) ✅ |
| 01.01.2026 | E | **Fix**: Node Exporter dashboard — variable `node_uname_info{nodename}` → `label_values(node_cpu_seconds_total, instance)`, removed `:.*` from all queries (commit `11ec233`) ✅ |
| 01.01.2026 | E | **Fix**: Argo CD cached old ConfigMap (showed Synced but did not apply) — `kubectl patch application grafana-dashboards ... sync HEAD` → ConfigMap updated ✅ |
| 01.01.2026 | E | All 3 dashboards working: **Node Exporter Lab** ✅ (instance `10.44.81.1xx:9100`), **K8s Cluster Lab** ✅, **Loki Logs Lab** ✅ |
| 01.01.2026 | I | Quick closures: marked [x] actually completed items in roadmap |
| 01.01.2026 | I | **Node add test**: worker-03 created via Terraform (VMID 113, pve02, 10.44.81.113) + Ansible join + kubectl → 4 nodes Ready ✅ |
| 01.01.2026 | I | **Node remove test**: kubectl cordon + drain + delete + terraform destroy (via Proxmox API) → 3 nodes Ready ✅ |
| 01.01.2026 | I | `terraform destroy` hung → Proxmox API: stop VM + DELETE + `terraform state rm` — Lesson 30 ✅ |
| 01.01.2026 | I | Commit `0c8fd5d`: Block I — node add/remove test, terraform.tfvars gitignored |
| 01.01.2026 | J | Zone labels assigned: master-01+worker-01 → zone-a, worker-02 → zone-b, all nodes → region=proxmox-lab ✅ |
| 01.01.2026 | J | Longhorn cross-zone: replicas on worker-01 (zone-a) + worker-02 (zone-b) confirmed ✅ |
| 01.01.2026 | J | **Zone A failure test**: cordon master-01+worker-01 → ALL services (13) on worker-02 zone-b survived ✅ uncordon → 3/3 Ready ✅ |
| 01.01.2026 | J | `cluster/platform/node-labels.yaml` created — commit `cf624c6` |
| 01.01.2026 | docs | Runbooks: `docs/runbooks/cluster-bootstrap.md` + `docs/runbooks/disaster-recovery.md` — commit `5d73763` |
| 01.01.2026 | docs | README, wiki lessons 30-31, chat history updated — Blocks A–J complete — commit `39d8a63` |
| 01.01.2026 | F | GitHub Actions + ARC v0.13.1: wiki-ci pipeline ✅, Sealed Secrets v2.18.3 ✅ — commit `9e5bd6c` |
| 01.01.2026 | G | N8N v2.10.2 — manifests created (`apps/n8n/`): namespace, pvc 5Gi, deployment, service, ingress, sealed-secret — commit `3e3b063` |
| 01.01.2026 | G | N8N: `cluster/apps/app-n8n.yaml` — Argo CD Application applied, Pod `1/1 Running` (k8s-worker-02), PVC `n8n-data` 5Gi Bound ✅ |
| 01.01.2026 | G | N8N: version 1.84.3 → pinned `n8nio/n8n:2.10.2` (latest stable), imagePullPolicy: IfNotPresent — commits `5f6d610`, `8973e7a`, `4a5db94` |
| 01.01.2026 | G | N8N Argo CD: Synced / Healthy, `https://n8n.lab.local` TLS ✅, `10.44.81.200 n8n.lab.local` in Windows hosts ✅ |

---

## 📋 PLAN — Backlog

> Tasks without a deadline — return when needed.

| Area | Description | Priority |
|------|-------------|---------|
| **Security: NetworkPolicies** | Isolate namespaces (wordpress, strapi, argocd, monitoring...) | 🔴 High |
| **Security: RBAC** | Fine-grained RBAC for workloads, PodSecurityAdmission `restricted` | 🔴 High |
| **Security: SSH MFA** | MFA for SSH on nodes | 🟡 Medium |
| **CI/CD: Trivy scan** | Image scanning as security gate in wiki-ci pipeline | 🟡 Medium |
| **CI/CD: Semver** | Image versioning (semver instead of `latest`) + Telegram notify | 🟡 Medium |
| **GitLab CE** | Self-hosted GitLab on Proxmox (VM via Terraform) + GitLab Runner in K8s | 🟡 Medium |
| **LiteLLM + OpenWebUI** | AI stack: LiteLLM as unified gateway (Claude + Gemini), OpenWebUI as ChatGPT interface | 🟡 Medium |
| **KeyCloak** | SSO platform: bitnami/keycloak Helm, Microsoft OIDC / Google OAuth2, service integration | 🟡 Medium |
| **Telegram Bot (N8N)** | Bot via N8N Webhook → Claude/Gemini API → replies, tasks, notifications | 🟡 Medium |
| **MCP Server** | Model Context Protocol server (Python/Node.js) in K8s: kubectl + Loki + Terraform tools for Claude | 🟢 Low |
| **Asterisk VM** | FreePBX on separate Proxmox VM + SIP trunk (Zadarma/Binotel) — IP telephony outside K8s | 🟢 Low |
| **ESO** | External Secrets Operator as an alternative to Sealed Secrets | �� Low |
| **TLS: Let's Encrypt** | Public domain + cert-manager ACME | 🟢 Low |
| **Kyverno** | Kubernetes-native policy engine: replacement for PodSecurityAdmission, admission webhooks, mutation/validation | 🔴 High |
| **Harbor** | Self-hosted Container Registry with UI, RBAC, built-in Trivy scanning — replaces `registry:2` | 🟡 Medium |
| **Argo Rollouts** | Canary / Blue-Green deployments via Argo CD — gradual rollout with automatic rollback | 🟡 Medium |
| **Grafana Tempo** | Distributed tracing backend — complements Grafana + Loki stack (OpenTelemetry) | 🟡 Medium |
| **KEDA** | Event-driven autoscaling: scale pods by queue (RabbitMQ, Kafka, Prometheus metrics) | 🟢 Low |
| **SonarQube** | Static code analysis: bugs, vulnerabilities, code smells — gate in CI/CD pipeline | 🟢 Low |
| **Renovate Bot** | Automatic PRs for dependency updates (Helm charts, Docker images, npm) | 🟢 Low |
| **Backstage** | Developer Portal from Spotify: service catalog, documentation, TechDocs, templates | 🟢 Low |
