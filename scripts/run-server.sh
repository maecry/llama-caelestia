#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# llama.cpp server with the caveman/ponytail chat template applied.
# Defaults target Ornith-1.5-9B (Q8_0) + vision on Vulkan with a 192k context.
# Machine-specific paths belong in <repo>/config.env (see config.env.example).
#
#   scripts/run-server.sh                  # defaults: 192k ctx, full GPU offload
#   NGL=12 scripts/run-server.sh           # fewer GPU layers (when VRAM is busy)
#   UBATCH=512 scripts/run-server.sh       # smaller prefill chunk if VRAM is tight
#   LOAD_MODE=mmap+mlock scripts/run-server.sh   # needs: ulimit -l unlimited
#
# Then:  curl http://127.0.0.1:8000/v1/models
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(dirname "$(readlink -f "$0")")/.."
[[ -f $ROOT/config.env ]] && . "$ROOT/config.env"
BIN="${BIN:-$ROOT/llama.cpp/build/bin/llama-server}"
export LD_LIBRARY_PATH="$(dirname "$BIN")${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" # libs live next to the binary

MODEL="${MODEL:-$ROOT/models/Ornith-1.5-9B-Q8_0.gguf}"
MMPROJ="${MMPROJ:-$ROOT/models/mmproj-Ornith-1.5-9B-BF16.gguf}"

CTX="${CTX:-196608}"        # 192k tokens (model supports 262144 natively, no YaRN needed)
NGL="${NGL:-99}"            # layers to offload to the GPU
KV="${KV_TYPE:-q8_0}"       # KV cache type: f16 | q8_0 | q4_0
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8000}"

# --- prompt-processing (prefill) tuning -------------------------------------
UBATCH="${UBATCH:-2048}"       # tokens per forward pass (default 512). Main prefill knob.
BATCH="${BATCH:-4096}"         # logical batch, must be >= UBATCH
NP="${NP:-1}"                  # server slots. 1 = one request may use the whole 192k
CACHE_REUSE="${CACHE_REUSE:-256}"  # reuse KV of an unchanged shared prompt prefix
THREADS="${THREADS:-12}"       # CPU threads for generation (i7-12700KF: 12 physical)
TBATCH="${TBATCH:-12}"         # CPU threads for prompt processing
LOAD_MODE="${LOAD_MODE:-mmap}" # auto | mmap | mlock | mmap+mlock | dio | none

# Chat template with the caveman/ponytail style block baked in (applies to every client).
TEMPLATE="${TEMPLATE:-$ROOT/style/caveman-ponytail.jinja}"

# Sampler settings from the Ornith-1.5 model card ("precise coding" profile).
TEMP="${TEMP:-0.6}"
TOP_P="${TOP_P:-0.95}"
TOP_K="${TOP_K:-20}"
MIN_P="${MIN_P:-0.0}"

for f in "$BIN" "$MODEL" "$MMPROJ"; do
  [[ -e "$f" ]] || { echo "error: missing $f" >&2; exit 1; }
done

if [[ "$LOAD_MODE" == *mlock* && "$(ulimit -l)" != "unlimited" ]]; then
  echo "warning: ulimit -l is $(ulimit -l) KiB; '$LOAD_MODE' may fail. Run: ulimit -l unlimited" >&2
fi

EXTRA=()
[[ -f "$TEMPLATE" ]] && EXTRA+=(--chat-template-file "$TEMPLATE")

exec "$BIN" \
  -m        "$MODEL" \
  --mmproj  "$MMPROJ" \
  --alias   "${ALIAS:-Ornith-1.5-9B}" \
  -c        "$CTX" \
  -ngl      "$NGL" \
  -fa       on \
  -ctk      "$KV" \
  -ctv      "$KV" \
  -b        "$BATCH" \
  -ub       "$UBATCH" \
  -np       "$NP" \
  -t        "$THREADS" \
  -tb       "$TBATCH" \
  -lm       "$LOAD_MODE" \
  --cache-reuse     "$CACHE_REUSE" \
  --warmup \
  --host    "$HOST" \
  --port    "$PORT" \
  --jinja \
  --reasoning-format deepseek \
  --temp    "$TEMP" \
  --top-p   "$TOP_P" \
  --top-k   "$TOP_K" \
  --min-p   "$MIN_P" \
  "${EXTRA[@]}"
