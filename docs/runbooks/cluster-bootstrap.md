# Runbook: Bootstrap Cluster from Scratch

**Time**: ~45–60 minutes  
**Result**: Fully operational Kubernetes cluster with all Argo CD applications deployed

---

## Prerequisites

- Proxmox: pve01 (`10.44.81.101`) and pve02 (`10.44.81.102`) are running
- Terraform installed on workstation
- Ansible available on master node (or locally)
- SSH key: `ssh/devops-lab` (stored outside the repo, in `.gitignore`)
- kubectl configured with `kubeconfig-lab.yaml` (in `.gitignore`)

---

## Step 1 — Create VMs via Terraform

```bash
cd terraform/proxmox-lab
terraform init
terraform apply -var-file="terraform.tfvars" -auto-approve
```

**Expected result**: 3 VMs created on Proxmox:
- `k8s-master-01` → pve01, `10.44.81.110`
- `k8s-worker-01` → pve01, `10.44.81.111`
- `k8s-worker-02` → pve02, `10.44.81.112`

**Verify**:
```bash
terraform output
# k8s_master_ip = "10.44.81.110"
# k8s_worker_ips = ["10.44.81.111", "10.44.81.112"]
```

---

## Step 2 — Bootstrap Kubernetes via Ansible

SSH to master and run the playbook:

```bash
ssh -i ssh/devops-lab ubuntu@10.44.81.110

cd ~/ansible
ansible-playbook -i inventory.ini kubeadm-cluster.yml
```

The playbook performs:
1. Baseline on all nodes (swap off, sysctl, containerd, kubelet)
2. `kubeadm init` on master
3. Calico CNI installation
4. Worker nodes join the cluster

**Time**: ~10–15 minutes

**Verify**:
```bash
kubectl get nodes
# NAME            STATUS   ROLES           VERSION
# k8s-master-01   Ready    control-plane   v1.31.14
# k8s-worker-01   Ready    <none>          v1.31.14
# k8s-worker-02   Ready    <none>          v1.31.14
```

---

## Step 3 — Copy kubeconfig to workstation

```bash
# On master:
cat ~/.kube/config
```

Copy the output to `kubeconfig-lab.yaml` on your workstation.  
Replace `server: https://127.0.0.1:6443` → `server: https://10.44.81.110:6443`

---

## Step 4 — Install Argo CD

```bash
# Create namespace
kubectl create namespace argocd

# Install via Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd -f cluster/argocd/values.yaml
```

---

## Step 5 — Apply App-of-Apps → everything else deploys automatically

```bash
kubectl apply -f cluster/apps/app-of-apps.yaml
```

Argo CD automatically syncs all applications from Git:
- MetalLB, cert-manager, ingress-nginx
- Longhorn (storage)
- kube-prometheus-stack, Loki, Promtail (observability)
- WordPress, Strapi, Uptime Kuma, Wiki (applications)
- MinIO, Velero (backup)
- metrics-server

**Sync time**: ~10–15 minutes

**Verify**:
```bash
kubectl get applications -n argocd
# All apps: Synced / Healthy
```

---

## Step 6 — Apply zone labels

```bash
kubectl label node k8s-master-01 topology.kubernetes.io/zone=zone-a topology.kubernetes.io/region=proxmox-lab
kubectl label node k8s-worker-01 topology.kubernetes.io/zone=zone-a topology.kubernetes.io/region=proxmox-lab
kubectl label node k8s-worker-02 topology.kubernetes.io/zone=zone-b topology.kubernetes.io/region=proxmox-lab
```

---

## Step 7 — Verify everything

```bash
# Nodes
kubectl get nodes -o wide

# All pods
kubectl get pods -A

# Argo CD applications
kubectl get applications -n argocd

# Services with external IPs
kubectl get svc -A | grep LoadBalancer
```

**Expected URLs after deploy**:

| Service     | URL                              |
|-------------|----------------------------------|
| Argo CD     | `https://argocd.lab.local`       |
| Grafana     | `https://grafana.lab.local`      |
| Longhorn    | `https://longhorn.lab.local`     |
| WordPress   | `https://wordpress.lab.local`    |
| Strapi      | `https://strapi.lab.local`       |
| Wiki        | `https://wiki.lab.local`         |
| Uptime Kuma | `https://status.lab.local`       |

---

## Critical Files for Recovery

| File                                   | Purpose                                             |
|----------------------------------------|-----------------------------------------------------|
| `terraform/proxmox-lab/terraform.tfvars` | Proxmox API tokens — **in `.gitignore`, store separately** |
| `ssh/devops-lab`                       | SSH private key — **in `.gitignore`**               |
| `kubeconfig-lab.yaml`                  | Cluster kubeconfig — **in `.gitignore`**            |
