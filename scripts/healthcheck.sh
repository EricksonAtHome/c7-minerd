#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${C7_CONFIG:-./.env}"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

RPC_URL="${RPC_URL:-http://127.0.0.1:13431/}"
RPC_USER="${RPC_USER:-}"
RPC_PASSWORD="${RPC_PASSWORD:-}"
RPC_COOKIE="${RPC_COOKIE:-}"

args=()
if [[ -n "$RPC_COOKIE" ]]; then
  args=(-u "$(cat "$RPC_COOKIE"):")
else
  args=(-u "${RPC_USER}:${RPC_PASSWORD}")
fi

curl --fail --silent --show-error --max-time 10 \
  "${args[@]}" \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"1.0","id":"health","method":"getblockchaininfo","params":[]}' \
  "$RPC_URL" | python3 -m json.tool
