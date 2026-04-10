#!/bin/bash
# fix-cluster.sh — Fix faulted volumes and broken apps
# Run as: bash fix-cluster.sh > /tmp/fix-cluster.log 2>&1
set -e
LOGFILE=/tmp/fix-cluster.log
exec > >(tee -a $LOGFILE) 2>&1

echo "=== $(date) Fix cluster broken apps ==="

echo ""
echo "=== 1/6 Current node/volume status ==="
kubectl get nodes
echo ""
kubectl get pvc -A | grep -E 'NAME|registry|minio|strapi|Terminating'

echo ""
echo "=== 2/6 Delete faulted PVCs and stuck pods ==="

# Registry
echo "--- Registry ---"
kubectl delete deployment registry -n registry --ignore-not-found 2>&1
sleep 2
kubectl delete pvc registry-pvc -n registry --wait=false --ignore-not-found 2>&1

# MinIO
echo "--- MinIO ---"
kubectl scale deployment minio -n minio --replicas=0 2>&1 || true
sleep 2
kubectl delete pvc minio -n minio --wait=false --ignore-not-found 2>&1

# Strapi
echo "--- Strapi ---"
kubectl scale deployment strapi -n strapi --replicas=0 2>&1 || true
sleep 2
kubectl delete pvc strapi-data -n strapi --wait=false --ignore-not-found 2>&1

echo ""
echo "=== 3/6 Force-remove finalizers from stuck Longhorn volumes ==="
# Get faulted volume names and remove finalizers to allow deletion
FAULTED=$(kubectl get volumes.longhorn.io -n longhorn-system --no-headers | awk '$3 == "faulted" {print $1}')
for vol in $FAULTED; do
  echo "Removing finalizer from faulted volume: $vol"
  kubectl patch volume.longhorn.io $vol -n longhorn-system -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 || true
  kubectl delete volume.longhorn.io $vol -n longhorn-system --ignore-not-found 2>&1 || true
done

echo ""
echo "=== 4/6 Wait for PVCs to fully delete ==="
sleep 10
kubectl get pvc -A | grep -E 'registry|minio|strapi' || echo "All faulted PVCs deleted!"

echo ""
echo "=== 5/6 ArgoCD sync — let ArgoCD recreate PVCs/pods ==="
ARGOCD_SERVER="argocd.lab.local"
# Get ArgoCD admin password
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "ezdBtzPyTxHJgD5p")

# Sync apps via ArgoCD API (internal)
for app in registry minio strapi; do
  echo "Syncing ArgoCD app: $app"
  kubectl annotate application $app -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>&1 || true
done

echo ""
echo "=== 6/6 Status ==="
kubectl get pvc -A | grep -E 'registry|minio|strapi'
kubectl get pods -n registry -n minio -n strapi 2>/dev/null | grep -v "No resources"
echo ""
echo "=== DONE at $(date) ==="
echo "Next step: Rebuild wiki image after registry is Running"
echo "  ssh ubuntu@10.44.81.110 'sudo nerdctl --namespace k8s.io build -t 10.44.81.110:30500/wiki:latest /home/ubuntu/wiki && sudo nerdctl --namespace k8s.io push --insecure-registry 10.44.81.110:30500/wiki:latest'"
