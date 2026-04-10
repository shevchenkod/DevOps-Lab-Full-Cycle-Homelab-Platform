## F. Delivery: Helm, GitOps, CI/CD, Pipelines

### Helm

- [x] ✅ All core components installed via Helm (Argo CD manages Helm applications)
- [x] ✅ Upgrade / rollback tested (WordPress, kube-prometheus-stack, loki)

### GitOps — Argo CD

- [x] ✅ Argo CD installed via Helm — 01.01.2026
  - namespace: `argocd`, 7 pods Running
  - `server.insecure=true` — TLS terminated at Ingress
  - `https://argocd.lab.local` → HTTP 200, cert Ready (lab-ca-issuer) ✅
  - Admin password: stored in cluster secret (not in repo)
- [x] ✅ Git repo connected — 01.01.2026
  - `https://github.com/shevchenkod/devops-lab.git` → STATUS: Successful ✅
  - Credentials via K8s Secret (not in Git), label `argocd.argoproj.io/secret-type=repository`
- [x] ✅ First application via Argo CD — 01.01.2026
  - `test-app`: Synced / Healthy ✅ (path: `apps/test-app`)
- [x] ✅ kube-prometheus-stack via Argo CD (Helm Application) — 01.01.2026
  - Synced / Healthy, all pods Running, PVC Bound (Longhorn)
- [x] ✅ **App-of-Apps structure** — 01.01.2026
  - `cluster/apps/app-of-apps.yaml` — root application
  - **15 applications** in `cluster/apps/` — all Synced / Healthy
  - Manages: monitoring, loki, minio, velero, wordpress, strapi, wiki, uptime-kuma, registry, metrics-server, dashboards, sealed-secrets, etc.
- [x] ✅ **Sync policies** — automated: prune + selfHeal on all applications

### CI/CD — GitHub Actions + ARC (Actions Runner Controller)

> **Tool chosen: GitHub Actions + ARC v0.13.1**
> Self-hosted runners in Kubernetes — scale-from-zero: runner pod created on job start, deleted after completion.

- [x] ✅ **ARC controller** installed — 01.01.2026
  - Helm: `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller`
  - Version: **v0.13.1**
  - Namespace: `arc-systems`
- [x] ✅ **RunnerScaleSet** `arc-runner-set` created — 01.01.2026
  - Namespace: `arc-runners`
  - Bound to: `https://github.com/shevchenkod/devops-lab`
  - PAT Token stored in K8s Secret (not committed to repo)
- [x] ✅ **RBAC** for ARC runner — `cluster/arc/rbac.yaml`
  - ServiceAccount `arc-runner` → ClusterRole `arc-runner-deploy`
  - Permissions: get/list/watch/patch Deployments, get Pods
- [x] ✅ **GitHub Actions workflow** `wiki-ci.yml` — 01.01.2026
  - File: `.github/workflows/wiki-ci.yml`
  - Trigger: `push` to `wiki/**` or `workflow_dispatch`
  - Runner: `arc-runner-set` (self-hosted ARC)
  - GitHub Secret: `MASTER_SSH_KEY` — raw PEM key for SSH to master
  - Steps:
    1. `actions/checkout@v4`
    2. SSH key setup
    3. SCP wiki source → master `~/wiki-build`
    4. SSH: `nerdctl build` + `nerdctl push` on master
    5. SSH: `kubectl rollout restart deployment/wiki -n wiki`
  - Status: **`completed | success`** ✅
- [ ] Pipeline: build Docker image → tag → push to registry → GitOps deploy
- [ ] GitLab CI: self-hosted GitLab CE on Proxmox (future block)
- [ ] (Optional) Security gate: image scan (Trivy)

### Registry

- [x] ✅ **In-cluster Registry** (`registry:2`) — NodePort 30500, HTTP insecure
  - Images: `10.44.81.110:30500/wiki:latest`
  - containerd mirrors configured on all nodes (`/etc/containerd/config.toml`)
  - Argo CD App: `cluster/apps/app-registry.yaml` → Synced / Healthy ✅
- [ ] Harbor: self-hosted registry with RBAC + Trivy scanning (backlog)

### Secrets Management — Sealed Secrets

> **Approach chosen: Sealed Secrets (Bitnami Labs)**
> SealedSecret is encrypted with the cluster public key → file is safe to commit to Git.
> The cluster decrypts SealedSecret → creates a regular K8s Secret automatically.

- [x] ✅ **Sealed Secrets controller** installed — 01.01.2026
  - Helm chart: `sealed-secrets v2.18.3` (bitnami-labs.github.io/sealed-secrets)
  - Namespace: `kube-system`, Controller pod: `sealed-secrets-controller-*`
  - Argo CD App: `cluster/apps/app-sealed-secrets.yaml` → Synced / Healthy ✅
- [x] ✅ **kubeseal CLI** v0.36.0 — `/usr/local/bin/kubeseal` on master
- [x] ✅ **WordPress SealedSecret** — `cluster/secrets/wordpress-credentials.yaml` — 01.01.2026
  - Keys: `wordpress-password`, `wordpress-mariadb-password`, `mariadb-root-password`, `mariadb-password`
  - Namespace: `wordpress`
  - Argo CD App: `cluster/apps/app-sealed-secrets-wordpress.yaml` → Synced / Healthy ✅
- [x] ✅ Secrets **not stored** in plaintext in the repository — WordPress credentials are encrypted

#### Creating a SealedSecret (cheat sheet)

```bash
# On master node (kubeseal installed):
kubectl create secret generic <secret-name> \
  --from-literal=key1='value1' \
  --from-literal=key2='value2' \
  --namespace=<namespace> \
  --dry-run=client -o yaml | \
kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  --format yaml > /tmp/sealed-secret.yaml

# Verify after apply:
kubectl get sealedsecret -n <namespace>
kubectl get secret <secret-name> -n <namespace>

# View cluster public key:
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system
```
