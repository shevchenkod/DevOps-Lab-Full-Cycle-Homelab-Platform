# 🏗️ IaC — Infrastructure as Code

Infrastructure is described as code. Terraform manages VMs on Proxmox, Ansible configures servers.

## Components

| Tool | Purpose | Status |
|------|---------|--------|
| [Terraform](terraform.md) | Proxmox VM provisioning | ✅ |
| [Ansible](ansible.md) | K8s bootstrap, configuration | ✅ |

## Repository

```
devops-lab/
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── provider.tf
│   │       ├── variables.tf
│   │       └── main.tf
│   └── modules/
│       └── proxmox-vm/
└── ansible/
    ├── inventory/
    │   └── hosts.ini
    ├── playbooks/
    │   ├── k8s-master.yaml
    │   └── k8s-workers.yaml
    └── roles/
```

## Workflow

```
Terraform plan/apply → VM created on Proxmox
         ↓
Ansible playbook → K8s installed and configured
         ↓
kubeadm join → node added to the cluster
         ↓
kubectl/helm → applications deployed
         ↓
Argo CD → GitOps continuous sync
```
