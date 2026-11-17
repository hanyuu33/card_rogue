# -*- coding: utf-8 -*-
"""角色动作段：把 AI 图生视频的六条角色片段剪成一段连续演示。

python tools/trailer_characters.py --out release/trailer/work_v9/chars_demo.mp4

约定：
  * 每条源片 5.17s / 24fps，取动作中段 0.4s 起 2.6s；
  * 源片左上角有「AI生成」水印 → 统一 crop 顶部 58px 去掉；
  * 源片比例 9:8 或 7:4：≥1.7 的满屏裁切，<1.7 的用模糊底信箱（不丢头脚）；
  * 段间 0.25s 交叉淡变，末段 0.4s 淡出；音轨统一静音，配乐后期再叠。
"""
import argparse
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CG = ROOT / "release" / "trailer" / "raw" / "cg"
FF = Path(os.environ.get(
    "CARD_ROGUE_FFMPEG",
    r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages"
    r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe",
))
W, H, FPS = 1280, 720, 30
SEG = 2.2
XF = 0.25
CROP_TOP = 74

# 顺序：人类四职业（暗 → 机械 → 自然 → 吟游）→ 鸭子骑士 → 鸭子弓手
SHOTS = [
    ("2D_anime_cel_shaded_animation__2026-11-17T09-59-59.mp4", 0.55, "01_rogue"),
    ("FLAT_2D_anime_cel_shaded_anima_2026-11-17T10-15-50.mp4", 0.60, "02_mech"),
    ("2D_anime_cel_shaded_animation__2026-11-17T10-05-53.mp4", 0.50, "03_forest"),
    ("2D_anime_cel_shaded_animation__2026-11-17T10-07-50.mp4", 0.50, "04_bard"),
    ("FLAT_2D_anime_cel_shaded_anima_2026-11-17T10-18-54.mp4", 1.15, "05_water"),
    ("2D_anime_cel_shaded_animation__2026-11-17T10-13-07.mp4", 0.50, "06_wind"),
    ("2D_anime_cel_shaded_animation__2026-11-17T09-57-24.mp4", 0.60, "07_knight"),
    ("2D_anime_cel_shaded_animation__2026-11-17T10-03-52.mp4", 0.50, "08_archer"),
]


def run(args, tag):
    r = subprocess.run([str(FF)] + args, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print("[FAIL]", tag)
        print((r.stderr or "")[-2500:])
        return False
    return True


def pick_filter():
    """满屏裁切 or 模糊底信箱，按源片宽高比决定。"""
    return None


def prep(src, ss, name, work, fi=0.12, fo=0.12):
    dst = work / ("%s.mp4" % name)
    # 先探比例
    p = subprocess.run([str(FF), "-hide_banner", "-i", str(src)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    import re
    m = re.search(r"Video:.*?(\d{2,5})x(\d{2,5})", p.stderr or "")
    if not m:
        print("[FAIL] probe", name)
        return None
    sw, sh = int(m.group(1)), int(m.group(2))
    ratio = sw / sh

    head = "crop=iw:ih-%d:0:%d," % (CROP_TOP, CROP_TOP)
    if ratio >= 1.7:
        vf = (head + "scale=-2:%d,crop=%d:%d:(iw-%d)/2:(ih-%d)/2,setsar=1"
              % (H, W, H, W, H))
    else:
        vf = (head + "split=2[a][b];"
              "[a]scale=-2:%d[fg];"
              "[b]scale=320:180,gblur=sigma=10,eq=brightness=-0.38:saturation=0.60,"
              "drawbox=c=black@0.16:t=fill,scale=%d:%d[bg];"
              "[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1" % (H, W, H))
    vf += ",fps=%d,format=yuv420p" % FPS
    # 段间不做 xfade（链式 xfade 在本机 ffmpeg 上会挂住），改为每段自带
    # 极短淡入淡出，拼接后观感接近交叉溶解，且 concat 可以 -c copy 秒过。
    vf += ",fade=t=in:st=0:d=%.2f,fade=t=out:st=%.2f:d=%.2f" % (fi, SEG - fo, fo)

    cmd = ["-y", "-hide_banner", "-ss", "%.2f" % ss, "-t", "%.2f" % SEG,
           "-i", str(src), "-filter_complex" if "split" in vf else "-vf", vf,
           "-an", "-c:v", "libx264", "-crf", "15", "-preset", "veryfast",
           "-pix_fmt", "yuv420p", str(dst)]
    if "split" in vf:
        # filter_complex 需要显式映射
        cmd = ["-y", "-hide_banner", "-ss", "%.2f" % ss, "-t", "%.2f" % SEG,
               "-i", str(src), "-filter_complex", vf,
               "-an", "-c:v", "libx264", "-crf", "15", "-preset", "medium",
               "-pix_fmt", "yuv420p", str(dst)]
    if not run(cmd, name):
        return None
    return dst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "release" / "trailer" / "work_v9" / "chars_demo.mp4"))
    ap.add_argument("--bgm", default=str(ROOT / "assets" / "audio" / "bgm" / "title.ogg"))
    args = ap.parse_args()
    out = Path(args.out).resolve()
    work = out.parent
    work.mkdir(parents=True, exist_ok=True)

    clips = []
    last = len(SHOTS) - 1
    for i, (fname, ss, name) in enumerate(SHOTS):
        src = CG / fname
        if not src.exists():
            raise FileNotFoundError(src)
        fi = 0.30 if i == 0 else 0.12
        fo = 0.50 if i == last else 0.12
        c = prep(src, ss, name, work, fi, fo)
        if c is None:
            return 1
        clips.append(c)
        print("prep ok:", name, flush=True)

    total = len(clips) * SEG
    lst = work / "chars_list.txt"
    lst.write_text("".join("file '%s'\n" % str(c).replace("\\", "/") for c in clips),
                   encoding="utf-8")
    silent = work / "chars_mute.mp4"
    if not run(["-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                "-c", "copy", str(silent)], "concat"):
        return 1

    # 叠 BGM（低音量），保持时长
    if Path(args.bgm).exists():
        cmd = ["-y", "-hide_banner", "-i", str(silent), "-stream_loop", "-1",
               "-i", str(args.bgm), "-filter_complex",
               "[1:a]volume=0.55,afade=t=in:st=0:d=0.4,"
               "afade=t=out:st=%.2f:d=0.6[a]" % (total - 0.7),
               "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac",
               "-b:a", "192k", "-ar", "48000", "-ac", "2",
               "-shortest", "-t", "%.2f" % total, str(out)]
    else:
        cmd = ["-y", "-hide_banner", "-i", str(silent), "-c", "copy", str(out)]
    if not run(cmd, "mix"):
        return 1
    print("FINAL:", out, out.stat().st_size, "%.2fs" % total)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
