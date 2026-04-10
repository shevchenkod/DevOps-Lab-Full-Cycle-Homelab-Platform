#!/bin/bash
# Fix containerd 1.7.x: remove conflicting config_path when mirrors is already set
CONFIG=/etc/containerd/config.toml

# For containerd 1.7.x: cannot have both config_path AND mirrors
# Remove the config_path we added that broke it
sudo sed -i '/^      config_path = "\/etc\/containerd\/certs\.d"$/d' "$CONFIG"

echo "=== After fix: config_path lines ==="
grep -n 'config_path' "$CONFIG"

echo "=== CRI plugin config ==="
grep -n -A3 'grpc.v1.cri.*registry' "$CONFIG" | head -10

# Restart containerd
sudo systemctl restart containerd
sleep 3
sudo systemctl is-active containerd

# Verify CRI is working
echo "=== containerd error check ==="
sudo journalctl -u containerd -n 5 --no-pager 2>&1 | grep -E "error|failed|cri" | head -5 || echo "no errors"
echo "Done: $HOSTNAME"
