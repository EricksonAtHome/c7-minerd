#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/c7-minerd}"
SERVICE_USER="${SERVICE_USER:-centraldatabase}"

sudo useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin "$SERVICE_USER" 2>/dev/null || true
sudo mkdir -p "$APP_DIR"
sudo cp c7-minerd.sh "$APP_DIR/c7-minerd.sh"
sudo chmod 0755 "$APP_DIR/c7-minerd.sh"
sudo cp systemd/c7-minerd.service /etc/systemd/system/c7-minerd.service
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$APP_DIR"

if [[ ! -f "$APP_DIR/.env" ]]; then
  sudo cp config.example.env "$APP_DIR/.env"
  sudo chown "$SERVICE_USER":"$SERVICE_USER" "$APP_DIR/.env"
  sudo chmod 0600 "$APP_DIR/.env"
  echo "Edit $APP_DIR/.env before starting the service."
fi

sudo systemctl daemon-reload
sudo systemctl enable c7-minerd
echo "Installed. Start with: sudo systemctl start c7-minerd"
