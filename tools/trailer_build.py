# -*- coding: utf-8 -*-
"""把录好的实机片段 + 生成引入 + 旁白拼成一条 trailer。

    python tools/trailer_build.py --lang en
    python tools/trailer_build.py --lang zh

分镜（约 34 秒）：
    0.0-5.0   生成引入（鸭子村远景）
    5.0-9.0   标题画面        ← "Every run begins with one card."
    9.0-13.0  冒险地图        ← "Choose your path."
    13.0-16.0 战斗开始        ← "Break the odds."
    16.0-30.0 战斗推进
    30.0-34.0 标题收尾
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "release" / "trailer" / "raw"
WORK = ROOT / "release" / "trailer" / "work"
OUT = ROOT / "release" / "trailer" / "out"
FF = Path(os.environ.get(
    "CARD_ROGUE_FFMPEG",
    r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages"
    r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe",
))

NARR = {
    "en": "A_white_duck_knight_in_silver__2026-11-14T12-22-19.mp4",
    "zh": "A_white_duck_knight_in_silver__2026-11-14T12-25-14.mp4",
}

# 引入段：森林场景 → 森林精魄CG → 城堡场景 → 暗影刺客CG
INTRO_FOREST_SCENE = "Cinematic_establishing_shot_of_2026-11-14T16-06-36.mp4"
INTRO_CASTLE_SCENE = "Cinematic_shot_of_a_dark_gothi_2026-11-14T16-08-38.mp4"
INTRO_FOREST_CG = "The_forest_spirit_girl_with_lo_2026-11-14T15-44-54.mp4"
INTRO_ROGUE_CG = "kb_1.mp4"  # 暗影刺客 Ken Burns

SHOTS_ZH = [
    (INTRO_FOREST_SCENE, 0.0,  3.0, "i1_forest_scene"),
    (INTRO_FOREST_CG,    0.0,  2.0, "i2_forest_cg"),
    (INTRO_CASTLE_SCENE, 0.0,  3.0, "i3_castle_scene"),
    (INTRO_ROGUE_CG,     0.0,  2.0, "i4_rogue_cg"),
    ("seg_test.avi",    4.3,  4.0, "s1_title"),
    ("seg_enemy2.avi", 20.7,  4.0, "s2_map"),
    ("seg_enemy2.avi", 28.7,  3.0, "s3_fight_in"),
    ("seg_enemy2.avi", 31.7, 14.0, "s4_fight"),
    ("seg_test.avi",   10.0,  4.0, "s5_end"),
]

SHOTS_EN = [
    (INTRO_FOREST_SCENE, 0.0,  3.0, "i1_forest_scene"),
    (INTRO_FOREST_CG,    0.0,  2.0, "i2_forest_cg"),
    (INTRO_CASTLE_SCENE, 0.0,  3.0, "i3_castle_scene"),
    (INTRO_ROGUE_CG,     0.0,  2.0, "i4_rogue_cg"),
    ("seg_test.avi",    4.3,  4.0, "s1_title"),
    ("seg_en.avi",    20.7,  4.0, "s2_map"),
    ("seg_en.avi",    28.7,  3.0, "s3_fight_in"),
    ("seg_en.avi",    31.7, 14.0, "s4_fight"),
    ("seg_test.avi",   10.0,  4.0, "s5_end"),
]


def run(args, tag):
    r = subprocess.run([str(FF)] + args, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print("[FAIL] %s" % tag)
        print((r.stderr or "")[-1500:])
        return False
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", default="en", choices=["en", "zh"])
    ap.add_argument("--scale", default="1280:720")
    args = ap.parse_args()

    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    shots = SHOTS_EN if args.lang == "en" else SHOTS_ZH
    clips = []
    for src, ss, dur, name in shots:
        dst = WORK / ("%s.mp4" % name)
        ok = run(["-y", "-ss", "%.3f" % ss, "-t", "%.3f" % dur,
                  "-i", str(RAW / src),
                  "-vf", "fps=30,scale=%s:flags=lanczos,setsar=1" % args.scale,
                  "-c:v", "libx264", "-crf", "17", "-preset", "medium",
                  "-pix_fmt", "yuv420p",
                  "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
                  str(dst)], name)
        if not ok:
            return 1
        clips.append(dst)
        print("clip ok:", name, "%.1fs" % dur)

    lst = WORK / "list.txt"
    lst.write_text("".join("file '%s'\n" % str(c).replace("\\", "/") for c in clips),
                   encoding="utf-8")
    merged = WORK / "merged.mp4"
    if not run(["-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                "-c", "copy", str(merged)], "concat"):
        return 1
    print("concat ok")

    narr = RAW / NARR[args.lang]
    final = OUT / ("quackill_trailer_%s.mp4" % args.lang)
    # 实机音轨压到 0.55，旁白提到 1.9；旁白延迟 10 秒（引入段之后）
    fc = ("[0:a]volume=0.55[a0];"
          "[1:a]volume=1.9,adelay=10200|10200[a1];"
          "[a0][a1]amix=inputs=2:duration=first:normalize=0[aout]")
    ok = run(["-y", "-i", str(merged), "-i", str(narr),
              "-filter_complex", fc,
              "-map", "0:v", "-map", "[aout]",
              "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
              "-shortest", str(final)], "mix")
    if not ok:
        return 1
    print("FINAL:", final)
    print("size:", final.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
