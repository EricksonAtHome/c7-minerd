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
EXPLORER_URL="${EXPLORER_URL:-https://blocks.prysel.com/}"

rpc() {
  local method="$1"
  local params="${2:-[]}"
  local auth_args=()

  if [[ -n "$RPC_COOKIE" && -r "$RPC_COOKIE" ]]; then
    auth_args=(-u "$(cat "$RPC_COOKIE"):")
  elif [[ -n "$RPC_USER" ]]; then
    auth_args=(-u "${RPC_USER}:${RPC_PASSWORD}")
  fi

  curl --fail-with-body --silent --show-error \
    --connect-timeout 4 --max-time 15 \
    "${auth_args[@]}" \
    -H 'content-type: application/json' \
    --data "{\"jsonrpc\":\"1.0\",\"id\":\"check-blocks\",\"method\":\"${method}\",\"params\":${params}}" \
    "$RPC_URL" 2>/dev/null || echo ""
}

rpc_result() {
  local method="$1"
  local params="${2:-[]}"
  local resp
  resp="$(rpc "$method" "$params")"
  if [[ -z "$resp" ]]; then
    return 1
  fi
  python3 -c '
import json, sys
try:
    x = json.load(sys.stdin)
    if x.get("error"):
        print(json.dumps(x["error"]), file=sys.stderr)
        sys.exit(1)
    print(json.dumps(x.get("result")))
except Exception as e:
    sys.exit(1)
' <<<"$resp"
}

echo "=========================================================="
echo "          Prysel C7 / CDCI Blocks Checker"
echo "=========================================================="
echo "Local Node RPC : $RPC_URL"
echo "Explorer URL   : $EXPLORER_URL"
echo "Timestamp      : $(date -u +"%Y-%m-%d %H:%M:%SZ")"
echo "----------------------------------------------------------"

# 1. Fetch Explorer Info
exp_status=""
exp_blocks=""
if [[ -n "$EXPLORER_URL" ]]; then
  exp_clean="${EXPLORER_URL%/}"
  exp_status="$(curl --silent --connect-timeout 5 --max-time 10 "$exp_clean/api/v1/status" 2>/dev/null || true)"
  exp_blocks="$(curl --silent --connect-timeout 5 --max-time 10 "$exp_clean/api/v1/blocks?limit=5" 2>/dev/null || true)"
fi

# 2. Fetch Local Node Info
node_info=""
node_net=""
node_mem=""
set +e
node_info="$(rpc_result getblockchaininfo '[]')"
node_net="$(rpc_result getnetworkinfo '[]')"
node_mem="$(rpc_result getmempoolinfo '[]')"
set -e

# 3. Parse and Compare
python3 - "$exp_status" "$exp_blocks" "$node_info" "$node_net" "$node_mem" <<'PY'
import sys, json

exp_raw = sys.argv[1]
exp_blocks_raw = sys.argv[2]
node_raw = sys.argv[3]
net_raw = sys.argv[4]
mem_raw = sys.argv[5]

print("\n--- [EXPLORER STATUS: https://blocks.prysel.com/] ---")
if exp_raw and exp_raw.strip().startswith("{"):
    try:
        e = json.loads(exp_raw)
        chain = e.get("chain", {})
        print(f"Status           : {e.get('status', 'unknown')}")
        print(f"Network / Chain  : {e.get('network', '?')} ({e.get('chainId', '?')})")
        print(f"Block Height     : {e.get('height', chain.get('blocks', '?'))}")
        print(f"Tip Block Hash   : {e.get('tipHash', chain.get('bestBlockHash', '?'))}")
        print(f"Difficulty       : {chain.get('difficulty', '?')}")
        print(f"Algorithm        : {e.get('algorithm', 'x11')} (11 rounds)")
        print(f"Unconfirmed TXs  : {e.get('unconfirmed', {}).get('count', '?')} records ({e.get('unconfirmed', {}).get('bytes', '?')} B)")
        print(f"Total 24h Records: {e.get('last24h', {}).get('records', '?')}")
    except Exception as err:
        print(f"Error parsing explorer status: {err}")
else:
    print("Explorer status unavailable or unreachable.")

if exp_blocks_raw and exp_blocks_raw.strip().startswith("{"):
    try:
        b_data = json.loads(exp_blocks_raw)
        blocks = b_data.get("blocks", [])
        print(f"\nLatest Explorer Blocks (total {b_data.get('total', len(blocks))}):")
        for b in blocks[:3]:
            print(f"  # {b.get('height')}: {b.get('hash')} | txs: {b.get('txCount')} | diff: {b.get('difficulty')}")
    except Exception as err:
        pass

print("\n--- [LOCAL CDCI NODE STATUS] ---")
if node_raw and node_raw.strip().startswith("{"):
    try:
        n = json.loads(node_raw)
        net = json.loads(net_raw) if net_raw and net_raw.startswith("{") else {}
        mem = json.loads(mem_raw) if mem_raw and mem_raw.startswith("{") else {}

        print(f"Network / Chain  : {n.get('chain', '?')}")
        print(f"Block Height     : {n.get('blocks', '?')}")
        print(f"Headers Height   : {n.get('headers', '?')}")
        print(f"Best Block Hash  : {n.get('bestblockhash', '?')}")
        print(f"Difficulty       : {n.get('difficulty', '?')}")
        print(f"Mempool Size     : {mem.get('size', n.get('mempool', '?'))} transactions ({mem.get('bytes', 0)} B)")
        print(f"Peer Connections : {net.get('connections', '?')}")
        print(f"Subversion       : {net.get('subversion', '?')}")
        print(f"Node Status      : OK (Synchronized: {n.get('verificationprogress', 1.0) >= 0.999})")
    except Exception as err:
        print(f"Error parsing node info: {err}")
else:
    print("Local CDCI node is NOT reachable at configured RPC_URL.")
    print("If running via Docker, make sure the node service is up:")
    print("  docker compose -f docker/docker-compose.yml up -d")

print("\n----------------------------------------------------------")
PY

