# Runbook: Disaster Recovery

**Scenarios**: data loss, namespace failure, node failure

> **Note on credentials**: Proxmox API tokens required for direct API calls are stored
> outside the repository (`terraform/proxmox-lab/terraform.tfvars`, in `.gitignore`).
> See SECURITY.md for the credential management approach.

---

## Scenario 1 — Restore namespace from Velero backup

### When to use
- Accidental namespace deletion (`kubectl delete namespace wordpress`)
- Data corruption in DB or files
- After testing — restore clean state

### Commands

```bash
# 1. List available backups
kubectl get backups -n velero

# 2. Select backup (example: wordpress-daily-xxxxxxxx)
BACKUP="wordpress-daily-20260302000000"

# 3. Create restore
kubectl create -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-wordpress-$(date +%Y%m%d%H%M%S)
  namespace: velero
spec:
  backupName: $BACKUP
  includedNamespaces:
    - wordpress
  restorePVs: true
EOF

# 4. Watch status
kubectl get restore -n velero -w
# Wait for: Phase = Completed

# 5. Verify pods
kubectl get pods -n wordpress
```

**Recovery time**: ~3–5 minutes

---

## Scenario 2 — Restore from Longhorn Snapshot

### When to use
- Quick data rollback at volume level (without pod recreation)
- WordPress file or Strapi data corruption

### Commands

```bash
# 1. List snapshots for the target PVC
kubectl get volumesnapshots -A

# 2. Via Longhorn UI: https://longhorn.lab.local
# Volumes → select volume → Snapshots → Revert

# Or via API: create PVC from snapshot
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-restored
  namespace: wordpress
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
  dataSource:
    name: <snapshot-name>
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
EOF
```

> **Important**: Use `VolumeSnapshotClass` with `type: bak` for DR-safe snapshots.
> `type: snap` data is stored inside the volume and is deleted with it — NOT DR-safe.

---

## Scenario 3 — Node failure (node NotReady)

### Diagnostics

```bash
# Check node status
kubectl get nodes

# Describe the problematic node
kubectl describe node k8s-worker-01

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### If node is temporarily unavailable (network, reboot)

```bash
# Wait 5–10 minutes — kubelet will reconnect automatically

# If node recovers — uncordon
kubectl uncordon k8s-worker-01
```

### If node is permanently lost

```bash
# 1. Remove from cluster
kubectl drain k8s-worker-01 --ignore-daemonsets --delete-emptydir-data --force
kubectl delete node k8s-worker-01

# 2. Stop and delete VM via Proxmox API (if terraform destroy hangs)
#    API token stored in terraform.tfvars (not committed — see .gitignore)
ssh -i ssh/devops-lab ubuntu@10.44.81.110 \
  'curl -sk -X POST "https://10.44.81.101:8006/api2/json/nodes/pve01/qemu/111/status/stop" \
   -H "Authorization: PVEAPIToken=<terraform-api-token-pve01>"'

# Wait 15 sec, then delete
ssh -i ssh/devops-lab ubuntu@10.44.81.110 \
  'curl -sk -X DELETE "https://10.44.81.101:8006/api2/json/nodes/pve01/qemu/111?purge=1" \
   -H "Authorization: PVEAPIToken=<terraform-api-token-pve01>"'

# 3. Clean Terraform state
cd terraform/proxmox-lab
terraform state rm proxmox_virtual_environment_vm.k8s_worker_01

# 4. Recreate node via Terraform
terraform apply -var-file="terraform.tfvars" -target="proxmox_virtual_environment_vm.k8s_worker_01" -auto-approve

# 5. Join via Ansible
ssh -i ssh/devops-lab ubuntu@10.44.81.110 \
  "ansible-playbook -i ~/ansible/inventory.ini ~/ansible/kubeadm-cluster.yml --limit 'k8s_master,10.44.81.111'"

# 6. Verify
kubectl get nodes
# worker-01 should appear Ready within ~1–2 minutes
```

**Longhorn automatically rebuilds replicas on the new node** (~5–10 minutes)

---

## Scenario 4 — Restore SSH access to master

### Symptom
`ssh ubuntu@10.44.81.110` fails — `Permission denied`

### Fix via kubectl debug node

```bash
# 1. Launch debug container on master node
kubectl debug node/k8s-master-01 -it --image=ubuntu

# 2. In the container (host filesystem is at /host)
chroot /host

# 3. Restore authorized_keys
cat /home/ubuntu/.ssh/authorized_keys
# If empty — add the public key from ssh/devops-lab.pub
echo "<contents-of-devops-lab.pub>" >> /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
exit; exit

# 4. Delete debug pod
kubectl delete pod node-debugger-k8s-master-01-xxxx
```

---

## Scenario 5 — Argo CD not syncing an application

```bash
# Force sync
kubectl -n argocd patch application <app-name> \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"force":{}}}}}'

# Or via argocd CLI
argocd app sync <app-name> --force

# Check status
kubectl get applications -n argocd
```

---

## Quick Reference

```
SSH:     ssh -i ssh/devops-lab ubuntu@10.44.81.110
kubectl: kubectl --kubeconfig=kubeconfig-lab.yaml

Longhorn UI:  https://longhorn.lab.local
Argo CD UI:   https://argocd.lab.local
MinIO:        http://minio.minio.svc.cluster.local:9000 (in-cluster)
              https://minio.lab.local (console, via ingress)

API tokens:   stored in terraform/proxmox-lab/terraform.tfvars (.gitignore)
```
