# 🖥️ Infrastructure

The base layer of the lab: virtualization, Kubernetes, networking, and storage.

## Components

| Component | Purpose | Status |
|-----------|---------|--------|
| [Proxmox VE](proxmox.md) | Hypervisor, VMs | ✅ |
| [Kubernetes Cluster](kubernetes.md) | Orchestration, 3 nodes | ✅ |
| [Networking (MetalLB, Ingress)](networking.md) | LoadBalancer, Ingress, TLS | ✅ |
| [Storage (Longhorn)](storage.md) | Distributed block storage | ✅ |

## Network Diagram

```
10.44.81.0/24
├── 10.44.81.101   pve01 (Proxmox VE)
├── 10.44.81.102   pve02 (Proxmox VE)
├── 10.44.81.110   k8s-master-01  [8 CPU / 8 GB / containerd 2.2.1]
├── 10.44.81.111   k8s-worker-01  [4 CPU / 4 GB / containerd 1.7.28]
├── 10.44.81.112   k8s-worker-02  [4 CPU / 4 GB / containerd 1.7.28]
└── 10.44.81.200   MetalLB (Ingress LB IP) — all *.lab.local services
```

## Access

| Host | SSH Command |
|------|-------------|
| master | `ssh -i "H:\DEVOPS-LAB\ssh\devops-lab" ubuntu@10.44.81.110` |
| worker-01 | `ssh -i "H:\DEVOPS-LAB\ssh\devops-lab" ubuntu@10.44.81.111` |
| worker-02 | `ssh -i "H:\DEVOPS-LAB\ssh\devops-lab" ubuntu@10.44.81.112` |
