# Моя настройка OpenClaw — Карта выживания

> Последнее обновление: 2026-03-02

## Архитектура: что где лежит

```
┌─────────────────────────────────────────────────────────────────────┐
│  Git-репозиторий: ~/Documents/GitHub/openclaw/                     │
│  Fork: github.com/pavelkonansro/openclaw                          │
│                                                                     │
│  ├── docker-compose.yml    ← параметризован через ${...}           │
│  ├── .env                  ← 🔒 gitignored, ВСЕ секреты тут       │
│  ├── scripts/              ← 📌 кастомные скрипты (в git!)         │
│  │   └── whisper-server.py ← локальный Whisper STT сервер          │
│  └── ...                   ← остальное = upstream OpenClaw          │
│                                                                     │
│  Remotes:                                                           │
│    origin   → github.com/pavelkonansro/openclaw  (мой форк)        │
│    upstream → github.com/openclaw/openclaw        (оригинал)        │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  Конфиг-директория: ~/.openclaw/           (ВНЕ репо — не теряется)│
│                                                                     │
│  ├── openclaw.json          ← 🧠 ГЛАВНЫЙ КОНФИГ (модели, TTS,     │
│  │                             аудио, Telegram, gateway, ...)       │
│  ├── scripts/                                                       │
│  │   └── transcribe.sh      ← 🎤 кастомный STT скрипт             │
│  │                             (монтируется в Docker как volume)     │
│  ├── workspace/              ← рабочая директория агентов           │
│  ├── memory/                 ← память бота                          │
│  ├── skills/                 ← установленные скиллы                 │
│  └── ...                                                            │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  LaunchAgent: ~/Library/LaunchAgents/                               │
│                                                                     │
│  └── com.openclaw.whisper-server.plist  ← автозапуск Whisper        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Что БЕЗОПАСНО при обновлении upstream

| Файл / директория                   | Где                     | В git?     | При `git pull upstream`                                   |
| ----------------------------------- | ----------------------- | ---------- | --------------------------------------------------------- |
| `.env`                              | репо                    | gitignored | **Не трогается** — секреты в безопасности                 |
| `~/.openclaw/openclaw.json`         | вне репо                | —          | **Не трогается** — вне git                                |
| `~/.openclaw/scripts/transcribe.sh` | вне репо                | —          | **Не трогается** — вне git                                |
| `whisper-server.plist`              | ~/Library/LaunchAgents/ | —          | **Не трогается** — вне git                                |
| `scripts/whisper-server.py`         | репо                    | **Да**     | ⚠️ **Может конфликтнуть** если upstream изменит этот файл |
| `docker-compose.yml`                | репо                    | **Да**     | ⚠️ **Может конфликтнуть** если upstream изменит формат    |

**Вывод:** 90% кастомизаций живут ВНЕ репо и при обновлении не теряются.

---

## Как обновлять OpenClaw

```bash
cd ~/Documents/GitHub/openclaw

# 1. Забрать изменения из upstream
git fetch upstream

# 2. Смержить в свой main
git merge upstream/main

# 3. Если конфликт — решить (обычно только docker-compose.yml или scripts/)
#    VSCode покажет конфликтные файлы, выбрать "Accept Both" или вручную

# 4. Запушить в свой форк
git push origin main

# 5. Пересобрать Docker-образ (если нужно)
docker compose build
docker compose up -d
```

**Если что-то пошло не так:**

```bash
# Откатить merge
git merge --abort

# Или вернуться к предыдущему состоянию
git reset --hard origin/main
```

---

## Голосовой пайплайн

### Схема обработки голосового сообщения

```
Telegram voice msg
    │
    ▼
OpenClaw Gateway (Docker)
    │
    ▼
Media-understanding pipeline
  (tools.media.audio в openclaw.json)
    │
    ▼ type: "cli" — запускает transcribe.sh
    │
~/.openclaw/scripts/transcribe.sh
  (volume mount: /app/skills/openai-whisper-api/scripts/transcribe.sh)
    │
    ▼ curl → http://host.docker.internal:9876
    │
whisper-server.py (на хосте, порт 9876)
  faster-whisper, модель "medium", язык "ru"
    │
    ▼ JSON { "text": "расшифровка..." }
    │
transcribe.sh → извлекает .text → передаёт в OpenClaw
    │
    ▼
LLM (Gemini Flash Lite через OpenRouter)
    │
    ▼
Ответ текстом + Edge TTS (ru-RU-DmitryNeural)
    │
    ▼
Telegram: текст + голосовое сообщение
```

### Ключевые настройки в openclaw.json

**Аудио (STT):**

```json
"tools": {
  "media": {
    "audio": {
      "enabled": true,
      "language": "ru",
      "models": [{
        "type": "cli",
        "command": "sh",
        "args": ["-lc", "out=$(/app/skills/openai-whisper-api/scripts/transcribe.sh \"{{MediaPath}}\" --language ru --out /tmp/whisper-out-$$.txt); cat \"$out\""],
        "timeoutSeconds": 120
      }]
    }
  }
}
```

**TTS (озвучка ответов):**

```json
"messages": {
  "tts": {
    "auto": "inbound",
    "mode": "final",
    "provider": "edge",
    "edge": {
      "enabled": true,
      "voice": "ru-RU-DmitryNeural",
      "lang": "ru-RU"
    }
  }
}
```

### Whisper Server (launchd)

**Расположение:** `~/Library/LaunchAgents/com.openclaw.whisper-server.plist`

```bash
# Статус
launchctl list | grep whisper

# Перезапуск
launchctl unload ~/Library/LaunchAgents/com.openclaw.whisper-server.plist
launchctl load   ~/Library/LaunchAgents/com.openclaw.whisper-server.plist

# Логи
tail -f /tmp/whisper-server.log

# Тест
curl http://localhost:9876/v1/audio/transcriptions \
  -F "file=@test.ogg" -F "model=whisper-1" -F "language=ru"
```

**Python:** используется `calendarsync/.venv/bin/python3` (там установлен `faster-whisper`)

---

## Бэкап-чеклист

Если переустанавливаешь macOS или переезжаешь на новый мак — сохрани:

1. **`~/.openclaw/`** — весь каталог (конфиг, скрипты, память, скиллы)
2. **`.env`** из `~/Documents/GitHub/openclaw/` — секреты и пути
3. **`~/Library/LaunchAgents/com.openclaw.whisper-server.plist`** — автозапуск
4. **Git форк** уже на GitHub — клонируй `github.com/pavelkonansro/openclaw`

```bash
# Быстрый бэкап
tar czf ~/openclaw-backup-$(date +%Y%m%d).tar.gz \
  ~/.openclaw/ \
  ~/Documents/GitHub/openclaw/.env \
  ~/Library/LaunchAgents/com.openclaw.whisper-server.plist
```

---

## Docker-compose: что параметризовано

Все значения берутся из `.env`:

| Переменная               | Для чего                        | Пример                              |
| ------------------------ | ------------------------------- | ----------------------------------- |
| `OPENCLAW_IMAGE`         | Docker-образ                    | `openclaw:local`                    |
| `OPENCLAW_GATEWAY_TOKEN` | Авторизация gateway             | `7e3b136f...`                       |
| `OPENCLAW_CONFIG_DIR`    | Путь к ~/.openclaw              | `/Users/pavelk/.openclaw`           |
| `OPENCLAW_WORKSPACE_DIR` | Рабочая директория              | `/Users/pavelk/.openclaw/workspace` |
| `OPENROUTER_API_KEY`     | API ключ OpenRouter             | `sk-or-v1-...`                      |
| `OPENAI_API_KEY`         | Тот же ключ (для совместимости) | `sk-or-v1-...`                      |
| `OPENAI_BASE_URL`        | Базовый URL API                 | `https://openrouter.ai/api/v1`      |
| `TELEGRAM_BOT_TOKEN`     | Токен Telegram-бота             | `7784976960:AAF...`                 |

**Volume mount для transcribe.sh:**

```yaml
- ${OPENCLAW_CONFIG_DIR}/scripts/transcribe.sh:/app/skills/openai-whisper-api/scripts/transcribe.sh:ro
```

Это подменяет встроенный скрипт OpenClaw на наш кастомный, который ходит в локальный Whisper вместо OpenAI API.
