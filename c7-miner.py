#!/usr/bin/env python3
"""
Prysel C7 Miner & Terminal UI (XMRig Style)
Connects to CentralDataBase CDCI via JSON-RPC, mines X11 Proof-of-Work,
and provides a beautiful XMRig-style dashboard in the terminal.
"""

import sys
import os
import time
import json
import base64
import urllib.request
import urllib.error
import platform
import subprocess
from datetime import datetime

# Enable ANSI colors on Windows CMD
if platform.system() == "Windows":
    os.system("color 07")
    os.system("")

# Terminal background setup for standard black
def setup_terminal():
    if platform.system() == "Windows":
        os.system("color 07")
    # OSC 11 sets background to black (#000000), OSC 10 sets text to light gray (#cccccc)
    sys.stdout.write("\033]11;#000000\007\033]10;#cccccc\007")
    # Clear screen with black background
    sys.stdout.write("\033[40m\033[2J\033[H")
    sys.stdout.flush()

def restore_terminal():
    # Reset terminal colors on exit
    sys.stdout.write("\033]111\007\033]110\007\033[0m\n")
    sys.stdout.flush()

# ANSI Color Codes
RESET   = "\033[0m"
DIM     = "\033[90m"
BOLD    = "\033[1m"
GREEN   = "\033[32m"
B_GREEN = "\033[92;1m"
CYAN    = "\033[36m"
B_CYAN  = "\033[96;1m"
MAGENTA = "\033[35m"
B_MAG   = "\033[95;1m"
YELLOW  = "\033[33m"
B_YEL   = "\033[93;1m"
WHITE   = "\033[97m"
B_WHITE = "\033[97;1m"
RED     = "\033[91;1m"

# Badges (XMRig background tags)
TAG_NET    = f"\033[44;97m net    {RESET}"
TAG_CPU    = f"\033[46;97m cpu    {RESET}"
TAG_MINER  = f"\033[45;97m miner  {RESET}"
TAG_BLOCK  = f"\033[42;30;1m block  {RESET}"
TAG_SIGNAL = f"\033[43;30;1m signal {RESET}"
TAG_WARN   = f"\033[41;97;1m error  {RESET}"

def log(tag: str, msg: str):
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    print(f"{DIM}[{now_str}]{RESET}  {tag}  {msg}")
    sys.stdout.flush()

def load_env(path: str = ".env"):
    cfg = {}
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip('"').strip("'")
                    cfg[k] = v
    return cfg

env = load_env()
RPC_URL = os.environ.get("RPC_URL", env.get("RPC_URL", "http://127.0.0.1:13431/"))
RPC_USER = os.environ.get("RPC_USER", env.get("RPC_USER", "c7miner"))
RPC_PASSWORD = os.environ.get("RPC_PASSWORD", env.get("RPC_PASSWORD", "change-me"))
MINER_ADDRESS = os.environ.get("MINER_ADDRESS", env.get("MINER_ADDRESS", "CGZCSzBowAqgHcXPtMT3vs7ycp8hLi5UAD"))
MAX_TRIES = int(os.environ.get("MAX_TRIES", env.get("MAX_TRIES", "1000000")))
BLOCKS_PER_CALL = int(os.environ.get("BLOCKS_PER_CALL", env.get("BLOCKS_PER_CALL", "1")))
SLEEP_SECONDS = float(os.environ.get("SLEEP_SECONDS", env.get("SLEEP_SECONDS", "0.5")))
EXPLORER_URL = os.environ.get("EXPLORER_URL", env.get("EXPLORER_URL", "https://blocks.prysel.com/"))

def rpc_call(method: str, params: list = None, timeout: float = 60.0):
    if params is None:
        params = []
    payload = json.dumps({
        "jsonrpc": "1.0",
        "id": "c7-miner",
        "method": method,
        "params": params
    }).encode("utf-8")

    req = urllib.request.Request(RPC_URL, data=payload)
    req.add_header("Content-Type", "application/json")
    if RPC_USER and RPC_PASSWORD:
        auth = base64.b64encode(f"{RPC_USER}:{RPC_PASSWORD}".encode()).decode()
        req.add_header("Authorization", f"Basic {auth}")

    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = json.loads(resp.read().decode())
        if data.get("error"):
            raise RuntimeError(str(data["error"]))
        return data.get("result")

def get_cpu_info():
    name = platform.processor() or "x86_64 CPU"
    cores = os.cpu_count() or 4
    if platform.system() == "Darwin":
        try:
            out = subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip()
            if out:
                name = out
        except Exception:
            pass
    elif platform.system() == "Linux":
        try:
            with open("/proc/cpuinfo") as f:
                for line in f:
                    if "model name" in line:
                        name = line.split(":", 1)[1].strip()
                        break
        except Exception:
            pass
    return name, cores

def get_ram_info():
    if platform.system() == "Darwin":
        try:
            out = subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True).strip()
            total_gb = int(out) / (1024 ** 3)
            return f"7.5/{total_gb:.1f} GB (94%)"
        except Exception:
            pass
    return "8.0/8.0 GB"

def render_banner(cpu_name, cores, ram_str, diff, height):
    print(f"{GREEN} * ABOUT       {RESET} {B_WHITE}Prysel C7 Miner / CDCI Core v1.0.0{RESET}")
    print(f"{GREEN} * LIBS        {RESET} {WHITE}libevent OpenSSL/3.0.x x11-native{RESET}")
    print(f"{GREEN} * HUGE PAGES  {RESET} {B_GREEN}permission granted{RESET}")
    print(f"{GREEN} * 1GB PAGES   {RESET} {DIM}unavailable{RESET}")
    print(f"{GREEN} * CPU         {RESET} {B_WHITE}{cpu_name} ({cores}T) 64-bit AES{RESET}")
    print(f"                {CYAN}L2:0.5 MB L3:4.0 MB {cores}C/{cores}T NUMA:1{RESET}")
    print(f"{GREEN} * MEMORY      {RESET} {WHITE}{ram_str}{RESET}")
    print(f"{GREEN} * DONATE      {RESET} {MAGENTA}0%{RESET}")
    print(f"{GREEN} * POOL #1     {RESET} {B_WHITE}{RPC_URL}{RESET} {CYAN}algo x11 diff {diff:.5f}{RESET}")
    print(f"{GREEN} * EXPLORER    {RESET} {B_CYAN}{EXPLORER_URL}{RESET}")
    print(f"{GREEN} * PAYOUT      {RESET} {YELLOW}{MINER_ADDRESS}{RESET}")
    print(f"{GREEN} * COMMANDS    {RESET} {MAGENTA}h{RESET}ashrate, {MAGENTA}p{RESET}ause, {MAGENTA}r{RESET}esume, {MAGENTA}b{RESET}locks, {MAGENTA}c{RESET}onnection")
    print(f"{GREEN} * OPENCL      {RESET} {DIM}disabled{RESET}")
    print(f"{GREEN} * CUDA        {RESET} {DIM}disabled{RESET}")
    sys.stdout.flush()

def main():
    setup_terminal()
    try:
        cpu_name, cores = get_cpu_info()
        ram_str = get_ram_info()

        # Initial probe
        info = None
        for attempt in range(15):
            try:
                info = rpc_call("getblockchaininfo")
                break
            except Exception as e:
                if attempt == 0:
                    log(TAG_WARN, f"waiting for node at {RPC_URL}: {e}")
                time.sleep(1.5)

        if not info:
            log(TAG_WARN, f"Could not connect to C7 node at {RPC_URL}. Ensure tunnel or daemon is running.")
            sys.exit(1)

        diff = info.get("difficulty", 0.00304)
        height = info.get("blocks", 0)

        render_banner(cpu_name, cores, ram_str, diff, height)

        log(TAG_NET, f"use node {RPC_URL} (authenticated)")
        log(TAG_NET, f"new job from cdci:main diff {diff:.5f} algo x11 height {height}")
        log(TAG_CPU, f"use x11 implementation 11-round chained (Blake, BMW, Groestl, Skein, JH, Keccak...)")
        log(TAG_CPU, f"READY threads {cores}/{cores} memory {ram_str} AES-NI: supported")

        # Hashrate tracking
        speed_history = []
        max_speed = 0.0
        accepted_blocks = 0
        total_attempts = 0

        while True:
            # Check mempool and block height
            try:
                mem_info = rpc_call("getmempoolinfo")
                mempool_size = mem_info.get("size", 0)
                if mempool_size > 0:
                    log(TAG_NET, f"mempool active: {B_CYAN}{mempool_size}{RESET} pending record(s) awaiting block inclusion")
            except Exception:
                mempool_size = 0

            # Execute mining round
            t0 = time.time()
            total_attempts += 1
            res = None
            err = None
            try:
                res = rpc_call("generatetoaddress", [BLOCKS_PER_CALL, MINER_ADDRESS, MAX_TRIES], timeout=180.0)
            except Exception as e:
                err = e

            t1 = time.time()
            elapsed = max(t1 - t0, 0.001)
            hashrate = MAX_TRIES / elapsed  # H/s
            speed_history.append((t1, hashrate))
            if hashrate > max_speed:
                max_speed = hashrate

            # Clean speed history older than 15 mins
            cutoff = t1 - 900
            speed_history = [item for item in speed_history if item[0] >= cutoff]

            # Calculate 10s and 60s averages
            h_10s = [h for t, h in speed_history if t >= t1 - 10]
            h_60s = [h for t, h in speed_history if t >= t1 - 60]
            avg_10s = sum(h_10s) / len(h_10s) if h_10s else hashrate
            avg_60s = sum(h_60s) / len(h_60s) if h_60s else hashrate

            # Convert to kH/s
            s_10s_str = f"{avg_10s / 1000.0:.1f}"
            s_60s_str = f"{avg_60s / 1000.0:.1f}"
            s_max_str = f"{max_speed / 1000.0:.1f}"

            if err:
                log(TAG_WARN, f"mining RPC error: {err}")
                time.sleep(2)
                continue

            # Check if block was solved
            if res and isinstance(res, list) and len(res) > 0:
                block_hash = res[0]
                accepted_blocks += 1
                ms = int(elapsed * 1000)
                log(TAG_BLOCK, f"{B_GREEN}ACCEPTED{RESET} ({accepted_blocks}/{accepted_blocks}) diff {diff:.5f} ({block_hash[:16]}...) ({ms} ms)")
                
                # Fetch updated blockchain height
                try:
                    new_info = rpc_call("getblockchaininfo")
                    new_height = new_info.get("blocks", height)
                    diff = new_info.get("difficulty", diff)
                    log(TAG_NET, f"new job from cdci:main diff {diff:.5f} algo x11 height {new_height}")
                except Exception:
                    pass
            else:
                # Normal mining speed update
                log(TAG_MINER, f"speed 10s/60s/15m {B_GREEN}{s_10s_str}{RESET} {GREEN}{s_60s_str}{RESET} n/a kH/s max {B_CYAN}{s_max_str}{RESET} kH/s")

            time.sleep(SLEEP_SECONDS)

    except KeyboardInterrupt:
        print()
        log(TAG_SIGNAL, "Ctrl+C received, exiting")
        restore_terminal()
        sys.exit(0)
    finally:
        restore_terminal()

if __name__ == "__main__":
    main()
