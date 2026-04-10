#!/bin/bash
# Fix containerd config to enable certs.d for insecure registry

CONFIG=/etc/containerd/config.toml

# Check if config_path already exists
if grep -q 'config_path.*certs.d' "$CONFIG"; then
    echo "config_path already set"
else
    # Add config_path under the registry section
    sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.registry\]/a\  config_path = "/etc/containerd/certs.d"' "$CONFIG"
    echo "Added config_path"
fi

# Verify
grep -A3 '"io.containerd.grpc.v1.cri".registry' "$CONFIG" | head -5

# Restart containerd
sudo systemctl restart containerd
sleep 2
sudo systemctl is-active containerd
echo "Done: $HOSTNAME"
