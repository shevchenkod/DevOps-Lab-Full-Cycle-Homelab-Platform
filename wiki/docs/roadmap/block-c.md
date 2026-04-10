## C. Configuration: Ansible

- [x] ✅ Inventory created on master node (`~/ansible/inventory.ini`) — 01.01.2026
  - Groups: `k3s_master` (110), `k3s_workers` (111, 112), `k3s_cluster`
  - `ansible_user=ubuntu`, key `~/.ssh/devops-lab`
  - `ansible ping` → SUCCESS on all 3 nodes
- [x] ✅ Baseline preparation of all nodes via Ansible — 01.01.2026
  - swap off, sysctl (bridge-nf-call-iptables, ip_forward), kernel modules (overlay, br_netfilter)
  - containerd installed + `SystemdCgroup=true` in config.toml
  - kubeadm / kubelet / kubectl v1.30 installed, packages held
- [x] ✅ Kubernetes installation (kubeadm) automated via Ansible — 01.01.2026
  - `kubeadm init` on master, CNI Calico v3.27.3, kubeconfig for ubuntu
- [x] ✅ Worker node join automated — 01.01.2026
  - token passed via `set_fact`, workers join automatically
- [x] ✅ Idempotency: `stat` checks on `admin.conf` and `kubelet.conf` — repeated run is safe
- [ ] Baseline hardening (separate):
  - [ ] firewall (ufw / nftables)
  - [ ] separate admin user / MFA
