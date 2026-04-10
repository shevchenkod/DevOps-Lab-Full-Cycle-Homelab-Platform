# J. AZ / Zone Topology ✅

> Status: **Completed 01.01.2026**

Simulating Availability Zones on two physical Proxmox hosts.

---

## Architecture

| Node | Host | Zone | Region |
|------|------|------|--------|
| k8s-master-01 | pve01 (10.44.81.101) | **zone-a** | proxmox-lab |
| k8s-worker-01 | pve01 (10.44.81.101) | **zone-a** | proxmox-lab |
| k8s-worker-02 | pve02 (10.44.81.102) | **zone-b** | proxmox-lab |

---

## Zone Labels

Standard Kubernetes topology labels:

```bash
# pve01 = Zone A
kubectl label node k8s-master-01 \
  topology.kubernetes.io/zone=zone-a \
  topology.kubernetes.io/region=proxmox-lab

kubectl label node k8s-worker-01 \
  topology.kubernetes.io/zone=zone-a \
  topology.kubernetes.io/region=proxmox-lab

# pve02 = Zone B
kubectl label node k8s-worker-02 \
  topology.kubernetes.io/zone=zone-b \
  topology.kubernetes.io/region=proxmox-lab

# Verify
kubectl get nodes --label-columns=topology.kubernetes.io/zone,topology.kubernetes.io/region
```

Documentation: `cluster/platform/node-labels.yaml`

---

## Longhorn Cross-Zone Replication

StorageClass `longhorn` (replicaCount=2) automatically places replicas on different nodes.
With zone labels — replicas are distributed **across zones**:

- **Replica 1** → k8s-worker-01 (zone-a)
- **Replica 2** → k8s-worker-02 (zone-b)

```bash
# Check replica placement
kubectl -n longhorn-system get volume
kubectl -n longhorn-system get replicas
```

> Longhorn UI → Volumes → `<volume-name>` → shows which nodes hold replicas.

---

## Test: Zone A Failure

**Simulating Zone A failure:**

```bash
# Exclude all Zone A nodes from scheduling
kubectl cordon k8s-master-01 k8s-worker-01

# Check where pods are running
kubectl get pods -A -o wide | grep "worker-02"
```

**Test results (01.01.2026):**

| Service | Namespace | Result |
|---------|-----------|--------|
| WordPress | wordpress | ✅ worker-02 |
| Grafana | monitoring | ✅ worker-02 |
| Loki | loki | ✅ worker-02 |
| MinIO | minio | ✅ worker-02 |
| Strapi | strapi | ✅ worker-02 |
| Wiki | wiki | ✅ worker-02 |
| Registry | registry | ✅ worker-02 |
| Velero | velero | ✅ worker-02 |
| ingress-nginx | ingress-nginx | ✅ worker-02 |
| metrics-server | kube-system | ✅ worker-02 |

**Restoring Zone A:**

```bash
kubectl uncordon k8s-master-01 k8s-worker-01
kubectl get nodes  # all 3 Ready
```

---

## Lessons

!!! warning "Test used `cordon`, not `drain`"
    `cordon` — prevents new pods from scheduling, but existing pods remain.
    Pods **did not restart** — they were already on zone-b or moved there earlier.
    In a real node failure scenario, pods **restart automatically** via K8s scheduler.

!!! tip "For full Zone HA you need replicas ≥ 2"
    A single-replica Deployment survives **only** through Longhorn cross-zone storage.
    For true HA — use `topologySpreadConstraints` or `podAntiAffinity` by zone + `replicas ≥ 2`.

---

## 📖 Lesson 31

Documented in detail in [Lessons Learned](../lessons/index.md#31-az-zone-topology-zone-labels-longhorn-cross-zone-zone-a-failure-test).

---

## 🔗 Related Files

- `cluster/platform/node-labels.yaml` — zone label manifest
- `docs/runbooks/disaster-recovery.md` → scenario "node failed"

