#!/bin/bash
set -e

# ตรวจสอบและติดตั้ง aws-cli หากยังไม่มีในระบบ
if ! command -v aws >/dev/null 2>&1; then
    echo "[Setup] aws command not found. Attempting to install AWS CLI..."
    if command -v apk >/dev/null 2>&1; then
        echo "[Setup] Alpine Linux detected. Installing aws-cli via apk..."
        sudo apk add --no-cache aws-cli || apk add --no-cache aws-cli
    elif command -v apt-get >/dev/null 2>&1; then
        echo "[Setup] Debian/Ubuntu detected. Installing awscli via apt-get..."
        sudo apt-get update && sudo apt-get install -y awscli || (apt-get update && apt-get install -y awscli)
    elif command -v pip3 >/dev/null 2>&1; then
        echo "[Setup] pip3 detected. Installing awscli via pip3..."
        pip3 install awscli || pip3 install --user awscli
        export PATH=$PATH:$HOME/.local/bin
    else
        echo "[Setup] Error: Cannot find a way to install aws-cli (no apk, apt-get, or pip3)."
        exit 1
    fi
fi

echo "[Setup] aws-cli is ready."

# รันสคริปต์ Python
python3 "$(dirname "$0")/generate_dashboard.py"
