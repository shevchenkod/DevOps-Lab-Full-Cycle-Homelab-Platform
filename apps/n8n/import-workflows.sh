#!/usr/bin/env bash
# =============================================================================
# N8N Workflow Importer
# Импортирует все JSON-файлы в N8N через REST API
#
# Использование:
#   ./import-workflows.sh <N8N_API_KEY>
#
# API ключ создать в N8N UI: Settings → API → Create API Key
# =============================================================================

set -euo pipefail

N8N_URL="${N8N_URL:-https://n8n.lab.local}"
N8N_API_KEY="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/workflows"

if [[ -z "$N8N_API_KEY" ]]; then
  echo "Usage: $0 <N8N_API_KEY>"
  echo ""
  echo "Get API key: N8N UI → Settings → API → Create API Key"
  exit 1
fi

echo "=== N8N Workflow Import ==="
echo "Target: $N8N_URL"
echo ""

# Функция импорта одного workflow
import_workflow() {
  local file="$1"
  local name
  name=$(python3 -c "import json,sys; d=json.load(open('$file')); print(d.get('name','unknown'))" 2>/dev/null || basename "$file" .json)

  echo -n "  → Importing: $name ... "

  local response
  response=$(curl -sk -X POST "$N8N_URL/api/v1/workflows" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$file" \
    -w "\n%{http_code}")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | head -1)

  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    local wf_id
    wf_id=$(echo "$body" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','?'))" 2>/dev/null || echo "?")
    echo "OK (id=$wf_id)"
  else
    echo "FAILED (HTTP $http_code)"
    echo "    Response: $body"
  fi
}

# Импортируем все workflows по порядку
for wf_file in "$SCRIPT_DIR"/0*.json; do
  if [[ -f "$wf_file" ]]; then
    import_workflow "$wf_file"
  fi
done

echo ""
echo "=== Done ==="
echo "Open N8N: $N8N_URL"
echo ""
echo "NEXT STEPS:"
echo "  1. Verify all workflows are imported and Active=ON"
echo "  2. Test Alertmanager: trigger a test alert from Prometheus"
echo "  3. Test Telegram Bot: send /help to your bot (chat_id 236281826)"
echo "  4. Test Webhook:  curl -sk -X POST http://n8n.n8n.svc.cluster.local:5678/webhook/cluster-action \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"action\":\"deployment-status\",\"namespace\":\"n8n\",\"name\":\"n8n\"}'"
echo "  5. Daily report runs at 09:00 Kyiv time — can trigger manually via N8N UI"
