#!/bin/bash
# Fix faulted registry volume and trigger ArgoCD sync
KUBECONFIG=/home/ubuntu/.kube/config

echo "=== Delete faulted registry PVC ==="
kubectl delete pvc registry-pvc -n registry --force --grace-period=0

echo "=== Remove Longhorn volume finalizers if stuck ==="
VOLUME=$(kubectl get volumes.longhorn.io -n longhorn-system -o name 2>/dev/null | grep pvc-02c8c480 | head -1)
if [ -n "$VOLUME" ]; then
    kubectl patch $VOLUME -n longhorn-system -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl delete $VOLUME -n longhorn-system --force --grace-period=0 2>/dev/null || true
fi

echo "=== Restart registry deployment ==="
kubectl rollout restart deployment/registry -n registry

echo "=== Waiting 20s for ArgoCD to sync... ==="
sleep 20
kubectl get pods -n registry
kubectl get pvc -n registry
