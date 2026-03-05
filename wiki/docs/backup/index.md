# 💾 Backup & DR: Velero + MinIO

> Velero backs up K8s resources and PVCs to MinIO (S3-compatible storage).

## Lab Configuration

| Parameter | Value |
|-----------|-------|
| Velero | v1.17.1 (Helm 11.4.0) |
| Plugin | velero-plugin-for-aws v1.13.0 |
| Backend | MinIO (`s3://velero-backups`) |
| MinIO URL | `http://minio.minio.svc:9000` (internal) / [minio.lab.local](https://minio.lab.local) |
| MinIO credentials | minioadmin / `DevOpsLab2026!` |
| BSL Status | Available ✅ |
| Schedules | `daily-cluster` (0 2 * * *) + `hourly-ns` (0 * * * *) |
| VolumeSnapshotClass | `longhorn-snapshot-class` (type: **bak**) |
| Argo CD | `cluster/argocd/app-velero.yaml` |

## Key Commands

```bash
# Status
velero backup get
velero schedule get
velero backup-location get

# Create a manual backup
velero backup create manual-$(date +%Y%m%d) --wait

# Backup a namespace
velero backup create ns-wiki --include-namespaces wiki --wait

# Restore
velero restore create --from-backup manual-20260301 --wait

# Logs
kubectl logs deployment/velero -n velero --tail=50
```

## DR Drill — Restore Verification

```bash
# 1. Create backup
velero backup create dr-test-$(date +%Y%m%d) --include-namespaces wordpress --wait
velero backup describe dr-test-$(date +%Y%m%d) --details

# 2. Delete namespace
kubectl delete namespace wordpress

# 3. Restore
velero restore create --from-backup dr-test-$(date +%Y%m%d) --wait

# 4. Verify
kubectl get pods -n wordpress
curl -sk https://wordpress.lab.local | grep -i "wordpress"
```

## MinIO — Console

| Parameter | Value |
|-----------|-------|
| URL | [https://minio.lab.local](https://minio.lab.local) |
| Access Key | `minioadmin` |
| Secret Key | `DevOpsLab2026!` |
| Bucket (velero) | `velero-backups` |
| Bucket (longhorn) | `longhorn-backup` |
| PVC | 10Gi `longhorn-single` |

---

!!! danger "CRITICAL: type: bak vs type: snap"
    This is the most costly lesson in this project. **See [Lessons Learned](../lessons/index.md).**

    | `type: snap` | `type: bak` |
    |-------------|-------------|
    | Data inside Longhorn volume (in-cluster) | Data in MinIO/S3 (external) |
    | ❌ Deleted with namespace | ✅ Survives deletion |
    | ❌ NOT for DR | ✅ For DR |

    Always use `type: bak` in `longhorn-snapshot-class`.

!!! warning "checksumAlgorithm for MinIO"
    velero-plugin-for-aws v1.13.0+ adds `x-amz-checksum-*` headers that MinIO does not understand.

    In `values.yaml`, this is mandatory:
    ```yaml
    configuration:
      backupStorageLocation:
        - config:
            checksumAlgorithm: ""   # ← REQUIRED for MinIO
    ```
