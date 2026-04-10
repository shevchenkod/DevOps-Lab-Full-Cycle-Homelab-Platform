# Vault Init & Unseal Runbook

> **One-time procedure** after HashiCorp Vault is deployed via ArgoCD.
> Vault starts in a **sealed** state — it cannot serve secrets until initialized and unsealed.

## Prerequisites

- Vault pod is Running (but will show `0/1 Ready` — that's expected before init)
- `kubectl` access to the cluster
- Somewhere safe to store the unseal keys (e.g., `F:\PROJECTS-MINE\private-sits\all-credentials.md`)

---

## Step 1 — Wait for Vault Pod

```bash
kubectl wait pod/vault-0 -n vault --for=condition=Initialized --timeout=300s
kubectl get pods -n vault
# Expected: vault-0   0/1   Running   0   Xm  (0/1 = sealed, not ready)
```

---

## Step 2 — Initialize Vault

```bash
# Initialize with 5 key shares, 3 threshold (need 3 of 5 keys to unseal)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-init.json

# View output
cat vault-init.json
```

**Save these values from `vault-init.json`:**
- `unseal_keys_b64[0..4]` — 5 unseal keys
- `root_token` — initial root token

> ⚠️ **CRITICAL: Store these in `F:\PROJECTS-MINE\private-sits\all-credentials.md`**
> If you lose the unseal keys, Vault data is permanently inaccessible.

---

## Step 3 — Unseal Vault (3 keys required)

```bash
# Run 3 times with 3 DIFFERENT keys from vault-init.json
kubectl exec -n vault vault-0 -- vault operator unseal <unseal_key_1>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal_key_2>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal_key_3>

# Verify: "Sealed: false"
kubectl exec -n vault vault-0 -- vault status
```

After unsealing, pod becomes `1/1 Ready`.

---

## Step 4 — Enable KV v2 Secrets Engine

```bash
# Login with root token
kubectl exec -n vault vault-0 -- sh -c \
  "VAULT_TOKEN=<root_token> vault secrets enable -path=secret kv-v2"

# Verify
kubectl exec -n vault vault-0 -- sh -c \
  "VAULT_TOKEN=<root_token> vault secrets list"
```

---

## Step 5 — Create Demo Secret (optional)

```bash
kubectl exec -n vault vault-0 -- sh -c \
  "VAULT_TOKEN=<root_token> vault kv put secret/demo \
   username=demo password=S3cr3tP@ssw0rd"

# Verify
kubectl exec -n vault vault-0 -- sh -c \
  "VAULT_TOKEN=<root_token> vault kv get secret/demo"
```

---

## Step 6 — Create vault-token SealedSecret for ESO

External Secrets Operator needs a Vault token to authenticate. Create it as a SealedSecret:

```powershell
# PowerShell on workstation
$token = "<root_token>"  # from vault-init.json

kubectl create secret generic vault-token `
  -n external-secrets `
  --from-literal=token=$token `
  --dry-run=client -o yaml `
  | kubeseal --controller-name=sealed-secrets-controller `
             --controller-namespace=kube-system `
  | kubectl apply -f -
```

Or save to Git:
```bash
kubectl create secret generic vault-token \
  -n external-secrets \
  --from-literal=token=<root_token> \
  --dry-run=client -o yaml \
  | kubeseal --controller-name=sealed-secrets-controller \
             --controller-namespace=kube-system \
  > cluster/secrets/vault-token-sealed.yaml

# Commit and push — ArgoCD will apply it
git add cluster/secrets/vault-token-sealed.yaml
git commit -m "feat(secrets): add vault-token SealedSecret for ESO"
git push
```

---

## Step 7 — Apply ClusterSecretStore

```bash
kubectl apply -f cluster/external-secrets/clustersecretstore.yaml

# Verify status: READY
kubectl get clustersecretstore vault-backend
# Expected: vault-backend   Valid   True   Xm
```

---

## Step 8 — Test ExternalSecret

```bash
kubectl apply -f cluster/external-secrets/example-externalsecret.yaml

# Check sync status
kubectl get externalsecret demo-secret -n default
# Expected: demo-secret   SecretSynced   True   Xs

# Verify K8s secret created
kubectl get secret demo-secret -n default
kubectl get secret demo-secret -n default -o jsonpath='{.data.username}' | base64 -d
# Expected: demo
```

---

## Post-Restart Unseal

> Vault auto-seals on restart (by design). After any Vault pod restart, unseal manually:

```bash
kubectl exec -n vault vault-0 -- vault operator unseal <unseal_key_1>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal_key_2>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal_key_3>
```

**Tip for production:** Use Vault Auto Unseal with a Cloud KMS (Azure Key Vault, AWS KMS) or Transit seal.
For this lab, manual unseal is acceptable.

---

## Vault UI

After unsealing: **https://vault.lab.local**

- Login with root token
- Navigate to **secret/** → KV v2 engine
- Create/read/update secrets via UI

---

## Useful Commands

```bash
# Vault status
kubectl exec -n vault vault-0 -- vault status

# List secrets
kubectl exec -n vault vault-0 -- sh -c \
  "VAULT_TOKEN=<token> vault kv list secret/"

# Write secret
kubectl exec -n vault vault-0 -- sh -c \
  "VAULT_TOKEN=<token> vault kv put secret/myapp api-key=abc123"

# Read secret
kubectl exec -n vault vault-0 -- sh -c \
  "VAULT_TOKEN=<token> vault kv get secret/myapp"

# Check ESO ClusterSecretStore
kubectl get clustersecretstore -A

# Check ExternalSecret sync status
kubectl get externalsecret -A
```
