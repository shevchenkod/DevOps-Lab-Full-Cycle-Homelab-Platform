# 📚 Wiki (MkDocs Material)

> This wiki. A static site built from Markdown, deployed to Kubernetes via nginx:alpine.

## Configuration

| Parameter | Value |
|-----------|-------|
| Namespace | `wiki` |
| URL | [https://wiki.lab.local](https://wiki.lab.local) |
| Image | `10.44.81.110:30500/wiki:latest` (nginx:alpine + MkDocs site) |
| Source | `wiki/` → mkdocs build → `site/` |
| MkDocs Material | 9.7.1 |
| Argo CD | `cluster/argocd/app-wiki.yaml` |
| Ingress | `10.44.81.200` → `wiki.lab.local` |
| Status | ✅ `1/1 Running` |

## Dockerfile

```dockerfile
FROM nginx:alpine
RUN rm -rf /usr/share/nginx/html/*
COPY site/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

## Content Update Process

```powershell
# 1. Rebuild site/ (from directory containing mkdocs.yml)
python -m mkdocs build

# 2. SCP to master
# ⚠️ NO trailing slash on source (Windows SCP creates double nesting site/site/)
scp -i "H:\DEVOPS-LAB\ssh\devops-lab" -r site ubuntu@10.44.81.110:/tmp/wiki-build/

# 3. Build + push image
ssh -i "H:\DEVOPS-LAB\ssh\devops-lab" ubuntu@10.44.81.110 `
  "cd /tmp/wiki-build && sudo nerdctl --namespace k8s.io build -t 10.44.81.110:30500/wiki:latest . && sudo nerdctl --namespace k8s.io push --insecure-registry 10.44.81.110:30500/wiki:latest"

# 4. Restart pod (imagePullPolicy: Always)
kubectl rollout restart deployment/wiki -n wiki
kubectl get pods -n wiki -w
```

## Monitoring

```powershell
kubectl get pods -n wiki -o wide
kubectl logs -n wiki deployment/wiki --tail=50
kubectl describe pod -n wiki -l app=wiki
```

!!! note "imagePullPolicy: Always"
    Kubernetes pulls a fresh image on every pod restart.
    Argo CD only watches manifests, not the `latest` tag — a `rollout restart` is required to pick up a new image.
