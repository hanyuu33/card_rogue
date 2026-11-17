"""角色 / 元素动作段剪辑：十段图生视频素材拼成一条连续片段。

素材来源：tools/ 里各条 VideoGen 输出，全部是「首帧=游戏原画」的图生视频，
所以角色设计与游戏内完全一致。原始输出 1344x768 (7:4)，两个角落带水印
（左上角来自首帧图的 AI 生成标识，右下角来自视频生成器），这里统一用
delogo 抹掉，再裁成 16:9 输出 1280x720。

用法：
    python tools/trailer_characters_ref.py                 # 出默认成片
    python tools/trailer_characters_ref.py --out xxx.mp4
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CG = ROOT / "release" / "trailer" / "raw" / "cg" / "ref"
WORK = ROOT / "release" / "trailer" / "work_v10"

FFBIN = Path("C:/Users/Administrator/AppData/Local/Microsoft/WinGet/Packages/"
             "Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/"
             "ffmpeg-9.0.2-full_build/bin")
FFMPEG = str(FFBIN / "ffmpeg.exe")
FFPROBE = str(FFBIN / "ffprobe.exe")

FPS = 30
OUT_W, OUT_H = 1280, 720

# (源文件名, 起播秒, 段长, 段落名)；顺序即成片顺序
SHOTS = [
    ("2D_anime_cel_shaded_animation__2026-11-17T10-44-42.mp4", 0.45, 2.6, "01_knight"),
    ("2D_anime_cel_shaded_animation__2026-11-17T10-47-12.mp4", 0.35, 2.8, "02_archer"),
    ("2D_anime_cel_shaded_animation__2026-11-17T11-02-27.mp4", 0.30, 2.7, "03_rogue"),
    ("2D_anime_cel_shaded_animation__2026-11-17T10-54-10.mp4", 0.40, 2.5, "04_mech"),
    ("2D_anime_cel_shaded_animation__2026-11-17T10-56-49.mp4", 0.50, 2.5, "05_forest"),
    ("2D_anime_cel_shaded_animation__2026-11-17T10-59-13.mp4", 0.50, 2.5, "06_bard"),
    ("2D_anime_cel_shaded_animation__2026-11-17T11-05-18.mp4", 1.10, 2.6, "07_earth"),
    ("2D_anime_cel_shaded_animation__2026-11-17T11-07-58.mp4", 0.40, 2.4, "08_fire"),
    ("2D_anime_cel_shaded_animation__2026-11-17T11-10-17.mp4", 0.30, 2.4, "09_water"),
    ("2D_anime_cel_shaded_animation__2026-11-17T11-12-47.mp4", 0.45, 2.4, "10_wind"),
]

# 水印精确包围盒（以 1344x768 为基准，实际按源分辨率等比缩放）
# 左上「AI生成」圆角标：x 11-92 / y 9-47；右下「AI生成 + WORKBUDDY」：x 1255-1340 / y 720-762
LOGO_TL_BASE = (5, 3, 94, 50)
LOGO_BR_BASE = (1248, 713, 94, 53)


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
        cw = int(round(h * 16 / 9 / 2)) * 2
        ch, cx, cy = h, (w - cw) // 2, 0
        cw = int(round(h * 16 / 9))
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


def run(args, tag):
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode != 0:
        print("[fail] %s\n%s" % (tag, p.stderr[-1800:]), flush=True)
        return False
    return True


def prep(src: Path, ss: float, seg: float, name: str, work: Path, fi=0.14, fo=0.14) -> Path | None:
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
    ap.add_argument("--out", default=str(ROOT / "release" / "trailer" / "work_v10" / "chars_ref.mp4"))
    args = ap.parse_args()

    work = WORK
    work.mkdir(parents=True, exist_ok=True)

    clips = []
    last = len(SHOTS) - 1
    for i, (fname, ss, seg, name) in enumerate(SHOTS):
        src = CG / fname
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

    lst = work / "chars_ref_list.txt"
    lst.write_text("".join("file '%s'\n" % str(c).replace("\\", "/") for c in clips),
                   encoding="utf-8")

    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    if not run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
                "-f", "concat", "-safe", "0", "-i", str(lst),
                "-c", "copy", str(out)], "concat"):
        return 1

    total = sum(s[2] for s in SHOTS)
    print("done: %s  (%.1fs)" % (out, total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
