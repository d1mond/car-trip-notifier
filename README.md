# Car Trip Notifier

Автоматические уведомления в Telegram о каждой поездке.

Данные берёт из [Traccar](https://www.traccar.org/), считает расход топлива и стоимость по цене дизеля в Польше. Работает на [n8n](https://n8n.io/) в Docker.

**Пример сообщения:**
```
🚗 Поездка завершена

📍 Głębocka, Warsaw → Sokołowskiego, Warsaw

📏 Расстояние: 16.2 км
⏱ Время в пути: 23мин
⚡ Скорость: 41 км/ч (средняя)
⛽ Топливо: 1.13 л (~расчёт)
💰 Стоимость: 7.36 PLN (6.5 PLN/л)

🕐 04.05, 10:51 → 04.05, 11:15
```

---

## Требования

- Docker + Docker Compose
- Работающий сервер Traccar с устройством
- Telegram-бот (создать через [@BotFather](https://t.me/BotFather))

---

## Установка

### 1. Клонировать репозиторий

```bash
git clone https://github.com/dmitryyu_playtika/car-trip-notifier.git
cd car-trip-notifier
```

### 2. Настроить переменные окружения

```bash
cp .env.example .env
```

Отредактировать `.env`:

```env
# Сгенерировать: openssl rand -hex 32
N8N_ENCRYPTION_KEY=...

# Traccar — URL сервера и данные устройства
TRACCAR_URL=http://your-traccar-server:8082
TRACCAR_DEVICE_ID=15
TRACCAR_USERNAME=admin@example.com
TRACCAR_PASSWORD=yourpassword

# Telegram — токен от @BotFather и твой Chat ID
TELEGRAM_BOT_TOKEN=1234567890:AABBccDD...
TELEGRAM_CHAT_ID=123456789

# Цена дизеля PLN/л и средний расход л/100км
DIESEL_PRICE_PLN=6.50
FUEL_L100KM=7.0
```

**Как получить Telegram Chat ID:**
1. Напиши своему боту любое сообщение
2. Открой в браузере: `https://api.telegram.org/bot<TOKEN>/getUpdates`
3. Найди `"chat":{"id":XXXXXXXX}` — это и есть Chat ID

**Как найти Device ID в Traccar:**
```bash
curl -s -u "email:password" "http://your-traccar/api/devices" | python3 -m json.tool
```

### 3. Запустить n8n

```bash
docker compose up -d
```

n8n будет доступен на `http://localhost:5678` (или IP сервера).

### 4. Настроить n8n (первый запуск)

Открыть `http://<ip>:5678` в браузере и пройти регистрацию владельца.

Либо автоматически через скрипт (создаст аккаунт `admin@driveiq.win` / `Admin123!@#`):

```bash
bash setup-n8n.sh
```

### 5. Импортировать workflow

- n8n UI → **Workflows** → кнопка **⋮** → **Import from file**
- Выбрать `n8n-workflow.json`
- Включить тумблер **Active** у workflow

### 6. Проверить

Нажать **Test workflow** в n8n — в логах должен появиться запрос к Traccar.
Если токен и chat ID верны, придёт тестовое сообщение в Telegram.

---

## Как это работает

```
каждые 15 мин
  → Traccar API /reports/trips (последние 48ч)
  → фильтр уже отправленных (дедупликация в SQLite n8n)
  → форматирование сообщения
  → Telegram Bot API
```

- **Дедупликация:** каждая поездка идентифицируется по `deviceId + startTime`, ID хранятся в n8n Static Data (SQLite). Даже если n8n был недоступен — поездки за последние 48ч не пропадут.
- **Топливо:** если OBD-адаптер не передаёт `spentFuel`, расход считается как `дистанция × FUEL_L100KM / 100`.
- **Скорость:** Traccar хранит скорость в узлах (knots), workflow конвертирует в км/ч.

---

## Переменные окружения

| Переменная | Описание | Пример |
|---|---|---|
| `N8N_ENCRYPTION_KEY` | Ключ шифрования n8n (мин. 32 символа) | `openssl rand -hex 32` |
| `TRACCAR_URL` | URL сервера Traccar | `http://1.2.3.4:8082` |
| `TRACCAR_DEVICE_ID` | ID устройства в Traccar | `15` |
| `TRACCAR_USERNAME` | Логин Traccar | `admin@example.com` |
| `TRACCAR_PASSWORD` | Пароль Traccar | — |
| `TELEGRAM_BOT_TOKEN` | Токен бота от @BotFather | `123:AAB...` |
| `TELEGRAM_CHAT_ID` | Твой Telegram Chat ID | `123456789` |
| `DIESEL_PRICE_PLN` | Цена дизеля (PLN/л) | `6.50` |
| `FUEL_L100KM` | Средний расход (л/100км) | `7.0` |
