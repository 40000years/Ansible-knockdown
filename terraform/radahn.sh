#!/bin/bash

# Configuration
IMAGE_NAME="radahn-dashboard"
CONTAINER_NAME="radahn-dashboard"
PORT=8000
# Resolve the real path of the script even if called via a symlink
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
# Function to show usage
show_help() {
    echo "Usage: radahn [start|stop|logs|update]"
    echo "Commands:"
    echo "  start   - Builds and starts the Radahn Local Dashboard container"
    echo "  stop    - Stops the Radahn Local Dashboard container"
    echo "  logs    - Shows the logs of the container"
    echo "  update  - Pulls the latest version from GitHub"
}

if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Docker Permission Auto-Escalation (Semaphore-like feel)
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    echo "[Radahn] Requesting sudo access for Docker..."
    if sudo -n docker ps >/dev/null 2>&1 || sudo docker ps >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    else
        echo "[Radahn] Error: Cannot run Docker. Please ensure Docker is installed and running."
        exit 1
    fi
fi

case "$1" in
    start)
        echo "[Radahn] Stopping any existing container..."
        $DOCKER_CMD stop $CONTAINER_NAME 2>/dev/null || true
        $DOCKER_CMD rm $CONTAINER_NAME 2>/dev/null || true

        echo "[Radahn] Building Docker image (this will be fast if already built)..."
        $DOCKER_CMD build -t $IMAGE_NAME "$DIR"

        echo "[Radahn] Starting container..."
        $DOCKER_CMD run -d --name $CONTAINER_NAME \
            -p $PORT:8000 \
            -v ~/.aws:/root/.aws \
            -v "$DIR":/app \
            -w /app \
            $IMAGE_NAME

        echo ""
        echo "=================================================================="
        echo " 🚀 RADAHN DASHBOARD RUNNING AT: http://localhost:$PORT"
        echo " 🔒 Secured via Docker Container & Read-only ~/.aws"
        echo " 🛑 To stop, run: radahn stop"
        echo " 📜 To view logs, run: radahn logs"
        echo "=================================================================="
        ;;
    stop)
        echo "[Radahn] Stopping container..."
        $DOCKER_CMD stop $CONTAINER_NAME
        $DOCKER_CMD rm $CONTAINER_NAME
        echo "[Radahn] Container stopped."
        ;;
    logs)
        $DOCKER_CMD logs -f $CONTAINER_NAME
        ;;
    update)
        echo "[Radahn] Updating system from GitHub..."
        (cd "$DIR/.." && git fetch origin Radahn && git reset --hard origin/Radahn)
        echo "[Radahn] Update complete! Run 'radahn start' to apply changes."
        ;;
    help)
        show_help
        exit 0
        ;;
    *)
        show_help
        exit 1
        ;;
esac
