## B. IaaS: Proxmox + Terraform

### 🖥️ Proxmox — base setup

- [x] ✅ Proxmox installed — **pve01** (`10.44.81.101`) — 01.01.2026
- [x] ✅ Proxmox installed — **pve02** (`10.44.81.102`) — 01.01.2026
- [x] ✅ Terraform API tokens created and verified via `curl.exe` — 01.01.2026
  - pve01: token `terraform@pve!terraform-pve01`
  - pve02: token `terraform@pve!terraform-pve02`
- [x] ✅ Storage pools defined — 01.01.2026
  - pve01: `local` (Directory, /var/lib/vz) + `local-lvm` (LVM-Thin)
  - pve02: `local` (Directory) + `local-lvm` (LVM-Thin) · 16 CPU · 15.58 GiB RAM · 121.95 GiB disk
- [x] ✅ Bridges / VLANs documented — 01.01.2026
  - `vmbr0` (Linux Bridge on ens33): pve01 `10.44.81.101/24`, pve02 `10.44.81.102/24`, gw `10.44.81.254`
  - All VMs (k8s nodes) on `vmbr0` in subnet `10.44.81.0/24`
  - MetalLB pool: `10.44.81.200–250` (reserved)
- [x] ✅ Templates (cloud-image Ubuntu 24.04) ready — 01.01.2026
  - `ubuntu-24.04-cloud.img` (600 MB) downloaded to pve01 and pve02
  - Path: `/var/lib/vz/template/cloud/ubuntu-24.04-cloud.img`
  - Installation ISO also uploaded: `/var/lib/vz/template/iso/ubuntu-24.04.4-live-server-amd64.iso`
- [x] ✅ Cloud-init works (VM template 9000 created) — 01.01.2026
  - VMID: `9000`, name: `ubuntu-2404-cloud`
  - Parameters: 2 CPU, 2048 MB RAM, `virtio-scsi`, `vmbr0`, cloud-init user: `ubuntu`
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
