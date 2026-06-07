# 🛡️ OPA Gatekeeper

Open Policy Agent (OPA) Gatekeeper — Kubernetes admission controller for policy enforcement.

## Overview

| Property | Value |
|----------|-------|
| Version | v3.18.x |
| Namespace | `gatekeeper-system` |
| Metrics URL | https://opa.lab.local/metrics |
| Pods | 4 (controller + audit + webhook + metrics) |
| Status | ✅ Running |

## What It Does

- **Admission Controller**: validates every K8s resource before it's created/updated
- **Constraint Templates**: define reusable policy rules (OPA Rego language)
- **Constraints**: apply templates to specific namespaces/resource types
- **Audit**: continuously checks existing resources against active constraints

## Operations

```bash
# Check pods
kubectl get pods -n gatekeeper-system

# List constraint templates (policy definitions)
kubectl get constrainttemplates

# List active constraints
kubectl get constraints

# Check audit results
kubectl get constraintpodstatuses -A
```

## Metrics

OPA Gatekeeper exposes Prometheus metrics at `/metrics`.
Accessible at: **https://opa.lab.local/metrics**

The ingress routes to the `gatekeeper-metrics-service` on port 8888.

## Example: Require Labels Policy

```yaml
# ConstraintTemplate — defines the policy logic
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }
---
# Constraint — applies the policy
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-label
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
  parameters:
    labels: ["app"]
```
