#!/bin/bash
# fix-registry-insecure.sh — Fix containerd insecure registry on all K8s nodes
# Use certs.d approach (works with containerd 1.7+)
REGISTRY="10.44.81.110:30500"

for NODE_IP in 10.44.81.110 10.44.81.111 10.44.81.112; do
  echo "=== Configuring $NODE_IP ==="
  ssh -i /home/ubuntu/.ssh/authorized_keys ubuntu@${NODE_IP} "echo skipping" 2>/dev/null || \
  ssh ubuntu@${NODE_IP} "
    sudo mkdir -p /etc/containerd/certs.d/${REGISTRY}
    # Create hosts.toml for insecure HTTP access
    sudo tee /etc/containerd/certs.d/${REGISTRY}/hosts.toml > /dev/null << 'HOSTS_EOF'
server = \"http://${REGISTRY}\"

[host.\"http://${REGISTRY}\"]
  capabilities = [\"pull\", \"resolve\", \"push\"]
  skip_verify = true
HOSTS_EOF
    # Update containerd config to use config_path
    if ! grep -q 'config_path' /etc/containerd/config.toml; then
      sudo sed -i 's|^\(\[plugins.\"io.containerd.grpc.v1.cri\".registry\"\]\)|\\1\\n  config_path = \"/etc/containerd/certs.d\"|' /etc/containerd/config.toml
    fi
    sudo systemctl restart containerd
    echo done
  " 2>&1
done
