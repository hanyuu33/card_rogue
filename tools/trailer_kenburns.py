# -*- coding: utf-8 -*-
"""用 CG 图做 Ken Burns 动效（缓推 + 平移），生成引入段视频。

用法：
    python tools/trailer_kenburns.py

输出：release/trailer/raw/intro_kenburns.mp4
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "release" / "trailer" / "raw"
OUT = RAW / "intro_kenburns.mp4"

FF = Path(os.environ.get(
    "CARD_ROGUE_FFMPEG",
    r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages"
    r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe",
))

# 每张 CG 做一段 Ken Burns
# (图片路径, 起始缩放, 结束缩放, 平移方向, 时长秒)
CG_SHOTS = [
    # 森林精魄：从全景缓推到脸部
    ("assets/ui/class_cg_forest.png", 1.0, 1.25, "center", 4.0),
    # 暗影刺客：从脸部缓拉到全景
    ("assets/ui/class_cg_rogue.png", 1.2, 1.0, "center", 4.0),
]


def run(args, tag):
    r = subprocess.run([str(FF)] + args, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print("[FAIL] %s" % tag)
        print((r.stderr or "")[-2000:])
        return False
    return True


def kenburns(img_path, zoom_start, zoom_end, pan, dur, out_path):
    """用 ffmpeg zoompan 做 Ken Burns 效果。"""
    fps = 30
    frames = int(dur * fps)

    # zoompan 滤镜：z 从 zoom_start 渐变到 zoom_end
    # x, y 居中平移
    vf = (
        "zoompan="
        "z='min(zoom+0.0005,%.3f)':"  # 每帧微增，上限 zoom_end
        "d=%d:"                       # 持续帧数
        "x='iw/2-(iw/zoom/2)':"       # 居中
        "y='ih/2-(ih/zoom/2)':"       # 居中
        "s=1280x720:"                 # 输出尺寸
        "fps=%d" % (zoom_end, frames, fps)
    )

    # 如果是拉远（zoom_end < zoom_start），用反向
    if zoom_end < zoom_start:
        vf = (
            "zoompan="
            "z='if(eq(on,1),%.3f,max(zoom-0.0005,%.3f))':"
            "d=%d:"
            "x='iw/2-(iw/zoom/2)':"
            "y='ih/2-(ih/zoom/2)':"
            "s=1280x720:"
            "fps=%d" % (zoom_start, zoom_end, frames, fps)
        )

    ok = run([
        "-y", "-i", str(img_path),
        "-vf", vf,
        "-t", "%.1f" % dur,
        "-c:v", "libx264", "-crf", "17", "-preset", "medium",
        "-pix_fmt", "yuv420p",
        "-an",
        str(out_path)
    ], "kenburns_%s" % Path(img_path).stem)

    return ok


def main():
    RAW.mkdir(parents=True, exist_ok=True)

    clips = []
    for i, (img, zs, ze, pan, dur) in enumerate(CG_SHOTS):
        out = RAW / ("kb_%d.mp4" % i)
        print("生成 Ken Burns: %s (%.1f→%.1f, %.1fs)" % (Path(img).name, zs, ze, dur))
        if kenburns(ROOT / img, zs, ze, pan, dur, out):
            clips.append(out)
        else:
            return 1

    # 拼接
    lst = RAW / "kb_list.txt"
    lst.write_text("".join("file '%s'\n" % str(c).replace("\\", "/") for c in clips),
                   encoding="utf-8")

    if not run(["-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                "-c", "copy", str(OUT)], "concat"):
        return 1

    print("DONE:", OUT)
    print("size:", OUT.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
