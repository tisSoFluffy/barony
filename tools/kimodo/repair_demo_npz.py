"""One-off: the bundled demo NPZs only ship global_rot_mats (for the viz app),
not local_rot_mats, so kimodo_convert refuses them. Kimodo's own
global_rots_to_local_rots is hierarchy-aware (handles the root specially), so
reuse it instead of hand-rolling parent-inverse @ child.

Usage: kimodo/.venv/Scripts/python.exe repair_demo_npz.py <in.npz> <out.npz>
"""
import sys

import numpy as np
import torch

from kimodo.skeleton.definitions import SOMASkeleton30
from kimodo.skeleton.transforms import global_rots_to_local_rots

src, dst = sys.argv[1], sys.argv[2]
d = np.load(src)

skeleton = SOMASkeleton30()
global_rot_mats = torch.from_numpy(d["global_rot_mats"]).float()  # (T, 30, 3, 3)
local_rot_mats = global_rots_to_local_rots(global_rot_mats, skeleton)

root_positions = d["posed_joints"][:, skeleton.root_idx, :]  # Hips world position per frame

np.savez(
    dst,
    local_rot_mats=local_rot_mats.numpy(),
    global_rot_mats=d["global_rot_mats"],
    root_positions=root_positions.astype(np.float32),
    posed_joints=d["posed_joints"],
    foot_contacts=d["foot_contacts"],
)
print(f"wrote {dst}: local_rot_mats {local_rot_mats.shape}, root_positions {root_positions.shape}")
