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
