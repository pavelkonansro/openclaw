#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_SCRIPT="$ROOT_DIR/scripts/ops-check.sh"
HYGIENE_SCRIPT="$ROOT_DIR/scripts/ops-hygiene.sh"
LOG_FILE="$ROOT_DIR/ops-check.log"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/ai.openclaw.ops-check.plist"
HYGIENE_PLIST_PATH="$PLIST_DIR/ai.openclaw.ops-hygiene.plist"

mkdir -p "$PLIST_DIR"

if [[ ! -x "$CHECK_SCRIPT" ]]; then
  chmod +x "$CHECK_SCRIPT"
fi

cat > "$HYGIENE_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "$ROOT_DIR"
docker compose run --rm openclaw-cli sessions cleanup --enforce --fix-missing
docker compose run --rm openclaw-cli doctor --fix
EOF
chmod +x "$HYGIENE_SCRIPT"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.ops-check</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>$CHECK_SCRIPT &gt;&gt; "$LOG_FILE" 2&gt;&amp;1</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>$LOG_FILE</string>
  <key>StandardErrorPath</key>
  <string>$LOG_FILE</string>

  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl load "$PLIST_PATH"

cat > "$HYGIENE_PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.ops-hygiene</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>$HYGIENE_SCRIPT &gt;&gt; "$LOG_FILE" 2&gt;&amp;1</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>0</integer>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>15</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>$LOG_FILE</string>
  <key>StandardErrorPath</key>
  <string>$LOG_FILE</string>

  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
EOF

launchctl unload "$HYGIENE_PLIST_PATH" >/dev/null 2>&1 || true
launchctl load "$HYGIENE_PLIST_PATH"

echo "Installed LaunchAgent: $PLIST_PATH"
echo "Installed LaunchAgent: $HYGIENE_PLIST_PATH"
echo "Daily check: 09:00 local time"
echo "Weekly hygiene: Sunday 09:15 local time"
echo "Log file: $LOG_FILE"
echo "Run now (daily): launchctl start ai.openclaw.ops-check"
echo "Run now (hygiene): launchctl start ai.openclaw.ops-hygiene"
