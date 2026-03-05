# 🔒 Security

## Components

| Tool | Purpose | Status |
|------|---------|--------|
| cert-manager | Automatic TLS certificates | ✅ |
| HashiCorp Vault | Secrets storage | ⏳ |
| Trivy | Image scanning | ⏳ |
| SonarQube | Static code analysis | ⏳ |

## cert-manager (current configuration)

> More details: [Networking & cert-manager](../infrastructure/networking.md)

The internal CA (`lab-ca-issuer`) issues certificates for all `*.lab.local` domains.

```bash
# Check certificates
kubectl get certificates -A
kubectl get certificaterequests -A
kubectl describe clusterissuer lab-ca-issuer
```

## HashiCorp Vault ⏳ (planned)

> Centralised secrets store. Integrates with K8s for automatic secret injection into pods.

```bash
# Planned deployment
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set server.ha.enabled=false  # standalone for lab
```

## Trivy ⏳ (planned)

> Scanning Docker images for CVEs before deployment.

```bash
# Scan an image
trivy image 10.44.81.110:30500/wiki:latest

# In CI/CD pipeline
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:latest
```

## Security Practices (lab)

- [x] SSH keys for node access (no passwords in production)
- [x] TLS on all public services (cert-manager)
- [x] Secrets not in git (`.gitignore` for `*.key`, `kubeconfig*.yaml`)
- [x] Argo CD HTTPS token (not SSH password)
- [ ] Vault for K8s secrets storage
- [ ] Network Policies (restrict traffic between namespaces)
- [ ] Trivy in CI pipeline
- [ ] Fine-grained RBAC for K8s
