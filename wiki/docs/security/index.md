# 🔒 Security

## Components

| Tool | Purpose | Status |
|------|---------|--------|
| cert-manager | Automatic TLS certificates for all `*.lab.local` | ✅ |
| HashiCorp Vault | Centralized secrets store + Vault Agent Injector | ✅ |
| External Secrets Operator | Sync Vault secrets → K8s Secrets automatically | ✅ |
| Sealed Secrets | Encrypted secrets safe to commit to Git | ✅ |
| Trivy Operator | Automated CVE scanning + IaC audit + Grafana dashboard | ✅ |
| Infisical | Secrets management platform (Web UI + API) | ✅ |
| OPA Gatekeeper | Policy engine — admission controller for K8s resources | ✅ |

---

## cert-manager

The internal CA (`lab-ca-issuer`) issues TLS certificates for all `*.lab.local` domains via cert-manager v1.20.0.

```bash
kubectl get certificates -A
kubectl get certificaterequests -A
kubectl describe clusterissuer lab-ca-issuer
```

---

## HashiCorp Vault ✅

Standalone Vault v1.19 with Raft storage backend. Deployed via Argo CD (Helm + local manifests).

- Web UI: **https://vault.lab.local**
- Storage: Longhorn PVC 10Gi
- Vault Agent Injector: auto-injects secrets into pods via annotations
- External Secrets Operator: `ClusterSecretStore vault-backend` syncs to K8s Secrets

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Unseal (required after every pod restart — Shamir's Secret Sharing, threshold: 2/3)
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>

# List secrets engines
kubectl exec -n vault vault-0 -- vault secrets list
```

!!! warning "Vault re-seals on pod restart"
    Vault uses Shamir's Secret Sharing (3 keys, threshold 2). It re-seals every time the pod restarts.
    For production-like behaviour, configure **Transit Auto-Unseal**.

---

## Infisical ✅

Open-source secrets management platform. Deployed with PostgreSQL backend.

- Web UI: **https://infisical.lab.local**
- Namespace: `infisical`
- Backend: PostgreSQL (bundled)

!!! note "Ingress webhook"
    Infisical bundles its own nginx ingress controller. Its `ValidatingWebhookConfiguration` must have
    a `namespaceSelector` restricting it to the `infisical` namespace — otherwise it intercepts
    all cluster ingress operations and breaks TLS cert issuance cluster-wide.

---

## OPA Gatekeeper ✅

Open Policy Agent admission controller for Kubernetes policy enforcement.

- Metrics endpoint: **https://opa.lab.local/metrics**
- Namespace: `gatekeeper-system`
- 4 pods: controller + audit + webhook + metrics

```bash
# Check Gatekeeper status
kubectl get pods -n gatekeeper-system

# List constraint templates
kubectl get constrainttemplates

# List active constraints
kubectl get constraints
```

---

## Sealed Secrets ✅

Encrypted secrets safe to commit to Git. Decrypted only inside the cluster by `sealed-secrets-controller`.

```bash
# Seal a new secret
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -f secret.yaml -w sealed-secret.yaml

# Verify
kubectl get sealedsecrets -A
```

---

## Trivy Operator ✅

Automated vulnerability scanning deployed as a Kubernetes operator.

- Scans: container images, K8s config, exposed secrets
- Results: CRDs + Prometheus ServiceMonitor → Grafana dashboard
- Namespace: `trivy-system`

```bash
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
kubectl get exposedsecretsreports -A
```

---

## Security Practices (lab)

- [x] SSH keys for node access (no passwords)
- [x] TLS on all services (cert-manager + internal CA)
- [x] Secrets not in git (`.gitignore`: `*.key`, `kubeconfig*.yaml`, `*.tfstate`)
- [x] Sealed Secrets for Git-safe secret storage
- [x] Vault for centralized secrets + ESO auto-sync
- [x] Infisical secrets platform
- [x] OPA Gatekeeper policy enforcement
- [x] Trivy Operator automated CVE scanning
- [ ] NetworkPolicies — namespace isolation (next priority)
- [ ] Fine-grained RBAC + PodSecurityAdmission `restricted`
- [ ] Vault Transit Auto-Unseal
