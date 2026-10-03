#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${C7_CONFIG:-./.env}"
if [[ -f "$CONFIG_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  set +a
fi

RPC_URL="${RPC_URL:-http://127.0.0.1:13431/}"
RPC_USER="${RPC_USER:-c7miner}"
RPC_PASSWORD="${RPC_PASSWORD:-change-me}"
RPC_COOKIE="${RPC_COOKIE:-}"
MINER_ADDRESS="${MINER_ADDRESS:-CSJJZQNp1CgW41s1biCrC9bCqSkrvzLHYz}"
MAX_TRIES="${MAX_TRIES:-1000000}"
BLOCKS_PER_CALL="${BLOCKS_PER_CALL:-1}"
SLEEP_SECONDS="${SLEEP_SECONDS:-1}"
MINER_NAME="${MINER_NAME:-c7-minerd}"
EXPLORER_URL="${EXPLORER_URL:-https://blocks.prysel.com/}"

if [[ -z "$MINER_ADDRESS" || "$MINER_ADDRESS" == "PUT_YOUR_C7_ADDRESS_HERE" ]]; then
  MINER_ADDRESS="CSJJZQNp1CgW41s1biCrC9bCqSkrvzLHYz"
  echo "[$MINER_NAME] MINER_ADDRESS not set, using default C7 address: $MINER_ADDRESS"
fi

rpc() {
  local method="$1"
  local params="${2:-[]}"
  local auth_args=()

  if [[ -n "$RPC_COOKIE" ]]; then
    if [[ ! -r "$RPC_COOKIE" ]]; then
      echo "[ERROR] RPC_COOKIE is not readable: $RPC_COOKIE" >&2
      return 2
    fi
    local cookie
    cookie="$(cat "$RPC_COOKIE")"
    auth_args=(-u "$cookie:")
  elif [[ -n "$RPC_USER" ]]; then
    auth_args=(-u "${RPC_USER}:${RPC_PASSWORD}")
  fi

  curl --fail-with-body --silent --show-error \
    --connect-timeout 5 --max-time 120 \
    "${auth_args[@]}" \
    -H 'content-type: application/json' \
    --data "{\"jsonrpc\":\"1.0\",\"id\":\"${MINER_NAME}\",\"method\":\"${method}\",\"params\":${params}}" \
    "$RPC_URL"
}

rpc_result() {
  local method="$1"
  local params="${2:-[]}"
  rpc "$method" "$params" | python3 -c '
import json,sys
x=json.load(sys.stdin)
if x.get("error") is not None:
    print(json.dumps(x["error"]), file=sys.stderr)
    raise SystemExit(1)
print(json.dumps(x.get("result")))
'
}

echo "=========================================================="
echo "[$MINER_NAME] Starting Prysel C7 Miner & Block Checker"
echo "[$MINER_NAME] RPC Node      : $RPC_URL"
echo "[$MINER_NAME] Explorer      : $EXPLORER_URL"
echo "[$MINER_NAME] Payout Address: $MINER_ADDRESS"
echo "[$MINER_NAME] Max Tries     : $MAX_TRIES"
echo "=========================================================="

while true; do
  set +e
  info="$(rpc_result getblockchaininfo '[]' 2>&1)"
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    echo "[$MINER_NAME] RPC unavailable at $RPC_URL: $info"
    # Still check explorer if available
    if [[ -n "$EXPLORER_URL" ]]; then
      exp_status="$(curl --silent --connect-timeout 3 --max-time 5 "${EXPLORER_URL%/}/api/v1/status" 2>/dev/null || true)"
      if [[ -n "$exp_status" && "$exp_status" =~ ^\{ ]]; then
        exp_height="$(python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d.get("height", d.get("chain",{}).get("blocks","?")))' <<<"$exp_status" 2>/dev/null || echo "?")"
        echo "[$MINER_NAME] [EXPLORER CHECK] Current blocks.prysel.com height: $exp_height (Waiting for local node...)"
      fi
    fi
    sleep 5
    continue
  fi

  height="$(python3 -c 'import json,sys; x=json.loads(sys.stdin.read()); print(x.get("blocks","?"))' <<<"$info")"
  network="$(python3 -c 'import json,sys; x=json.loads(sys.stdin.read()); print(x.get("chain","?"))' <<<"$info")"
  tip_hash="$(python3 -c 'import json,sys; x=json.loads(sys.stdin.read()); print(x.get("bestblockhash","?"))' <<<"$info")"

  set +e
  mem="$(rpc_result getmempoolinfo '[]' 2>&1)"
  mem_rc=$?
  set -e
  if [[ $mem_rc -eq 0 ]]; then
    pending="$(python3 -c 'import json,sys; x=json.loads(sys.stdin.read()); print(x.get("size","?"))' <<<"$mem")"
  else
    pending="?"
  fi

  # Check explorer status
  exp_height="?"
  exp_unconfirmed="?"
  if [[ -n "$EXPLORER_URL" ]]; then
    exp_status="$(curl --silent --connect-timeout 3 --max-time 5 "${EXPLORER_URL%/}/api/v1/status" 2>/dev/null || true)"
    if [[ -n "$exp_status" && "$exp_status" =~ ^\{ ]]; then
      exp_height="$(python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d.get("height", d.get("chain",{}).get("blocks","?")))' <<<"$exp_status" 2>/dev/null || echo "?")"
      exp_unconfirmed="$(python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d.get("unconfirmed",{}).get("count","?"))' <<<"$exp_status" 2>/dev/null || echo "?")"
    fi
  fi

  echo "[$MINER_NAME] [BLOCK CHECK] network=$network node_height=$height explorer_height=$exp_height exp_unconfirmed=$exp_unconfirmed node_mempool=$pending"

  params="$(python3 - "$BLOCKS_PER_CALL" "$MINER_ADDRESS" "$MAX_TRIES" <<'PY'
import json,sys
n=int(sys.argv[1])
addr=sys.argv[2]
tries=int(sys.argv[3])
print(json.dumps([n, addr, tries], separators=(",",":")))
PY
)"

  set +e
  result="$(rpc_result generatetoaddress "$params" 2>&1)"
  rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    if [[ "$result" != "[]" && "$result" != "null" && -n "$result" ]]; then
      echo "[$MINER_NAME] [BLOCK ACCEPTED] Generated block hash: $result"
      new_info="$(rpc_result getblockchaininfo '[]' 2>/dev/null || true)"
      if [[ -n "$new_info" ]]; then
        new_height="$(python3 -c 'import json,sys; x=json.loads(sys.stdin.read()); print(x.get("blocks","?"))' <<<"$new_info" 2>/dev/null || echo "?")"
        echo "[$MINER_NAME] [BLOCK VERIFIED] Updated local block height: $new_height"
      fi
    else
      echo "[$MINER_NAME] Round completed: no block found within $MAX_TRIES attempts, retrying..."
    fi
  else
    echo "[$MINER_NAME] mining call returned: $result"
  fi

  sleep "$SLEEP_SECONDS"
done
