# Godot MCP server

This repo ships a **project-scoped MCP server** so any agentic editor (Claude
Code, Cursor, etc.) can drive the Godot engine directly: launch the editor, run
the project, capture runtime/debug output, inspect project structure, and script
scene/node edits.

The server is [`@coding-solo/godot-mcp`](https://github.com/Coding-Solo/godot-mcp),
pinned in [`.mcp.json`](../.mcp.json) at the repo root. It runs locally over
stdio via `npx` — nothing is hosted, and no clone/build step is required.

## Prerequisites

- **Node.js 18+** (this repo is validated on Node 22). `npx` ships with npm.
- **Godot 4.7** installed locally — the same version this project targets
  (`config/features=PackedStringArray("4.7", ...)` in `godot/project.godot`).

## How it's wired

`.mcp.json` (committed, shared by the whole team):

```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["-y", "@coding-solo/godot-mcp@0.1.1"],
      "env": {
        "GODOT_PATH": "${GODOT_PATH:-}",
        "DEBUG": "${GODOT_MCP_DEBUG:-false}"
      }
    }
  }
}
```

- The version is **pinned** (`@0.1.1`) so every dev gets the same toolset.
- `GODOT_PATH` is an **optional override**. Leave it unset and the server
  auto-detects Godot in common install locations; the empty default
  (`${GODOT_PATH:-}`) is treated as "not set," so auto-detection still runs.
- `GODOT_MCP_DEBUG=true` turns on verbose server logging when troubleshooting.

## Point it at your Godot binary (if auto-detect fails)

Godot's binary is often named oddly (e.g. `Godot_v4.7-stable_linux.x86_64`, or
buried in an `.app` bundle on macOS), so auto-detect may miss it. Set
`GODOT_PATH` in your shell before launching your editor:

| OS      | Example |
|---------|---------|
| macOS   | `export GODOT_PATH="/Applications/Godot.app/Contents/MacOS/Godot"` |
| Linux   | `export GODOT_PATH="$HOME/bin/Godot_v4.7-stable_linux.x86_64"` |
| Windows | `set GODOT_PATH=C:\Tools\Godot_v4.7-stable_win64.exe` (PowerShell: `$env:GODOT_PATH=...`) |

Verify with the `get_godot_version` tool once connected.

## Enabling it in Claude Code

`.mcp.json` is project-scoped, so Claude Code prompts you to **approve** the
server the first time you open this repo (project servers are untrusted until
approved). Approve it, then check status:

```
/mcp
```

You should see `godot` listed as connected with its tools available.

## The Barony project lives in `godot/`

This repo's Godot project is the `godot/` subdirectory, **not** the repo root.
Pass that path to the project-scoped tools, e.g.:

- `run_project` → `projectPath: "godot"` (optionally `scene: "res://scenes/Main.tscn"`)
- `get_project_info` / `launch_editor` → `projectPath: "godot"`
- `list_projects` → `directory: "."` (recursive) will find it too

## Tools provided (13)

| Tool | Purpose |
|------|---------|
| `launch_editor` | Open the Godot editor for the project |
| `run_project` | Run the project (optionally a specific scene) and capture output |
| `stop_project` | Stop the running project |
| `get_debug_output` | Fetch current console/debug output and errors |
| `get_godot_version` | Report the installed Godot version |
| `list_projects` | Find Godot projects under a directory |
| `get_project_info` | Analyze project structure/metadata |
| `create_scene` | Create a new scene with a given root node |
| `add_node` | Add a node with properties to a scene |
| `load_sprite` | Load a texture into a Sprite2D |
| `export_mesh_library` | Export a 3D scene as a `MeshLibrary` for GridMaps |
| `save_scene` | Save a scene (in place or as a variant) |
| `get_uid` / `update_project_uids` | Manage resource UIDs (Godot 4.4+) |

## Troubleshooting

- **"Could not find a valid Godot executable"** → set `GODOT_PATH` (see above).
- **Server not listed in `/mcp`** → make sure you opened the editor from the
  repo root (so `.mcp.json` is picked up) and approved the project server.
- **Verbose logs** → set `GODOT_MCP_DEBUG=true` in your environment and restart.
