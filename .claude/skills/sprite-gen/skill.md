---
name: sprite-gen
description: >
  Automate sprite sheet generation for Barony HD 2D characters via the Gemini
  web UI. Uses Playwright to drive Chrome with the user's existing Google login —
  no API key required. Generates all 4 animation sheets in parallel (4 Chrome
  windows simultaneously) after the reference sheet is done.
---

# Sprite Generation Workflow (Automated, Parallel)

Drives `tools/sprite-gen/gemini_bot.py` to generate all animation sheets for a
character via the Gemini web UI, then slices and wires them into Godot.

## Invocation

```
/sprite-gen [character]
```

**Available characters:** `murloc`, `skeleton`, `orc`, `troll`, `necro`, `gormaul`, `projectiles`, `items`, `gear`

If omitted or `list`, print the list and stop.

---

## Workflow

### Step 0 — Preflight

```bash
python3 -c "import playwright; print('ok')" 2>&1
```

If that fails:
```bash
pip3 install playwright && python3 -m playwright install chrome
```

Read `godot/sprites/SPRITE_PROMPTS.md` to extract all prompts for the character.

---

### Step 1 — Reference Sheet (single, no attachment)

```bash
python3 tools/sprite-gen/gemini_bot.py \
  "<REFERENCE_PROMPT>" \
  "<character>-reference-sheet.png"
```

Wait for the script to exit before proceeding.

---

### Step 2 — All 4 Animation Sheets in Parallel

One command, 4 Chrome windows open simultaneously:

```bash
python3 tools/sprite-gen/gemini_bot.py --parallel \
  "<character>-reference-sheet.png" \
  "<IDLE_PROMPT>"       "<character>-idle.png" \
  "<WALK_PROMPT>"       "<character>-walk.png" \
  "<ATTACK_PROMPT>"     "<character>-attack.png" \
  "<HURT_DEATH_PROMPT>" "<character>-hurt-death.png"
```

- First run: each worker profile is cloned from `~/.barony-bot-chrome` (one-time, ~30s).
- All 4 sheets generate and download concurrently — total time ~2 min instead of ~8 min.
- Each window is labelled w0–w3 in the terminal output.

---

### Step 3 — Slice & Wire

After all 4 sheets are saved in `godot/sprites/`:

1. **Update `tools/slice_sprites.py`** — add 4 entries for the new character (idle, walk, attack, hurt-death).

2. **Run the slicer:**
```bash
python3 tools/slice_sprites.py
```
Verify frames appear in `godot/sprites/sliced/<character>/`.

3. **Update `godot/scripts/autoload/SpriteFactory.gd`** — add character to `CHAR_CONFIG` with correct `pixel_size`.

4. **Update `godot/scripts/Dungeon.gd`** — add character to spawn pool.

---

## Pixel sizes by character

| Type | pixel_size |
|------|-----------|
| Small (kobold, murloc) — 64px | 0.002 |
| Medium (skeleton, orc, troll, necro) — 96px | 0.0015 |
| Boss (Gor'maul) — 192px | 0.0008 |

---

## Execution notes

- Run Step 1 and Step 2 sequentially — reference sheet must exist before parallel run.
- First parallel run clones the login session to 4 worker profiles (`~/.barony-bot-chrome-w0` through `w3`). Subsequent runs are instant.
- If a sheet comes back as a single row for hurt-death, re-run just that one:
  ```bash
  python3 tools/sprite-gen/gemini_bot.py "<HURT_DEATH_PROMPT>" "<character>-hurt-death.png" "<character>-reference-sheet.png"
  ```
- For **projectiles, items, gear**: no reference sheet; run `gemini_bot.py` once per item with no attachment.
