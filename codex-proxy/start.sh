#!/bin/bash
# Codex Proxy - Responses API to Chat Completions converter
# Usage: ./start.sh [start|stop|status|logs]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_BIN="$SCRIPT_DIR/codex-proxy"
PID_FILE="$SCRIPT_DIR/.codex-proxy.pid"
LOG_FILE="$SCRIPT_DIR/.codex-proxy.log"

# Default configuration - connects to llama.cpp server
LISTEN_ADDR="${LISTEN_ADDR:-:28081}"
UPSTREAM_URL="${UPSTREAM_URL:-http://127.0.0.1:28080/v1}"

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Codex proxy already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    echo "Starting codex-proxy..."
    echo "  Listen: $LISTEN_ADDR"
    echo "  Upstream: $UPSTREAM_URL"

    cd "$SCRIPT_DIR"
    LISTEN_ADDR="$LISTEN_ADDR" UPSTREAM_URL="$UPSTREAM_URL" \
        nohup "$PROXY_BIN" > "$LOG_FILE" 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"
    sleep 1

    if kill -0 "$pid" 2>/dev/null; then
        echo "Started codex-proxy (PID: $pid)"
        echo ""
        echo "Configure Codex to use proxy:"
        echo "  base_url = \"http://127.0.0.1:${LISTEN_ADDR#:}/v1\""
    else
        echo "Failed to start. Check $LOG_FILE"
        rm -f "$PID_FILE"
        return 1
    fi
}

stop() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping codex-proxy (PID: $pid)..."
            kill "$pid"
            echo "Stopped."
        else
            echo "Not running."
        fi
        rm -f "$PID_FILE"
    else
        echo "No PID file."
    fi
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Running (PID: $(cat "$PID_FILE"))"
        curl -s "http://127.0.0.1${LISTEN_ADDR#:}/health" 2>/dev/null && echo ""
    else
        echo "Not running."
        rm -f "$PID_FILE" 2>/dev/null
    fi
}

logs() {
    tail -f "$LOG_FILE"
}

case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 1; start ;;
    status)  status ;;
    logs)    logs ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Environment:"
        echo "  LISTEN_ADDR   Listen address (default: :28081)"
        echo "  UPSTREAM_URL  Upstream API (default: http://127.0.0.1:28080/v1)"
        exit 1
        ;;
esac
