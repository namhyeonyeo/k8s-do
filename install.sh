#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/usr/local/bin/k8s-do"
COMPLETION_PATH="/etc/bash_completion.d/k8s-do"
CONFIG_DIR="/etc/k8s-do"
CONFIG_PATH="$CONFIG_DIR/config.sh"

install -d -m 750 "$CONFIG_DIR"
install -m 755 "$SRC_DIR/k8s-do" "$BIN_PATH"
install -m 644 "$SRC_DIR/k8s-do.completion" "$COMPLETION_PATH"

if [[ ! -f "$CONFIG_PATH" ]]; then
  install -m 640 "$SRC_DIR/config.sh" "$CONFIG_PATH"
  echo "[INFO] Installed new config: $CONFIG_PATH"
else
  cp -f "$CONFIG_PATH" "$CONFIG_PATH.bak.$(date +%Y%m%d%H%M%S)"
  install -m 640 "$SRC_DIR/config.sh" "$CONFIG_PATH"
  echo "[INFO] Replaced config and created backup under $CONFIG_DIR"
fi

mkdir -p /srv/k8s/file/ssh/kubeconfigs /srv/k8s/file/ssh/privatekey /srv/k8s/file/ssh/cache 2>/dev/null || true
chmod 700 /srv/k8s/file/ssh/privatekey 2>/dev/null || true

hash -r 2>/dev/null || true

echo "[OK] Installed k8s-do v3.2.5"
echo "Run: source $COMPLETION_PATH"
echo "Check: k8s-do version && k8s-do __complete clusters"
