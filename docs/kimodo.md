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

## One blocker left: the gated text encoder

Kimodo encodes prompts with **`meta-llama/Meta-Llama-3-8B-Instruct`**, a gated
Hugging Face repo. Generation currently fails with a 401 until someone with a
Hugging Face account:

1. accepts the licence at <https://huggingface.co/meta-llama/Meta-Llama-3-8B-Instruct>, then
2. runs `hf auth login` (or writes the token to `~/.cache/huggingface/token`).

This needs a human with the account — it cannot be scripted here.

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
