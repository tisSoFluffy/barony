# Kimodo (NVIDIA) — motion generation

[Kimodo](https://research.nvidia.com/labs/sil/projects/kimodo/) is a kinematic
motion diffusion model: text prompts and kinematic constraints in, **skeletal
motion** out. It is installed here as a local, self-contained tool environment.

## What is installed

| | |
|---|---|
| location | `tools/kimodo/.venv` (4.8 GB, gitignored) |
| python | 3.10.21, fetched by `uv` — the system Python 3.14 is untouched |
| torch | 2.11.0+cu128, CUDA verified on the RTX 5080 (sm_120) |
| kimodo | 1.0.0 from `git+https://github.com/nv-tlabs/kimodo.git` |
| CLIs | `kimodo_gen`, `kimodo_demo`, `kimodo_convert`, `kimodo_textencoder` |

Reproduce from scratch:

```bash
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"   # if uv is missing
uv tool install cmake                                        # kimodo builds a native ext
uv venv --python 3.10 tools/kimodo/.venv
uv pip install --python tools/kimodo/.venv/Scripts/python.exe \
    torch --index-url https://download.pytorch.org/whl/cu128
uv pip install --python tools/kimodo/.venv/Scripts/python.exe \
    "git+https://github.com/nv-tlabs/kimodo.git"
```

## Text encoder access

Kimodo encodes prompts with **`meta-llama/Meta-Llama-3-8B-Instruct`** (3.0,
*not* 3.1 — the McGill-NLP LLM2Vec adapter kimodo loads is trained on that
specific base and hardcodes its repo id). This is a gated Hugging Face repo;
access needs a human with an HF account to accept the licence at
<https://huggingface.co/meta-llama/Meta-Llama-3-8B-Instruct> and run
`hf auth login`. Access is currently granted (account `professorlama`) — if
generation starts 403ing again, check `hf auth whoami` first, then whether
the grant lapsed.

## Running it

The GPU has 16.3 GB and Kimodo wants ~17 GB to run entirely on-device, so put
the text encoder on the CPU (68 GB system RAM, so this is comfortable):

```bash
TEXT_ENCODER_DEVICE=cpu tools/kimodo/.venv/Scripts/kimodo_gen.exe \
    "a soldier walks forward slowly" --duration 4 --output out/walk.npz --bvh
```

`--bvh` is the important flag for us: it exports standard BVH (SOMA models
only), which Blender can import and retarget. NPZ is the native format
(`posed_joints`, `global_rot_mats`, `foot_contacts`, …); SMPL-X models can also
emit AMASS NPZ and G1 can emit MuJoCo CSV.

Checkpoints download automatically on first use. Skeletons available: **SOMA**
(5 variants), **Unitree G1** (2), **SMPL-X** (1).

## What this does *not* do

Kimodo animates a **skeleton it already knows**. Our enemy models are unrigged
Hunyuan3D output — no bones, no skin weights — and most of them are not
humanoid, so a humanoid skeleton has nothing to map onto:

| enemy | shape | Kimodo applicable? |
|---|---|---|
| `silence_guard` | humanoid | yes |
| `memory_construct` | humanoid | yes |
| `void_leaper` | biped, long claw-limbs | rough retarget at best |
| `scrap_crawler` | quadruped robot | no |
| `turret_spider` | four-legged | no |
| `drone_swarm` | quadrotor | no |
| `core_guardian` | cube | no |
| `nexus` | floating polyhedron | no |

For the humanoids the missing steps are **rigging** (skeleton + skin weights —
Kimodo does not do this) and **retargeting** its skeleton onto that rig, then
glTF export with the skin and animation for Godot to import.

## Rigging + retargeting onto Kael

Kael (`fractured-orbit/assets/models/player.glb`) is rigged — see the "rigged,
skinned Kael" commit and `fractured-orbit/tools/autorig.py`, which builds a
19-bone armature (`Hips/Spine/Chest/Neck/Head`, `Shoulder/UpperArm/LowerArm/
Hand` per side, `UpperLeg/LowerLeg/Foot` per side). `tools/retarget_kimodo.py`
maps Kimodo's SOMA skeleton onto it by name (`Spine1+Spine2 → Spine`,
`Neck1+Neck2 → Neck`, everything else 1:1) and copies each bone's
rest-relative rotation across in Blender.

End-to-end recipe:

```bash
TEXT_ENCODER_DEVICE=cpu tools/kimodo/.venv/Scripts/kimodo_gen.exe \
    "a person walks forward at a steady pace" --duration 4 --output out/walk.npz

# Do NOT retarget kimodo_gen's own --bvh output directly — it isn't in the
# standard T-pose reference frame Kael's rig assumes, and the result is a
# character rotated ~90-120° off (lying on its side). Always regenerate the
# BVH through kimodo_convert with --bvh_standard_tpose first:
tools/kimodo/.venv/Scripts/kimodo_convert.exe out/walk.npz out/walk.bvh \
    --to soma-bvh --bvh_standard_tpose

"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
    --python tools/retarget_kimodo.py -- \
    --bvh out/walk.bvh --target fractured-orbit/assets/models/player.glb \
    --out out/kael_walk.glb --anim-name walk
```

The bundled demo motions under `kimodo/assets/demo/examples/*/motion.npz`
only ship `global_rot_mats` (no `local_rot_mats`, which `kimodo_convert`
requires) — `tools/kimodo/repair_demo_npz.py` derives it via kimodo's own
`global_rots_to_local_rots` if you want to test the pipeline without running
generation.

`tools/dump_bones.py` and `tools/dump_anim.py` print an armature's bone
hierarchy / animation fcurves for sanity checks; `tools/shot_anim.py` renders
a handful of frames with a camera that follows the root motion (useful since
Kimodo motions can travel meters from the origin).

Not yet done: importing the retargeted `.glb` into the Godot project and
wiring it into `Player.gd`/an `AnimationPlayer`.
