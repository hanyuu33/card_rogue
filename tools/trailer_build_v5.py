# -*- coding: utf-8 -*-
"""第五版预告片：动作引入 + 正常实机 + 肉鸽卡牌/战棋卖点字卡。"""
import argparse
import os
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "release" / "trailer" / "raw"
WORK = ROOT / "release" / "trailer" / "work_v5"
OUT = ROOT / "release" / "trailer" / "out"
FF = Path(os.environ.get(
    "CARD_ROGUE_FFMPEG",
    r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages"
    r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe",
))

FOREST = "Cinematic_establishing_shot_of_2026-11-14T16-06-36.mp4"
DUCKS = "Dynamic_cinematic_action_shot__2026-11-14T17-43-06.mp4"
ROGUE = "A_nimble_anime_shadow_assassin_2026-11-14T17-45-28.mp4"
MANUAL = "seg_manual2.avi"
NARR = {
    "en": "Static_simple_dark_blue_studio_2026-11-14T17-48-18.mp4",
    "zh": "Static_simple_dark_blue_studio_2026-11-14T17-51-14.mp4",
}

# 秒数区间均来自抽帧验收；AI 镜头统一裁 8% 四边去水印。
SHOTS = [
    (FOREST, 0.0, 3.0, "i1_forest", "ai", ""),
    (DUCKS, 0.0, 4.0, "i2_ducks", "ai", "deck"),
    (ROGUE, 0.0, 4.0, "i3_rogue", "ai", ""),
    ("MAP", 0.0, 3.0, "s1_map", "full", "run"),
    (MANUAL, 108.0, 5.0, "s2_summon", "battle", "summon"),
    (MANUAL, 114.0, 4.0, "s3_place", "battle", ""),
    (MANUAL, 544.0, 6.0, "s4_grid", "battle", "grid"),
    (MANUAL, 554.0, 5.0, "s5_clash", "battle", ""),
    (MANUAL, 358.0, 3.0, "s6_victory", "battle", ""),
    ("TITLE", 0.0, 4.0, "s7_title", "full", "wishlist"),
]

CAPTIONS = {
    "en": {
        "deck": "BUILD YOUR DECK",
        "run": "EVERY RUN, A NEW BATTLE",
        "summon": "SUMMON ALLIES",
        "grid": "COMMAND THE GRID",
        "wishlist": "QUACKILL  ·  WISHLIST ON STEAM",
    },
    "zh": {
        "deck": "构筑你的牌组",
        "run": "每一局，都是新的战局",
        "summon": "召唤盟友 · 出牌布阵",
        "grid": "掌控每一步走位",
        "wishlist": "嘎嘎乱杀  ·  加入 Steam 愿望单",
    },
}


def run(args, tag):
    r = subprocess.run([str(FF)] + args, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print("[FAIL]", tag)
        print((r.stderr or "")[-2400:])
        return False
    return True


def font_for(lang, size):
    candidates = [
        r"C:\Windows\Fonts\msyh.ttc" if lang == "zh" else r"C:\Windows\Fonts\arialbd.ttf",
        r"C:\Windows\Fonts\arial.ttf",
    ]
    for f in candidates:
        if Path(f).exists():
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def make_caption(text, lang, path):
    im = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    font = font_for(lang, 38 if lang == "en" else 40)
    box = d.textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    x = (1280 - tw) // 2
    d.rounded_rectangle((x - 30, 22, x + tw + 30, 22 + th + 30),
                        radius=16, fill=(10, 17, 22, 196),
                        outline=(222, 190, 112, 210), width=2)
    d.text((x, 36 - box[1]), text, font=font, fill=(250, 245, 224, 255))
    im.save(path)


def source_for(key, lang):
    if key == "MAP":
        return ("seg_en.avi", 20.7) if lang == "en" else (MANUAL, 55.0)
    if key == "TITLE":
        return "seg_test.avi", 4.3
    return key, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", choices=["en", "zh"], required=True)
    args = ap.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    clips = []
    for raw_key, ss, dur, name, mode, caption_key in SHOTS:
        src, override_ss = source_for(raw_key, args.lang)
        if override_ss is not None:
            ss = override_ss
        dst = WORK / ("%s_%s.mp4" % (name, args.lang))
        if mode == "ai":
            vf = "crop=iw*0.84:ih*0.84:iw*0.08:ih*0.08,fps=30,scale=1280:720:flags=lanczos,setsar=1"
        elif mode == "battle" and args.lang == "en":
            vf = "crop=960:540:160:90,fps=30,scale=1280:720:flags=lanczos,setsar=1"
        else:
            vf = "fps=30,scale=1280:720:flags=lanczos,setsar=1"
        cmd = ["-y", "-ss", "%.3f" % ss, "-t", "%.3f" % dur, "-i", str(RAW / src)]
        if caption_key:
            cap = WORK / ("caption_%s_%s.png" % (caption_key, args.lang))
            make_caption(CAPTIONS[args.lang][caption_key], args.lang, cap)
            cmd += ["-loop", "1", "-i", str(cap),
                    "-filter_complex", "[0:v]%s[v0];[v0][1:v]overlay=0:0:shortest=1[v]" % vf,
                    "-map", "[v]", "-map", "0:a?"]
        else:
            cmd += ["-vf", vf]
        cmd += ["-t", "%.3f" % dur, "-c:v", "libx264", "-crf", "17",
                "-preset", "medium", "-pix_fmt", "yuv420p",
                "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", str(dst)]
        if not run(cmd, name):
            return 1
        clips.append(dst)
        print("clip ok:", name)

    lst = WORK / ("list_%s.txt" % args.lang)
    lst.write_text("".join("file '%s'\n" % str(c).replace("\\", "/") for c in clips),
                   encoding="utf-8")
    merged = WORK / ("merged_%s.mp4" % args.lang)
    if not run(["-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                "-c", "copy", str(merged)], "concat"):
        return 1

    narr = RAW / NARR[args.lang]
    bgm = ROOT / "assets" / "audio" / "bgm" / "title.ogg"
    final = OUT / ("quackill_trailer_%s.mp4" % args.lang)
    if args.lang == "en":
        cuts = [(0.0, 1.35, 3200), (2.0, 3.65, 14000), (4.3, 7.45, 27000)]
    else:
        cuts = [(0.15, 1.95, 3200), (3.05, 5.10, 14000), (6.0, 9.55, 27000)]
    fc = ["[0:a]volume=0.72[a0]", "[2:a]volume=0.16[bg]"]
    labels = ["a0", "bg"]
    for i, (start, end, delay) in enumerate(cuts):
        fc.append("[1:a]atrim=start=%.2f:end=%.2f,asetpts=PTS-STARTPTS,volume=1.8,adelay=%d|%d[v%d]"
                  % (start, end, delay, delay, i))
        labels.append("v%d" % i)
    fc.append("[%s]amix=inputs=%d:duration=first:normalize=0[aout]" % ("][".join(labels), len(labels)))
    if not run(["-y", "-i", str(merged), "-i", str(narr), "-i", str(bgm),
                "-filter_complex", ";".join(fc), "-map", "0:v", "-map", "[aout]",
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", str(final)], "mix"):
        return 1
    print("FINAL:", final)
    print("size:", final.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
