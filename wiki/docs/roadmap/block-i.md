# I. Operations / Day-2 ✅

> Status: **Completed 01.01.2026**

Day-2 operations: scaling, node maintenance, rolling updates, HPA, PDB.

---

## ✅ Completed

### metrics-server v0.8.1

Required for HPA/VPA and `kubectl top`. In a kubeadm cluster, installed manually with `--kubelet-insecure-tls`.
Managed via Argo CD GitOps (`cluster/apps/app-metrics-server.yaml`).

```bash
kubectl top nodes
kubectl top pods -A
```

### Rolling Update + HPA + PDB

Configured for WordPress (Bitnami Helm chart):

| Parameter | Value |
|-----------|-------|
| Rolling Update | `maxSurge: 0, maxUnavailable: 1` (RWO-safe) |
| HPA CPU target | 60% |
| HPA Memory target | 50% |
| HPA min/max replicas | 1 / 3 |
| PDB | `minAvailable: 1` |

```bash
kubectl get hpa -n wordpress
kubectl get pdb -n wordpress
kubectl rollout status deployment/wordpress -n wordpress
```

> ⚠️ `maxSurge > 0` + RWO PVC = Multi-Attach error. Always `maxSurge: 0` for stateful services.

### Kubernetes Upgrade v1.30 → v1.31.14

```bash
# On master
sudo apt-get install -y kubeadm=1.31.14-1.1
sudo kubeadm upgrade apply v1.31.14
sudo apt-get install -y kubelet=1.31.14-1.1 kubectl=1.31.14-1.1
sudo systemctl restart kubelet

# On each worker
kubectl drain <worker> --ignore-daemonsets --delete-emptydir-data
# (on worker) sudo apt-get install -y kubeadm=1.31.14-1.1 kubelet=1.31.14-1.1
# (on worker) sudo kubeadm upgrade node && sudo systemctl restart kubelet
kubectl uncordon <worker>
```

### Node Add/Remove — full cycle

**Adding a node:**

```bash
# 1. Terraform — add VM in nodes.tf, terraform apply
cd terraform/proxmox-lab
terraform apply -target=proxmox_virtual_environment_vm.k8s_worker_03

# 2. Ansible — join the cluster
ansible-playbook -i inventory.ini kubeadm-cluster.yml --limit 'k3s_master,10.44.81.113'

# 3. Verify
kubectl get nodes
```

**Removing a node:**

```bash
kubectl cordon k8s-worker-03
kubectl drain k8s-worker-03 --ignore-daemonsets --delete-emptydir-data
kubectl delete node k8s-worker-03

# terraform destroy (if stuck — see Proxmox API below)
terraform destroy -target=proxmox_virtual_environment_vm.k8s_worker_03
```

**If `terraform destroy` is stuck:**

```bash
# Via SSH to master (bash, not PowerShell — ! in token breaks PS)
# Stop VM
curl -s -k -X POST \
  -H "Authorization: PVEAPIToken=<terraform-api-token>" \
  https://10.44.81.102:8006/api2/json/nodes/pve02/qemu/113/status/stop

# Delete VM
curl -s -k -X DELETE \
  -H "Authorization: PVEAPIToken=<terraform-api-token>" \
  https://10.44.81.102:8006/api2/json/nodes/pve02/qemu/113

# Remove from state
terraform state rm proxmox_virtual_environment_vm.k8s_worker_03
```

> ⚠️ A new node may join with a different K8s version (normal for short-term tests).

---

## 📖 Lessons Learned

- **Lesson 28**: Rolling Update + HPA + PDB — configuration and verification
- **Lesson 29**: RWO PVC + maxSurge > 0 = Multi-Attach error
- **Lesson 30**: Node add/remove full cycle + `terraform destroy` via Proxmox API rescue

---

## 🔗 Related Files

- `cluster/apps/app-metrics-server.yaml` — GitOps for metrics-server
- `cluster/monitoring/metrics-server.yaml` — manifest
- `terraform/proxmox-lab/nodes.tf` — VM definitions
- `docs/runbooks/cluster-bootstrap.md` — adding a node from scratch
- `docs/runbooks/disaster-recovery.md` — node failure recovery

