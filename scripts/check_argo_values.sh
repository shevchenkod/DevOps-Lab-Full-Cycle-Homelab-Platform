#!/bin/bash
kubectl get application wordpress -n argocd -o json | python3 -c "
import sys, json
d = json.load(sys.stdin)
vo = d.get('spec', {}).get('source', {}).get('helm', {}).get('valuesObject', {})
keys = ['autoscaling', 'updateStrategy', 'pdb', 'resources']
result = {k: v for k, v in vo.items() if k in keys}
print(json.dumps(result, indent=2))
"
