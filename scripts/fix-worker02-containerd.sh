#!/bin/bash
# Fix duplicate config_path on worker-02 (containerd 1.7.x)
CONFIG=/etc/containerd/config.toml

# Remove the line we just added (it was added before the existing empty config_path)
# and replace the existing empty config_path with our path
sudo sed -i '162d' "$CONFIG"

# Now fix the remaining empty config_path (now at line 162) and set it properly
sudo sed -i 's/^      config_path = ""$/      config_path = "\/etc\/containerd\/certs.d"/' "$CONFIG"

# Verify
echo "=== Lines 160-167 ==="
sed -n '160,167p' "$CONFIG"

echo "=== All config_path entries ==="
grep -n 'config_path' "$CONFIG"

# Restart
sudo systemctl restart containerd
sleep 2
sudo systemctl is-active containerd
echo "Done"
