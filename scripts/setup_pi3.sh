#!/usr/bin/env bash
set -euo pipefail

# LoopBreaker Raspberry Pi 3 B Setup Script
# Configures lightweight SQLite storage + Gemini API (no Neo4j / Ollama RAM overhead).

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$REPO_DIR/backend"
ENV_FILE="$BACKEND_DIR/.env"
DB_PATH="$BACKEND_DIR/loopbreaker.db"

echo "=== LoopBreaker Raspberry Pi 3 Setup ==="
echo "Repository: $REPO_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is not installed. Run: sudo apt update && sudo apt install -y python3 python3-venv"
  exit 1
fi

echo "1. Setting up Python virtual environment..."
python3 -m venv "$BACKEND_DIR/venv"
"$BACKEND_DIR/venv/bin/pip" install --upgrade pip
"$BACKEND_DIR/venv/bin/pip" install -r "$BACKEND_DIR/requirements.txt"

echo "2. Configuring $ENV_FILE for SQLite + Gemini..."
touch "$ENV_FILE"

set_env_var() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    rm -f "${ENV_FILE}.bak"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

set_env_var "DB_BACKEND" "sqlite"
set_env_var "SQLITE_PATH" "$DB_PATH"
set_env_var "GEMINI_MODEL" "gemini-3.5-flash-lite"
set_env_var "SERVE_STATIC_WEB" "true"

if ! grep -q "^GEMINI_API_KEY=" "$ENV_FILE"; then
  printf "Enter GEMINI_API_KEY (typing hidden, get one free at https://aistudio.google.com/apikey): "
  read -r -s api_key
  echo
  if [ -n "$api_key" ]; then
    echo "GEMINI_API_KEY=$api_key" >> "$ENV_FILE"
    echo "Saved GEMINI_API_KEY to $ENV_FILE."
  else
    echo "Skipped GEMINI_API_KEY. Add it later to $ENV_FILE."
  fi
else
  echo "GEMINI_API_KEY already configured in $ENV_FILE."
fi

SERVICE_FILE="/tmp/loopbreaker.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=LoopBreaker AI Backend & Web Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$BACKEND_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$BACKEND_DIR/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "=== Setup Complete ==="
echo "To test manually:"
echo "  cd $BACKEND_DIR && venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000"
echo ""
echo "To install as a systemd service (auto-start on boot):"
echo "  sudo mv $SERVICE_FILE /etc/systemd/system/loopbreaker.service"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now loopbreaker"
