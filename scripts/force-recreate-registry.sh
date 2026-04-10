#!/bin/bash
# force-recreate-registry.sh — Delete faulted registry PVC and trigger ArgoCD sync
echo "=== Force recreate registry with 5Gi PVC ==="

# Delete registry deployment and faulted PVC
kubectl delete deployment registry -n registry --ignore-not-found
sleep 2

# Remove finalizer and delete PVC
kubectl patch pvc registry-pvc -n registry -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 || true
kubectl delete pvc registry-pvc -n registry --force --ignore-not-found 2>&1

# Also delete the faulted Longhorn volume
FAULTED_VOL=$(kubectl get volumes.longhorn.io -n longhorn-system --no-headers | awk '$3 == "faulted" {print $1}' | head -1)
if [ -n "$FAULTED_VOL" ]; then
  echo "Removing faulted volume: $FAULTED_VOL"
  kubectl patch volume.longhorn.io $FAULTED_VOL -n longhorn-system -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 || true
  kubectl delete volume.longhorn.io $FAULTED_VOL -n longhorn-system --ignore-not-found 2>&1
fi

sleep 3

echo "=== Trigger ArgoCD sync ==="
kubectl annotate application registry -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>&1

sleep 10
echo "=== PVC status ==="
kubectl get pvc -n registry
kubectl get pods -n registry
echo "Done"
