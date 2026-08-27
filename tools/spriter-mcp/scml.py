"""Parse and write Spriter Pro SCML project files.

SCML is Spriter's XML project format. Coordinates are y-up, angles are
degrees counter-clockwise, pivots are fractions of the image measured from
the bottom-left corner (SCML default pivot is x=0, y=1 = top-left).
"""

from __future__ import annotations

import os
import xml.etree.ElementTree as ET
from xml.dom import minidom


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def _f(el, attr, default=0.0):
    v = el.get(attr)
    return float(v) if v is not None else default


def _i(el, attr, default=0):
    v = el.get(attr)
    return int(v) if v is not None else default


def parse_scml(path):
    """Parse an .scml file into plain dicts."""
    tree = ET.parse(path)
    root = tree.getroot()
    if root.tag != "spriter_data":
        raise ValueError(f"{path} is not an SCML file (root tag {root.tag!r})")

    folders = []
    for folder_el in root.findall("folder"):
        files = []
        for file_el in folder_el.findall("file"):
            files.append({
                "id": _i(file_el, "id"),
                "name": file_el.get("name", ""),
                "width": _i(file_el, "width"),
                "height": _i(file_el, "height"),
                "pivot_x": _f(file_el, "pivot_x", 0.0),
                "pivot_y": _f(file_el, "pivot_y", 1.0),
            })
        folders.append({
            "id": _i(folder_el, "id"),
            "name": folder_el.get("name", ""),
            "files": files,
        })

    entities = []
    for entity_el in root.findall("entity"):
        animations = []
        for anim_el in entity_el.findall("animation"):
            animations.append(_parse_animation(anim_el))
        entities.append({
            "id": _i(entity_el, "id"),
            "name": entity_el.get("name", ""),
            "animations": animations,
        })

    return {"path": os.path.abspath(path), "folders": folders, "entities": entities}


def _parse_ref(ref_el):
    ref = {
        "id": _i(ref_el, "id"),
        "timeline": _i(ref_el, "timeline"),
        "key": _i(ref_el, "key"),
    }
    parent = ref_el.get("parent")
    ref["parent"] = int(parent) if parent is not None else None
    if ref_el.tag == "object_ref":
        ref["z_index"] = _i(ref_el, "z_index")
    return ref


def _parse_animation(anim_el):
    mainline_keys = []
    mainline_el = anim_el.find("mainline")
    if mainline_el is not None:
        for key_el in mainline_el.findall("key"):
            mainline_keys.append({
                "id": _i(key_el, "id"),
                "time": _i(key_el, "time"),
                "curve_type": key_el.get("curve_type", "linear"),
                "bone_refs": [_parse_ref(r) for r in key_el.findall("bone_ref")],
                "object_refs": [_parse_ref(r) for r in key_el.findall("object_ref")],
            })

    timelines = []
    for tl_el in anim_el.findall("timeline"):
        keys = []
        for key_el in tl_el.findall("key"):
            obj_el = key_el.find("object")
            kind = "sprite"
            if obj_el is None:
                obj_el = key_el.find("bone")
                kind = "bone"
            obj = None
            if obj_el is not None:
                obj = {
                    "x": _f(obj_el, "x", 0.0),
                    "y": _f(obj_el, "y", 0.0),
                    "angle": _f(obj_el, "angle", 0.0),
                    "scale_x": _f(obj_el, "scale_x", 1.0),
                    "scale_y": _f(obj_el, "scale_y", 1.0),
                    "a": _f(obj_el, "a", 1.0),
                }
                if kind == "sprite":
                    obj["folder"] = _i(obj_el, "folder")
                    obj["file"] = _i(obj_el, "file")
                    if obj_el.get("pivot_x") is not None:
                        obj["pivot_x"] = _f(obj_el, "pivot_x")
                    if obj_el.get("pivot_y") is not None:
                        obj["pivot_y"] = _f(obj_el, "pivot_y")
            keys.append({
                "id": _i(key_el, "id"),
                "time": _i(key_el, "time"),
                "spin": _i(key_el, "spin", 1),
                "curve_type": key_el.get("curve_type", "linear"),
                "obj": obj,
                "kind": kind,
            })
        timelines.append({
            "id": _i(tl_el, "id"),
            "name": tl_el.get("name", ""),
            "object_type": tl_el.get("object_type", "sprite"),
            "keys": keys,
        })

    return {
        "id": _i(anim_el, "id"),
        "name": anim_el.get("name", ""),
        "length": _i(anim_el, "length"),
        "interval": _i(anim_el, "interval", 100),
        "looping": anim_el.get("looping", "true") != "false",
        "mainline": mainline_keys,
        "timelines": timelines,
    }


def find_entity(project, entity_name):
    if entity_name is None:
        if len(project["entities"]) == 1:
            return project["entities"][0]
        names = [e["name"] for e in project["entities"]]
        raise ValueError(f"Project has multiple entities {names}; specify one.")
    for e in project["entities"]:
        if e["name"] == entity_name:
            return e
    names = [e["name"] for e in project["entities"]]
    raise ValueError(f"Entity {entity_name!r} not found. Available: {names}")


def find_animation(entity, anim_name):
    for a in entity["animations"]:
        if a["name"] == anim_name:
            return a
    names = [a["name"] for a in entity["animations"]]
    raise ValueError(f"Animation {anim_name!r} not found. Available: {names}")


def file_lookup(project):
    """Map (folder_id, file_id) -> file dict with folder name attached."""
    out = {}
    for folder in project["folders"]:
        for f in folder["files"]:
            out[(folder["id"], f["id"])] = f
    return out


def file_by_name(project, name):
    """Find (folder_id, file_id, file) by file name (path as stored in SCML)."""
    norm = name.replace("\\", "/")
    for folder in project["folders"]:
        for f in folder["files"]:
            if f["name"].replace("\\", "/") == norm:
                return folder["id"], f["id"], f
    raise ValueError(f"Image {name!r} is not in the project. Add it first.")


# ---------------------------------------------------------------------------
# Writing
# ---------------------------------------------------------------------------

def _fmt(v):
    """Format a float the way Spriter does: no trailing zeros, ints stay ints."""
    if isinstance(v, float):
        if v == int(v):
            return str(int(v))
        return f"{v:.6f}".rstrip("0").rstrip(".")
    return str(v)


def write_scml(project, path):
    """Serialize a project dict back to an .scml file Spriter Pro can open."""
    root = ET.Element("spriter_data", {
        "scml_version": "1.0",
        "generator": "BrashMonkey Spriter",
        "generator_version": "r11",
    })

    for folder in project["folders"]:
        folder_el = ET.SubElement(root, "folder", {"id": str(folder["id"])})
        if folder.get("name"):
            folder_el.set("name", folder["name"])
        for f in folder["files"]:
            ET.SubElement(folder_el, "file", {
                "id": str(f["id"]),
                "name": f["name"],
                "width": str(f["width"]),
                "height": str(f["height"]),
                "pivot_x": _fmt(float(f.get("pivot_x", 0.0))),
                "pivot_y": _fmt(float(f.get("pivot_y", 1.0))),
            })

    for entity in project["entities"]:
        entity_el = ET.SubElement(root, "entity", {
            "id": str(entity["id"]),
            "name": entity["name"],
        })
        for anim in entity["animations"]:
            _write_animation(entity_el, anim)

    xml_bytes = ET.tostring(root, encoding="UTF-8")
    pretty = minidom.parseString(xml_bytes).toprettyxml(indent="    ", encoding="UTF-8")
    # minidom puts the declaration on its own line already; strip blank lines
    lines = [ln for ln in pretty.decode("utf-8").splitlines() if ln.strip()]
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def _write_animation(entity_el, anim):
    anim_el = ET.SubElement(entity_el, "animation", {
        "id": str(anim["id"]),
        "name": anim["name"],
        "length": str(anim["length"]),
        "interval": str(anim.get("interval", 100)),
    })
    if not anim.get("looping", True):
        anim_el.set("looping", "false")

    mainline_el = ET.SubElement(anim_el, "mainline")
    for key in anim["mainline"]:
        key_el = ET.SubElement(mainline_el, "key", {"id": str(key["id"])})
        if key["time"]:
            key_el.set("time", str(key["time"]))
        for ref in key.get("bone_refs", []):
            attrs = {"id": str(ref["id"])}
            if ref.get("parent") is not None:
                attrs["parent"] = str(ref["parent"])
            attrs["timeline"] = str(ref["timeline"])
            attrs["key"] = str(ref["key"])
            ET.SubElement(key_el, "bone_ref", attrs)
        for ref in key.get("object_refs", []):
            attrs = {"id": str(ref["id"])}
            if ref.get("parent") is not None:
                attrs["parent"] = str(ref["parent"])
            attrs["timeline"] = str(ref["timeline"])
            attrs["key"] = str(ref["key"])
            attrs["z_index"] = str(ref.get("z_index", 0))
            ET.SubElement(key_el, "object_ref", attrs)

    for tl in anim["timelines"]:
        tl_attrs = {"id": str(tl["id"]), "name": tl["name"]}
        if tl.get("object_type", "sprite") != "sprite":
            tl_attrs["object_type"] = tl["object_type"]
        tl_el = ET.SubElement(anim_el, "timeline", tl_attrs)
        for key in tl["keys"]:
            key_el = ET.SubElement(tl_el, "key", {"id": str(key["id"])})
            if key["time"]:
                key_el.set("time", str(key["time"]))
            key_el.set("spin", str(key.get("spin", 1)))
            obj = key["obj"]
            tag = "bone" if key.get("kind") == "bone" else "object"
            attrs = {}
            if tag == "object":
                attrs["folder"] = str(obj["folder"])
                attrs["file"] = str(obj["file"])
            for name, default in (("x", 0.0), ("y", 0.0), ("angle", 0.0),
                                  ("scale_x", 1.0), ("scale_y", 1.0), ("a", 1.0)):
                if obj.get(name, default) != default:
                    attrs[name] = _fmt(float(obj[name]))
            if tag == "object":
                for name in ("pivot_x", "pivot_y"):
                    if name in obj:
                        attrs[name] = _fmt(float(obj[name]))
            ET.SubElement(key_el, tag, attrs)
