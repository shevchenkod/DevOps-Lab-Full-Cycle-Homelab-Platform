#!/bin/bash
# Worker-01 Kubernetes setup script
# Run as: bash setup-worker-01.sh "<join_command>"
set -e

echo "=== [1/7] System prep ==="
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
sudo apt-get update -qq

echo "=== [2/7] Kernel modules ==="
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system -q

echo "=== [3/7] Install containerd ==="
sudo apt-get install -y -qq containerd apt-transport-https ca-certificates curl gnupg 2>/dev/null
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "containerd: $(sudo systemctl is-active containerd)"

echo "=== [4/7] Install Kubernetes packages ==="
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -qq

# Install latest available 1.31.x
sudo apt-get install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
echo "kubeadm: $(kubeadm version -o short 2>/dev/null || kubeadm version)"

echo "=== [5/7] Enable kubelet ==="
sudo systemctl enable kubelet

echo "=== [6/7] Configure crictl ==="
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

echo "=== [7/7] Join cluster ==="
sudo $1

echo "=== DONE ==="
echo "Worker-01 should now be joining the cluster."
echo "Run: kubectl get nodes -w"
