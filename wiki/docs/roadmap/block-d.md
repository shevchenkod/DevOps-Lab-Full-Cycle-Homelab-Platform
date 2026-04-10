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
