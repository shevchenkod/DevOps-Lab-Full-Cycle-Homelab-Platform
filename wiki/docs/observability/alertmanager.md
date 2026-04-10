# 🔔 Alertmanager

> Alert routing. Receives from Prometheus, groups, and sends to Telegram/Slack/Email.

## Lab Configuration

| Parameter | Value |
|-----------|-------|
| Namespace | `monitoring` |
| Receiver | Telegram bot |
| Helm chart | bundled with `kube-prometheus-stack` |
| Argo CD | `cluster/apps/app-monitoring.yaml` |

## Configuration Example

```yaml
# alertmanager.yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'namespace']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'telegram'
  routes:
    - match:
        severity: critical
      receiver: 'telegram-critical'

receivers:
  - name: 'telegram'
    telegram_configs:
      - bot_token: '<bot-token>'
        chat_id: <chat-id>
        message: |
          Warning: {{ .GroupLabels.alertname }}
          {{ range .Alerts }}{{ .Annotations.description }}{{ end }}

  - name: 'telegram-critical'
    telegram_configs:
      - bot_token: '<bot-token>'
        chat_id: <chat-id>
        message: |
          CRITICAL: {{ .GroupLabels.alertname }}
          {{ range .Alerts }}{{ .Annotations.description }}{{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace']
```

!!! note "Telegram token"
    The Telegram bot token is stored as a SealedSecret — encrypted in Git, safe to commit.
    See `cluster/secrets/` for the sealed secret manifest.

## Integration with N8N

Alertmanager sends webhook POST requests to N8N:

```
Alertmanager → POST https://n8n.lab.local/webhook/alertmanager → N8N Workflow 01 → Telegram
```

This allows custom message formatting and filtering before delivery.

## Quick Commands

```powershell
$env:KUBECONFIG = "H:\DEVOPS-LAB\kubeconfig-lab.yaml"

# Check Alertmanager status
kubectl get pods -n monitoring -l alertmanager=kube-prometheus-stack-alertmanager

# View active alerts via Prometheus API
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090 &
Start-Sleep 2
(Invoke-RestMethod "http://localhost:9090/api/v1/alerts").data.alerts | Format-Table
```
