#!/usr/bin/env bash
# Mirror the packaged caelestia shell into ~/.config/quickshell/caelestia as per-file
# symlinks, then apply our chat-panel patches on top. Rerun after caelestia-shell updates.
#   ./sync.sh           install / refresh
#   ./sync.sh --clean   drop the mirror, go back to the packaged shell
set -euo pipefail

SRC=/etc/xdg/quickshell/caelestia
DST="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
HERE="$(dirname "$(readlink -f "$0")")"

if [[ ${1:-} == "--clean" ]]; then
    rm -rf "$DST"
    echo "removed $DST"
    exit 0
fi

[[ -d $SRC ]] || { echo "error: $SRC not found (caelestia-shell installed?)" >&2; exit 1; }

rm -rf "$DST"
mkdir -p "$DST"
(cd "$SRC" && find . -type d -exec mkdir -p "$DST/{}" \;)
(cd "$SRC" && find . -type f -exec ln -s "$SRC/{}" "$DST/{}" \;)
python3 "$HERE/shell-overlay/patch.py" "$DST"

echo
echo "mirror ready: $DST"
echo "restart the shell: qs -c caelestia kill; sleep .1; caelestia shell -d"
