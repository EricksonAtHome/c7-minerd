#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/RoboticsStudio/Centraldb_CDCI.git}"
REF="${REF:-main}"
PREFIX="${PREFIX:-/opt/centraldatabase}"

sudo apt-get update
sudo apt-get install -y \
  build-essential autoconf automake libtool pkg-config \
  git curl python3 ca-certificates \
  bsdmainutils

sudo mkdir -p "$PREFIX"
sudo chown "$USER":"$USER" "$PREFIX"

if [[ ! -d "$PREFIX/src/Centraldb_CDCI/.git" ]]; then
  mkdir -p "$PREFIX/src"
  git clone --branch "$REF" "$REPO_URL" "$PREFIX/src/Centraldb_CDCI"
else
  git -C "$PREFIX/src/Centraldb_CDCI" fetch --all
  git -C "$PREFIX/src/Centraldb_CDCI" checkout "$REF"
  git -C "$PREFIX/src/Centraldb_CDCI" pull --ff-only || true
fi

cd "$PREFIX/src/Centraldb_CDCI"

# Project-provided deterministic dependencies.
make -C depends NO_QT=1 NO_WALLET=1 NO_UPNP=1 -j"$(nproc)"

./autogen.sh

./configure \
  --prefix="$PREFIX" \
  --disable-wallet \
  --disable-tests \
  --disable-bench \
  --enable-miner

make -j"$(nproc)"
make install

echo
echo "Built:"
"$PREFIX/bin/centraldatabased" --version || true
echo
echo "Miner RPC should be available as:"
echo "  generatetoaddress <nblocks> <address> <maxtries>"
