<#
.SYNOPSIS
  One-shot: kimodo_gen -> kimodo_convert (standard T-pose BVH) -> retarget onto
  a rig -> sanity dump, for quickly iterating on a motion prompt.

.EXAMPLE
  .\tools\kimodo_iterate.ps1 -Prompt "a person walks forward at a steady pace" `
      -TargetModel alien_rigged_noyaw -AnimName try1

.EXAMPLE
  .\tools\kimodo_iterate.ps1 -Prompt "a person lunges and stabs with a knife" `
      -TargetModel player -AnimName stab1 -Duration 1.5 -Shots
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    # Bare name (looked up as out\<name>.glb), a known alias (player/kael),
    # or a literal path to a .glb.
    [string]$TargetModel = "alien_rigged_noyaw",

    [Parameter(Mandatory = $true)]
    [string]$AnimName,

    [double]$Duration = 4.0,

    # Render a handful of preview frames to out\shots_<AnimName> afterwards.
    [switch]$Shots,

    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    [string]$KimodoVenv = "tools\kimodo\.venv\Scripts"
)

$ErrorActionPreference = "Stop"

function Invoke-Checked {
    param([string]$Description, [scriptblock]$Command)
    Write-Host "==> $Description" -ForegroundColor Cyan
    & $Command
    # Blender exits 0 even after an unhandled Python exception unless you pass
    # --python-exit-code, so every Blender call below does. Without that,
    # $LASTEXITCODE alone would silently let a failed step (e.g. "no armature
    # found") fall through to the next one instead of stopping the script.
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed (exit $LASTEXITCODE)"
    }
}

# Resolve the target rig: literal path, alias, or bare name under out\.
switch -Regex ($TargetModel) {
    '^(player|kael)$' { $TargetPath = "fractured-orbit\assets\models\player.glb"; break }
    default {
        if (Test-Path $TargetModel) {
            $TargetPath = $TargetModel
        } elseif (Test-Path "out\$TargetModel.glb") {
            $TargetPath = "out\$TargetModel.glb"
        } else {
            throw "Can't find target model '$TargetModel' (tried as literal path and out\$TargetModel.glb)"
        }
    }
}

New-Item -ItemType Directory -Force -Path out | Out-Null

# Fail fast, before burning a minute on kimodo_gen, if the target has no
# armature - e.g. a cleaned-but-unrigged mesh (*_clean*.glb / *-raw.glb)
# instead of the rigged one (*_rigged*.glb) that autorig.py produced.
Invoke-Checked "check $TargetPath has an armature" {
    & $BlenderExe --background --python-exit-code 1 --python tools\dump_bones.py -- $TargetPath
}

$npz = "out\$AnimName.npz"
$bvh = "out\$AnimName.bvh"
$glb = "out\$AnimName.glb"

$env:TEXT_ENCODER_DEVICE = "cpu"
Invoke-Checked "kimodo_gen: `"$Prompt`" ($Duration s)" {
    & "$KimodoVenv\kimodo_gen.exe" $Prompt --duration $Duration --output $npz
}

Invoke-Checked "kimodo_convert -> standard T-pose BVH" {
    & "$KimodoVenv\kimodo_convert.exe" $npz $bvh --to soma-bvh --bvh_standard_tpose
}

Invoke-Checked "retarget onto $TargetPath" {
    & $BlenderExe --background --python-exit-code 1 --python tools\retarget_kimodo.py -- `
        --bvh $bvh --target $TargetPath --out $glb --anim-name $AnimName
}

Invoke-Checked "sanity dump" {
    & $BlenderExe --background --python-exit-code 1 --python tools\dump_anim.py -- $glb
}

if ($Shots) {
    $shotsDir = "out\shots_$AnimName"
    New-Item -ItemType Directory -Force -Path $shotsDir | Out-Null
    Invoke-Checked "render preview frames" {
        & $BlenderExe --background --python-exit-code 1 --python tools\shot_anim.py -- $glb "$PWD\$shotsDir"
    }
    Write-Host "Preview frames: $shotsDir" -ForegroundColor Green
}

Write-Host "Done: $glb" -ForegroundColor Green
