---
name: local-llm
description: >
  Hand off a self-contained dev subtask to a local LLM running in LM Studio
  (OpenAI-compatible API at localhost:1234). Use when the user asks to delegate,
  offload, or "use the local model / LM Studio / local LLM" for work such as
  drafting boilerplate, generating GDScript, writing tests, summarizing or
  reviewing files/diffs, or batch text transforms — especially when the goal is
  to keep work local/private or save on cost. Only works on a machine where
  LM Studio is running with a model loaded.
---

# Local LLM handoff (LM Studio)

Delegate well-scoped, verifiable subtasks to the user's local model instead of
doing them yourself. The local model is typically smaller/less capable than me,
so **I stay the orchestrator**: I scope the task, hand it off, then review and
integrate the result.

## The tool

`tools/local-llm/lmstudio.py` — a dependency-free Python CLI that calls LM
Studio's OpenAI-compatible endpoint. Run it via Bash.

```bash
# Confirm a model is loaded (do this first if unsure)
python3 tools/local-llm/lmstudio.py --list-models

# Basic handoff
python3 tools/local-llm/lmstudio.py "Write a GDScript helper that ..."

# With role + file context (repeat --file as needed)
python3 tools/local-llm/lmstudio.py \
  --system "You are a Godot 4.7 GDScript expert. Return only code." \
  --file godot/scripts/Player.gd \
  "Add a sprint that drains stamina while move_forward is held"

# Review a diff (pipe via stdin; '-' reads stdin)
git diff | python3 tools/local-llm/lmstudio.py \
  --system "Review this diff for bugs. Be concise." -
```

Config via env (all optional): `LMSTUDIO_BASE_URL` (default
`http://localhost:1234/v1`), `LMSTUDIO_MODEL` (default: first loaded model),
`LMSTUDIO_API_KEY` (default `lm-studio`).

## When to hand off

Good fits: boilerplate/scaffolding, first-draft GDScript, unit/test stubs,
docstrings/comments, summarizing a long file, a quick second-opinion review,
repetitive text transforms across many inputs.

Keep it yourself when: the task needs broad repo context, careful
cross-file reasoning, or correctness I must personally guarantee (the local
model's output is a draft, not ground truth).

## Workflow

1. **Check availability** — run `--list-models`. If it errors, tell the user to
   start LM Studio's local server and load a model; don't silently fall back.
2. **Scope tightly** — give the local model a `--system` role and only the
   `--file` context it needs. Vague prompts produce weak local-model output.
3. **Capture & review** — read the tool's stdout, sanity-check it (does it
   compile / match project style / actually answer the task?). Fix or redo
   anything off.
4. **Integrate** — apply the reviewed result with my normal edit tools and
   verify (run the game's tests, e.g. the `--gametest` path in `Main.gd`).

## Notes

- This only works locally — in a remote/web session `localhost` is the sandbox,
  not the user's machine, so the call will fail to connect.
- Use `--temperature 0.2` (default) for code; raise it for brainstorming.
- Use `--stream` only for interactive viewing; omit it when you need to capture
  the full result for further processing.
