#!/usr/bin/env bash
# Start/stop the llama.cpp server in the background.
# Usage: llama-ctl.sh start|stop|toggle|status   (status exits 0 when running)
set -uo pipefail

HERE="$(dirname "$(readlink -f "$0")")/.."
# Local machine paths (model, llama.cpp build). Never committed.
[[ -f $HERE/config.env ]] && . "$HERE/config.env"

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/llama-server.pid"
LOG="${LLAMA_LOG:-$HERE/llama-server.log}"

running() {
    local pid
    [[ -r $PIDFILE ]] || return 1
    pid=$(<"$PIDFILE")
    [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null
}

start() {
    running && return 0
    setsid "$HERE/scripts/run-server.sh" >>"$LOG" 2>&1 </dev/null &
    echo $! >"$PIDFILE" # run-server.sh execs llama-server, so $! is the server
}

stop() {
    local pid i
    running || {
        rm -f "$PIDFILE"
        return 0
    }
    pid=$(<"$PIDFILE")
    kill "$pid" 2>/dev/null
    for i in {1..50}; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
    done
    kill -9 "$pid" 2>/dev/null
    rm -f "$PIDFILE"
}

case "${1:-status}" in
    start) start ;;
    stop) stop ;;
    toggle) if running; then stop; else start; fi ;;
    status)
        if running; then
            echo "running (pid $(<"$PIDFILE"))"
            exit 0
        fi
        echo stopped
        exit 1
        ;;
    *)
        echo "usage: $0 start|stop|toggle|status" >&2
        exit 2
        ;;
esac
