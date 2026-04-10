# 🌐 Networking: MetalLB, Ingress, cert-manager

## ⚖️ MetalLB (L2 Mode)

> Load Balancer for bare-metal Kubernetes. Without it, `LoadBalancer` services stay in `<pending>`.

### Lab Configuration

| Parameter | Value |
|-----------|-------|
| Mode | L2 (ARP) |
| IP pool | `10.44.81.200 – 10.44.81.250` |
| Ingress EXTERNAL-IP | `10.44.81.200` |

```yaml
# cluster/metallb/ipaddresspool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lab-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.44.81.200-10.44.81.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lab-l2
  namespace: metallb-system
```

---

## 🌐 ingress-nginx

> Routes external HTTPS traffic to services by hostname.

### Ingress Template with TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    cert-manager.io/cluster-issuer: "lab-ca-issuer"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - myapp.lab.local
      secretName: myapp-tls
  rules:
    - host: myapp.lab.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-svc
                port:
                  number: 80
```

### Windows hosts file

```
# C:\Windows\System32\drivers\etc\hosts
10.44.81.200  argocd.lab.local
10.44.81.200  grafana.lab.local
10.44.81.200  longhorn.lab.local
10.44.81.200  wordpress.lab.local
10.44.81.200  kuma.lab.local
10.44.81.200  minio.lab.local
10.44.81.200  strapi.lab.local
10.44.81.200  wiki.lab.local
10.44.81.200  n8n.lab.local
```

---

## 🔒 cert-manager (Internal CA)

> Automatic TLS certificates for `*.lab.local` via an internal CA.

### Lab Configuration

| Parameter | Value |
|-----------|-------|
| Version | v1.19.4 |
| ClusterIssuer | `lab-ca-issuer` |
| CA Secret | `lab-ca-secret` (ns `cert-manager`) |
| CA cert | Imported into Windows → `Cert:\LocalMachine\Root` |

### Verify Certificates

```bash
kubectl get certificates -A
kubectl get clusterissuers
kubectl describe certificate -n <namespace> <name>
```

### Import CA into Windows (to prevent browser warnings)

```powershell
# Export CA from K8s
$caData = kubectl get secret lab-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}'
[System.IO.File]::WriteAllBytes("lab-ca.crt",
  [System.Convert]::FromBase64String($caData))

# Import into trusted roots
Import-Certificate -FilePath "lab-ca.crt" -CertStoreLocation "Cert:\LocalMachine\Root"
```

---

## Screenshots

<figure markdown="span">
  ![NGINX Ingress — status](../assets/images/nginx/devops-lab-nginx.png){ loading=lazy }
  <figcaption>NGINX Ingress Controller — status and routing rules list</figcaption>
</figure>
