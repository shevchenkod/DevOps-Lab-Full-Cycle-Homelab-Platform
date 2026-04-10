# 📝 WordPress in Kubernetes

## Lab Configuration

| Parameter | Value |
|-----------|-------|
| Namespace | `wordpress` |
| UI | [https://wordpress.lab.local](https://wordpress.lab.local) |
| Login | Local admin account |
| Helm chart | Bitnami `wordpress 29.1.2` |
| WordPress image | `bitnamilegacy/wordpress:6.8.2-debian-12-r5` |
| MariaDB image | `bitnamilegacy/mariadb:11.8.3-debian-12-r0` |
| WP PVC | `wordpress` — 5Gi (Longhorn) |
| DB PVC | `data-wordpress-mariadb-0` — 2Gi (Longhorn) |
| Argo CD | `cluster/argocd/app-wordpress.yaml` |
| Status | ✅ `1/1 Running` |

## Quick Commands

```powershell
kubectl get pods -n wordpress
kubectl logs -n wordpress deployment/wordpress --tail=50
kubectl rollout restart deployment/wordpress -n wordpress
```

!!! warning "Bitnami DockerHub"
    Bitnami removed all `docker.io/bitnami/*` images from DockerHub.
    Use `bitnamilegacy` — the official legacy repository for Debian-based images.

---

## Screenshots

<figure markdown="span">
  ![WordPress — main page](../assets/images/wordpress/devops-lab-wordpress-01.png){ loading=lazy }
  <figcaption>WordPress — lab site main page</figcaption>
</figure>
