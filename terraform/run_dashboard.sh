#!/bin/bash
set -e

# ตรวจสอบและติดตั้ง aws-cli หากยังไม่มีในระบบ
if ! command -v aws >/dev/null 2>&1; then
    echo "[Setup] aws command not found. Attempting to install AWS CLI via pip3..."
    
    # พยายามติดตั้งผ่าน pip3 เนื่องจากเราไม่มีสิทธิ์ root (sudo)
    # และ Python 3.11+ อาจต้องการ --break-system-packages
    if pip3 install --user awscli --break-system-packages 2>/dev/null || pip3 install --user awscli 2>/dev/null || pip3 install awscli 2>/dev/null; then
        echo "[Setup] Successfully installed awscli via pip3."
    else
        echo "[Setup] Error: Failed to install awscli via pip3. Please ensure pip3 is available and has network access."
        exit 1
    fi
fi

# นำ ~/.local/bin เข้า PATH เผื่อ aws ถูกติดตั้งไว้ที่นั่น
export PATH=$PATH:$HOME/.local/bin

echo "[Setup] aws-cli is ready."

# รันสคริปต์ Python
python3 "$(dirname "$0")/generate_dashboard.py"
