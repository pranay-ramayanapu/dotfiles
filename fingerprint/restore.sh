#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$SCRIPT_DIR/fprint-backup"

echo "Installing patched libfprint..."

sudo install -Dm755 \
    "$BACKUP/libfprint-2.so.2.0.0" \
    /usr/local/lib64/libfprint-2.so.2.0.0

sudo ln -sfn /usr/local/lib64/libfprint-2.so.2.0.0 \
    /usr/local/lib64/libfprint-2.so.2

sudo ln -sfn /usr/local/lib64/libfprint-2.so.2 \
    /usr/local/lib64/libfprint-2.so

sudo install -Dm644 \
    "$SCRIPT_DIR/local-lib64.conf" \
    /etc/ld.so.conf.d/local-lib64.conf

sudo ldconfig

echo "Restarting fingerprint service..."
sudo systemctl restart fprintd

echo "Verifying library..."
ldd /usr/libexec/fprintd | grep libfprint

echo "Fingerprint driver restoration complete."
