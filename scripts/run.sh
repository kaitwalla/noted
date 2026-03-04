#!/bin/bash
#
# Noted Server Runner with Auto-Restart
#
# This script runs the Noted server and handles automatic restarts
# when an update is triggered. It monitors for SIGUSR1 signals and
# a .restart marker file.
#
# Usage: ./scripts/run.sh
#
# Environment variables:
#   UPDATE_SECRET     - Required for update endpoint authentication
#   UPDATE_ENABLED    - Set to "true" to enable auto-updates
#   GIT_BRANCH        - Branch to pull from (default: main)
#   SERVER_ROOT_PATH  - Path to repo root (default: parent of server dir)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"
RESTART_FILE="$SERVER_DIR/.restart"
BINARY="$SERVER_DIR/server"
PID_FILE="$SERVER_DIR/.server.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[noted]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[noted]${NC} $1"
}

error() {
    echo -e "${RED}[noted]${NC} $1"
}

# Clean up on exit
cleanup() {
    log "Cleaning up..."
    rm -f "$PID_FILE"
    rm -f "$RESTART_FILE"
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        log "Stopping server (PID: $SERVER_PID)..."
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    log "Goodbye!"
}

trap cleanup EXIT

# Handle restart signal
restart_requested=false
handle_restart() {
    restart_requested=true
    log "Restart signal received"
}

trap handle_restart USR1

# Build if binary doesn't exist
build_server() {
    log "Building server..."
    cd "$SERVER_DIR"
    go build -o server ./cmd/server
    log "Build complete"
}

# Main loop
main() {
    log "Starting Noted server runner"
    log "Server directory: $SERVER_DIR"

    # Export SERVER_ROOT_PATH if not set
    if [ -z "$SERVER_ROOT_PATH" ]; then
        export SERVER_ROOT_PATH="$(dirname "$SERVER_DIR")"
    fi
    log "Repository root: $SERVER_ROOT_PATH"

    # Build if needed
    if [ ! -f "$BINARY" ]; then
        build_server
    fi

    # Clean up any stale restart file
    rm -f "$RESTART_FILE"

    while true; do
        restart_requested=false

        log "Starting server..."
        cd "$SERVER_DIR"
        ./server &
        SERVER_PID=$!
        echo $SERVER_PID > "$PID_FILE"
        log "Server started (PID: $SERVER_PID)"

        # Wait for server to exit or restart signal
        while kill -0 "$SERVER_PID" 2>/dev/null; do
            # Check for restart file (created by update handler)
            if [ -f "$RESTART_FILE" ]; then
                log "Restart file detected"
                restart_requested=true
                rm -f "$RESTART_FILE"
                break
            fi

            # Check for restart signal
            if [ "$restart_requested" = true ]; then
                break
            fi

            sleep 1
        done

        # Stop the server if still running
        if kill -0 "$SERVER_PID" 2>/dev/null; then
            log "Stopping server for restart..."
            kill -TERM "$SERVER_PID" 2>/dev/null || true

            # Wait for graceful shutdown (max 30 seconds)
            for i in {1..30}; do
                if ! kill -0 "$SERVER_PID" 2>/dev/null; then
                    break
                fi
                sleep 1
            done

            # Force kill if still running
            if kill -0 "$SERVER_PID" 2>/dev/null; then
                warn "Server didn't stop gracefully, forcing..."
                kill -9 "$SERVER_PID" 2>/dev/null || true
            fi
        fi

        wait "$SERVER_PID" 2>/dev/null || true
        EXIT_CODE=$?

        if [ "$restart_requested" = true ]; then
            log "Restarting server..."
            sleep 1
            continue
        fi

        # Server exited on its own
        if [ $EXIT_CODE -eq 0 ]; then
            log "Server exited normally"
            break
        else
            error "Server crashed with exit code $EXIT_CODE"
            warn "Restarting in 5 seconds..."
            sleep 5
        fi
    done
}

main "$@"
