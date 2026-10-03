:; # Shell polyglot header: allows running directly in Mac/Linux terminal as ./start-miner.bat
:; DIR="$(cd "$(dirname "$0")" && pwd)"
:; cd "$DIR"
:; exec bash "$DIR/run.sh" "$@"
@echo off
color 07
setlocal enabledelayedexpansion

title Prysel C7 Miner

echo ==========================================================
echo           Starting Prysel C7 Miner (Windows)
echo ==========================================================

cd /d "%~dp0"

echo [INFO] Ensuring C7 node container is running...
docker compose -f docker\docker-compose.yml up -d c7-node
docker compose -f docker\docker-compose.yml stop c7-minerd >nul 2>&1

echo [INFO] Starting miner in terminal...
python c7-miner.py 2>nul || python3 ./c7-miner.py

pause
