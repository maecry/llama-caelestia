#!/usr/bin/env bash
# List recent pi sessions for a working directory, newest first.
# usage: pi-sessions.sh [count]   → one line per session: "<path>\t<date>\t<first user prompt>"
set -uo pipefail

COUNT="${1:-8}"
CWD="${PI_SESSIONS_CWD:-$HOME}"

# pi encodes the cwd as --path-with-dashes-- under ~/.pi/agent/sessions/
slug=$(realpath --relative-to=/ "$CWD" | tr '/' '-')
dir="$HOME/.pi/agent/sessions/--$slug--"
[[ -d $dir ]] || exit 0

find "$dir" -maxdepth 1 -name '*.jsonl' -printf '%T@\t%p\n' | sort -rn | head -n "$COUNT" |
    while IFS=$'\t' read -r _ path; do
        snippet=$(python3 - "$path" <<'PY'
import json, sys
for line in open(sys.argv[1], errors="replace"):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    m = e.get("message") or {}
    if e.get("type") == "message" and m.get("role") == "user":
        c = m.get("content") or []
        text = " ".join(p.get("text", "") for p in c if isinstance(p, dict))
        print(text.replace("\n", " ")[:80])
        break
PY
)
        date=$(basename "$path" | cut -c1-16 | tr 'T' ' ')
        printf '%s\t%s\t%s\n' "$path" "$date" "${snippet:-…}"
    done
