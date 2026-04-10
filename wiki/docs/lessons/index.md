## 🚨 Lessons Learned — Грабли и нюансы

> Этот раздел собран из реального опыта настройки лаборатории.  
> Каждый пункт — это конкретная проблема, в которую можно наступить, и её решение.  
> **Читай это ПЕРЕД тем, как делать что-то первый раз.**

---

### 1. 💾 Velero + MinIO — обязательный параметр `checksumAlgorithm`

**Проблема:** бэкап завершается с ошибкой InvalidChecksum / SignatureDoesNotMatch.

**Причина:** velero-plugin-for-aws начиная с v1.13.0 перешёл на `aws-sdk-go-v2`, который по умолчанию добавляет `x-amz-checksum-*` заголовки. MinIO их не понимает.

**Решение:** В `values.yaml` Velero обязательно добавь:
```yaml
configuration:
  backupStorageLocation:
    - config:
        checksumAlgorithm: ""   # ← ОБЯЗАТЕЛЬНО для MinIO
```

> ⚠️ Без этого параметра Velero + MinIO не работает. Актуально для velero-plugin-for-aws **v1.13.0+**.

---

### 2. 📸 Longhorn CSI: `type: snap` vs `type: bak` — КРИТИЧЕСКИ ВАЖНО для DR

**Это самый дорогостоящий урок в этом проекте.**

| Параметр | `type: snap` | `type: bak` |
|----------|-------------|-------------|
| Где хранятся данные | Внутри Longhorn volume (в кластере) | Во внешнем BackupTarget (MinIO/S3) |
| Выживает при удалении namespace? | ❌ **НЕТ** — удаляется вместе с volume | ✅ **ДА** |
| Подходит для Disaster Recovery? | ❌ **НЕТ** | ✅ **ДА** |
| Требует BackupTarget? | ❌ Нет | ✅ **ДА** |
| Скорость создания | Мгновенно | Медленнее (копирует в S3) |

**Симптомы использования `type: snap` как DR-backup:**
- Velero backup — `Phase: Completed` (выглядит успешно!)
- Namespace удалён → Velero restore → pods застряли в `Init:0/1`
- `kubectl describe volumesnapshot ...` → `VolumeCloneFailed: cannot find source volume pvc-xxxxxx`
- Причина: `snapshotHandle: snap://pvc-xxx/snapshot-xxx` — данные жили внутри удалённого volume

**Правило:** Для любого CSI backup предназначенного для DR — **всегда `type: bak`**.

```yaml
# cluster/storage/longhorn-volumesnapshotclass.yaml
parameters:
  type: bak   # ← DR-safe: данные идут в MinIO через BackupTarget
  # type: snap  ← НЕ использовать для DR!
```

---

### 3. 🎯 Longhorn BackupTarget — это CRD, не настройка в UI

**Проблема:** BackupTarget настроен в UI Longhorn, но после рестарта или при применении через GitOps — не сохраняется / не работает.

**Причина:** BackupTarget — это отдельный CRD `backuptargets.longhorn.io`, а не просто Setting. Управлять им нужно как K8s-ресурсом.

**Решение:** Создать манифест и применять через `kubectl apply`:
```yaml
apiVersion: longhorn.io/v1beta2
kind: BackupTarget
metadata:
  name: default
  namespace: longhorn-system
spec:
  backupTargetURL: "s3://longhorn-backup@us-east-1/"
  credentialSecret: "longhorn-backup-secret"
  pollInterval: "5m0s"
```

**Secret** с точными ключами (другие ключи не работают):
```yaml
stringData:
  AWS_ACCESS_KEY_ID: "minioadmin"
  AWS_SECRET_ACCESS_KEY: "your-password"
  AWS_ENDPOINTS: "http://minio.minio.svc.cluster.local:9000"
```

**Формат URL:** `s3://bucket-name@region/` — `@region` обязателен даже для MinIO, используй любой (например `us-east-1`).

> ✅ Проверка: `kubectl get backuptargets.longhorn.io -n longhorn-system` → поле `AVAILABLE` должно быть `True`.

---

### 4. 📦 external-snapshotter — порядок установки важен

**Проблема:** VolumeSnapshot не создаётся, ошибка "no kind VolumeSnapshotClass registered".

**Причина:** CRDs от external-snapshotter не установлены или установлены не в том порядке.

**Правильный порядок:**
```bash
# 1. Сначала CRDs (из репо kubernetes-csi/external-snapshotter, ветка release-8.2)
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

# 2. Потом controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v8.2.0/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
```

> ⚠️ Версия v8.2.0 совместима с Kubernetes v1.30.x. Для других версий K8s — смотри [таблицу совместимости](https://github.com/kubernetes-csi/external-snapshotter#compatibility).

---

### 5. 🌐 Ingress-NGINX — `configuration-snippet` заблокирован по умолчанию

**Проблема:** Ingress с аннотацией `nginx.ingress.kubernetes.io/configuration-snippet: |` не применяется, конфиг игнорируется.

**Причина:** В современных версиях ingress-nginx `allow-snippet-annotations: false` — это дефолт ради безопасности (защита от SSRF через Lua-снипеты).

**Симптомы:** Uptime Kuma не показывает статусы (WebSocket не работает), в логах nginx нет пользовательских директив.

**Решение:** Не используй `configuration-snippet`. Для WebSocket и аналогичных задач — используй стандартные аннотации:
```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
  nginx.ingress.kubernetes.io/proxy-set-headers: "Upgrade, Connection"
```

---

### 6. ⚙️ containerd + Kubernetes — `SystemdCgroup = true` обязателен

**Проблема:** Nodes в статусе `NotReady`, kubelet крашится.

**Причина:** kubelet по умолчанию ожидает `cgroupDriver: systemd`, а containerd по умолчанию использует `cgroupfs`. Конфликт драйверов cgroup.

**Решение:** В `/etc/containerd/config.toml` (на ВСЕХ нодах):
```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

После изменения: `systemctl restart containerd`.

> Если настраиваешь через Ansible — добавь это как задачу в playbook, иначе ноды нестабильны.

---

### 7. 🗄️ Longhorn — prerequisites на ВСЕХ нодах (включая master)

**Проблема:** Longhorn поды Running, но PVC не монтируется, pod застревает в `ContainerCreating`.

**Причина:** На ноде не установлен `open-iscsi` или не загружен модуль `iscsi_tcp`.

**Что должно быть на КАЖДОЙ ноде (включая control-plane):**
```bash
# Пакеты
apt install -y open-iscsi multipath-tools

# Сервис
systemctl enable --now iscsid

# Модуль ядра — загрузить сейчас
modprobe iscsi_tcp

# Модуль ядра — загружать при старте
echo "iscsi_tcp" > /etc/modules-load.d/iscsi_tcp.conf
```

> ✅ Проверка: `systemctl is-active iscsid` → `active`, `lsmod | grep iscsi_tcp` → есть.

---

### 8. 💽 Longhorn — нехватка места при scheduledStorage > 80%

**Проблема:** PVC не создаётся, ошибка `insufficient storage`.

**Причина:** Longhorn рассчитывает `scheduledStorage` исходя из реплик. При 2 репликах и 2 воркерах, когда занято > 80% — новые PVC отклоняются.

**Решение:** Создать отдельный StorageClass с одной репликой для некритичных нагрузок:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-single
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "1"   # ← 1 реплика
  staleReplicaTimeout: "2880"
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

> Используй `longhorn-single` для: MinIO, Loki, Strapi, dev-окружений. `longhorn` (2 реплики) — для WordPress, Prometheus, критичных данных.

---

### 9. 🪣 MinIO Helm — race condition при создании bucket через hooks

**Проблема:** После `helm install` bucket не создан, хотя в `values.yaml` указан `buckets: [{name: velero, policy: none}]`.

**Причина:** Helm Job-hook для создания bucket запускается до того, как MinIO под успел инициализироваться. Race condition.

**Решение:** Убрать `buckets:` из `values.yaml`. Создавать вручную через `mc` после деплоя:
```bash
# Получить доступ к mc внутри пода MinIO
kubectl exec -n minio deploy/minio -- \
  mc alias set myminio http://localhost:9000 minioadmin DevOpsLab2026! --api s3v4

# Создать bucket
kubectl exec -n minio deploy/minio -- mc mb myminio/velero
kubectl exec -n minio deploy/minio -- mc mb myminio/longhorn-backup
```

---

### 10. 🔄 Velero + Argo CD — OutOfSync из-за VolumeSnapshotLocation

**Проблема:** Velero Application в Argo CD постоянно показывает `OutOfSync`, хотя конфиг не менялся.

**Причина:** Velero при `snapshotsEnabled: true` (дефолт) автоматически создаёт `VolumeSnapshotLocation` ресурс. Argo CD видит этот ресурс как "лишний" и считает состояние отличным от Git.

**Решение:**
```yaml
# В values.yaml для Velero:
snapshotsEnabled: false   # отключить управление VSL

# А EnableCSI включать через:
configuration:
  features: EnableCSI     # ← это отдельный feature flag, не связан с snapshotsEnabled
```

> `snapshotsEnabled: false` + `features: EnableCSI` — корректная комбинация для MinIO-бэкапов с CSI snapshot поддержкой.

---

### 11. 🔒 cert-manager — цепочка CA и доверие Windows

**Как правильно настроить внутренний CA:**

```
selfSigned ClusterIssuer
    ↓  выпускает
Certificate (isCA: true, kind: Certificate)
    ↓  сохраняется как
Secret (тип: kubernetes.io/tls)
    ↓  используется как источник в
CA ClusterIssuer (spec.ca.secretName: ...)
    ↓  выпускает
Сертификаты для всех сервисов
```

**Важно:** В `Certificate` для корневого CA обязательно `isCA: true`:
```yaml
spec:
  isCA: true
  usages:
    - cert sign
    - crl sign
```

**Доверие в Windows** (один раз, запустить от администратора):
```powershell
# Скопировать crt с кластера
kubectl get secret lab-root-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | `
  [System.Convert]::FromBase64String([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))) | `
  Set-Content -Path "lab-root-ca.crt" -Encoding Byte

# Или через scp, потом импортировать:
Import-Certificate -FilePath "lab-root-ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

---

### 12. 🚀 Argo CD — credentials для private GitHub repo

**Проблема:** Argo CD не может подключиться к репозиторию, ошибка authentication.

**Правило:** Credentials хранить в K8s Secret, НЕ в Application манифесте:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-devops-lab
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository   # ← обязательный label
stringData:
  type: git
  url: https://github.com/shevchenkod/devops-lab.git
  username: shevchenkod
  password: ghp_xxxx   # GitHub Personal Access Token
```

---

### 13. 🌿 Calico CNI — pod CIDR должен совпадать

**Проблема:** После `kubectl apply -f calico.yaml` поды Calico в CrashLoop, networking не работает.

**Причина:** В `kubeadm init` указан CIDR, не совпадающий с Calico-дефолтом.

**Правило:** Calico по умолчанию ожидает `192.168.0.0/16`. Используй именно этот CIDR:
```bash
kubeadm init --pod-network-cidr=192.168.0.0/16
```

Или в `kubeadm-config.yaml`:
```yaml
networking:
  podSubnet: "192.168.0.0/16"
```

---

### 14. 🗂️ Strapi v4 в Kubernetes — полный список граблей (01.03.2026)

> Перешли с v5 → **v4.26.1**. Strapi v5 нестабильна: create-strapi-app интерактивна, плагины отсутствуют на npm, Node<20 не поддерживается.

#### Грабля 1: `npm run develop` зависает → SIGINT
- **Причина:** интерактивный вопрос `Install react? (Y/n)` — K8s перенаправляет stdin в pipe → SIGINT при отсутствии ответа
- **Решение:** ТОЛЬКО `npm run start` в K8s (production-режим без интерактивности)

#### Грабля 2: `npm run start` падает — Admin panel not built
- **Причина:** `strapi start` требует заранее собранную admin-панель
- **Решение:** добавить шаг в initContainer: `NODE_ENV=production npm run build`; только после сборки — основной контейнер `npm run start`  

#### Грабля 3: react / react-dom отсутствуют
- **Причина:** при ручном scaffold (без create-strapi-app) react не добавляется в package.json
- **Решение:** явно добавить в dependencies: `react@^18`, `react-dom@^18`, `react-router-dom@^5`, `styled-components@^5`  

#### Грабля 4: `public/uploads` не существует при старте
- **Причина:** Strapi создаёт директорию только если существует parent; при монтировании PVC структура пуста
- **Решение:** `mkdir -p /srv/app/public/uploads /srv/app/.tmp` в самом начале initContainer, **ДО** early-exit check  

#### Грабля 5: `better-sqlite3` требует `python3` / `make` / `g++`  
- **Причина:** нативный C++ модуль, требует build-tools при `npm install`  
- **Решение:** `apk add --no-cache python3 make g++` в initContainer перед `npm install`  

#### Грабля 6: `@strapi/plugin-i18n@^5.0.0` не существует на npm
- **Причина:** Strapi v5 плагины не опубликованы / другой scope
- **Решение:** использовать v4: `@strapi/plugin-i18n@4.25.23`  

#### Грабля 7: Strapi v5 требует Node≥20
- **Причина:** `engines: { node: '>=20.x' }` в Strapi v5 package.json
- **Решение:** `node:18-alpine` + Strapi **v4.26.1** = рабочая связка; v5 — только с node:20+  

#### Грабля 8: Strapi + WordPress на одном ноде (resource contention)
- **Причина:** оба на `k8s-worker-02`; initContainer потребляет 2 CPU + 2.5Gi во время `npm install` + `npm run build` → MariaDB не получает ресурсы → WordPress падает
- **Решение:** `nodeAffinity` разнести по нодам, или уменьшить `limits` initContainer до 1CPU/1Gi  

#### Грабля 9: Multi-Attach error (RWO PVC)
- **Причина:** при RollingUpdate новый pod стартует до завершения старого → оба пытаются примонтировать один RWO PVC
- **Решение:** `strategy: type: Recreate` в Deployment  

#### Грабля 10: TLS timeout на `kubectl logs` (worker:10250)
- **Причина:** kubelet API на `k8s-worker-01:10250` недоступен извне (firewall / сеть)
- **Решение:** повторить позже; использовать `kubectl describe pod` + events для диагностики без прямого обращения к kubelet  

---

### 15. 💿 Proxmox — resize диска VM (важен порядок)

**Проблема:** После `qm resize` в Proxmox, место внутри VM не увеличилось.

**Причина:** Proxmox расширяет диск на уровне гипервизора, но OS не знает об этом до `growpart` и `resize2fs`.

**Правильная последовательность (Ubuntu с ext4, без LVM):**
```bash
# Внутри VM:
growpart /dev/sda 1       # расширить раздел
resize2fs /dev/sda1       # расширить ФС
df -h                     # проверить
```

**Для Ubuntu с LVM (стандартная cloud-image):**
```bash
growpart /dev/sda 3       # расширить раздел с LVM PV
pvresize /dev/sda3        # расширить Physical Volume
lvresize -l +100%FREE /dev/ubuntu-vg/ubuntu-lv   # расширить Logical Volume
resize2fs /dev/ubuntu-vg/ubuntu-lv               # расширить ФС
```

**Через Proxmox REST API (с Windows):**
```powershell
# Resize через API (node=pve01, vmid=111, disk=scsi0, size=+40G)
Invoke-WebRequest -Uri "https://10.44.81.101:8006/api2/json/nodes/pve01/qemu/111/resize" `
  -Method PUT `
  -Headers @{"Authorization" = "PVEAPIToken=terraform@pve!token=xxx"} `
  -Body "disk=scsi0&size=+40G" `
  -SkipCertificateCheck
```

---

### 16. ☸️ kubectl на Windows — быстрый доступ к кластеру

**Настройка:**
```powershell
# Разово в текущей сессии:
$env:KUBECONFIG = "H:\DEVOPS-LAB\kubeconfig-lab.yaml"

# Постоянно (добавить в $PROFILE):
Add-Content $PROFILE '$env:KUBECONFIG = "H:\DEVOPS-LAB\kubeconfig-lab.yaml"'

# Проверка:
kubectl get nodes -o wide
```

> `kubeconfig-lab.yaml` содержит `insecure-skip-tls-verify: true` для API server — это нормально для lab-окружения с self-signed сертификатом.

---

### 17. 🐳 Velero CLI — distroless образ, нет shell

**Проблема:** `kubectl exec -it -n velero deploy/velero -- sh` → `OCI runtime exec failed: exec: "sh": executable file not found`.

**Причина:** Velero использует distroless образ — в нём нет shell (`sh`, `bash`), только бинарник `/velero`.

**Решение:**
```bash
# Всегда так (без -it, указывать /velero явно):
VELERO_POD=$(kubectl get pod -n velero -l app.kubernetes.io/name=velero -o name | head -1)

kubectl exec -n velero $VELERO_POD -- /velero backup get
kubectl exec -n velero $VELERO_POD -- /velero restore create --from-backup my-backup
kubectl exec -n velero $VELERO_POD -- /velero schedule get
```

---

### 18. 📊 Longhorn HA — drain ноды не означает потерю данных

**Важное понимание:** При `kubectl drain` нода становится `SchedulingDisabled`, но Longhorn volume с репликами продолжает работать через реплику на другой ноде.

**Проверено:**
```bash
kubectl drain k8s-worker-01 --ignore-daemonsets --delete-emptydir-data
# Pod переезжает на worker-02
# Longhorn монтирует volume с реплики на worker-02
# Данные целы ✅

kubectl uncordon k8s-worker-01
# Нода возвращается в ротацию
```

> Работает только если у volume **2+ реплики** (StorageClass `longhorn`, не `longhorn-single`).

---

### 19. 🔑 Версионная совместимость — таблица

| Компонент | Версия в lab | Совместимость / заметки |
|-----------|-------------|------------------------|
| Kubernetes | v1.30.14 | kubeadm, Ubuntu 24.04 |
| containerd | 1.7.28 | `SystemdCgroup = true` обязательно |
| Calico | v3.27.3 | pod CIDR 192.168.0.0/16 |
| Helm | v3.20.0 | установлен на master |
| Longhorn | Helm latest | prereqs: open-iscsi + iscsi_tcp на ВСЕХ нодах |
| external-snapshotter | **v8.2.0** | CRDs до controller; совместим с K8s 1.30 |
| cert-manager | **v1.19.4** | CRDs отдельно или `--set crds.enabled=true` |
| Velero | **v1.17.1** | Helm chart 11.4.0 |
| velero-plugin-for-aws | **v1.13.0** | `checksumAlgorithm: ""` для MinIO |
| MinIO chart | 5.4.0 | не использовать bucket hooks (race condition) |
| Argo CD | v2.14 | `server.insecure: true` + TLS на ingress |
| kube-prometheus-stack | Helm | PVC на longhorn (2 реплики) |
| Loki | **6.29.0** chart | singleBinary, PVC longhorn-single |
| Promtail | **6.16.6** chart | DaemonSet, толерации для master |
| WordPress | Bitnami chart 29.1.2 | `bitnamilegacy` debian images |
| Strapi | **v4.26.1** (node:18-alpine) | initContainer bootstrap, `NODE_ENV=production`, `npm run start` |

---

### 20. 💡 Общие правила (выведены из практики)

1. **Всегда проверяй `kubectl events`** перед тем как рестартить поды — там причина.
2. **PVC в состоянии `Pending`** → смотри `kubectl describe pvc` → причина в Events.
3. **Longhorn volume `detached`** после restore → значит snapshot был `type:snap`, данные потеряны.
4. **ArgoCD OutOfSync** — не всегда ошибка. Проверь `ignoreDifferences` перед паникой.
5. **MinIO + Velero** — всегда `checksumAlgorithm: ""`, иначе не работает.
6. **CSI backup** — всегда проверяй BackupTarget AVAILABLE перед запуском.
7. **Диски воркеров** — расширяй заранее, а не когда уже нет места. Порог: 70% free disk.
8. **StorageClass** — для критичных данных 2 реплики (`longhorn`), для dev 1 реплика (`longhorn-single`).
9. **ingress-nginx** — не используй `configuration-snippet`, он отключён по умолчанию.
10. **Velero restore** — перед restore убедись что namespace удалён, иначе конфликт ресурсов.

---

### 21. 🗂️ Windows SCP — trailing slash создаёт двойное вложение site/site/

**Проблема:** После `scp -r site/ user@host:/path/site/` — в NGINX `403 Forbidden`, папка `/path/site/site/` вместо `/path/site/`.

**Причина:** Windows OpenSSH при `scp -r <src>/` копирует директорию **внутрь** существующей цели.
Если `/path/site/` уже существует, содержимое попадает в `/path/site/site/` — двойное вложение.

**Решение:**
```powershell
# НЕПРАВИЛЬНО (trailing slash у source):
scp -r site/ ubuntu@host:/tmp/wiki-build/site/

# ПРАВИЛЬНО (без trailing slash — SCP создаст site/ внутри wiki-build/):
scp -r site ubuntu@host:/tmp/wiki-build/
```

Если вложение уже создано — исправить на сервере:
```bash
cd /tmp/wiki-build
mv site/site site_correct && rm -rf site && mv site_correct site
```

---

### 22. 📊 MinIO Console — пустые графики Usage/Traffic/Resources

**Проблема:** MinIO Console → Metrics → вкладки Usage, Traffic, Resources показывают пустые графики с пунктирными рамками.

**Причина:** `MINIO_PROMETHEUS_JOB_ID` не совпадает с реальным `job` label в Prometheus.
MinIO Console запрашивает метрики с `{job="<JOB_ID>"}` — если label другой, данных нет.

**Prometheus job label** задаётся из `metadata.name` ServiceMonitor:
```yaml
# ServiceMonitor metadata.name: minio  →  job = "minio"
```

**Решение:**
```yaml
# cluster/argocd/app-minio.yaml
environment:
  MINIO_PROMETHEUS_JOB_ID: "minio"   # должен точно совпадать с именем ServiceMonitor
```

**Проверка:**
```powershell
# Проверить реальный job label в Prometheus
(Invoke-RestMethod "http://localhost:9090/api/v1/targets").data.activeTargets |
  Where-Object {$_.labels.job -like "*minio*"} |
  Select-Object @{N="job";E={$_.labels.job}}, health
```

---

### 23. 📋 MinIO Audit Webhook — несовместимый формат с Loki Push API

**Проблема:** MinIO Console → Logs показывает ошибки:
`unable to send audit/log entry(s) err 'Loki returned 422 Unprocessable Entity'`

**Причина:** MinIO отправляет audit-события как raw JSON объект `{...}`.
Loki Push API (`/loki/api/v1/push`) ожидает строгий формат:
```json
{"streams": [{"stream": {"job": "minio"}, "values": [["<unix_nano>", "<log_line>"]]}]}
```
Эти форматы несовместимы без промежуточного адаптера.

**Решение для лаборатории:** Не использовать `MINIO_AUDIT_WEBHOOK_*` напрямую с Loki.
Вместо этого — Promtail DaemonSet автоматически собирает логи пода MinIO и отправляет в Loki:
```logql
# В Grafana → Explore → Loki:
{namespace="minio"}
```

**Если нужен полный audit pipeline:** использовать Vector или Fluentbit как адаптер между MinIO webhook и Loki.

---

### 24. 🚀 Argo CD App-of-Apps — почему отдельный kubectl apply для каждого сервиса — антипаттерн

**Проблема:** При добавлении нового сервиса приходится вручную делать `kubectl apply -f cluster/argocd/app-new.yaml`. При росте числа приложений (10+) это неудобно, легко забыть, и нет единой точки управления всеми Application-объектами.

**Причина:** Без App-of-Apps Argo CD Applications живут вне гита — они применены вручную, и Argo CD сам за ними не следит.

**Решение — App-of-Apps паттерн:**

```
app-of-apps (root Application)
  └── watches: cluster/apps/
        ├── app-wordpress.yaml   → Application: wordpress
        ├── app-minio.yaml       → Application: minio
        ├── app-wiki.yaml        → Application: wiki
        └── app-*.yaml           → ...
```

```yaml
# cluster/argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/shevchenkod/devops-lab.git
    targetRevision: HEAD
    path: cluster/apps      # директория с app-*.yaml манифестами
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true       # удалить Application если app-*.yaml удалён из git
      selfHeal: true
```

**Workflow после внедрения:**
```bash
# Добавить новый сервис:
# 1. Создать cluster/apps/app-newservice.yaml
# 2. git add + commit + push
# 3. Argo CD автоматически обнаружит и задеплоит
# kubectl apply больше не нужен!
```

**Adoption существующих apps:** Argo CD автоматически «усыновляет» уже существующие Application-объекты с таким же name/namespace — пересоздания не происходит, downtime нет.

> ⚠️ Применить root app нужно один раз вручную: `kubectl apply -f cluster/argocd/app-of-apps.yaml`. После этого все последующие Application-манифесты подхватываются автоматически через git push.

### 25. ☸️ Upgrade Kubernetes кластера (kubeadm) — v1.30 → v1.31

**Правило:** Kubernetes можно обновлять только на **одну minor версию** за раз (v1.30 → v1.31, не v1.30 → v1.32). Пропускать версии нельзя — kubeadm проверяет это принудительно.

**Процедура (для каждой ноды):**

```bash
# 0. Добавить apt-репозиторий для новой minor версии (на каждой ноде)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-v1.31-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-v1.31-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes-v1.31.list

# 1. Control-plane: upgrade apply (только на master)
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.31.14-1.1
sudo apt-mark hold kubeadm
sudo kubeadm upgrade apply v1.31.14 --yes

# 2. Drain ноды (workload уходит на другие ноды, DaemonSet остаётся)
kubectl drain k8s-master-01 --ignore-daemonsets --delete-emptydir-data

# 3. Upgrade kubelet + kubectl, перезапуск
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.31.14-1.1 kubectl=1.31.14-1.1
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# 4. Uncordon — нода снова принимает поды
kubectl uncordon k8s-master-01

# ---- Для worker-нод (повторить для каждой) ----
kubectl drain k8s-worker-01 --ignore-daemonsets --delete-emptydir-data
# На worker: добавить repo + установить пакеты + kubeadm upgrade node + restart kubelet
sudo kubeadm upgrade node
kubectl uncordon k8s-worker-01
```

**Ключевые нюансы:**
- Каждая minor версия имеет **отдельный apt-репозиторий** — нужно добавлять вручную
- Пакеты держатся на hold — перед upgrade: `apt-mark unhold`, после: `apt-mark hold`
- `kubeadm upgrade apply` — **только на control-plane** (master)
- `kubeadm upgrade node` — **только на worker-нодах**
- После drain нода показывает `Ready,SchedulingDisabled` — workload эвакуируется на другие ноды
- Версия ноды в `kubectl get nodes` обновляется после `systemctl restart kubelet`

> ✅ Кластер обновлён: v1.30.14 → v1.31.14 (все 3 ноды Ready) — 01.03.2026
---
### 26. 📊 SLO/SLI: Service Level Objectives в Kubernetes

**Концепции:**
- **SLI** (Service Level Indicator) — измеримый показатель качества: доля успешных запросов, задержка P99, uptime
- **SLO** (Service Level Objective) — целевое значение SLI: "99.5% запросов без 5xx за 30 дней"
- **Error Budget** = (1 - SLO) × период = допустимое количество ошибок

**Наш SLO для WordPress:**
- Availability SLO: **99.5%** (error budget = 216 мин/мес)
- Latency SLO: **95%** запросов быстрее 500ms

**Стек:**

```bash
# 1. Включить NGINX Ingress metrics (если не включены)
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --reuse-values \
  --set controller.metrics.enabled=true

# 2. Создать ServiceMonitor (Prometheus Operator)
# cluster/monitoring/servicemonitor-ingress-nginx.yaml

# 3. Создать PrometheusRule с recording rules + alerts
# cluster/monitoring/prometheusrule-wordpress-slo.yaml

# 4. Проверить target в Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
curl -sG http://localhost:9090/api/v1/targets | grep ingress

# 5. Проверить recording rules
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=job:wordpress_request_error_rate:ratio_rate5m'
```

**Multi-window Multi-burn-rate алерты (Google SRE Book, ch.5):**

| Burn Rate | Окно | Интерпретация | Severity |
|-----------|------|---------------|---------|
| 14x | 1h + 5m | Error budget сгорит за **2 часа** | Critical |
| 6x | 6h + 30m | Error budget сгорит за **5 дней** | Warning |

**Ключевые лейблы NGINX Ingress метрик:**
- `ingress` = имя Ingress ресурса (`wordpress`)
- `exported_namespace` = namespace Ingress'а (`wordpress`) — НЕ `namespace`!
- `namespace` = namespace контроллера (`ingress-nginx`)

**Правильный PromQL для SLO:**
```promql
# Error rate (доля 5xx)
sum(rate(nginx_ingress_controller_requests{
  ingress="wordpress", exported_namespace="wordpress", status=~"5.."
}[5m]))
/
sum(rate(nginx_ingress_controller_requests{
  ingress="wordpress", exported_namespace="wordpress"
}[5m]))
```

> ✅ SLO для WordPress настроен: error_rate=0%, latency_ok=100%, Prometheus target up — 01.03.2026

---

### 27. 🔭 Lens Cluster Overview — конфликт двух Prometheus

**Симптом:** Левая панель (Memory Workers) в Cluster Overview показывает данные, правая (Pod статусы / CPU) — ошибку подключения.

**Причина:** Lens Desktop самостоятельно деплоит собственный Prometheus в namespace `lens-metrics` при включении `Settings → Lens Metrics`. Если в кластере уже есть `kube-prometheus-stack` — возникает конфликт: два Prometheus одновременно, Lens не знает к какому обращаться для каждой панели.

**Диагностика:**
```bash
kubectl get all -n lens-metrics
# → найдено: prometheus-0, kube-state-metrics, node-exporter, etc.
```

**Решение:**
```bash
kubectl delete namespace lens-metrics
```
После удаления остаётся только `kube-prometheus-stack` → Cluster Overview: обе панели работают ✅

**Правило:** Если используешь внешний Prometheus (`kube-prometheus-stack`) — **не включай** `Settings → Lens Metrics` в Lens Desktop. Оба Prometheus конфликтуют.

> ✅ Lens Cluster Overview исправлен: удалён namespace `lens-metrics` — 01.03.2026

---

### 28. ⚖️ Rolling Update + HPA + PDB — Day-2 Operations в Kubernetes

#### metrics-server — обязательное условие для HPA

HPA (HorizontalPodAutoscaler) требует Metrics API. В kubeadm-кластере metrics-server нужно ставить вручную и обязательно добавлять флаг `--kubelet-insecure-tls` (kubelet сертификат не подписан публичным CA):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
# Проверка:
kubectl top nodes
```

#### Rolling Update стратегия

В Bitnami Helm chart (и большинстве других) параметры через `valuesObject` в Argo CD Application:

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0       # см. урок #29 про RWO PVC!
    maxUnavailable: 1
```

**Проверка:**
```bash
kubectl rollout status deployment/wordpress -n wordpress
kubectl rollout history deployment/wordpress -n wordpress
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>
```

#### HPA — HorizontalPodAutoscaler

В Bitnami WordPress chart:
```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPU: 60      # scale up при CPU > 60% от request
```

После применения:
```bash
kubectl get hpa -n wordpress
# NAME        REFERENCE              TARGETS                    MINPODS  MAXPODS  REPLICAS
# wordpress   Deployment/wordpress   memory:10%/50%,cpu:2%/60%  1        3        1
```

#### PDB — PodDisruptionBudget

Защищает под при `kubectl drain`, rolling update, node maintenance:
```yaml
pdb:
  create: true
  minAvailable: 1   # минимум 1 pod должен оставаться доступным
```

```bash
kubectl get pdb -n wordpress
# NAME       MIN AVAILABLE  MAX UNAVAILABLE  ALLOWED DISRUPTIONS
# wordpress  1              N/A              0
# (0 = нельзя удалять pods, пока replicas=1)
```

> ✅ Rolling Update + HPA + PDB для WordPress настроены: metrics-server v0.8.1, HPA (cpu/mem), PDB minAvailable=1 — 01.03.2026

---

### 29. 📦 RWO PVC + Rolling Update = Multi-Attach error

**Проблема:** Rolling Update с `maxSurge: 1` зависает с ошибкой:
```
Warning  FailedAttachVolume  attachdetach-controller
Multi-Attach error for volume "pvc-xxx"
Volume is already used by pod(s) wordpress-old-pod
```

**Причина:** `ReadWriteOnce` (RWO) PVC можно примонтировать только к **одному поду одновременно**.
При `maxSurge: 1` — новый pod стартует **до** удаления старого. Оба пода на одной ноде или нет — новый не получит доступ к volume.

| Параметр | Поведение | RWO совместимость |
|----------|-----------|-------------------|
| `maxSurge: 1, maxUnavailable: 0` | Сначала новый pod, потом удаляем старый | ❌ Multi-Attach error |
| `maxSurge: 0, maxUnavailable: 1` | Сначала убиваем старый, потом новый | ✅ Работает (краткий gap ~30s) |
| `strategy: Recreate` | Удалить все → создать новые | ✅ Работает (полный даунтайм) |

**Решения для zero-downtime:**
- Использовать `ReadWriteMany` (RWX) storage — Longhorn поддерживает через NFS subpath
- Вынести состояние в внешние хранилища (S3, DB) — stateless deployment
- Использовать StatefulSet с headless service

**Правило:** `maxSurge > 0` + RWO PVC = потенциальная проблема. Всегда проверяй `accessModes` PVC перед Rolling Update.

> ✅ Задокументировано: WordPress + Longhorn RWO + maxSurge:0 — 01.03.2026
---

### 30. 🗋️ Node Add/Remove — полный цикл + terraform destroy через Proxmox API

#### Цикл добавления ноды

1. **Terraform** — добавить VM в `nodes.tf`
2. **Ansible** — запустить playbook с `--limit 'k3s_master,<new_ip>'`
3. **kubectl** — проверить `kubectl get nodes`

```bash
# Шаг 1: Terraform создаёт VM
cd terraform/proxmox-lab
terraform apply -target=proxmox_virtual_environment_vm.k8s_worker_03

# Шаг 2: Ansible добавляет ноду в кластер
# inventory.ini на master обновить вручную
ssh ubuntu@10.44.81.110 'echo "10.44.81.113" >> /etc/ansible/inventory.ini'
ansible-playbook -i inventory.ini kubeadm-cluster.yml --limit 'k3s_master,10.44.81.113'

# Шаг 3: Проверка
kubectl get nodes
# NAME              STATUS   ROLES           AGE   VERSION
# k8s-master-01     Ready    control-plane   ...   v1.31.14
# k8s-worker-01     Ready    <none>          ...   v1.31.14
# k8s-worker-02     Ready    <none>          ...   v1.31.14
# k8s-worker-03     Ready    <none>          ...   v1.30.14  ← новая
```

#### Цикл удаления ноды

```bash
# 1. Исключить ноду из расписания
kubectl cordon k8s-worker-03

# 2. Выселить все поды
kubectl drain k8s-worker-03 --ignore-daemonsets --delete-emptydir-data

# 3. Удалить из кластера
kubectl delete node k8s-worker-03

# 4. Terraform destroy VM
terraform destroy -target=proxmox_virtual_environment_vm.k8s_worker_03
```

#### Проблема: `terraform destroy` виснет

`terraform destroy` может зависнуть, если VM в Proxmox находится в состоянии Running. Решение — Proxmox API:

```bash
# Состояние VM (VMID=113, узел pve02)
ssh ubuntu@10.44.81.110 'curl -s -k \
  -H "Authorization: PVEAPIToken=terraform@pve!terraform-pve02=TOKEN" \
  https://10.44.81.102:8006/api2/json/nodes/pve02/qemu/113/status/current \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[\"data\"][\"status\"])"'

# Остановить VM
ssh ubuntu@10.44.81.110 'curl -s -k -X POST \
  -H "Authorization: PVEAPIToken=terraform@pve!terraform-pve02=TOKEN" \
  https://10.44.81.102:8006/api2/json/nodes/pve02/qemu/113/status/stop'

# Удалить VM (destroy)
ssh ubuntu@10.44.81.110 'curl -s -k -X DELETE \
  -H "Authorization: PVEAPIToken=terraform@pve!terraform-pve02=TOKEN" \
  https://10.44.81.102:8006/api2/json/nodes/pve02/qemu/113'

# Очистить terraform state
terraform state rm proxmox_virtual_environment_vm.k8s_worker_03
```

> ⚠️ **Урок:** `!` в токене Proxmox API ломает PowerShell (history expansion). Запускай `curl` через SSH на master — bash не экранирует `!`.  
> ⚠️ **Урок:** новая нода может присоединиться с другой версией Kubernetes (v1.30 vs v1.31) — это норма для краткосрочных тестов.

> ✅ Block I: node add/remove полный цикл (Terraform + Ansible + kubectl + Proxmox API) — 02.03.2026

---

### 31. 🌍 AZ/Zone Topology — zone labels, Longhorn cross-zone, Zone A failure test

#### Zone Labels — присвоить нодам зоны

```bash
# pve01 = Zone A
kubectl label node k8s-master-01 topology.kubernetes.io/zone=zone-a topology.kubernetes.io/region=proxmox-lab
kubectl label node k8s-worker-01 topology.kubernetes.io/zone=zone-a topology.kubernetes.io/region=proxmox-lab

# pve02 = Zone B
kubectl label node k8s-worker-02 topology.kubernetes.io/zone=zone-b topology.kubernetes.io/region=proxmox-lab

# Проверка
kubectl get nodes --label-columns=topology.kubernetes.io/zone,topology.kubernetes.io/region
# NAME            ZONE    REGION
# k8s-master-01   zone-a  proxmox-lab
# k8s-worker-01   zone-a  proxmox-lab
# k8s-worker-02   zone-b  proxmox-lab
```

#### Longhorn Cross-Zone Replication

Longhorn автоматически размещает реплики на разных нодах при репликации ≥ 2. Стандартный StorageClass `longhorn` (replicaCount=2) автоматически даёт cross-zone replicas: **worker-01 (zone-a) + worker-02 (zone-b)**.

```bash
# Проверить Longhorn volumes
kubectl get volume -n longhorn-system -o wide
# У PVC wordpress-data: replicas на worker-01 (zone-a) + worker-02 (zone-b)
```

#### Тест "падает Zone A"

```bash
# Симуляция отказа Zone A (cordon master-01 + worker-01)
kubectl cordon k8s-master-01 k8s-worker-01

# Проверить распределение подов (Running должны быть на worker-02)
kubectl get pods -A -o wide | Select-String "Running" | Select-String "worker-02"

# Результат — ВСЕ сервисы выжили на zone-b:
# wordpress, grafana, loki, minio, strapi, wiki, registry, velero, ingress-nginx, metrics-server

# Вернуть zone-a (разкордонить)
kubectl uncordon k8s-master-01 k8s-worker-01
```

| Сервис | Результат Zone A failure |
|--------|------|
| WordPress | ✅ worker-02 |
| Grafana | ✅ worker-02 |
| Loki | ✅ worker-02 |
| MinIO | ✅ worker-02 |
| Strapi | ✅ worker-02 |
| Wiki | ✅ worker-02 |
| Registry | ✅ worker-02 |
| Velero | ✅ worker-02 |
| ingress-nginx | ✅ worker-02 |
| metrics-server | ✅ worker-02 |

> ⚠️ Тест использовал `cordon` (не `drain`) — поды остались жить, новые не планировались на zone-a. В реальном отказе поды рестартовались бы автоматически через K8s scheduling.  
> ⚠️ **Урок:** Для полноценного Zone HA — каждый Deployment/StatefulSet должен иметь `replicas ≥ 2` с `topologySpreadConstraints` или `podAntiAffinity` по `zone`. В нашей лаборатории single-replica сервисы пережили за счёт Longhorn cross-zone реплик (storage не умерла, поды перешедулились).

> ✅ Block J: zone labels + cross-zone Longhorn + Zone A failure test — 02.03.2026
---


---

### 32. 🔒 Proxmox API — Lock file deadlock при конкурирующих запросах

#### Проблема
При отправке нескольких команд `shutdown`/`stop` через Proxmox API к одной ВМ создаётся файл блокировки `lock-111.conf`. Несколько задач конкурируют, получая ошибку:
```
can't lock file '/var/lock/qemu-server/lock-111.conf'
```

#### Причина
Proxmox создаёт эксклюзивный lock-файл на время любой операции с ВМ (start/stop/reboot/config). Второй запрос не может получить lock → задача завершается с ошибкой.

#### Решение
```bash
# НЕПРАВИЛЬНО — несколько конкурирующих команд:
POST /api2/json/nodes/pve01/qemu/111/status/shutdown
POST /api2/json/nodes/pve01/qemu/111/status/shutdown   # <-- обе в полёте

# ПРАВИЛЬНО — дождаться завершения tasks:
GET /api2/json/nodes/pve01/tasks?vmid=111  # Ждать status=OK
POST /api2/json/nodes/pve01/qemu/111/status/stop   # Только тогда
```

> ✅ Правило: **один Proxmox task на ВМ одновременно**. Всегда проверяй UPID'ы через `/tasks?vmid=N`.

---

### 33. 🔄 Proxmox PUT /config — изменения применяются только после cold reboot

#### Проблема
`PUT /api2/json/nodes/pve01/qemu/111/config` возвращает `{"data":null}` (успех), но после `sudo reboot` на ВМ изменения не применяются:
```
# Ожидаем: cpus=4, maxmem=6144MB
# Реальность: cpus=2, maxmem=4096MB  ← старые значения!
```

#### Причина
`sudo reboot` = **QEMU warm reset** — QEMU процесс продолжает работать, новая конфигурация (cores/memory) НЕ применяется к работающему процессу.

#### Решение — cold boot через Proxmox API
```python
# STOP (завершит QEMU процесс)
POST /api2/json/nodes/pve01/qemu/111/status/stop

# Дождаться status=stopped
GET /api2/json/nodes/pve01/qemu/111/status/current

# START (запустит с новой конфигурацией)
POST /api2/json/nodes/pve01/qemu/111/status/start
```

| Метод | QEMU процесс | Новый конфиг | Использовать когда |
|-------|-------------|--------------|-------------------|
| `sudo reboot` | Продолжает жить (warm reset) | ❌ НЕ применяется | Патчи ОС, мягкая перезагрузка |
| `POST /status/reboot` | Warm reset через QEMU | ❌ НЕ применяется | Аналогично reboot |
| `POST /status/stop` + `start` | Завершается + новый процесс | ✅ Применяется | Изменение CPU/RAM |

> ✅ Правило: **CPU/RAM через Proxmox API требуют STOP+START**, не reboot.

---

### 34. 📊 Worker resource starvation — 2 CPU / 4 GB для 59+ подов

#### Симптомы
```
# kubectl top node k8s-worker-01
NAME           CPU(cores)  CPU%  MEMORY(bytes)  MEMORY%
k8s-worker-01  1950m       97%   3.85Gi         98%
```
- OOMKilled поды
- `ImagePullBackOff` (registry pod убит OOM)
- `CrashLoopBackOff` у системных DaemonSets
- Prometheus/Alertmanager нестабильны

#### Первопричина
Worker-01 имел 2 CPU / 4 GB RAM, но нёс **59 подов** (после того как worker-02 был недоступен). Kubernetes продолжал планировать поды, не учитывая реальную нагрузку.

#### Решение
```bash
# Резервировать достаточно ресурсов на worker:
# Правило: 1 vCPU на каждые 10-15 runtime-подов
# Правило: 1 GB RAM на каждые 5-8 поды с Prometheus/Grafana

# Для 3-нодного кластера с полным стеком мониторинга:
# master-01: 8 vCPU / 8 GB
# worker-01:  4 vCPU / 6 GB  ← ИСПРАВЛЕНО (было 2/4)
# worker-02:  4 vCPU / 8 GB
```

> ✅ Правило: **Рассчитывай ресурсы с учётом реальной нагрузки**. kube-prometheus-stack ≈ 800m CPU + 1.5 GB. Loki ≈ 300m + 512MB. Итого системный overhead ≈ 2 CPU + 3 GB только на observability.

---

### 35. 🏗️ pve01 и pve02 — независимые Proxmox instances (НЕ cluster)

#### Факты
- pve01 (10.44.81.101) и pve02 (10.44.81.102) — **отдельные standalone Proxmox-хосты**
- Они **не объединены** в Proxmox cluster (проверено: `/api2/json/cluster/status` на pve01 возвращает только pve01)
- VMs с pve01 нельзя управлять через API pve02 и наоборот  
- Template 9000 присутствует **на обоих** хостах независимо

#### Последствия для управления
```powershell
# НЕЛЬЗЯ — управлять VM на pve02 через pve01 API (без кластера):
$TOKEN_PVE01 = "terraform@pve!..."
curl.exe ... "https://10.44.81.101:8006/api2/json/nodes/pve02/qemu"
# Ответ: {"data":null} или 404

# ПРАВИЛЬНО — каждый хост доступен отдельно:
$TOKEN_PVE01 = "terraform@pve!terraform-pve01=..."
curl.exe ... "https://10.44.81.101:8006/api2/json/nodes/pve01/qemu"

$TOKEN_PVE02 = "terrafor@pve!terraform-pve02=..."   # ВАЖНО: 'terrafor' (опечатка в токене!)
curl.exe ... "https://10.44.81.102:8006/api2/json/nodes/pve02/qemu"
```

#### Опечатка в API токене pve02
Токен pve02 был создан с опечаткой в имени пользователя: `terrafor@pve` (без 'м'). Это **правильное** значение для использования:
```
pve02_api_token = "terrafor@pve!terraform-pve02=f25d0f53-c576-4f27-860e-a591e38bc04f"
```

> ✅ Правило: если нужен единый интерфейс управления — настроить **Proxmox Cluster** (corosync). Иначе — управляй каждым хостом отдельно через свой API.

---

### 36. 💥 Terraform bpg/proxmox v0.101.1 — crash на Windows (gRPC)

#### Симптомы
```powershell
terraform init    # OK, скачивает плагин
terraform plan    # CRASH:
# Error: Plugin did not respond
# The plugin encountered an error, and failed to respond to the plugin.(*GRPCProvider).GetProviderSchema call.
# Plugin process exited with exit status 1
```

#### Причина
Terraform провайдер `bpg/proxmox v0.101.1` использует gRPC для общения с основным процессом Terraform. На Windows есть баг совместимости в gRPC layer → провайдер падает при первом вызове.

#### Обходные пути (по приоритету)

1. **Прямой Proxmox REST API** (использовался в нашем случае):
```python
import urllib.request, urllib.parse, ssl
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
data = urllib.parse.urlencode({'cores':'4', 'memory':'8192'}).encode()
req = urllib.request.Request('https://10.44.81.101:8006/api2/json/nodes/pve01/qemu/111/config', data=data, method='PUT')
req.add_header('Authorization', 'PVEAPIToken=terraform@pve!terraform-pve01=...')
r = urllib.request.urlopen(req, context=ctx)
```

2. **Запустить Terraform в WSL2**:
```bash
# В WSL2 Ubuntu — gRPC проблема не воспроизводится
wsl terraform plan
wsl terraform apply
```

3. **Откатить провайдер** до v0.97.x (та что работала ранее):
```hcl
# terraform.tf
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.97.1"   # рабочая версия
    }
  }
}
```

> ✅ Правило: при обновлении Terraform провайдера — **тестируй на целевой ОС** прежде чем коммитить. Windows + gRPC-based провайдеры могут быть несовместимы.

---

### 🖥️ Инфраструктура

| Логотип | Инструмент | Описание |
|:-------:|------------|----------|
| ��️ | **Proxmox VE** | Гипервизор с открытым исходным кодом. Управляет виртуальными машинами (KVM) и контейнерами (LXC) через удобный веб-интерфейс. Основа для домашней лабораторной среды. |
| ⚖️ | **MetalLB** | Load Balancer для bare-metal Kubernetes кластеров. Назначает реальные IP-адреса сервисам типа `LoadBalancer` без облачного провайдера. Режим L2 (ARP) — самый простой для старта. |
| 🗄️ | **Longhorn** | Распределённое блочное хранилище для Kubernetes. Управляет persistent volumes, делает репликацию данных между нодами. Альтернатива дорогим облачным хранилищам. |
| 💾 | **Velero** | Резервное копирование и восстановление ресурсов Kubernetes. Сохраняет состояние кластера, namespace, PVC. Незаменим при миграции или disaster recovery. |
| 🔒 | **Cert-Manager** | Автоматическое управление TLS/SSL-сертификатами в Kubernetes. Интегрируется с Let's Encrypt, выдаёт и обновляет сертификаты без ручного вмешательства. |
| 🌐 | **NGINX Ingress** | Ingress Controller для Kubernetes. Маршрутизирует внешний HTTP/HTTPS трафик к нужным сервисам внутри кластера по правилам (хост, путь). |

---

### 🐳 Контейнеризация

| Логотип | Инструмент | Описание |
|:-------:|------------|----------|
| 🐳 | **Docker** | Стандарт де-факто для контейнеризации. Упаковывает приложение со всеми зависимостями в изолированный контейнер. Работает одинаково на любом сервере. |
| ⛵ | **Helm** | Менеджер пакетов для Kubernetes. Позволяет устанавливать и управлять сложными приложениями в кластере через готовые Charts (шаблоны манифестов). |
| 🔭 | **Lens** | Desktop IDE для Kubernetes. Визуальный интерфейс для работы с кластером: просмотр подов, логов, метрик, выполнение команд — без написания kubectl вручную. |

---

### 🔄 CI/CD & GitOps

| Логотип | Инструмент | Описание |
|:-------:|------------|----------|
| 🐙 | **GitHub** | Хостинг Git-репозиториев + GitHub Actions для CI/CD. Самая популярная платформа для хранения кода и автоматизации сборки/деплоя. |
| 🦊 | **GitLab** | Полная DevOps-платформа: Git, CI/CD, Container Registry, Wiki, Issue Tracker — всё в одном. Можно развернуть self-hosted. |
| ⚙️ | **Jenkins** | Ветеран автоматизации. Гибкий CI/CD сервер с огромным количеством плагинов. Подходит для сложных пайплайнов и legacy-инфраструктуры. |
| 🚀 | **Argo CD** | GitOps-инструмент для Kubernetes. Следит за Git-репозиторием и автоматически синхронизирует состояние кластера с описанием в коде. «Что в Git — то и в кластере». Паттерн **App-of-Apps**: один root Application управляет всеми дочерними — добавить сервис = git push, без kubectl. |
| 🤖 | **Ansible** | Инструмент конфигурационного управления и автоматизации. Описывает нужное состояние серверов в YAML-playbooks и приводит серверы к этому состоянию без агентов (только SSH). |

---

### ��️ IaC

| Логотип | Инструмент | Описание |
|:-------:|------------|----------|
| 🏗️ | **Terraform** | Инфраструктура как код от HashiCorp. Описывает облачные и локальные ресурсы (VM, сети, DNS) в файлах `.tf` и управляет их жизненным циклом через plan/apply. |

---

### 📊 Мониторинг & Логирование

| Логотип | Инструмент | Описание |
|:-------:|------------|----------|
| 🔥 | **Prometheus** | Система мониторинга и хранения метрик. Собирает числовые данные (CPU, RAM, RPS) с серверов и сервисов по pull-модели, хранит в time-series БД. |
| 📈 | **Grafana** | Платформа для визуализации данных. Строит красивые дашборды из метрик Prometheus, логов Loki, и других источников. Основной инструмент для наблюдаемости. |
| 📋 | **Loki + Promtail** | Стек для агрегации логов от Grafana. Loki хранит логи (индексирует только метки, не контент). Promtail — агент, собирает логи и отправляет в Loki. |
| 🔔 | **Alertmanager** | Менеджер алертов для Prometheus. Принимает алерты, группирует их, применяет маршрутизацию и отправляет уведомления в Telegram, Slack, Email, PagerDuty. |
| 🟢 | **Uptime Kuma** | Лёгкий self-hosted монитор доступности сервисов. Проверяет HTTP, TCP, DNS, Ping — и уведомляет при падении. Красивый UI, простая настройка. |

---

### 🔒 Безопасность

| Логотип | Инструмент | Описание |
|:-------:|------------|----------|
| 🔐 | **HashiCorp Vault** | Централизованное хранилище секретов (пароли, токены, сертификаты, API-ключи). Интегрируется с Kubernetes для автоматической выдачи секретов подам. |
| 🛡️ | **Trivy** | Сканер безопасности для контейнеров, файлов конфигурации и IaC. Находит CVE-уязвимости в образах Docker до деплоя. Легко встраивается в CI/CD. |
| 🔍 | **SonarQube** | Статический анализ качества и безопасности кода. Находит баги, уязвимости, code smells. Интегрируется в пайплайн для обязательной проверки перед деплоем. |

---

### 📦 Сервисы & Приложения

| Логотип | Инструмент | Описание |
|:-------:|------------|----------|
| 📝 | **WordPress** | Самая популярная CMS. Разворачивается в Docker/Kubernetes как демонстрационное приложение для отработки деплоя, хранилищ, ingress и SSL. |
| 📞 | **Asterisk** | Open-source АТС (IP-телефония). Управляет звонками, IVR, конференциями. Разворачивается как сервис в Docker или на VM для практики с реальной телефонией. |

---

### 🧰 Дополнительно (не упустить!)

| Логотип | Инструмент | Описание |
|:-------:|------------|----------|
| 🐧 | **Linux / Bash** | Фундамент всего. Без уверенного владения командной строкой, процессами, сетью и правами доступа — всё остальное будет даваться сложнее. |
| 🌿 | **Git** | Система контроля версий. Основа всего CI/CD. Ветки, merge, rebase, stash, cherry-pick — обязательный минимум для DevOps-инженера. |
| 🌐 | **Networking** | DNS, TCP/IP, NAT, VLAN, firewall (iptables/nftables). Без понимания сети невозможно отладить ни Kubernetes, ни VoIP, ни инфраструктуру. |
| 📦 | **Harbor** | Self-hosted Container Registry. Хранит Docker-образы внутри инфраструктуры с контролем доступа, сканированием уязвимостей и управлением версиями. |
| 🎯 | **k9s** | Terminal UI для Kubernetes. Быстрее чем Lens для работы в терминале — навигация по кластеру, логи, exec в поды, всё с клавиатуры. |

---

## ✅ Статус прогресса

| Инструмент | Категория | Статус | Заметки |
|------------|-----------|--------|---------|
| 🐧 Linux / Bash | Основы | ⏳ | |
| 🌿 Git | Основы | ⏳ | |
| 🐳 Docker | Контейнеры | ⏳ | |
| ⛵ Helm | Kubernetes | ✅ | v3.20.0, установлен на master 28.02.2026 |
| ☸️ Kubernetes | Оркестрация | ✅ | v1.31.14, kubeadm, 4 ноды Ready (master+worker-01/02/03), upgrade v1.30→v1.31 ✅, worker-03 добавлен (zone-b, pve02, 4CPU/8GB) ✅ |
| 🔭 Lens | Kubernetes | ✅ | Desktop + Mobile подключен, 28.02.2026; Cluster Overview fix: удалён `lens-metrics` (конфликт Prometheus) → обе панели ✅, 01.03.2026 |
| 🎯 k9s | Kubernetes | ⏳ | |
| 🖥️ Proxmox | Инфраструктура | ✅ | pve01+pve02, API токены, 27.02.2026 |
| ⚖️ MetalLB | Инфраструктура | ✅ | L2, pool 10.44.81.200-250, 28.02.2026 |
| 🗄️ Longhorn | Инфраструктура | ✅ | Helm, 23 пода Running, SC default, PVC ✅, HA drain ✅, UI https://longhorn.lab.local ✅, BackupTarget → MinIO AVAILABLE ✅, 01.03.2026 |
| 🌐 NGINX Ingress | Инфраструктура | ✅ | EXTERNAL-IP 10.44.81.200, 28.02.2026 |
| 🔒 Cert-Manager | Инфраструктура | ✅ | v1.19.4, lab-ca-issuer, TLS работает, 28.02.2026 |
| 🗄️ MinIO | Инфраструктура | ✅ | v5.4.0 chart, standalone, 10Gi longhorn-single, Console https://minio.lab.local, minioadmin/DevOpsLab2026!, buckets: velero + longhorn-backup, ServiceMonitor (job=minio), Prometheus metrics ✅, 01.03.2026 |
| 💾 Velero | Инфраструктура | ✅ | v1.17.1, Helm 11.4.0, BSL Available, schedules x2, --features=EnableCSI, CSI VolumeSnapshot support, 01.03.2026 |
| 📸 external-snapshotter | Инфраструктура | ✅ | v8.2.0, 3 CRDs, snapshot-controller 2 пода Running, 01.03.2026 |
| 📸 VolumeSnapshotClass | Инфраструктура | ✅ | longhorn-snapshot-class, driver.longhorn.io, type:bak (DR-safe), 01.03.2026 |
| 🐙 GitHub | CI/CD | ✅ | `shevchenkod/devops-lab`, SSH-ключ, 28.02.2026 |
| 🦊 GitLab CI/CD | CI/CD | ⏳ | план: GitLab.com → self-hosted CE |
| ⚙️ Jenkins | CI/CD | ⏳ | |
| 🚀 Argo CD | GitOps | ✅ | Helm v3, argocd.lab.local TLS, GitHub repo connected, 28.02.2026 |
| 🤖 Ansible | Автоматизация | ✅ | core 2.16.3, kubeadm bootstrap, 28.02.2026 |
| 🏗️ Terraform | IaC | ✅ | v1.14.6, bpg/proxmox v0.97.1, 28.02.2026 |
| 🔥 Prometheus | Мониторинг | ✅ | kube-prometheus-stack, Argo CD, PVC Longhorn 10Gi, 28.02.2026 |
| 📈 Grafana | Визуализация | ✅ | https://grafana.lab.local, TLS, admin/DevOpsLab2026!, 28.02.2026 |
| 📋 Loki + Promtail | Логирование | ✅ | Loki 6.29.0 singleBinary, Promtail 6.16.6 DaemonSet 3/3, namespace loki, Grafana datasource, 01.03.2026 |
| 🔔 Alertmanager | Алертинг | ✅ | Telegram notifications, AlertmanagerConfig CRD + PrometheusRules (6 алертов), 28.02.2026 |
| 📊 SLO/SLI | Observability | ✅ | WordPress: NGINX Ingress metrics, ServiceMonitor, recording rules (6), burn-rate alerts (4), error_rate=0%, latency_ok=100%, 01.03.2026 |
| ⚖️ Rolling+HPA+PDB | Operations | ✅ | WordPress: metrics-server v0.8.1, HPA (cpu/60%,mem/50%), PDB minAvailable=1, Rolling maxSurge=0, 01.03.2026 |
| 🗋️ Node Add/Remove | Operations | ✅ | Terraform+Ansible join+kubectl cordon/drain/delete+Proxmox API destroy, worker-03 полный цикл, 02.03.2026 |
| 🌍 AZ/Zone Topology | Operations | ✅ | zone-a (pve01: master+worker-01), zone-b (pve02: worker-02+worker-03), Longhorn cross-zone, Zone A failure test ✅, 02.03.2026 |
| 🟢 Uptime Kuma | Мониторинг | ✅ | v2.1.3, `kuma.lab.local` TLS, PVC 1Gi Longhorn, Argo CD, 28.02.2026 |
| 🔐 Vault | Безопасность | ⏳ | |
| 🛡️ Trivy | Безопасность | ⏳ | |
| 🔍 SonarQube | Качество кода | ⏳ | |
| 📦 Harbor | Registry | ⏳ | |
| 📝 WordPress | Сервисы | ✅ | 6.8.2 Bitnami, MariaDB 11.8.3, `wordpress.lab.local` TLS, Argo CD, admin/DevOpsLab2026!, 28.02.2026 |
| 🗂️ Strapi | Сервисы | ✅ | **v4.26.1**, node:18-alpine, `strapi.lab.local` TLS, Argo CD, `1/1 Running` ✅, 01.03.2026 |
| 📞 Asterisk | Телефония | ⏳ | |

> **Легенда:** ✅ Изучено | 🔄 В процессе | ⏳ Не начато | ❌ Проблема

---


