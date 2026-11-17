"""角色 / 元素动作段剪辑（三视图路线版）。

素材链路（全部「图生视频」，角色一致性由首帧保证）：
    1. 卡图 / CG  → ImageGen 生成白底三视图（角色设定表，锁死设计）
    2. 设定表     → ImageGen 生成 16:9 动作场景图（姿态自由）
    3. 场景图     → VideoGen 生成动作视频

素材放在 raw/cg/<sub>/ 下，本脚本负责：两处水印 delogo、裁 16:9、
缩放 1280x720、段间短淡变、concat 拼接。

用法：
    python tools/trailer_characters_ref.py
    python tools/trailer_characters_ref.py --out xxx.mp4
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CG = ROOT / "release" / "trailer" / "raw" / "cg"
WORK = ROOT / "release" / "trailer" / "work_v11"

FFBIN = Path("C:/Users/Administrator/AppData/Local/Microsoft/WinGet/Packages/"
             "Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/"
             "ffmpeg-9.0.2-full_build/bin")
FFMPEG = str(FFBIN / "ffmpeg.exe")
FFPROBE = str(FFBIN / "ffprobe.exe")

FPS = 30
OUT_W, OUT_H = 1280, 720

# 水印精确包围盒（以 1344x768 为基准，实际按源分辨率等比缩放）
LOGO_TL_BASE = (5, 3, 94, 50)
LOGO_BR_BASE = (1248, 713, 94, 53)

# (子目录, 源文件名, 起播秒, 段长, 段落名)；顺序即成片顺序
SHOTS = [
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-44-45.mp4", 1.10, 2.6, "01_knight"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-47-11.mp4", 0.85, 2.6, "02_archer"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-37-06.mp4", 0.30, 3.2, "03_rogue"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-49-29.mp4", 0.50, 2.6, "04_mech"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-59-51.mp4", 0.95, 2.6, "05_forest"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T12-02-25.mp4", 2.10, 2.6, "06_bard"),
    ("ref", "2D_anime_cel_shaded_animation__2026-11-17T11-05-18.mp4", 1.10, 2.6, "07_earth"),
    ("ref", "2D_anime_cel_shaded_animation__2026-11-17T11-07-58.mp4", 0.40, 2.4, "08_fire"),
    ("ref", "2D_anime_cel_shaded_animation__2026-11-17T11-10-17.mp4", 0.30, 2.4, "09_water"),
    ("ref", "2D_anime_cel_shaded_animation__2026-11-17T11-12-47.mp4", 0.45, 2.4, "10_wind"),
]


def run(args, tag):
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode != 0:
        print("[fail] %s\n%s" % (tag, p.stderr[-1800:]), flush=True)
        return False
    return True


def probe(path: Path) -> tuple[int, int]:
    p = subprocess.run([FFPROBE, "-v", "error", "-select_streams", "v:0",
                        "-show_entries", "stream=width,height", "-of", "csv=p=0",
                        str(path)], capture_output=True, text=True)
    w, h = p.stdout.strip().split(",")[:2]
    return int(w), int(h)


def build_vf(w: int, h: int, seg: float, fi: float, fo: float) -> str:
    """按源分辨率自适应：水印坐标等比缩放，再裁成 16:9。"""
    sx, sy = w / 1344.0, h / 768.0
    tl = "delogo=x=%d:y=%d:w=%d:h=%d" % tuple(
        int(round(v * s)) for v, s in zip(LOGO_TL_BASE, (sx, sy, sx, sy)))
    br = "delogo=x=%d:y=%d:w=%d:h=%d" % tuple(
        int(round(v * s)) for v, s in zip(LOGO_BR_BASE, (sx, sy, sx, sy)))
    # 部分素材比 16:9 更宽（1408x736），这类裁宽不裁高
    if w / h > 16 / 9:
        cw = int(round(h * 16 / 9))
        ch, cx, cy = h, (w - cw) // 2, 0
    else:
        cw = w
        ch = int(round(w * 9 / 16 / 2)) * 2
        cx, cy = 0, (h - ch) // 2
    return (
        "%s,%s," % (tl, br)
        + "crop=%d:%d:%d:%d," % (cw, ch, cx, cy)
        + "scale=%d:%d,setsar=1," % (OUT_W, OUT_H)
        + "fps=%d," % FPS
        + "fade=t=in:st=0:d=%.2f,fade=t=out:st=%.2f:d=%.2f," % (fi, seg - fo, fo)
        + "format=yuv420p"
    )


def prep(src: Path, ss: float, seg: float, name: str, work: Path, fi=0.14, fo=0.14):
    dst = work / ("%s.mp4" % name)
    w, h = probe(src)
    vf = build_vf(w, h, seg, fi, fo)
    ok = run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
              "-ss", "%.3f" % ss, "-t", "%.3f" % seg, "-i", str(src),
              "-vf", vf, "-an",
              "-c:v", "libx264", "-crf", "16", "-preset", "veryfast",
              "-pix_fmt", "yuv420p", str(dst)], "prep:%s" % name)
    return dst if ok else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(WORK / "chars_ref.mp4"))
    args = ap.parse_args()

    work = WORK
    work.mkdir(parents=True, exist_ok=True)

    clips = []
    last = len(SHOTS) - 1
    for i, (sub, fname, ss, seg, name) in enumerate(SHOTS):
        src = CG / sub / fname
        if not src.exists():
            print("[missing]", src)
            return 1
        fi = 0.35 if i == 0 else 0.14
        fo = 0.5 if i == last else 0.14
        c = prep(src, ss, seg, name, work, fi, fo)
        if c is None:
            return 1
        clips.append(c)
        print("prep ok:", name, flush=True)

    lst = work / "chars_list.txt"
    lst.write_text("".join("file '%s'\n" % str(c).replace("\\", "/") for c in clips),
                   encoding="utf-8")

    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    if not run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
                "-f", "concat", "-safe", "0", "-i", str(lst),
                "-c", "copy", str(out)], "concat"):
        return 1

    print("done: %s  (%.1fs)" % (out, sum(s[3] for s in SHOTS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
