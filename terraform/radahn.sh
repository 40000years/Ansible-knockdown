#!/bin/bash

# Configuration
IMAGE_NAME="radahn-dashboard"
CONTAINER_NAME="radahn-dashboard"
PORT=8000
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to show usage
show_help() {
    echo "Usage: radahn [start|stop|logs]"
    echo "Commands:"
    echo "  start   - Builds and starts the Radahn Local Dashboard container"
    echo "  stop    - Stops the Radahn Local Dashboard container"
    echo "  logs    - Shows the logs of the container"
}

if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

case "$1" in
    start)
        echo "[Radahn] Stopping any existing container..."
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true

        echo "[Radahn] Building Docker image (this will be fast if already built)..."
        docker build -t $IMAGE_NAME "$DIR"

        echo "[Radahn] Starting container..."
        docker run -d --name $CONTAINER_NAME \
            -p $PORT:8000 \
            -v ~/.aws:/root/.aws:ro \
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
        docker stop $CONTAINER_NAME
        docker rm $CONTAINER_NAME
        echo "[Radahn] Container stopped."
        ;;
    logs)
        docker logs -f $CONTAINER_NAME
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
