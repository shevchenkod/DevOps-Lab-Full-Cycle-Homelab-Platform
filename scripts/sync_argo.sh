#!/bin/bash
kubectl annotate application wordpress -n argocd \
  argocd.argoproj.io/refresh="hard" --overwrite
echo "REFRESH: $?"
sleep 10
kubectl get application wordpress -n argocd -o jsonpath='{.status.sync.status} {.status.health.status}'
echo ""
