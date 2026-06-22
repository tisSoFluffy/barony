#!/usr/bin/env bash
# Smoke-test the local-LLM handoff against a running LM Studio.
# Usage:  bash tools/local-llm/smoke.sh
# Proves the tool talks to your real local model and can code a Barony task.
set -euo pipefail

cd "$(dirname "$0")/../.."   # repo root
TOOL="tools/local-llm/lmstudio.py"

echo "==> 1/2  Models loaded in LM Studio:"
if ! python3 "$TOOL" --list-models; then
  echo "    LM Studio not reachable. Start its server + load a model, then retry." >&2
  exit 1
fi

echo
echo "==> 2/2  Handing off a real Barony task (commafy for Util.gd):"
python3 "$TOOL" \
  --system "You are a Godot 4.7 GDScript expert. Output ONLY valid GDScript — no markdown fences, no prose. Match the terse style of the provided file." \
  --file godot/scripts/Util.gd \
  'Write a static function commafy(n: int) -> String that formats an integer with thousands separators. Examples: 1234 -> "1,234", -98765 -> "-98,765", 0 -> "0", 100 -> "100". Pure logic only. Return just the function.'

echo
echo "==> Done. Review the GDScript above; if it looks right, ask me to integrate it."
