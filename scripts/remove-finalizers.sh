#!/bin/bash
# remove-finalizers.sh — Remove stuck PVC finalizers
echo "=== Removing finalizers from stuck PVCs ==="
kubectl patch pvc registry-pvc -n registry -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 || true
kubectl patch pvc strapi-data -n strapi -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 || true
sleep 3

echo "=== Removing finalizers from stuck Longhorn volumes ==="
for vol in pvc-a6247cdb-fb76-4077-839e-4df73ab3e840 pvc-b3a8da84-0509-4cc3-8cea-3b41e094fbf6; do
  kubectl patch volume.longhorn.io $vol -n longhorn-system -p '{"metadata":{"finalizers":[]}}' --type=merge 2>&1 || true
  kubectl delete volume.longhorn.io $vol -n longhorn-system --ignore-not-found 2>&1 || true
done
sleep 5

echo "=== PVC status ==="
kubectl get pvc -A | grep -E 'registry|strapi' || echo "All cleared."

echo "=== Trigger ArgoCD recreate ==="
kubectl annotate application registry -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>&1 || true
kubectl annotate application strapi -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>&1 || true

echo "Done"
