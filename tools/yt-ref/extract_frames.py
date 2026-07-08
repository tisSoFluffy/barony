#!/usr/bin/env python3
"""
Extract evenly-spaced frames from a YouTube video for HD 2D style analysis.

Usage:
    python3 extract_frames.py <youtube-url> [--frames N] [--out DIR] [--start SS] [--duration SS]
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

DEFAULT_FRAMES = 12
DEFAULT_DURATION = 60  # cap download to first 60s by default

YT_DLP = ["python3", "-m", "yt_dlp"]


def run(cmd, check=True, capture=False):
    kwargs = {"check": check}
    if capture:
        kwargs["capture_output"] = True
        kwargs["text"] = True
    return subprocess.run(cmd, **kwargs)


def probe_duration(video_path: str) -> float:
    result = run(
        ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", video_path],
        capture=True,
    )
    info = json.loads(result.stdout)
    return float(info["format"].get("duration", DEFAULT_DURATION))


def download_clip(url: str, out_path: str, start: float, duration: float) -> str:
    """Download a segment of the YouTube video as mp4."""
    cmd = YT_DLP + [
        "--format", "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best[height<=720]",
        "--merge-output-format", "mp4",
        "--download-sections", f"*{start:.0f}-{start + duration:.0f}",
        "--output", out_path,
        "--no-playlist",
        "--quiet",
        "--progress",
        url,
    ]
    print(f"Downloading clip ({duration:.0f}s starting at {start:.0f}s)...", flush=True)
    result = run(cmd, check=False)
    if result.returncode != 0:
        # fallback: no section clipping
        cmd_fallback = YT_DLP + [
            "--format", "best[height<=720]/best",
            "--output", out_path,
            "--no-playlist",
            "--quiet",
            "--progress",
            url,
        ]

        print("Section download failed, falling back to full download...", flush=True)
        run(cmd_fallback)
    return out_path


def extract_frames(video_path: str, out_dir: str, n_frames: int, start: float, duration: float) -> list[str]:
    """Extract n_frames evenly spaced from [start, start+duration]."""
    actual_duration = min(probe_duration(video_path) - start, duration)
    interval = actual_duration / n_frames

    os.makedirs(out_dir, exist_ok=True)

    cmd = [
        "ffmpeg", "-y",
        "-ss", str(start),
        "-i", video_path,
        "-t", str(actual_duration),
        "-vf", f"fps=1/{interval:.3f},scale=960:-1",
        "-q:v", "2",
        os.path.join(out_dir, "frame_%03d.jpg"),
        "-loglevel", "error",
    ]
    run(cmd)

    frames = sorted(
        os.path.join(out_dir, f)
        for f in os.listdir(out_dir)
        if f.startswith("frame_") and f.endswith(".jpg")
    )
    return frames


def get_video_title(url: str) -> str:
    result = run(
        YT_DLP + ["--get-title", "--no-playlist", url],
        capture=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else "Unknown"


def main():
    parser = argparse.ArgumentParser(description="Extract frames from a YouTube video for HD 2D analysis")
    parser.add_argument("url", help="YouTube video URL")
    parser.add_argument("--frames", type=int, default=DEFAULT_FRAMES, help="Number of frames to extract")
    parser.add_argument("--out", help="Output directory (default: auto temp dir)")
    parser.add_argument("--start", type=float, default=0.0, help="Start offset in seconds")
    parser.add_argument("--duration", type=float, default=float(DEFAULT_DURATION), help="Clip duration in seconds")
    args = parser.parse_args()

    out_dir = args.out or tempfile.mkdtemp(prefix="hd2d_frames_")
    video_path = os.path.join(out_dir, "clip.mp4")

    title = get_video_title(args.url)
    print(f"Video: {title}", flush=True)

    download_clip(args.url, video_path, args.start, args.duration)

    frames = extract_frames(video_path, out_dir, args.frames, 0, args.duration)
    if not frames:
        print("ERROR: No frames extracted", file=sys.stderr)
        sys.exit(1)

    print(f"\nExtracted {len(frames)} frames to: {out_dir}")
    print("FRAMES:")
    for f in frames:
        print(f"  {f}")

    # Clean up video file to save space
    try:
        os.remove(video_path)
    except OSError:
        pass

    return out_dir, frames


if __name__ == "__main__":
    main()
