#!/bin/bash
set -e
echo "=== Configure containerd ==="
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
# Also fix pause image to 3.9 (matches k8s 1.31)
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:.*"|sandbox_image = "registry.k8s.io/pause:3.9"|' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "containerd: $(systemctl is-active containerd)"

echo "=== Install K8s repo ==="
sudo apt-get install -y apt-transport-https ca-certificates curl -q 2>/dev/null
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -q 2>/dev/null

echo "=== Install kubeadm kubelet kubectl ==="
sudo apt-get install -y kubeadm kubelet kubectl 2>&1 | tail -3
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl enable kubelet
echo "kubeadm: $(kubeadm version -o short 2>/dev/null)"

echo "=== Configure crictl ==="
cat <<EOF_C | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF_C

echo "=== Join cluster ==="
sudo kubeadm join 10.44.81.110:6443 --token lmvqaa.eofrosgzaoc0xvkd --discovery-token-ca-cert-hash sha256:57211c01e0f98ea544047059cc08705fc9567cfc3ef55dc5c770bb31cc2ae536 2>&1

echo "=== DONE - Worker-01 joined! ==="
