#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG_FILE="${C7_CONFIG:-./.env}"
if [[ -f "$CONFIG_FILE" ]]; then
  set -a
  source "$CONFIG_FILE"
  set +a
fi

echo "=========================================================="
echo "          Starting Prysel C7 Miner (Live Network)         "
echo "=========================================================="

REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-ubuntu}"
SSH_KEY="${SSH_KEY:-}"
TUNNEL_LOCAL_PORT="${TUNNEL_LOCAL_PORT:-23431}"
TUNNEL_REMOTE_PORT="${TUNNEL_REMOTE_PORT:-13431}"
RPC_URL="${RPC_URL:-http://127.0.0.1:13431/}"
RPC_USER="${RPC_USER:-c7miner}"
RPC_PASSWORD="${RPC_PASSWORD:-change-me}"

# 1. Check or start SSH tunnel to the node powering blocks.prysel.com
if [[ -f "$SSH_KEY" && -n "$REMOTE_HOST" ]]; then
  chmod 600 "$SSH_KEY" 2>/dev/null || true
  if ! nc -z 127.0.0.1 "$TUNNEL_LOCAL_PORT" 2>/dev/null; then
    echo "[INFO] Establishing secure tunnel to blocks.prysel.com ($REMOTE_HOST)..."
    ssh -i "$SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o ExitOnForwardFailure=yes \
        -N -f \
        -L "${TUNNEL_LOCAL_PORT}:127.0.0.1:${TUNNEL_REMOTE_PORT}" \
        "${REMOTE_USER}@${REMOTE_HOST}" 2>/dev/null || true
    sleep 2
  fi
fi

# 2. Verify connection to the RPC endpoint
echo "[INFO] Connecting to RPC node at $RPC_URL..."
ready=false
for i in {1..15}; do
  resp="$(curl -s -u "${RPC_USER}:${RPC_PASSWORD}" -H 'content-type: application/json' \
       --data '{"jsonrpc":"1.0","id":"ping","method":"getblockcount","params":[]}' \
       "$RPC_URL" 2>/dev/null || true)"
  if [[ "$resp" == *"result"* ]]; then
    ready=true
    echo "[OK] Connected to live C7 node! Explorer: ${EXPLORER_URL:-https://blocks.prysel.com/}"
    break
  fi
  sleep 1
done

if [[ "$ready" != "true" ]]; then
  echo "[WARN] RPC endpoint not responding yet, launching miner controller..."
fi

# 3. Launch miner with XMRig-style UI
echo "[INFO] Starting miner in terminal..."
exec python3 ./c7-miner.py
