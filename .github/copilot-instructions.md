# GitHub Copilot Instructions — DevOps Lab

## Architecture Overview

Full-cycle homelab platform on bare-metal: **Proxmox VE** (2 hosts) → **Terraform** (VM provisioning) → **Ansible** (K8s bootstrap) → **Kubernetes v1.31** (3 nodes via kubeadm) → **Argo CD GitOps** (17 apps, App-of-Apps pattern).

- Network: `10.44.81.0/24` | MetalLB pool: `10.44.81.200–250` | Ingress IP: `10.44.81.200`
- Zones: `zone-a` = pve01 (master-01 + worker-01), `zone-b` = pve02 (worker-02)
- All services exposed via `*.lab.local` over HTTPS (cert-manager + internal CA `lab-ca-issuer`)
- No Docker daemon — builds use `nerdctl` + `buildkitd` on master node

## GitOps — App-of-Apps Pattern (CRITICAL)

**Never `kubectl apply` individual manifests manually.** The only workflow is:

1. Edit manifest files → `git push` → Argo CD syncs automatically
2. Add a new app: create `apps/<name>/` manifests + `cluster/apps/app-<name>.yaml` Application CRD → push

Root application: `cluster/argocd/app-of-apps.yaml` watches `cluster/apps/` for `app-*.yaml` files.  
Each `app-*.yaml` points to either a Helm chart (external repo) or a local path (`apps/<name>/`).

**Helm-based apps** (monitoring, velero, minio) embed `valuesObject:` directly in the Application manifest — no separate `values.yaml` files.

## Secrets — Sealed Secrets Only

**Never commit plain Kubernetes `Secret` objects.** All secrets use Sealed Secrets v2.18.3:

```bash
# Create a SealedSecret from a plain secret
kubectl create secret generic my-secret --from-literal=key=value --dry-run=client -o yaml \
  | kubeseal --controller-name=sealed-secrets-controller --controller-namespace=kube-system \
  | kubectl apply -f -
```

Sealed secrets live in `cluster/secrets/` or alongside app manifests (e.g., `apps/n8n/sealed-secret.yaml`). They are safe to commit.

## Storage Classes

| StorageClass | Replicas | Use for |
|---|---|---|
| `longhorn` | 2 | Stateful HA apps (WordPress, Prometheus, Grafana, Loki) |
| `longhorn-single` | 1 | MinIO (performance, owns its own redundancy) |

**CSI Snapshots / DR:** Always use `VolumeSnapshotClass: longhorn-snapshot-class` with `type: bak` — NOT `type: snap`. `type: snap` data is deleted with the volume and is **not DR-safe**.

## Image Builds (No Docker)

Wiki and custom images are built on `k8s-master-01` using containerd-native toolchain:

```bash
ssh -i ~/.ssh/devops-lab ubuntu@10.44.81.110
sudo nerdctl --namespace k8s.io build -t 10.44.81.110:30500/wiki:latest .
sudo nerdctl --namespace k8s.io push --insecure-registry 10.44.81.110:30500/wiki:latest
kubectl rollout restart deployment/wiki -n wiki
```

In-cluster registry: `10.44.81.110:30500` (HTTP, insecure NodePort 30500). All nodes have containerd mirrors configured for this endpoint. CI/CD (`.github/workflows/wiki-ci.yml`) SSHes to master to build and push using `arc-runner-set` (ARC self-hosted runners in K8s).

## Ingress Conventions

All Ingress resources follow this pattern:

```yaml
annotations:
  cert-manager.io/cluster-issuer: lab-ca-issuer    # Always use this issuer
  # For WebSocket apps (e.g., Uptime Kuma):
  nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
  nginx.ingress.kubernetes.io/upgrade: websocket
ingressClassName: nginx
```

## Deployment Strategy Patterns

- **Recreate** strategy for SQLite-backed single-writer apps (N8N, Strapi) — RWO PVC cannot attach to 2 pods simultaneously
- **RollingUpdate** for stateless apps — but watch for `Multi-Attach` errors if PVC is RWO

## Key Commands

```bash
# Set kubeconfig (Windows PowerShell)
$env:KUBECONFIG = 'H:\DEVOPS-LAB\kubeconfig-lab.yaml'

# SSH to cluster
ssh -i H:\DEVOPS-LAB\ssh\devops-lab ubuntu@10.44.81.110   # SSH user is 'ubuntu', not root

# Check all Argo CD apps
kubectl get application -n argocd

# Velero backup status
kubectl get backupstoragelocation -n velero
kubectl get backup.velero.io -n velero

# Force Argo CD sync
kubectl annotate application <name> -n argocd argocd.argoproj.io/refresh=normal
```

## Known Gotchas

- **Strapi**: locked at v4 — npm registry for v5 had breaking incompatibilities
- **Velero + MinIO**: requires `checksumAlgorithm: ""` in BSL config for MinIO compatibility; `snapshotsEnabled: false` to avoid null-provider CRD errors
- **Metrics-server**: managed via Argo CD (`cluster/apps/app-metrics-server.yaml`), not standalone `kubectl apply`
- **Zone labels** (`topology.kubernetes.io/zone`) are applied via Ansible/kubectl and documented in `cluster/platform/node-labels.yaml` — no native CRD, cannot be purely GitOps
- **Lesson 24**: adding an Application via `kubectl apply` directly (bypassing App-of-Apps) creates an unmanaged resource — always add `app-*.yaml` to `cluster/apps/`

## Repository Layout

```
cluster/argocd/app-of-apps.yaml   # Root GitOps entry point
cluster/apps/app-*.yaml           # One Application CRD per service
apps/<name>/                      # Raw K8s manifests for custom apps
cluster/secrets/                  # SealedSecrets (safe to commit)
cluster/storage/                  # VolumeSnapshotClass, BackupTarget
cluster/platform/node-labels.yaml # Zone topology documentation
wiki/                             # MkDocs Material source (31 lessons)
docs/runbooks/                    # cluster-bootstrap.md, disaster-recovery.md
docs/DevOps.md                    # Credentials, configs, reference commands
terraform/proxmox-lab/            # VM provisioning
ansible/                          # K8s bootstrap playbooks
```
