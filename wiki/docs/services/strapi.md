# 🗂️ Strapi v4 in Kubernetes

## Lab Configuration

| Parameter | Value |
|-----------|-------|
| Namespace | `strapi` |
| UI/Admin | [https://strapi.lab.local/admin](https://strapi.lab.local/admin) |
| Login | *(created on first login)* |
| Image | `node:18-alpine` (custom bootstrap via initContainer) |
| Strapi version | **v4.26.1** |
| NODE_ENV | `production` |
| Database | SQLite (`/srv/app/.tmp/data.db`) |
| PVC | `strapi-data` — 3Gi (`longhorn-single`) |
| Argo CD | `cluster/argocd/app-strapi.yaml` |
| Status | ✅ `1/1 Running` |

## Quick Commands

```powershell
kubectl get pods -n strapi
kubectl logs -n strapi -f deployment/strapi -c init-strapi  # initContainer (~5 min on first start)
kubectl logs -n strapi -f deployment/strapi
kubectl rollout restart deployment/strapi -n strapi
```

!!! tip "initContainer bootstrap"
    The initContainer performs a full bootstrap: mkdir, project files, npm install, npm run build.
    This takes approximately 5 minutes on first start.

!!! warning "longhorn-single is required"
    StorageClass `longhorn` (2 replicas) may run out of capacity (>82% scheduled).
    Use `longhorn-single` (1 replica) for the `strapi-data` PVC.

---

## Screenshots

<figure markdown="span">
  ![Strapi CMS — Content Manager](../assets/images/strapi/devops-lab-strapi-01.png){ loading=lazy }
  <figcaption>Strapi CMS — Content Manager: creating and editing entries</figcaption>
</figure>

<figure markdown="span">
  ![Strapi CMS — Media Library](../assets/images/strapi/devops-lab-strapi-02.png){ loading=lazy }
  <figcaption>Strapi CMS — Media Library and plugin settings</figcaption>
</figure>
