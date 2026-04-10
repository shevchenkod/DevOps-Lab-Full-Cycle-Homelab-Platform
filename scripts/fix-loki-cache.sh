#!/bin/bash
# fix-loki-cache.sh — Remove corrupted TSDB cache from Loki PVC
echo "=== Fix Loki Corrupted TSDB Cache ==="

# 1. Note the PVC name
PVC_NAME="storage-loki-0"
NS="loki"

# 2. Scale down Loki StatefulSet
echo "Scaling down Loki..."
kubectl scale statefulset loki -n $NS --replicas=0 2>&1
sleep 10
kubectl get pods -n $NS

# 3. Create a temporary pod to clean the PVC
echo "Creating cleanup pod..."
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: loki-cache-cleaner
  namespace: loki
spec:
  containers:
  - name: cleaner
    image: busybox:1.36
    command: ["sh", "-c", "echo 'Cleaning...'; ls /loki/tsdb-shipper-cache/ 2>/dev/null; rm -rf /loki/tsdb-shipper-cache/ && echo 'Cache deleted!' || echo 'No cache dir'; ls /loki/; echo DONE"]
    volumeMounts:
    - name: loki-data
      mountPath: /loki
  volumes:
  - name: loki-data
    persistentVolumeClaim:
      claimName: storage-loki-0
  restartPolicy: Never
EOF

# 4. Wait for cleanup pod to complete
echo "Waiting for cleanup..."
kubectl wait pod/loki-cache-cleaner -n $NS --for=condition=Ready --timeout=60s 2>&1 || true
sleep 10
kubectl logs loki-cache-cleaner -n $NS 2>&1

# 5. Delete cleanup pod
kubectl delete pod loki-cache-cleaner -n $NS 2>&1

# 6. Scale Loki back up
echo "Scaling Loki back up..."
kubectl scale statefulset loki -n $NS --replicas=1 2>&1
sleep 15
kubectl get pods -n $NS
echo "=== Done. Monitor: kubectl logs loki-0 -n loki -c loki -f ==="
