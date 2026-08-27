"""MCP server for BrashMonkey Spriter Pro.

Spriter Pro has no CLI or scripting API, so this server automates it at the
file level: it authors and edits .scml project files directly, bakes
animations to PNG frames / sprite sheets with a built-in SCML renderer, and
can launch the Spriter Pro GUI for manual polish.

Runs over stdio. See docs/spriter-mcp.md in the repo root.
"""

from __future__ import annotations

import glob as globmod
import json
import os
import subprocess
import sys
from html.parser import HTMLParser

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mcp.server.fastmcp import FastMCP
from PIL import Image

import render as rend
import scml

mcp = FastMCP("spriter")

SPRITER_DEFAULT = r"C:\Program Files (x86)\Steam\steamapps\common\Spriter\Spriter.exe"


def _abs(path):
    return os.path.abspath(os.path.expanduser(path))


def _load(project_path):
    path = _abs(project_path)
    if not os.path.isfile(path):
        raise ValueError(f"No such project file: {path}")
    return scml.parse_scml(path)


# ---------------------------------------------------------------------------
# Discovery / inspection
# ---------------------------------------------------------------------------

@mcp.tool()
def list_projects(directory: str) -> list[dict]:
    """Find Spriter projects (.scml files) under a directory, recursively.

    Tip: Spriter Pro ships sample projects under
    'C:/Program Files (x86)/Steam/steamapps/common/Spriter/Art Packs'.
    """
    root = _abs(directory)
    out = []
    for path in sorted(globmod.glob(os.path.join(root, "**", "*.scml"), recursive=True)):
        if ".autosave." in os.path.basename(path):
            continue
        try:
            proj = scml.parse_scml(path)
            out.append({
                "path": path,
                "entities": [
                    {"name": e["name"],
                     "animations": [a["name"] for a in e["animations"]]}
                    for e in proj["entities"]
                ],
            })
        except Exception as exc:  # unparseable file: still report it
            out.append({"path": path, "error": str(exc)})
    return out


@mcp.tool()
def get_project_info(project_path: str) -> dict:
    """Summarize a Spriter project: its images (with pivots) and every
    entity/animation with length, looping flag, and timeline count."""
    proj = _load(project_path)
    return {
        "path": proj["path"],
        "images": [
            {"name": f["name"], "width": f["width"], "height": f["height"],
             "pivot_x": f["pivot_x"], "pivot_y": f["pivot_y"]}
            for folder in proj["folders"] for f in folder["files"]
        ],
        "entities": [
            {"name": e["name"],
             "animations": [
                 {"name": a["name"], "length_ms": a["length"],
                  "looping": a["looping"], "timelines": len(a["timelines"]),
                  "mainline_keys": len(a["mainline"])}
                 for a in e["animations"]]}
            for e in proj["entities"]
        ],
    }


@mcp.tool()
def get_animation_details(project_path: str, animation: str,
                          entity: str | None = None) -> dict:
    """Full keyframe data for one animation: every timeline with its keys
    (time, x, y, angle, scale, alpha, spin, image). Use this before editing
    an existing animation."""
    proj = _load(project_path)
    ent = scml.find_entity(proj, entity)
    anim = scml.find_animation(ent, animation)
    files = scml.file_lookup(proj)

    timelines = []
    for tl in anim["timelines"]:
        keys = []
        for k in tl["keys"]:
            obj = dict(k["obj"])
            if k["kind"] == "sprite":
                fdict = files.get((obj.pop("folder", None), obj.pop("file", None)))
                obj["image"] = fdict["name"] if fdict else None
            keys.append({"time": k["time"], "spin": k["spin"], **obj})
        timelines.append({"name": tl["name"], "type": tl["object_type"],
                          "keys": keys})
    return {
        "entity": ent["name"], "animation": anim["name"],
        "length_ms": anim["length"], "looping": anim["looping"],
        "mainline_key_times": [k["time"] for k in anim["mainline"]],
        "timelines": timelines,
    }


# ---------------------------------------------------------------------------
# Authoring
# ---------------------------------------------------------------------------

def _register_images(proj, project_dir, images):
    """Add image files to the project's folder 0, reading real dimensions."""
    if not proj["folders"]:
        proj["folders"].append({"id": 0, "name": "", "files": []})
    folder = proj["folders"][0]
    existing = {f["name"].replace("\\", "/") for f in folder["files"]}
    next_id = max((f["id"] for f in folder["files"]), default=-1) + 1
    added = []
    for spec in images:
        if isinstance(spec, str):
            spec = {"image": spec}
        name = spec["image"].replace("\\", "/")
        full = os.path.join(project_dir, name.replace("/", os.sep))
        if not os.path.isfile(full):
            raise ValueError(
                f"Image not found: {full} (paths are relative to the .scml file)")
        if name in existing:
            continue
        with Image.open(full) as img:
            w, h = img.size
        folder["files"].append({
            "id": next_id, "name": name, "width": w, "height": h,
            "pivot_x": float(spec.get("pivot_x", 0.5)),
            "pivot_y": float(spec.get("pivot_y", 0.5)),
        })
        existing.add(name)
        added.append(name)
        next_id += 1
    return added


@mcp.tool()
def create_project(project_path: str, images: list[dict],
                   entity: str = "entity_000") -> dict:
    """Create a new Spriter project (.scml) from existing PNG part images.

    `images`: [{"image": "parts/torso.png", "pivot_x": 0.5, "pivot_y": 0.5}, ...]
    Paths are relative to the .scml location; pivots are fractions from the
    image's bottom-left (default 0.5/0.5 = center). Build the character by
    then calling build_animation. Fails if the file already exists.
    """
    path = _abs(project_path)
    if os.path.exists(path):
        raise ValueError(f"{path} already exists; edit it instead.")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    proj = {"path": path, "folders": [],
            "entities": [{"id": 0, "name": entity, "animations": []}]}
    added = _register_images(proj, os.path.dirname(path), images)
    scml.write_scml(proj, path)
    return {"path": path, "images_added": added, "entity": entity}


@mcp.tool()
def add_images(project_path: str, images: list[dict]) -> dict:
    """Register additional PNG images in an existing project. Same image
    spec as create_project. Images already present are skipped."""
    proj = _load(project_path)
    added = _register_images(proj, os.path.dirname(proj["path"]), images)
    scml.write_scml(proj, proj["path"])
    return {"images_added": added}


@mcp.tool()
def set_pivot(project_path: str, image: str, pivot_x: float, pivot_y: float) -> dict:
    """Set the default pivot of an image (fraction from bottom-left).

    The pivot is the point that x/y position and rotation act around, e.g.
    a thigh image pivots at the hip end: pivot_y near the top -> ~0.9."""
    proj = _load(project_path)
    _, _, fdict = scml.file_by_name(proj, image)
    fdict["pivot_x"], fdict["pivot_y"] = float(pivot_x), float(pivot_y)
    scml.write_scml(proj, proj["path"])
    return {"image": fdict["name"], "pivot_x": fdict["pivot_x"],
            "pivot_y": fdict["pivot_y"]}


@mcp.tool()
def build_animation(project_path: str, animation: str, length_ms: int,
                    keys: list[dict], entity: str | None = None,
                    looping: bool = True) -> dict:
    """Create or replace an animation from full-pose keyframes.

    `keys` is a list of poses; every pose lists ALL visible sprites:
      [{"time": 0, "sprites": [
          {"image": "parts/torso.png",  // must be registered in the project
           "name": "torso",             // optional stable id; default image stem.
                                        // Sprites with the same name across
                                        // keys become one tweened timeline.
           "x": 0, "y": 0,              // world position of the pivot, y-up
           "angle": 0,                  // degrees counter-clockwise
           "scale_x": 1, "scale_y": 1, "alpha": 1,
           "spin": 1,                   // tween direction to NEXT key: 1=CCW,
                                        // -1=CW, 0=no rotation tween
           "z": 0}]},                   // draw order, higher = in front
       {"time": 400, "sprites": [...]}]

    Spriter tweens between keys (linear); a looping animation tweens the last
    key back to the first. Replaces any existing animation with this name.
    """
    proj = _load(project_path)
    if entity is None and not proj["entities"]:
        proj["entities"].append({"id": 0, "name": "entity_000", "animations": []})
    try:
        ent = scml.find_entity(proj, entity)
    except ValueError:
        if entity is None:
            raise
        ent = {"id": max((e["id"] for e in proj["entities"]), default=-1) + 1,
               "name": entity, "animations": []}
        proj["entities"].append(ent)

    if not keys:
        raise ValueError("At least one key is required.")
    keys = sorted(keys, key=lambda k: k.get("time", 0))
    if keys[0].get("time", 0) != 0:
        raise ValueError("The first key must be at time 0.")

    # Group sprites into timelines by stable name.
    order = []            # timeline names, in first-seen order
    tl_keys = {}          # name -> list of (time, sprite_spec)
    pose_refs = []        # per pose: list of (name, z)
    for pose in keys:
        t = int(pose.get("time", 0))
        if t >= length_ms and t != 0:
            raise ValueError(f"Key time {t} must be < length_ms ({length_ms}).")
        refs = []
        seen = set()
        for spr in pose.get("sprites", []):
            name = spr.get("name") or os.path.splitext(
                os.path.basename(spr["image"]))[0]
            if name in seen:
                raise ValueError(
                    f"Duplicate sprite name {name!r} at time {t}; give copies "
                    f"distinct 'name' values.")
            seen.add(name)
            if name not in tl_keys:
                order.append(name)
                tl_keys[name] = []
            tl_keys[name].append((t, spr))
            refs.append((name, int(spr.get("z", 0))))
        pose_refs.append((t, refs))

    timelines = []
    key_index = {}  # (tl_name, time) -> key id
    for tl_id, name in enumerate(order):
        entries = []
        for kid, (t, spr) in enumerate(tl_keys[name]):
            fid_folder, fid_file, _ = scml.file_by_name(proj, spr["image"])
            key_index[(name, t)] = kid
            entries.append({
                "id": kid, "time": t, "spin": int(spr.get("spin", 1)),
                "kind": "sprite",
                "obj": {
                    "folder": fid_folder, "file": fid_file,
                    "x": float(spr.get("x", 0)), "y": float(spr.get("y", 0)),
                    "angle": float(spr.get("angle", 0)) % 360.0,
                    "scale_x": float(spr.get("scale_x", 1)),
                    "scale_y": float(spr.get("scale_y", 1)),
                    "a": float(spr.get("alpha", 1)),
                },
            })
        timelines.append({"id": tl_id, "name": name, "object_type": "sprite",
                          "keys": entries})

    tl_ids = {name: i for i, name in enumerate(order)}
    mainline = []
    for mid, (t, refs) in enumerate(pose_refs):
        refs_sorted = sorted(refs, key=lambda r: r[1])
        object_refs = []
        for oid, (name, _z) in enumerate(refs_sorted):
            object_refs.append({
                "id": oid, "parent": None,
                "timeline": tl_ids[name], "key": key_index[(name, t)],
                "z_index": oid,
            })
        mainline.append({"id": mid, "time": t, "bone_refs": [],
                         "object_refs": object_refs})

    anim = {
        "id": 0, "name": animation, "length": int(length_ms),
        "interval": 100, "looping": bool(looping),
        "mainline": mainline, "timelines": timelines,
    }
    existing = [a for a in ent["animations"] if a["name"] == animation]
    if existing:
        anim["id"] = existing[0]["id"]
        ent["animations"][ent["animations"].index(existing[0])] = anim
        replaced = True
    else:
        anim["id"] = max((a["id"] for a in ent["animations"]), default=-1) + 1
        ent["animations"].append(anim)
        replaced = False

    scml.write_scml(proj, proj["path"])
    return {"entity": ent["name"], "animation": animation,
            "length_ms": length_ms, "timelines": len(timelines),
            "keys": len(mainline), "replaced_existing": replaced,
            "hint": "Check the result with render_pose or export_sprite_sheet."}


@mcp.tool()
def delete_animation(project_path: str, animation: str,
                     entity: str | None = None) -> dict:
    """Remove an animation from an entity."""
    proj = _load(project_path)
    ent = scml.find_entity(proj, entity)
    anim = scml.find_animation(ent, animation)
    ent["animations"].remove(anim)
    scml.write_scml(proj, proj["path"])
    return {"deleted": animation, "remaining": [a["name"] for a in ent["animations"]]}


# ---------------------------------------------------------------------------
# Rendering / export
# ---------------------------------------------------------------------------

@mcp.tool()
def render_pose(project_path: str, animation: str, out_path: str,
                time_ms: float = 0, entity: str | None = None,
                scale: float = 1.0) -> dict:
    """Render a single frame of an animation to a PNG. Use this to visually
    inspect a pose while iterating — read the PNG back to see it."""
    proj = _load(project_path)
    ent = scml.find_entity(proj, entity)
    anim = scml.find_animation(ent, animation)
    ops = rend.sample_animation(proj, ent, anim, time_ms)
    if not ops:
        raise ValueError("Nothing to draw at that time.")
    bbox = rend.frame_bbox(ops)
    cache = rend.ImageCache(os.path.dirname(proj["path"]))
    img = rend.render_frame(ops, bbox, scale, cache, padding=2)
    out = _abs(out_path)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out)
    return {"path": out, "size": list(img.size), "time_ms": time_ms,
            "sprites_drawn": len(ops)}


@mcp.tool()
def render_frames(project_path: str, animation: str, out_dir: str,
                  entity: str | None = None, frame_count: int | None = None,
                  fps: float | None = None, scale: float = 1.0) -> dict:
    """Bake an animation to numbered PNG frames (frame_000.png, ...).

    All frames share one canvas size/origin so they align when played back.
    Give frame_count OR fps; default derives from the animation's snap
    interval. `scale` scales the output resolution (e.g. 0.25 to shrink
    high-res art to game size)."""
    proj = _load(project_path)
    ent = scml.find_entity(proj, entity)
    anim = scml.find_animation(ent, animation)
    frames, bbox = rend.render_animation(proj, ent, anim,
                                         frame_count=frame_count, fps=fps,
                                         scale=scale)
    out = _abs(out_dir)
    os.makedirs(out, exist_ok=True)
    paths = []
    for i, (_t, img) in enumerate(frames):
        p = os.path.join(out, f"frame_{i:03d}.png")
        img.save(p)
        paths.append(p)
    return {"frames": paths, "frame_size": list(frames[0][1].size),
            "world_bbox": list(bbox), "animation_length_ms": anim["length"]}


@mcp.tool()
def export_sprite_sheet(project_path: str, animation: str, out_path: str,
                        entity: str | None = None,
                        frame_count: int | None = None,
                        fps: float | None = None, scale: float = 1.0,
                        columns: int | None = None) -> dict:
    """Bake an animation into a single grid sprite sheet PNG plus a JSON
    sidecar (<out>.json) with frame size / count / fps — everything needed
    to wire it into Godot as an AnimatedSprite3D/SpriteFrames."""
    proj = _load(project_path)
    ent = scml.find_entity(proj, entity)
    anim = scml.find_animation(ent, animation)
    frames, bbox = rend.render_animation(proj, ent, anim,
                                         frame_count=frame_count, fps=fps,
                                         scale=scale)
    sheet, cols, rows = rend.build_sprite_sheet(frames, columns)
    out = _abs(out_path)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)

    n = len(frames)
    eff_fps = fps if fps else n * 1000.0 / max(1, anim["length"])
    meta = {
        "sheet": os.path.basename(out),
        "animation": anim["name"], "entity": ent["name"],
        "frame_count": n, "columns": cols, "rows": rows,
        "frame_width": frames[0][1].size[0],
        "frame_height": frames[0][1].size[1],
        "fps": round(eff_fps, 3), "looping": anim["looping"],
        "animation_length_ms": anim["length"],
    }
    meta_path = os.path.splitext(out)[0] + ".json"
    with open(meta_path, "w", encoding="utf-8") as fh:
        json.dump(meta, fh, indent=2)
    return {**meta, "path": out, "metadata_path": meta_path,
            "sheet_size": list(sheet.size)}


# ---------------------------------------------------------------------------
# Documentation
# ---------------------------------------------------------------------------

def _docs_dir():
    exe = os.environ.get("SPRITER_PATH") or SPRITER_DEFAULT
    docs = os.path.join(os.path.dirname(exe), "docs")
    if not os.path.isdir(docs):
        raise ValueError(
            f"Spriter manual not found at {docs}. Set SPRITER_PATH to the "
            f"Spriter.exe that sits next to the 'docs' folder.")
    return docs


def _doc_topics():
    return sorted(os.path.splitext(f)[0] for f in os.listdir(_docs_dir())
                  if f.lower().endswith(".htm"))


class _TextExtractor(HTMLParser):
    _BLOCK = {"p", "div", "br", "tr", "li", "h1", "h2", "h3", "h4", "table",
              "ul", "ol"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.chunks = []
        self._skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style"):
            self._skip += 1
        elif tag in self._BLOCK:
            self.chunks.append("\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style") and self._skip:
            self._skip -= 1
        elif tag in self._BLOCK:
            self.chunks.append("\n")

    def handle_data(self, data):
        if not self._skip:
            self.chunks.append(data)

    def text(self):
        raw = "".join(self.chunks)
        lines = [" ".join(ln.split()) for ln in raw.splitlines()]
        out = []
        for ln in lines:
            if ln:
                out.append(ln)
            elif out and out[-1]:
                out.append("")
        return "\n".join(out).strip()


@mcp.tool()
def list_docs() -> list[str]:
    """List the topics of Spriter Pro's built-in manual (the HTML docs
    installed with the app). Read one with read_doc. Consult these whenever
    unsure how a Spriter feature or workflow works — pivots, bones, z-order,
    keyframing, character maps, exporting, etc."""
    return _doc_topics()


@mcp.tool()
def read_doc(topic: str) -> dict:
    """Return one Spriter Pro manual page as plain text.

    `topic` is a name from list_docs or just keywords — the closest match
    wins (e.g. 'bones', 'pivot', 'z order', 'exporting')."""
    topics = _doc_topics()
    want = topic.lower().replace(".htm", "").strip()
    if want in topics:
        matches = [want]
    else:
        matches = [t for t in topics if want in t]
        if not matches:
            want_words = set(want.split())
            scored = sorted(
                ((len(want_words & set(t.split())), t) for t in topics),
                key=lambda s: (-s[0], s[1]))
            matches = [t for score, t in scored if score > 0]
    if not matches:
        raise ValueError(f"No manual page matches {topic!r}. "
                         f"Topics: {', '.join(topics)}")
    best = matches[0]
    path = os.path.join(_docs_dir(), best + ".htm")
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        parser = _TextExtractor()
        parser.feed(fh.read())
    return {"topic": best, "text": parser.text(),
            "other_matches": matches[1:6]}


# ---------------------------------------------------------------------------
# GUI
# ---------------------------------------------------------------------------

@mcp.tool()
def open_in_spriter(project_path: str | None = None) -> dict:
    """Launch the Spriter Pro GUI, optionally opening a project — for the
    user to inspect or hand-polish what was authored here. Non-blocking."""
    exe = os.environ.get("SPRITER_PATH") or SPRITER_DEFAULT
    if not os.path.isfile(exe):
        raise ValueError(
            f"Spriter.exe not found at {exe}. Set SPRITER_PATH to override.")
    args = [exe]
    if project_path:
        args.append(_abs(project_path))
    subprocess.Popen(args, cwd=os.path.dirname(exe),
                     creationflags=subprocess.DETACHED_PROCESS
                     | subprocess.CREATE_NEW_PROCESS_GROUP)
    return {"launched": exe, "project": _abs(project_path) if project_path else None}


if __name__ == "__main__":
    mcp.run()
