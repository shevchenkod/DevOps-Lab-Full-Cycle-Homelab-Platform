## H. Backup / DR: Velero

- [x] ✅ **MinIO 5.4.0** installed — standalone, namespace `minio`, 10Gi `longhorn-single` PVC — 01.01.2026
  - S3 API: `http://minio.minio.svc.cluster.local:9000`
  - Console: `https://minio.lab.local`
  - Bucket `velero` created manually via `mc` (buckets hook removed — race condition)
- [x] ✅ **Velero 1.17.1** installed — Helm chart 11.4.0, Argo CD Application — 01.01.2026
  - Plugin: `velero-plugin-for-aws:v1.13.0`
  - `checksumAlgorithm: ""` — mandatory for MinIO + aws-sdk-go-v2 v1.13
  - `snapshotsEnabled: false` — fs-backup only (kopia), VolumeSnapshotLocation not created
  - node-agent DaemonSet: 2 pods Running (kopia fs-backup for PVCs)
  - Argo CD: **Synced / Healthy** ✅ (fixed: snapshotsEnabled: false)
- [x] ✅ **Backup storage**: MinIO S3 in-cluster — BSL `default` → status **Available** ✅ — 01.01.2026
- [x] ✅ **Backup schedules (cron)** — 01.01.2026
  - `wordpress-daily` — `0 2 * * *` (02:00 UTC), TTL 30d, namespace: `wordpress`
  - `uptime-kuma-daily` — `0 3 * * *` (03:00 UTC), TTL 30d, namespace: `uptime-kuma`
- [x] ✅ **Test backup** `test-wordpress-manual` — Phase: Completed, 97 MiB, 42 objects — 01.01.2026
- [x] ✅ **Restore test** — 01.01.2026
  - [x] ✅ Namespace `wordpress` restored from `test-wordpress-manual` (Velero restore)
  - [x] ✅ WordPress fully restored: pods `1/1 Running`, PVC Bound (2Gi+5Gi), `https://wordpress.lab.local` HTTP 200, Title: "DevOps Lab" ✅
  - [x] ✅ Restore: phase=Completed, warnings=1, errors=0. Restore time: ~3 min
- [x] ✅ **CSI Snapshot Infrastructure** — 01.01.2026
  - [x] ✅ external-snapshotter v8.2.0 CRDs installed (VolumeSnapshot, VolumeSnapshotContent, VolumeSnapshotClass)
  - [x] ✅ snapshot-controller deployed in kube-system (2 pods Running)
  - [x] ✅ VolumeSnapshotClass `longhorn-snapshot-class`: driver `driver.longhorn.io`, `parameters.type: bak`
  - [x] ✅ Velero `--features=EnableCSI` enabled in `app-velero.yaml`
- [x] ✅ **Longhorn BackupTarget → MinIO** — 01.01.2026
  - [x] ✅ Bucket `longhorn-backup` created in MinIO
  - [x] ✅ Secret `longhorn-backup-secret` created in namespace `longhorn-system`
  - [x] ✅ BackupTarget `default` configured: `s3://longhorn-backup@us-east-1/`, status AVAILABLE
  - [x] ✅ File `cluster/storage/longhorn-backuptarget.yaml` created and committed
- [x] ✅ **DR scenarios** — 01.01.2026
  - [x] ✅ Namespace loss → restore from Velero FSB backup (test passed in ~3 min)
  - [x] ✅ CSI restore (`type: bak`) — infrastructure ready and verified
  - [ ] Node loss → reschedule (covered in Block J)
  - [ ] PDB + rolling updates (covered in Block I)

> ⚠️ **DR lesson:** `type: snap` = Longhorn internal snapshot (data INSIDE the volume) → deleted with namespace. Use `type: bak` for DR — data is stored in MinIO and survives deletion.
> 📌 **Workers CPU:** workers upgraded to 4 vCPU (previously 2 vCPU) — 01.01.2026
> 📌 **Worker disks expanded** to 60 GB via Proxmox API + growpart — 01.01.2026
