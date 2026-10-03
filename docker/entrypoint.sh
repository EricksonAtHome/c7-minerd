#!/usr/bin/env bash
set -e

cmd="${1:-c7-minerd}"

if [[ "$cmd" == "centraldatabased" ]]; then
  exec /usr/local/bin/centraldatabased "${@:2}"
elif [[ "$cmd" == "centraldatabase-cli" ]]; then
  exec /usr/local/bin/centraldatabase-cli "${@:2}"
elif [[ "$cmd" == "check-blocks" ]]; then
  exec /usr/local/bin/check-blocks "${@:2}"
elif [[ "$cmd" == "c7-minerd" || "$cmd" == "miner" ]]; then
  exec /usr/local/bin/c7-minerd "${@:2}"
else
  exec "$@"
fi
