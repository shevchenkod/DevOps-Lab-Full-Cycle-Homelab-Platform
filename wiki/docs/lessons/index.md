## 🚨 Lessons Learned — Gotchas & Nuances

> This section is compiled from real experience setting up the lab.
> Each item is a concrete problem you can step on, and its solution.
> **Read this BEFORE doing anything for the first time.**

---

### 1. 💾 Velero + MinIO — required `checksumAlgorithm` parameter

**Problem:** backup completes with InvalidChecksum / SignatureDoesNotMatch error.

**Cause:** velero-plugin-for-aws starting from v1.13.0 switched to `aws-sdk-go-v2`,
which by default adds `x-amz-checksum-*` headers. MinIO does not understand them.

**Solution:** In Velero `values.yaml`, always add:
```yaml
configuration:
  backupStorageLocation:
    - config:
        checksumAlgorithm: ""   # ← REQUIRED for MinIO
```

> ⚠️ Without this parameter, Velero + MinIO will not work. Applies to velero-plugin-for-aws **v1.13.0+**.

---

### 2. 📸 Longhorn CSI: `type: snap` vs `type: bak` — CRITICAL for DR

**This is the most costly lesson in this project.**

| Parameter | `type: snap` | `type: bak` |
|-----------|-------------|-------------|
| Where data is stored | Inside Longhorn volume (in-cluster) | External BackupTarget (MinIO/S3) |
| Survives namespace deletion? | ❌ **NO** — deleted with the volume | ✅ **YES** |
| Suitable for Disaster Recovery? | ❌ **NO** | ✅ **YES** |
| Requires BackupTarget? | ❌ No | ✅ **YES** |
| Creation speed | Instant | Slower (copies to S3) |

**Symptoms of using `type: snap` as a DR backup:**
- Velero backup — `Phase: Completed` (looks successful!)
- Namespace deleted → Velero restore → pods stuck in `Init:0/1`
- `kubectl describe volumesnapshot ...` → `VolumeCloneFailed: cannot find source volume pvc-xxxxxx`
- Cause: `snapshotHandle: snap://pvc-xxx/snapshot-xxx` — data lived inside the deleted volume

**Rule:** For any CSI backup intended for DR — **always use `type: bak`**.

```yaml
# cluster/storage/longhorn-volumesnapshotclass.yaml
parameters:
  type: bak   # ← DR-safe: data goes to MinIO via BackupTarget
  # type: snap  ← DO NOT use for DR!
```

---

### 3. 🎯 Longhorn BackupTarget — it's a CRD, not a UI setting

**Problem:** BackupTarget is configured in the Longhorn UI, but after restart or when applied via GitOps — it does not persist / does not work.

**Cause:** BackupTarget is a separate CRD `backuptargets.longhorn.io`, not just a Setting. It must be managed as a K8s resource.

**Solution:** Create a manifest and apply via `kubectl apply`:
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

**Secret** with exact keys (other keys will not work):
```yaml
stringData:
  AWS_ACCESS_KEY_ID: "minioadmin"
  AWS_SECRET_ACCESS_KEY: "your-password"
  AWS_ENDPOINTS: "http://minio.minio.svc.cluster.local:9000"
```

**URL format:** `s3://bucket-name@region/` — `@region` is required even for MinIO, use any value (e.g. `us-east-1`).

> ✅ Verification: `kubectl get backuptargets.longhorn.io -n longhorn-system` → the `AVAILABLE` field must be `True`.

---

### 4. 📦 external-snapshotter — installation order matters

**Problem:** VolumeSnapshot is not created, error "no kind VolumeSnapshotClass registered".

**Cause:** CRDs from external-snapshotter are not installed, or installed in the wrong order.

**Correct order:**
```bash
# 1. CRDs first (from repo kubernetes-csi/external-snapshotter, branch release-8.2)
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

# 2. Then the controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
```

> ⚠️ Version v8.2.0 is compatible with Kubernetes v1.30.x. For other K8s versions — check the [compatibility table](https://github.com/kubernetes-csi/external-snapshotter#compatibility).

---

### 5. 🌐 Ingress-NGINX — `configuration-snippet` is blocked by default

**Problem:** Ingress with annotation `nginx.ingress.kubernetes.io/configuration-snippet: |` is not applied, config is ignored.

**Cause:** In modern versions of ingress-nginx `allow-snippet-annotations: false` is the default for security reasons (protection from SSRF via Lua snippets).

**Symptoms:** Uptime Kuma does not show statuses (WebSocket not working), no custom directives in nginx logs.

**Solution:** Do not use `configuration-snippet`. For WebSocket and similar tasks — use standard annotations:
```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
  nginx.ingress.kubernetes.io/proxy-set-headers: "Upgrade, Connection"
```

---

### 6. ⚙️ containerd + Kubernetes — `SystemdCgroup = true` is mandatory

**Problem:** Nodes stuck in `NotReady`, kubelet crashes.

**Cause:** kubelet by default expects `cgroupDriver: systemd`, while containerd by default uses `cgroupfs`. cgroup driver conflict.

**Solution:** In `/etc/containerd/config.toml` (on ALL nodes):
```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

After the change: `systemctl restart containerd`.

> If configuring via Ansible — add this as a task in the playbook, otherwise nodes will be unstable.

---

### 7. 🗄️ Longhorn — prerequisites on ALL nodes (including master)

**Problem:** Longhorn pods Running, but PVC does not mount, pod stuck in `ContainerCreating`.

**Cause:** `open-iscsi` is not installed or `iscsi_tcp` module is not loaded on the node.

**What must be present on EVERY node (including control-plane):**
```bash
# Packages
apt install -y open-iscsi multipath-tools

# Service
systemctl enable --now iscsid

# Kernel module — load now
modprobe iscsi_tcp

# Kernel module — load at boot
echo "iscsi_tcp" > /etc/modules-load.d/iscsi_tcp.conf
```

> ✅ Check: `systemctl is-active iscsid` → `active`, `lsmod | grep iscsi_tcp` → present.

---

### 8. 💽 Longhorn — storage shortage when scheduledStorage > 80%

**Problem:** PVC is not created, error `insufficient storage`.

**Cause:** Longhorn calculates `scheduledStorage` based on replicas. With 2 replicas and 2 workers, when > 80% is occupied — new PVCs are rejected.

**Solution:** Create a separate StorageClass with one replica for non-critical workloads:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-single
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "1"   # ← 1 replica
  staleReplicaTimeout: "2880"
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

> Use `longhorn-single` for: MinIO, Loki, Strapi, dev environments. `longhorn` (2 replicas) — for WordPress, Prometheus, critical data.

---

### 9. 🪣 MinIO Helm — race condition when creating bucket via hooks

**Problem:** After `helm install` the bucket is not created, even though `buckets: [{name: velero, policy: none}]` is specified in `values.yaml`.

**Cause:** The Helm Job-hook for bucket creation runs before the MinIO pod has finished initialising. Race condition.

**Solution:** Remove `buckets:` from `values.yaml`. Create manually via `mc` after deployment:
```bash
# Access mc inside the MinIO pod
kubectl exec -n minio deploy/minio -- \
  mc alias set myminio http://localhost:9000 minioadmin DevOpsLab2026! --api s3v4

# Create buckets
kubectl exec -n minio deploy/minio -- mc mb myminio/velero
kubectl exec -n minio deploy/minio -- mc mb myminio/longhorn-backup
```

---

### 10. 🔄 Velero + Argo CD — OutOfSync due to VolumeSnapshotLocation

**Problem:** Velero Application in Argo CD constantly shows `OutOfSync`, even though config has not changed.

**Cause:** Velero with `snapshotsEnabled: true` (default) automatically creates a `VolumeSnapshotLocation` resource. Argo CD sees this resource as "extra" and considers the state different from Git.

**Solution:**
```yaml
# In values.yaml for Velero:
snapshotsEnabled: false   # disable VSL management

# Enable CSI via:
configuration:
  features: EnableCSI     # ← this is a separate feature flag, unrelated to snapshotsEnabled
```

> `snapshotsEnabled: false` + `features: EnableCSI` — the correct combination for MinIO-backed backups with CSI snapshot support.

---

### 11. 🔒 cert-manager — CA chain and Windows trust

**How to correctly set up an internal CA:**

```
selfSigned ClusterIssuer
    ↓  issues
Certificate (isCA: true, kind: Certificate)
    ↓  stored as
Secret (type: kubernetes.io/tls)
    ↓  used as source in
CA ClusterIssuer (spec.ca.secretName: ...)
    ↓  issues
Certificates for all services
```

**Important:** In the `Certificate` for the root CA, `isCA: true` is mandatory:
```yaml
spec:
  isCA: true
  usages:
    - cert sign
    - crl sign
```

**Trusting in Windows** (once, run as administrator):
```powershell
# Copy crt from cluster
kubectl get secret lab-root-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | `
  [System.Convert]::FromBase64String([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))) | `
  Set-Content -Path "lab-root-ca.crt" -Encoding Byte

# Or via scp, then import:
Import-Certificate -FilePath "lab-root-ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

---

### 12. 🚀 Argo CD — credentials for private GitHub repo

**Problem:** Argo CD cannot connect to the repository, authentication error.

**Rule:** Store credentials in a K8s Secret, NOT in the Application manifest:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-devops-lab
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository   # ← required label
stringData:
  type: git
  url: https://github.com/shevchenkod/devops-lab.git
  username: shevchenkod
  password: ghp_xxxx   # GitHub Personal Access Token
```

---

### 13. 🌿 Calico CNI — pod CIDR must match

**Problem:** After `kubectl apply -f calico.yaml` Calico pods are in CrashLoop, networking is broken.

**Cause:** The CIDR specified in `kubeadm init` does not match the Calico default.

**Rule:** Calico by default expects `192.168.0.0/16`. Use exactly this CIDR:
```bash
kubeadm init --pod-network-cidr=192.168.0.0/16
```

Or in `kubeadm-config.yaml`:
```yaml
networking:
  podSubnet: "192.168.0.0/16"
```

---

### 14. 🗂️ Strapi v4 in Kubernetes — complete list of gotchas (01.01.2026)

> Switched from v5 → **v4.26.1**. Strapi v5 is unstable: create-strapi-app is interactive, plugins are missing from npm, Node<20 is not supported.

#### Gotcha 1: `npm run develop` hangs → SIGINT
- **Cause:** interactive question `Install react? (Y/n)` — K8s redirects stdin to a pipe → SIGINT when no answer
- **Solution:** Use ONLY `npm run start` in K8s (production mode without interactivity)

#### Gotcha 2: `npm run start` fails — Admin panel not built
- **Cause:** `strapi start` requires a pre-built admin panel
- **Solution:** add a step to initContainer: `NODE_ENV=production npm run build`; only after building — the main container runs `npm run start`

#### Gotcha 3: react / react-dom are missing
- **Cause:** when scaffolding manually (without create-strapi-app), react is not added to package.json
- **Solution:** explicitly add to dependencies: `react@^18`, `react-dom@^18`, `react-router-dom@^5`, `styled-components@^5`

#### Gotcha 4: `public/uploads` does not exist at startup
- **Cause:** Strapi creates the directory only if the parent exists; when the PVC is mounted the structure is empty
- **Solution:** `mkdir -p /srv/app/public/uploads /srv/app/.tmp` at the very beginning of initContainer, **BEFORE** the early-exit check

#### Gotcha 5: `better-sqlite3` requires `python3` / `make` / `g++`
- **Cause:** native C++ module, requires build-tools during `npm install`
- **Solution:** `apk add --no-cache python3 make g++` in initContainer before `npm install`

#### Gotcha 6: `@strapi/plugin-i18n@^5.0.0` does not exist on npm
- **Cause:** Strapi v5 plugins are unpublished / different scope
- **Solution:** use v4: `@strapi/plugin-i18n@4.25.23`

#### Gotcha 7: Strapi v5 requires Node≥20
- **Cause:** `engines: { node: '>=20.x' }` in Strapi v5 package.json
- **Solution:** `node:18-alpine` + Strapi **v4.26.1** = working combination; v5 — only with node:20+

#### Gotcha 8: Strapi + WordPress on the same node (resource contention)
- **Cause:** both on `k8s-worker-02`; initContainer consumes 2 CPU + 2.5Gi during `npm install` + `npm run build` → MariaDB does not get resources → WordPress crashes
- **Solution:** use `nodeAffinity` to spread across nodes, or reduce `limits` of initContainer to 1CPU/1Gi

#### Gotcha 9: Multi-Attach error (RWO PVC)
- **Cause:** during RollingUpdate the new pod starts before the old one terminates → both try to mount the same RWO PVC
- **Solution:** `strategy: type: Recreate` in the Deployment

#### Gotcha 10: TLS timeout on `kubectl logs` (worker:10250)
- **Cause:** kubelet API on `k8s-worker-01:10250` is not accessible externally (firewall / network)
- **Solution:** retry later; use `kubectl describe pod` + events for diagnostics without directly accessing kubelet

---

### 15. 💿 Proxmox — VM disk resize (order matters)

**Problem:** After `qm resize` in Proxmox, space inside the VM has not increased.

**Cause:** Proxmox expands the disk at the hypervisor level, but the OS does not know about it until `growpart` and `resize2fs`.

**Correct sequence (Ubuntu with ext4, no LVM):**
```bash
# Inside the VM:
growpart /dev/sda 1       # expand partition
resize2fs /dev/sda1       # expand filesystem
df -h                     # verify
```

**For Ubuntu with LVM (standard cloud-image):**
```bash
growpart /dev/sda 3       # expand partition with LVM PV
pvresize /dev/sda3        # expand Physical Volume
lvresize -l +100%FREE /dev/ubuntu-vg/ubuntu-lv   # expand Logical Volume
resize2fs /dev/ubuntu-vg/ubuntu-lv               # expand filesystem
```

**Via Proxmox REST API (from Windows):**
```powershell
# Resize via API (node=pve01, vmid=111, disk=scsi0, size=+40G)
Invoke-WebRequest -Uri "https://10.44.81.101:8006/api2/json/nodes/pve01/qemu/111/resize" `
  -Method PUT `
  -Headers @{"Authorization" = "PVEAPIToken=terraform@pve!token=xxx"} `
  -Body "disk=scsi0&size=+40G" `
  -SkipCertificateCheck
```

---

### 16. ☸️ kubectl on Windows — quick cluster access

**Setup:**
```powershell
# For the current session only:
$env:KUBECONFIG = "H:\DEVOPS-LAB\kubeconfig-lab.yaml"

# Permanently (add to $PROFILE):
Add-Content $PROFILE '$env:KUBECONFIG = "H:\DEVOPS-LAB\kubeconfig-lab.yaml"'

# Verify:
kubectl get nodes -o wide
```

> `kubeconfig-lab.yaml` contains `insecure-skip-tls-verify: true` for the API server — this is normal for a lab environment with a self-signed certificate.

---

### 17. 🐳 Velero CLI — distroless image, no shell

**Problem:** `kubectl exec -it -n velero deploy/velero -- sh` → `OCI runtime exec failed: exec: "sh": executable file not found`.

**Cause:** Velero uses a distroless image — it has no shell (`sh`, `bash`), only the `/velero` binary.

**Solution:**
```bash
# Always use this (no -it, specify /velero explicitly):
VELERO_POD=$(kubectl get pod -n velero -l app.kubernetes.io/name=velero -o name | head -1)

kubectl exec -n velero $VELERO_POD -- /velero backup get
kubectl exec -n velero $VELERO_POD -- /velero restore create --from-backup my-backup
kubectl exec -n velero $VELERO_POD -- /velero schedule get
```

---

### 18. 📊 Longhorn HA — draining a node does not mean data loss

**Important understanding:** When `kubectl drain` is run, the node becomes `SchedulingDisabled`, but the Longhorn volume with replicas continues to work through a replica on another node.

**Verified:**
```bash
kubectl drain k8s-worker-01 --ignore-daemonsets --delete-emptydir-data
# Pod moves to worker-02
# Longhorn mounts the volume from the replica on worker-02
# Data is intact ✅

kubectl uncordon k8s-worker-01
# Node returns to the rotation
```

> Only works if the volume has **2+ replicas** (StorageClass `longhorn`, not `longhorn-single`).

---

### 19. 🔑 Version compatibility — table

| Component | Version in lab | Compatibility / notes |
|-----------|--------------|----------------------|
| Kubernetes | v1.30.14 | kubeadm, Ubuntu 24.04 |
| containerd | 1.7.28 | `SystemdCgroup = true` required |
| Calico | v3.27.3 | pod CIDR 192.168.0.0/16 |
| Helm | v3.20.0 | installed on master |
| Longhorn | Helm latest | prereqs: open-iscsi + iscsi_tcp on ALL nodes |
| external-snapshotter | **v8.2.0** | CRDs before controller; compatible with K8s 1.30 |
| cert-manager | **v1.19.4** | CRDs separately or `--set crds.enabled=true` |
| Velero | **v1.17.1** | Helm chart 11.4.0 |
| velero-plugin-for-aws | **v1.13.0** | `checksumAlgorithm: ""` for MinIO |
| MinIO chart | 5.4.0 | do not use bucket hooks (race condition) |
| Argo CD | v2.14 | `server.insecure: true` + TLS on ingress |
| kube-prometheus-stack | Helm | PVC on longhorn (2 replicas) |
| Loki | **6.29.0** chart | singleBinary, PVC longhorn-single |
| Promtail | **6.16.6** chart | DaemonSet, tolerations for master |
| WordPress | Bitnami chart 29.1.2 | `bitnamilegacy` debian images |
| Strapi | **v4.26.1** (node:18-alpine) | initContainer bootstrap, `NODE_ENV=production`, `npm run start` |

---

### 20. 💡 General rules (derived from practice)

1. **Always check `kubectl events`** before restarting pods — the cause is there.
2. **PVC in `Pending` state** → check `kubectl describe pvc` → cause is in Events.
3. **Longhorn volume `detached`** after restore → the snapshot was `type:snap`, data is lost.
4. **ArgoCD OutOfSync** — not always an error. Check `ignoreDifferences` before panicking.
5. **MinIO + Velero** — always `checksumAlgorithm: ""`, otherwise it will not work.
6. **CSI backup** — always check BackupTarget AVAILABLE before running.
7. **Worker disks** — expand proactively, not when space runs out. Threshold: 70% free disk.
8. **StorageClass** — for critical data use 2 replicas (`longhorn`), for dev 1 replica (`longhorn-single`).
9. **ingress-nginx** — do not use `configuration-snippet`, it is disabled by default.
10. **Velero restore** — before restore, make sure the namespace is deleted, otherwise resource conflicts.

---

### 21. 🗂️ Windows SCP — trailing slash creates double nesting site/site/

**Problem:** After `scp -r site/ user@host:/path/site/` — NGINX shows `403 Forbidden`, folder `/path/site/site/` instead of `/path/site/`.

**Cause:** Windows OpenSSH with `scp -r <src>/` copies the directory **inside** the existing target.
If `/path/site/` already exists, the content ends up in `/path/site/site/` — double nesting.

**Solution:**
```powershell
# WRONG (trailing slash on source):
scp -r site/ ubuntu@host:/tmp/wiki-build/site/

# CORRECT (no trailing slash — SCP will create site/ inside wiki-build/):
scp -r site ubuntu@host:/tmp/wiki-build/
```

If the double nesting has already been created — fix it on the server:
```bash
cd /tmp/wiki-build
mv site/site site_correct && rm -rf site && mv site_correct site
```

---

### 22. 📊 MinIO Console — empty Usage/Traffic/Resources charts

**Problem:** MinIO Console → Metrics → tabs Usage, Traffic, Resources show empty charts with dashed borders.

**Cause:** `MINIO_PROMETHEUS_JOB_ID` does not match the actual `job` label in Prometheus.
MinIO Console requests metrics with `{job="<JOB_ID>"}` — if the label is different, there is no data.

**The Prometheus job label** is set from the ServiceMonitor `metadata.name`:
```yaml
# ServiceMonitor metadata.name: minio  →  job = "minio"
```

**Solution:**
```yaml
# cluster/argocd/app-minio.yaml
environment:
  MINIO_PROMETHEUS_JOB_ID: "minio"   # must exactly match the ServiceMonitor name
```

**Verification:**
```powershell
# Check the actual job label in Prometheus
(Invoke-RestMethod "http://localhost:9090/api/v1/targets").data.activeTargets |
  Where-Object {$_.labels.job -like "*minio*"} |
  Select-Object @{N="job";E={$_.labels.job}}, health
```

---

### 23. 📋 MinIO Audit Webhook — incompatible format with Loki Push API

**Problem:** MinIO Console → Logs shows errors:
`unable to send audit/log entry(s) err 'Loki returned 422 Unprocessable Entity'`

**Cause:** MinIO sends audit events as a raw JSON object `{...}`.
Loki Push API (`/loki/api/v1/push`) expects a strict format:
```json
{"streams": [{"stream": {"job": "minio"}, "values": [["<unix_nano>", "<log_line>"]]}]}
```
These formats are incompatible without an intermediate adapter.

**Solution for the lab:** Do not use `MINIO_AUDIT_WEBHOOK_*` directly with Loki.
Instead — Promtail DaemonSet automatically collects MinIO pod logs and sends them to Loki:
```logql
# In Grafana → Explore → Loki:
{namespace="minio"}
```

**If a full audit pipeline is needed:** use Vector or Fluentbit as an adapter between MinIO webhook and Loki.

---

### 24. 🚀 Argo CD App-of-Apps — why a separate kubectl apply per service is an anti-pattern

**Problem:** When adding a new service, you have to manually run `kubectl apply -f cluster/argocd/app-new.yaml`. As the number of applications grows (10+), this is inconvenient, easy to forget, and there is no single point of control for all Application objects.

**Cause:** Without App-of-Apps, Argo CD Applications live outside of git — they are applied manually, and Argo CD itself does not watch them.

**Solution — App-of-Apps pattern:**

```
app-of-apps (root Application)
  └── watches: cluster/apps/
        ├── app-wordpress.yaml   → Application: wordpress
        ├── app-minio.yaml       → Application: minio
        ├── app-wiki.yaml        → Application: wiki
        └── app-*.yaml           → ...
```

```yaml
# cluster/argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/shevchenkod/devops-lab.git
    targetRevision: HEAD
    path: cluster/apps      # directory with app-*.yaml manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true       # delete Application if app-*.yaml is removed from git
      selfHeal: true
```

**Workflow after adoption:**
```bash
# Add a new service:
# 1. Create cluster/apps/app-newservice.yaml
# 2. git add + commit + push
# 3. Argo CD will auto-discover and deploy
# kubectl apply is no longer needed!
```

**Adopting existing apps:** Argo CD automatically "adopts" existing Application objects with the same name/namespace — no recreation happens, no downtime.

> ⚠️ Apply the root app once manually: `kubectl apply -f cluster/argocd/app-of-apps.yaml`. After that, all subsequent Application manifests are picked up automatically via git push.

---

### 25. ☸️ Kubernetes cluster upgrade (kubeadm) — v1.30 → v1.31

**Rule:** Kubernetes can only be upgraded by **one minor version** at a time (v1.30 → v1.31, not v1.30 → v1.32). Skipping versions is not allowed — kubeadm enforces this.

**Procedure (for each node):**

```bash
# 0. Add apt repository for the new minor version (on each node)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-v1.31-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-v1.31-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes-v1.31.list

# 1. Control-plane: upgrade apply (master only)
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.31.14-1.1
sudo apt-mark hold kubeadm
sudo kubeadm upgrade apply v1.31.14 --yes

# 2. Drain node (workload moves to other nodes, DaemonSet stays)
kubectl drain k8s-master-01 --ignore-daemonsets --delete-emptydir-data

# 3. Upgrade kubelet + kubectl, restart
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.31.14-1.1 kubectl=1.31.14-1.1
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# 4. Uncordon — node accepts pods again
kubectl uncordon k8s-master-01

# ---- For worker nodes (repeat for each) ----
kubectl drain k8s-worker-01 --ignore-daemonsets --delete-emptydir-data
# On worker: add repo + install packages + kubeadm upgrade node + restart kubelet
sudo kubeadm upgrade node
kubectl uncordon k8s-worker-01
```

**Key notes:**
- Each minor version has a **separate apt repository** — must be added manually
- Packages are held — before upgrade: `apt-mark unhold`, after: `apt-mark hold`
- `kubeadm upgrade apply` — **control-plane only** (master)
- `kubeadm upgrade node` — **worker nodes only**
- After drain, node shows `Ready,SchedulingDisabled` — workload is evacuated to other nodes
- Node version in `kubectl get nodes` updates after `systemctl restart kubelet`

> ✅ Cluster upgraded: v1.30.14 → v1.31.14 (all 3 nodes Ready) — 01.01.2026

---

### 26. 📊 SLO/SLI: Service Level Objectives in Kubernetes

**Concepts:**
- **SLI** (Service Level Indicator) — measurable quality metric: fraction of successful requests, P99 latency, uptime
- **SLO** (Service Level Objective) — target value for an SLI: "99.5% of requests without 5xx over 30 days"
- **Error Budget** = (1 - SLO) × period = allowable number of errors

**Our SLO for WordPress:**
- Availability SLO: **99.5%** (error budget = 216 min/month)
- Latency SLO: **95%** of requests faster than 500ms

**Stack:**

```bash
# 1. Enable NGINX Ingress metrics (if not enabled)
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --reuse-values \
  --set controller.metrics.enabled=true

# 2. Create ServiceMonitor (Prometheus Operator)
# cluster/monitoring/servicemonitor-ingress-nginx.yaml

# 3. Create PrometheusRule with recording rules + alerts
# cluster/monitoring/prometheusrule-wordpress-slo.yaml

# 4. Verify target in Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
curl -sG http://localhost:9090/api/v1/targets | grep ingress

# 5. Verify recording rules
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=job:wordpress_request_error_rate:ratio_rate5m'
```

**Multi-window Multi-burn-rate alerts (Google SRE Book, ch.5):**

| Burn Rate | Window | Interpretation | Severity |
|-----------|--------|----------------|---------|
| 14x | 1h + 5m | Error budget will be consumed in **2 hours** | Critical |
| 6x | 6h + 30m | Error budget will be consumed in **5 days** | Warning |

**Key labels for NGINX Ingress metrics:**
- `ingress` = Ingress resource name (`wordpress`)
- `exported_namespace` = Ingress namespace (`wordpress`) — NOT `namespace`!
- `namespace` = controller namespace (`ingress-nginx`)

**Correct PromQL for SLO:**
```promql
# Error rate (fraction of 5xx)
sum(rate(nginx_ingress_controller_requests{
  ingress="wordpress", exported_namespace="wordpress", status=~"5.."
}[5m]))
/
sum(rate(nginx_ingress_controller_requests{
  ingress="wordpress", exported_namespace="wordpress"
}[5m]))
```

> ✅ SLO for WordPress configured: error_rate=0%, latency_ok=100%, Prometheus target up — 01.01.2026

---

### 27. 🔭 Lens Cluster Overview — conflict between two Prometheus instances

**Symptom:** Left panel (Memory Workers) in Cluster Overview shows data, right panel (Pod status / CPU) — connection error.

**Cause:** Lens Desktop independently deploys its own Prometheus in the `lens-metrics` namespace when `Settings → Lens Metrics` is enabled. If the cluster already has `kube-prometheus-stack` — a conflict arises: two Prometheus instances simultaneously, Lens does not know which one to use for each panel.

**Diagnostics:**
```bash
kubectl get all -n lens-metrics
# → found: prometheus-0, kube-state-metrics, node-exporter, etc.
```

**Solution:**
```bash
kubectl delete namespace lens-metrics
```
After deletion, only `kube-prometheus-stack` remains → Cluster Overview: both panels work ✅

**Rule:** If you use an external Prometheus (`kube-prometheus-stack`) — **do not enable** `Settings → Lens Metrics` in Lens Desktop. Both Prometheus instances will conflict.

> ✅ Lens Cluster Overview fixed: deleted namespace `lens-metrics` — 01.01.2026

---

### 28. ⚖️ Rolling Update + HPA + PDB — Day-2 Operations in Kubernetes

#### metrics-server — required for HPA

HPA (HorizontalPodAutoscaler) requires the Metrics API. In a kubeadm cluster, metrics-server must be installed manually and the `--kubelet-insecure-tls` flag must be added (kubelet certificate is not signed by a public CA):
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
# Verify:
kubectl top nodes
```

#### Rolling Update strategy

In Bitnami Helm chart (and most others), parameters via `valuesObject` in Argo CD Application:
```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0       # see lesson #29 about RWO PVC!
    maxUnavailable: 1
```

**Verify:**
```bash
kubectl rollout status deployment/wordpress -n wordpress
kubectl rollout history deployment/wordpress -n wordpress
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>
```

#### HPA — HorizontalPodAutoscaler

In Bitnami WordPress chart:
```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPU: 60      # scale up when CPU > 60% of request
```

After applying:
```bash
kubectl get hpa -n wordpress
# NAME        REFERENCE              TARGETS                    MINPODS  MAXPODS  REPLICAS
# wordpress   Deployment/wordpress   memory:10%/50%,cpu:2%/60%  1        3        1
```

#### PDB — PodDisruptionBudget

Protects pods during `kubectl drain`, rolling update, node maintenance:
```yaml
pdb:
  create: true
  minAvailable: 1   # at least 1 pod must remain available
```

```bash
kubectl get pdb -n wordpress
# NAME       MIN AVAILABLE  MAX UNAVAILABLE  ALLOWED DISRUPTIONS
# wordpress  1              N/A              0
# (0 = cannot delete pods while replicas=1)
```

> ✅ Rolling Update + HPA + PDB for WordPress configured: metrics-server v0.8.1, HPA (cpu/mem), PDB minAvailable=1 — 01.01.2026

---

### 29. 📦 RWO PVC + Rolling Update = Multi-Attach error

**Problem:** Rolling Update with `maxSurge: 1` hangs with error:
```
Warning  FailedAttachVolume  attachdetach-controller
Multi-Attach error for volume "pvc-xxx"
Volume is already used by pod(s) wordpress-old-pod
```

**Cause:** A `ReadWriteOnce` (RWO) PVC can only be mounted by **one pod at a time**.
With `maxSurge: 1` — the new pod starts **before** the old one is deleted. Regardless of whether both pods are on the same node — the new one will not get access to the volume.

| Parameter | Behaviour | RWO compatibility |
|-----------|-----------|-------------------|
| `maxSurge: 1, maxUnavailable: 0` | New pod first, then delete old | ❌ Multi-Attach error |
| `maxSurge: 0, maxUnavailable: 1` | Kill old first, then create new | ✅ Works (brief ~30s gap) |
| `strategy: Recreate` | Delete all → create new | ✅ Works (full downtime) |

**Solutions for zero-downtime:**
- Use `ReadWriteMany` (RWX) storage — Longhorn supports it via NFS subpath
- Move state to external storage (S3, DB) — stateless deployment
- Use StatefulSet with headless service

**Rule:** `maxSurge > 0` + RWO PVC = potential problem. Always check `accessModes` of the PVC before a Rolling Update.

> ✅ Documented: WordPress + Longhorn RWO + maxSurge:0 — 01.01.2026

---

### 30. 🗋️ Node Add/Remove — full cycle + terraform destroy via Proxmox API

#### Node addition cycle

1. **Terraform** — add VM to `nodes.tf`
2. **Ansible** — run playbook with `--limit 'k3s_master,<new_ip>'`
3. **kubectl** — verify with `kubectl get nodes`

```bash
# Step 1: Terraform creates the VM
cd terraform/proxmox-lab
terraform apply -target=proxmox_virtual_environment_vm.k8s_worker_03

# Step 2: Ansible joins the node to the cluster
# Update inventory.ini on master manually
ssh ubuntu@10.44.81.110 'echo "10.44.81.113" >> /etc/ansible/inventory.ini'

ansible-playbook -i inventory.ini kubeadm-cluster.yml --limit 'k3s_master,10.44.81.113'

# Step 3: Verify
kubectl get nodes
# NAME              STATUS   ROLES           AGE   VERSION
# k8s-master-01     Ready    control-plane   ...   v1.31.14
# k8s-worker-01     Ready    <none>          ...   v1.31.14
# k8s-worker-02     Ready    <none>          ...   v1.31.14
# k8s-worker-03     Ready    <none>          ...   v1.30.14  ← new
```

#### Node removal cycle

```bash
# 1. Cordon the node
kubectl cordon k8s-worker-03

# 2. Evict all pods
kubectl drain k8s-worker-03 --ignore-daemonsets --delete-emptydir-data

# 3. Remove from cluster
kubectl delete node k8s-worker-03

# 4. Terraform destroy the VM
terraform destroy -target=proxmox_virtual_environment_vm.k8s_worker_03
```

#### Problem: `terraform destroy` hangs

`terraform destroy` can hang if the VM in Proxmox is in Running state. Solution — Proxmox API:

```bash
# VM state (VMID=113, node pve02)
ssh ubuntu@10.44.81.110 'curl -s -k \
  -H "Authorization: PVEAPIToken=terraform@pve!terraform-pve02=TOKEN" \
  https://10.44.81.102:8006/api2/json/nodes/pve02/qemu/113/status/current \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[\"data\"][\"status\"])"'

# Stop VM
ssh ubuntu@10.44.81.110 'curl -s -k -X POST \
  -H "Authorization: PVEAPIToken=terraform@pve!terraform-pve02=TOKEN" \
  https://10.44.81.102:8006/api2/json/nodes/pve02/qemu/113/status/stop'

# Delete VM (destroy)
ssh ubuntu@10.44.81.110 'curl -s -k -X DELETE \
  -H "Authorization: PVEAPIToken=terraform@pve!terraform-pve02=TOKEN" \
  https://10.44.81.102:8006/api2/json/nodes/pve02/qemu/113'

# Clean terraform state
terraform state rm proxmox_virtual_environment_vm.k8s_worker_03
```

> ⚠️ **Lesson:** `!` in the Proxmox API token breaks PowerShell (history expansion). Run `curl` via SSH on master — bash does not escape `!`.
> ⚠️ **Lesson:** a new node may join with a different Kubernetes version (v1.30 vs v1.31) — this is normal for short-term tests.

> ✅ Block I: node add/remove full cycle (Terraform + Ansible + kubectl + Proxmox API) — 01.01.2026

---

### 31. 🌍 AZ/Zone Topology — zone labels, Longhorn cross-zone, Zone A failure test

#### Zone Labels — assign zones to nodes

```bash
# pve01 = Zone A
kubectl label node k8s-master-01 topology.kubernetes.io/zone=zone-a topology.kubernetes.io/region=proxmox-lab
kubectl label node k8s-worker-01 topology.kubernetes.io/zone=zone-a topology.kubernetes.io/region=proxmox-lab

# pve02 = Zone B
kubectl label node k8s-worker-02 topology.kubernetes.io/zone=zone-b topology.kubernetes.io/region=proxmox-lab

# Verify
kubectl get nodes --label-columns=topology.kubernetes.io/zone,topology.kubernetes.io/region
# NAME            ZONE    REGION
# k8s-master-01   zone-a  proxmox-lab
# k8s-worker-01   zone-a  proxmox-lab
# k8s-worker-02   zone-b  proxmox-lab
```

#### Longhorn Cross-Zone Replication

Longhorn automatically places replicas on different nodes when replication ≥ 2. The standard StorageClass `longhorn` (replicaCount=2) automatically gives cross-zone replicas: **worker-01 (zone-a) + worker-02 (zone-b)**.

```bash
# Check Longhorn volumes
kubectl get volume -n longhorn-system -o wide
# For PVC wordpress-data: replicas on worker-01 (zone-a) + worker-02 (zone-b)
```

#### "Zone A fails" test

```bash
# Simulate Zone A failure (cordon master-01 + worker-01)
kubectl cordon k8s-master-01 k8s-worker-01

# Check pod distribution (Running pods should be on worker-02)
kubectl get pods -A -o wide | Select-String "Running" | Select-String "worker-02"

# Result — ALL services survived on zone-b:
# wordpress, grafana, loki, minio, strapi, wiki, registry, velero, ingress-nginx, metrics-server

# Restore zone-a (uncordon)
kubectl uncordon k8s-master-01 k8s-worker-01
```

| Service | Zone A failure result |
|---------|----------------------|
| WordPress | ✅ worker-02 |
| Grafana | ✅ worker-02 |
| Loki | ✅ worker-02 |
| MinIO | ✅ worker-02 |
| Strapi | ✅ worker-02 |
| Wiki | ✅ worker-02 |
| Registry | ✅ worker-02 |
| Velero | ✅ worker-02 |
| ingress-nginx | ✅ worker-02 |
| metrics-server | ✅ worker-02 |

> ⚠️ The test used `cordon` (not `drain`) — pods stayed alive, new ones were not scheduled on zone-a. In a real failure, pods would restart automatically via K8s scheduling.
> ⚠️ **Lesson:** For full Zone HA — each Deployment/StatefulSet should have `replicas ≥ 2` with `topologySpreadConstraints` or `podAntiAffinity` by `zone`. In our lab, single-replica services survived thanks to Longhorn cross-zone replicas (storage did not die, pods were rescheduled).

> ✅ Block J: zone labels + cross-zone Longhorn + Zone A failure test — 01.01.2026

---

## 🖥️ Infrastructure

| Icon | Tool | Description |
|:----:|------|-------------|
| 🖥️ | **Proxmox VE** | Open-source hypervisor. Manages virtual machines (KVM) and containers (LXC) through a convenient web interface. The foundation of the homelab environment. |
| ⚖️ | **MetalLB** | Load Balancer for bare-metal Kubernetes clusters. Assigns real IP addresses to `LoadBalancer` type services without a cloud provider. L2 mode (ARP) — the simplest way to get started. |
| 🗄️ | **Longhorn** | Distributed block storage for Kubernetes. Manages persistent volumes, replicates data between nodes. An alternative to expensive cloud storage. |
| 💾 | **Velero** | Backup and restore of Kubernetes resources. Saves cluster state, namespaces, PVCs. Indispensable for migration or disaster recovery. |
| 🔒 | **Cert-Manager** | Automatic TLS/SSL certificate management in Kubernetes. Integrates with Let's Encrypt, issues and renews certificates without manual intervention. |
| 🌐 | **NGINX Ingress** | Ingress Controller for Kubernetes. Routes external HTTP/HTTPS traffic to the correct services inside the cluster based on rules (host, path). |

---

## 🐳 Containerisation

| Icon | Tool | Description |
|:----:|------|-------------|
| 🐳 | **Docker** | De facto standard for containerisation. Packages an application with all its dependencies into an isolated container. Works the same on any server. |
| ⛵ | **Helm** | Package manager for Kubernetes. Allows installing and managing complex applications in the cluster via ready-made Charts (manifest templates). |
| 🔭 | **Lens** | Desktop IDE for Kubernetes. Visual interface for working with the cluster: browsing pods, logs, metrics, executing commands — without typing kubectl manually. |

---

## 🔄 CI/CD & GitOps

| Icon | Tool | Description |
|:----:|------|-------------|
| 🐙 | **GitHub** | Git repository hosting + GitHub Actions for CI/CD. The most popular platform for storing code and automating builds/deployments. |
| 🦊 | **GitLab** | Full DevOps platform: Git, CI/CD, Container Registry, Wiki, Issue Tracker — all in one. Can be deployed self-hosted. |
| ⚙️ | **Jenkins** | Veteran of automation. Flexible CI/CD server with a huge number of plugins. Suitable for complex pipelines and legacy infrastructure. |
| 🚀 | **Argo CD** | GitOps tool for Kubernetes. Watches a Git repository and automatically synchronises cluster state with the code. "What is in Git — is in the cluster." **App-of-Apps pattern**: one root Application manages all children — adding a service = git push, no kubectl. |
| 🤖 | **Ansible** | Configuration management and automation tool. Describes the desired state of servers in YAML playbooks and brings servers to that state without agents (SSH only). |

---

## ��️ IaC

| Icon | Tool | Description |
|:----:|------|-------------|
| 🏗️ | **Terraform** | Infrastructure as Code from HashiCorp. Describes cloud and local resources (VMs, networks, DNS) in `.tf` files and manages their lifecycle via plan/apply. |

---

## 📊 Monitoring & Logging

| Icon | Tool | Description |
|:----:|------|-------------|
| 🔥 | **Prometheus** | Monitoring and metrics storage system. Collects numeric data (CPU, RAM, RPS) from servers and services using the pull model, stores in a time-series DB. |
| 📈 | **Grafana** | Data visualisation platform. Builds beautiful dashboards from Prometheus metrics, Loki logs, and other sources. The primary tool for observability. |
| 📋 | **Loki + Promtail** | Log aggregation stack from Grafana. Loki stores logs (indexes only labels, not content). Promtail is the agent that collects logs and sends them to Loki. |
| 🔔 | **Alertmanager** | Alert manager for Prometheus. Receives alerts, groups them, applies routing, and sends notifications to Telegram, Slack, Email, PagerDuty. |
| 🟢 | **Uptime Kuma** | Lightweight self-hosted uptime monitor. Checks HTTP, TCP, DNS, Ping — and notifies on failure. Beautiful UI, simple setup. |

---

## 🔒 Security

| Icon | Tool | Description |
|:----:|------|-------------|
| 🔐 | **HashiCorp Vault** | Centralised secrets store (passwords, tokens, certificates, API keys). Integrates with Kubernetes for automatic secret injection into pods. |
| 🛡️ | **Trivy** | Security scanner for containers, configuration files, and IaC. Finds CVE vulnerabilities in Docker images before deployment. Easy to embed in CI/CD. |
| 🔍 | **SonarQube** | Static analysis of code quality and security. Finds bugs, vulnerabilities, code smells. Integrates into the pipeline for mandatory checks before deployment. |

---

## 📦 Services & Applications

| Icon | Tool | Description |
|:----:|------|-------------|
| 📝 | **WordPress** | The most popular CMS. Deployed in Docker/Kubernetes as a demo application for practising deployment, storage, ingress, and SSL. |
| 📞 | **Asterisk** | Open-source PBX (IP telephony). Manages calls, IVR, conferences. Deployed as a service in Docker or on a VM for hands-on telephony practice. |

---

## 🧰 Additional (don't miss!)

| Icon | Tool | Description |
|:----:|------|-------------|
| 🐧 | **Linux / Bash** | The foundation of everything. Without confident command-line skills, process management, networking, and permissions — everything else will be harder. |
| 🌿 | **Git** | Version control system. The basis of all CI/CD. Branches, merge, rebase, stash, cherry-pick — the required minimum for a DevOps engineer. |
| 🌐 | **Networking** | DNS, TCP/IP, NAT, VLAN, firewall (iptables/nftables). Without understanding networking, you cannot debug Kubernetes, VoIP, or any infrastructure. |
| 📦 | **Harbor** | Self-hosted Container Registry. Stores Docker images inside the infrastructure with access control, vulnerability scanning, and version management. |
| 🎯 | **k9s** | Terminal UI for Kubernetes. Faster than Lens for terminal work — cluster navigation, logs, exec into pods, all from the keyboard. |

---

## ✅ Progress Status

| Tool | Category | Status | Notes |
|------|----------|--------|-------|
| 🐧 Linux / Bash | Basics | ⏳ | |
| 🌿 Git | Basics | ⏳ | |
| 🐳 Docker | Containers | ⏳ | |
| ⛵ Helm | Kubernetes | ✅ | v3.20.0, installed on master 01.01.2026 |
| ☸️ Kubernetes | Orchestration | ✅ | v1.31.14, kubeadm, 3 nodes Ready, upgrade v1.30→v1.31 ✅, 01.01.2026 |
| 🔭 Lens | Kubernetes | ✅ | Desktop + Mobile connected, 01.01.2026; Cluster Overview fix: deleted `lens-metrics` (Prometheus conflict) → both panels ✅, 01.01.2026 |
| 🎯 k9s | Kubernetes | ⏳ | |
| 🖥️ Proxmox | Infrastructure | ✅ | pve01+pve02, API tokens, 01.01.2026 |
| ⚖️ MetalLB | Infrastructure | ✅ | L2, pool 10.44.81.200-250, 01.01.2026 |
| 🗄️ Longhorn | Infrastructure | ✅ | Helm, 23 pods Running, SC default, PVC ✅, HA drain ✅, UI https://longhorn.lab.local ✅, BackupTarget → MinIO AVAILABLE ✅, 01.01.2026 |
| 🌐 NGINX Ingress | Infrastructure | ✅ | EXTERNAL-IP 10.44.81.200, 01.01.2026 |
| 🔒 Cert-Manager | Infrastructure | ✅ | v1.19.4, lab-ca-issuer, TLS works, 01.01.2026 |
| 🗄️ MinIO | Infrastructure | ✅ | v5.4.0 chart, standalone, 10Gi longhorn-single, Console https://minio.lab.local, minioadmin/DevOpsLab2026!, buckets: velero + longhorn-backup, ServiceMonitor (job=minio), Prometheus metrics ✅, 01.01.2026 |
| 💾 Velero | Infrastructure | ✅ | v1.17.1, Helm 11.4.0, BSL Available, schedules x2, --features=EnableCSI, CSI VolumeSnapshot support, 01.01.2026 |
| 📸 external-snapshotter | Infrastructure | ✅ | v8.2.0, 3 CRDs, snapshot-controller 2 pods Running, 01.01.2026 |
| 📸 VolumeSnapshotClass | Infrastructure | ✅ | longhorn-snapshot-class, driver.longhorn.io, type:bak (DR-safe), 01.01.2026 |
| 🐙 GitHub | CI/CD | ✅ | `shevchenkod/devops-lab`, SSH key, 01.01.2026 |
| 🦊 GitLab CI/CD | CI/CD | ⏳ | plan: GitLab.com → self-hosted CE |
| ⚙️ Jenkins | CI/CD | ⏳ | |
| 🚀 Argo CD | GitOps | ✅ | Helm v3, argocd.lab.local TLS, GitHub repo connected, 01.01.2026 |
| 🤖 Ansible | Automation | ✅ | core 2.16.3, kubeadm bootstrap, 01.01.2026 |
| 🏗️ Terraform | IaC | ✅ | v1.14.6, bpg/proxmox v0.97.1, 01.01.2026 |
| 🔥 Prometheus | Monitoring | ✅ | kube-prometheus-stack, Argo CD, PVC Longhorn 10Gi, 01.01.2026 |
| �� Grafana | Visualisation | ✅ | https://grafana.lab.local, TLS, admin/DevOpsLab2026!, 01.01.2026 |
| 📋 Loki + Promtail | Logging | ✅ | Loki 6.29.0 singleBinary, Promtail 6.16.6 DaemonSet 3/3, namespace loki, Grafana datasource, 01.01.2026 |
| 🔔 Alertmanager | Alerting | ✅ | Telegram notifications, AlertmanagerConfig CRD + PrometheusRules (6 alerts), 01.01.2026 |
| 📊 SLO/SLI | Observability | ✅ | WordPress: NGINX Ingress metrics, ServiceMonitor, recording rules (6), burn-rate alerts (4), error_rate=0%, latency_ok=100%, 01.01.2026 |
| ⚖️ Rolling+HPA+PDB | Operations | ✅ | WordPress: metrics-server v0.8.1, HPA (cpu/60%,mem/50%), PDB minAvailable=1, Rolling maxSurge=0, 01.01.2026 |
| 🗋️ Node Add/Remove | Operations | ✅ | Terraform+Ansible join+kubectl cordon/drain/delete+Proxmox API destroy, worker-03 full cycle, 01.01.2026 |
| 🌍 AZ/Zone Topology | Operations | ✅ | zone-a (pve01: master+worker-01), zone-b (pve02: worker-02), Longhorn cross-zone, Zone A failure test ✅, 01.01.2026 |
| �� Uptime Kuma | Monitoring | ✅ | v2.1.3, `kuma.lab.local` TLS, PVC 1Gi Longhorn, Argo CD, 01.01.2026 |
| 🔐 Vault | Security | ⏳ | |
| 🛡️ Trivy | Security | ⏳ | |
| 🔍 SonarQube | Code quality | ⏳ | |
| 📦 Harbor | Registry | ⏳ | |
| 📝 WordPress | Services | ✅ | 6.8.2 Bitnami, MariaDB 11.8.3, `wordpress.lab.local` TLS, Argo CD, admin/DevOpsLab2026!, 01.01.2026 |
| 🗂️ Strapi | Services | ✅ | **v4.26.1**, node:18-alpine, `strapi.lab.local` TLS, Argo CD, `1/1 Running` ✅, 01.01.2026 |
| 📞 Asterisk | Telephony | ⏳ | |

> **Legend:** ✅ Completed | 🔄 In progress | ⏳ Not started | ❌ Problem

---
