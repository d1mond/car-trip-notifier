#!/usr/bin/env bash
set -euo pipefail

N8N_URL="http://localhost:5678"
WORKFLOW_FILE="./n8n-workflow.json"

echo "=== Ждём запуска n8n ==="
for i in $(seq 1 30); do
  if curl -sf "$N8N_URL/healthz" > /dev/null 2>&1; then
    echo "n8n запущен"
    break
  fi
  echo "  попытка $i/30..."
  sleep 3
done

echo ""
echo "=== Проверяем состояние настройки ==="
SETUP_STATUS=$(curl -sf "$N8N_URL/rest/settings" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('userManagement',{}).get('showSetupOnFirstLoad','unknown'))" 2>/dev/null || echo "unknown")

if [ "$SETUP_STATUS" = "True" ] || [ "$SETUP_STATUS" = "true" ]; then
  echo "Первый запуск — создаём владельца..."
  curl -sf -X POST "$N8N_URL/rest/owner/setup" \
    -H "Content-Type: application/json" \
    -c /tmp/n8n_session.txt \
    -d '{
      "email": "admin@driveiq.win",
      "firstName": "Dmitry",
      "lastName": "Admin",
      "password": "Admin123!@#",
      "agree": true
    }' > /dev/null
  echo "Владелец создан: admin@driveiq.win / Admin123!@#"
else
  echo "n8n уже настроен, входим..."
  curl -sf -X POST "$N8N_URL/rest/login" \
    -H "Content-Type: application/json" \
    -c /tmp/n8n_session.txt \
    -d '{"email":"admin@driveiq.win","password":"Admin123!@#"}' > /dev/null || true
fi

echo ""
echo "=== Импортируем workflow ==="
IMPORT_RESULT=$(curl -sf -X POST "$N8N_URL/rest/workflows" \
  -H "Content-Type: application/json" \
  -b /tmp/n8n_session.txt \
  -d @"$WORKFLOW_FILE" 2>&1)

WORKFLOW_ID=$(echo "$IMPORT_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")

if [ -z "$WORKFLOW_ID" ]; then
  echo "ОШИБКА при импорте workflow:"
  echo "$IMPORT_RESULT"
  exit 1
fi

echo "Workflow импортирован, ID: $WORKFLOW_ID"
echo ""
echo "=== Активируем workflow ==="
curl -sf -X PATCH "$N8N_URL/rest/workflows/$WORKFLOW_ID" \
  -H "Content-Type: application/json" \
  -b /tmp/n8n_session.txt \
  -d '{"active": true}' > /dev/null

echo "Workflow активирован!"
echo ""
echo "=== ГОТОВО ==="
echo "n8n UI: http://localhost:5678"
echo "  Логин: admin@driveiq.win"
echo "  Пароль: Admin123!@#"
echo ""
echo "TELEGRAM — нужно сделать вручную (2 минуты):"
echo "  1. Напиши @BotFather в Telegram → /newbot → задай имя → получи TOKEN"
echo "  2. Напиши @userinfobot → получи свой CHAT_ID"
echo "  3. Обнови .env:"
echo "     TELEGRAM_BOT_TOKEN=<токен от BotFather>"
echo "     TELEGRAM_CHAT_ID=<твой chat id>"
echo "  4. Перезапусти: docker compose up -d"
echo ""
