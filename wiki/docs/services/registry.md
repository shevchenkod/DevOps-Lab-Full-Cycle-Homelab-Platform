# 🗄️ In-Cluster Container Registry

> registry:2 — a lightweight Docker registry inside the cluster. Stores images locally without DockerHub.

## Configuration

| Parameter | Value |
|-----------|-------|
| Namespace | `registry` |
| Image | `registry:2` |
| NodePort | `30500` (accessible on all nodes) |
| URL | `http://10.44.81.110:30500` (insecure HTTP) |
| PVC | `registry-pvc` — 20Gi `longhorn-single` |
| Argo CD | `cluster/argocd/app-registry.yaml` |
| Status | ✅ Running (worker-01) |

## Verify Registry

```bash
# List images
curl http://10.44.81.110:30500/v2/_catalog

# List tags for wiki image
curl http://10.44.81.110:30500/v2/wiki/tags/list
```

## Building and Pushing Images via nerdctl

```bash
# nerdctl is installed on master: /usr/local/bin/nerdctl (v2.2.1)
# buildkitd systemd service: active

# Build
sudo nerdctl --namespace k8s.io build -t 10.44.81.110:30500/wiki:latest .

# Push
sudo nerdctl --namespace k8s.io push --insecure-registry 10.44.81.110:30500/wiki:latest
```

!!! warning "containerd insecure registry"
    containerd 1.7.x: `hosts.toml` **does not work** without `config_path` in `config.toml`.
    An explicit mirrors entry is required in `/etc/containerd/config.toml` on **each node**:
    ```toml
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."10.44.81.110:30500"]
      endpoint = ["http://10.44.81.110:30500"]
    ```
    After the change: `sudo systemctl restart containerd`

    Script: `_tmp/fix-containerd-registry.sh`

!!! tip "nerdctl flags"
    - `--namespace k8s.io` — required, otherwise the image is not visible to Kubernetes
    - `--insecure-registry` — required for HTTP registries without TLS
