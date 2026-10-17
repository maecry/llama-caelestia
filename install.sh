#!/usr/bin/env bash
# Install / refresh the chat panel and the server control script.
set -euo pipefail

HERE="$(dirname "$(readlink -f "$0")")"

command -v caelestia >/dev/null || { echo "error: caelestia shell not found" >&2; exit 1; }
[[ -x ${HOME}/.pi/agent/bin/pi ]] || echo "warning: ${HOME}/.pi/agent/bin/pi missing — edit ChatState.qml" >&2

mkdir -p "${HOME}/.local/bin"
ln -sf "$HERE/scripts/llama-ctl.sh" "${HOME}/.local/bin/llama-ctl"
ln -sf "$HERE/scripts/pi-sessions.sh" "${HOME}/.local/bin/pi-sessions"

"$HERE/sync.sh"

cat <<'EOF'

next:
  1. add ~/.local/bin to PATH (if it is not already) and a model entry for the
     llama.cpp server in ~/.pi/agent/models.json (see README)
  2. restart the shell:
       qs -c caelestia kill; sleep .1; caelestia shell -d
EOF
