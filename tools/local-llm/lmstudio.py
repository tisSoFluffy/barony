#!/usr/bin/env python3
"""Hand off a dev task to a local LLM served by LM Studio.

LM Studio exposes an OpenAI-compatible API (default http://localhost:1234/v1).
This CLI is dependency-free (stdlib only) so it runs anywhere Python 3.8+ does.

Examples
--------
  # Simple prompt
  lmstudio.py "Write a GDScript function that clamps a Vector2 to a rect"

  # With a system role and a couple of files as context
  lmstudio.py --system "You are a Godot 4.7 GDScript expert." \\
      --file godot/scripts/Player.gd \\
      "Suggest a stamina system for this controller"

  # Pipe content via stdin; the positional arg is the instruction (they merge)
  git diff | lmstudio.py --system "You are a code reviewer." "Review this diff for bugs"

  # Or let stdin be the whole prompt
  git diff | lmstudio.py -

  # Inspect what's loaded
  lmstudio.py --list-models

Configuration (env vars, all optional)
  LMSTUDIO_BASE_URL   default http://localhost:1234/v1
  LMSTUDIO_MODEL      default: first model reported by /v1/models
  LMSTUDIO_API_KEY    default "lm-studio" (LM Studio ignores it)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_BASE_URL = os.environ.get("LMSTUDIO_BASE_URL", "http://localhost:1234/v1")
DEFAULT_API_KEY = os.environ.get("LMSTUDIO_API_KEY", "lm-studio")


def _request(url: str, payload: dict | None, method: str = "GET", timeout: float = 600.0):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {DEFAULT_API_KEY}")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.URLError as e:
        reason = getattr(e, "reason", e)
        sys.exit(
            f"error: could not reach LM Studio at {DEFAULT_BASE_URL} ({reason}).\n"
            "  - Is LM Studio running with the local server started?\n"
            "  - Is a model loaded? (LM Studio > Developer > Start Server)\n"
            "  - Set LMSTUDIO_BASE_URL if it's on a non-default host/port."
        )


def list_models(base_url: str) -> list[str]:
    out = _request(f"{base_url}/models", None)
    return [m.get("id", "") for m in out.get("data", [])]


def resolve_model(base_url: str, requested: str | None) -> str:
    if requested:
        return requested
    env_model = os.environ.get("LMSTUDIO_MODEL")
    if env_model:
        return env_model
    models = list_models(base_url)
    if not models:
        sys.exit("error: no models loaded in LM Studio. Load one in the GUI first.")
    return models[0]


def read_prompt(positional: str | None) -> str:
    # Piped stdin is treated as content; a positional prompt as the instruction.
    # If both are present they're merged (instruction first, then content).
    # "-" is an explicit "prompt is on stdin" marker.
    stdin_data = "" if sys.stdin.isatty() else sys.stdin.read()
    instruction = None if positional in (None, "-") else positional
    if instruction and stdin_data:
        return f"{instruction}\n\n{stdin_data}"
    if instruction:
        return instruction
    if stdin_data.strip():
        return stdin_data
    sys.exit("error: no prompt given. Pass a prompt argument or pipe one via stdin.")


def build_messages(args, prompt: str) -> list[dict]:
    messages: list[dict] = []
    if args.system:
        messages.append({"role": "system", "content": args.system})
    context_blocks = []
    for path in args.file or []:
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                content = fh.read()
        except OSError as e:
            sys.exit(f"error: cannot read --file {path}: {e}")
        context_blocks.append(f"--- FILE: {path} ---\n{content}")
    user_content = prompt
    if context_blocks:
        user_content = "\n\n".join(context_blocks) + "\n\n--- TASK ---\n" + prompt
    messages.append({"role": "user", "content": user_content})
    return messages


def chat(args) -> None:
    base_url = args.base_url
    model = resolve_model(base_url, args.model)
    prompt = read_prompt(args.prompt)
    payload = {
        "model": model,
        "messages": build_messages(args, prompt),
        "temperature": args.temperature,
        "stream": args.stream,
    }
    if args.max_tokens:
        payload["max_tokens"] = args.max_tokens

    if not args.stream:
        out = _request(f"{base_url}/chat/completions", payload, method="POST")
        if args.json:
            print(json.dumps(out, indent=2))
            return
        choices = out.get("choices") or []
        if not choices:
            sys.exit(f"error: empty response from model:\n{json.dumps(out, indent=2)}")
        print(choices[0]["message"]["content"])
        return

    # streaming: print tokens as they arrive
    _stream(base_url, payload)


def _stream(base_url: str, payload: dict) -> None:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{base_url}/chat/completions", data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {DEFAULT_API_KEY}")
    try:
        with urllib.request.urlopen(req, timeout=600.0) as resp:
            for raw in resp:
                line = raw.decode().strip()
                if not line.startswith("data:"):
                    continue
                chunk = line[len("data:"):].strip()
                if chunk == "[DONE]":
                    break
                try:
                    obj = json.loads(chunk)
                    delta = obj["choices"][0]["delta"].get("content", "")
                    if delta:
                        sys.stdout.write(delta)
                        sys.stdout.flush()
                except (json.JSONDecodeError, KeyError, IndexError):
                    continue
            sys.stdout.write("\n")
    except urllib.error.URLError as e:
        sys.exit(f"error: stream failed: {getattr(e, 'reason', e)}")


def main() -> None:
    p = argparse.ArgumentParser(
        description="Hand off a dev task to a local LLM via LM Studio's OpenAI-compatible API.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument("prompt", nargs="?", help='The task/prompt. Use "-" or pipe stdin to read from stdin.')
    p.add_argument("--system", help="Optional system prompt (role/instructions).")
    p.add_argument("--file", action="append", metavar="PATH",
                   help="Include a file as context (repeatable).")
    p.add_argument("--model", help="Model id (default: LMSTUDIO_MODEL or first loaded model).")
    p.add_argument("--temperature", type=float, default=0.2, help="Sampling temperature (default 0.2).")
    p.add_argument("--max-tokens", type=int, default=0, help="Cap response length (0 = model default).")
    p.add_argument("--base-url", default=DEFAULT_BASE_URL, help=f"API base (default {DEFAULT_BASE_URL}).")
    p.add_argument("--stream", action="store_true", help="Stream tokens as they generate.")
    p.add_argument("--json", action="store_true", help="Print the raw JSON response.")
    p.add_argument("--list-models", action="store_true", help="List loaded models and exit.")
    args = p.parse_args()

    if args.list_models:
        for m in list_models(args.base_url):
            print(m)
        return

    chat(args)


if __name__ == "__main__":
    main()
