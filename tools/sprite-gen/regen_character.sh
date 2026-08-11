#!/usr/bin/env bash
# Regenerate every sheet for one character with the hardened prompts.
#
#   ./tools/sprite-gen/regen_character.sh murloc
#
# Reference sheet first (nothing attached), then the 4 animation sheets in
# parallel with the reference attached. Prompts come from prompts.py so the
# Identity Lock and the no-text clause can't be dropped by hand-pasting.
#
# Must run in the FOREGROUND: gemini_bot.py drives a visible Chrome window and
# a backgrounded process gets no window.

set -euo pipefail

CHAR="${1:-}"
if [[ -z "$CHAR" ]]; then
  echo "usage: $0 <character>"
  python3 "$(dirname "$0")/prompts.py" --list
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BOT="$ROOT/tools/sprite-gen/gemini_bot.py"
P="$ROOT/tools/sprite-gen/prompts.py"
REF="${CHAR}-reference-sheet.png"

prompt() { python3 "$P" "$CHAR" "$1"; }

echo "=== $CHAR: reference sheet ==="
python3 "$BOT" "$(prompt reference)" "$REF"

echo "=== $CHAR: 4 animation sheets in parallel ==="
python3 "$BOT" --parallel "$REF" \
  "$(prompt idle)"       "${CHAR}-idle.png" \
  "$(prompt walk)"       "${CHAR}-walk.png" \
  "$(prompt attack)"     "${CHAR}-attack.png" \
  "$(prompt hurt-death)" "${CHAR}-hurt-death.png"

echo "=== $CHAR: done. Slice + normalize with:"
echo "    python3 tools/slice_sprites.py && python3 tools/normalize_frames.py $CHAR"
