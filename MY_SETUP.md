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

---

## Workflow: разработка форка + обновления upstream

### Принцип разделения

```
Upstream (openclaw/openclaw)     Мой форк (pavelkonansro/openclaw)
         │                                │
         │  git merge upstream/main       │
         └───────────────────────────────▶│
                                          │
                                          │  Кастомные файлы в git:
                                          │    - MY_SETUP.md (этот файл)
                                          │    - scripts/whisper-server.py
                                          │
                                          │  Кастомные настройки ВНЕ git:
                                          │    - ~/.openclaw/openclaw.json
                                          │    - ~/.openclaw/scripts/transcribe.sh
                                          │    - ~/.openclaw/workspace/ (SOUL.md, AGENTS.md, ...)
                                          │    - .env (gitignored)
```

**Правило:** код форка = upstream + минимум своих файлов. Всё остальное — конфиг вне репо.

### Добавление новых фишек

**Если фишка = настройка (модель, TTS, команды, скиллы):**

- Менять `~/.openclaw/openclaw.json` — ничего в git не нужно
- Скиллы устанавливать в `~/.openclaw/skills/`
- Агентов настраивать в `~/.openclaw/agents/`

**Если фишка = новый скрипт (как whisper-server.py):**

1. Создать скрипт в `scripts/` (попадёт в git)
2. Если нужно монтировать в Docker — добавить volume mount в `docker-compose.yml`
3. Если нужен автозапуск — создать plist в `~/Library/LaunchAgents/`
4. Задокументировать здесь

**Если фишка = патч кода OpenClaw:**

- Избегать по возможности — конфликты при merge upstream
- Если неизбежно — делать в отдельной ветке, squash-мержить в main
- Оставить комментарий `// FORK: описание` в коде для поиска при конфликтах

### Обновление с upstream

```bash
cd ~/Documents/GitHub/openclaw

# 1. Проверить текущее состояние
git status
git log --oneline origin/main..HEAD  # мои коммиты поверх upstream

# 2. Забрать upstream
git fetch upstream

# 3. Посмотреть что нового (до merge)
git log --oneline HEAD..upstream/main

# 4. Смержить
git merge upstream/main

# 5. При конфликте
#    Конфликтные файлы — обычно docker-compose.yml или scripts/
#    Решить в VSCode, сохранить оба изменения где нужно

# 6. Пересобрать и запустить
docker compose build
docker compose up -d

# 7. Проверить что бот работает
docker logs openclaw-openclaw-gateway-1 --tail 10

# 8. Запушить в свой форк
git push origin main
```

### Откат если обновление сломало бота

```bash
# Вариант 1: откатить merge (если ещё не запушили)
git merge --abort         # если merge в процессе
git reset --hard HEAD~1   # если merge завершён

# Вариант 2: вернуться к конкретному коммиту
git log --oneline -10     # найти рабочий коммит
git reset --hard <hash>

# Пересобрать на старой версии
docker compose build && docker compose up -d
```

---

## Известные проблемы и решения

### Gemini Flash Lite: `Unhandled stop reason: error`

**Проблема:** Модель `google/gemini-2.5-flash-lite` через OpenRouter иногда возвращает `finish_reason: "error"` вместо `"stop"`. openclaw не обрабатывает этот finish_reason и считает запрос проваленным.

**Причина:** Safety filter Gemini срабатывает недетерминированно, особенно когда включён thinking mode — модель генерирует внутренний reasoning, который сам может триггерить фильтр.

**Решение (2026-03-02):** Отключён thinking mode в `openclaw.json`:

```json
"thinkingDefault": "off"   // было "low"
```

**Если проблема вернётся:** Сменить primary модель на `deepseek/deepseek-v3.2` или `openai/gpt-5-mini`.

### Health Monitor: ложные рестарты Telegram

**Проблема:** Health monitor каждые 30 минут рестартил Telegram provider с reason "stuck", потому что не получал webhook-события (никто не писал боту).

**Причина:** Health monitor рассчитан на WebSocket (Slack), где events приходят постоянно. Для Telegram webhook 30 минут тишины — норма.

**Решение (2026-03-02):** Отключён health monitor в `openclaw.json`:

```json
"gateway": {
  "channelHealthCheckMinutes": 0   // отключает health monitor
}
```

---

## Текущий конфиг (ключевые параметры)

> Полный конфиг: `~/.openclaw/openclaw.json`

| Параметр        | Значение                                  | Описание                       |
| --------------- | ----------------------------------------- | ------------------------------ |
| Primary модель  | `openrouter/google/gemini-2.5-flash-lite` | Самая дешёвая ($0.075/M input) |
| Fallback модели | `gpt-5-mini` → `deepseek-v3.2`            | Цепочка при ошибке primary     |
| Thinking        | `off`                                     | Отключён из-за safety filter   |
| TTS             | Edge, `ru-RU-DmitryNeural`                | Русский мужской голос          |
| STT             | Локальный Whisper (medium, ru)            | Через whisper-server.py        |
| Health monitor  | Отключён                                  | `channelHealthCheckMinutes: 0` |
| Session idle    | 30 минут                                  | Автосброс контекста            |
| Context pruning | cache-ttl, 2h                             | Старые сообщения удаляются     |
| Compaction      | safeguard, 40%                            | Автосжатие при большой истории |
| Max concurrent  | 2 агента, 3 субагента                     | Ограничение параллелизма       |
