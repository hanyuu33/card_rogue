# -*- coding: utf-8 -*-
"""第六版预告片：短引入 + 真实选牌/地图 + 元素连携实机。

python tools/trailer_build_v6.py --lang zh
python tools/trailer_build_v6.py --lang en

与 v5 的区别：不把「构筑牌组」贴在生成动画上；中英文各自使用对应界面的
Movie Maker 实机；旁白对准地图/选牌/战棋；最终音频限制真峰值。
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "release" / "trailer" / "raw"
WORK = ROOT / "release" / "trailer" / "work_v6"
OUT = ROOT / "release" / "trailer" / "out"
FF = Path(os.environ.get(
    "CARD_ROGUE_FFMPEG",
    r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages"
    r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe",
))
FOREST = "Cinematic_establishing_shot_of_2026-11-14T16-06-36.mp4"
DUCKS = "Dynamic_cinematic_action_shot__2026-11-14T17-43-06.mp4"
NARR = {
    "en": "Static_simple_dark_blue_studio_2026-11-14T17-48-18.mp4",
    "zh": "Static_simple_dark_blue_studio_2026-11-14T17-51-14.mp4",
}
CAPTIONS = {
    "en": {
        "run": "EVERY RUN, A NEW BATTLE",
        "deck": "BUILD YOUR DECK",
        "summon": "SUMMON · COPY · COMBO",
        "earth": "0-COST EARTH PRIMAL",
        "fire": "BURN THE WHOLE ROW",
        "victory": "WIN · LOOT · ADAPT",
        "wishlist": "QUACKILL  ·  WISHLIST ON STEAM",
    },
    "zh": {
        "run": "每一局，都是新的战局",
        "deck": "构筑你的牌组",
        "summon": "召唤 · 复制 · 连携铺场",
        "earth": "0 费土元素 · 连携入场",
        "fire": "火墙术 · 整行打击",
        "victory": "胜利 · 战利品 · 继续构筑",
        "wishlist": "嘎嘎乱杀  ·  加入 Steam 愿望单",
    },
}


def shots_for(lang):
    combo = "seg_element_combo_en.avi" if lang == "en" else "seg_element_combo.avi"
    shots = [
        (FOREST, 0.0, 2.0, "01_forest", "ai", ""),
        (DUCKS, 0.0, 2.5, "02_ducks", "ai", ""),
        ("seg_en.avi" if lang == "en" else "seg_manual2.avi",
         20.7 if lang == "en" else 90.0, 2.5, "03_map", "full", "run"),
        (combo if lang == "en" else "seg_manual2.avi",
         3.5 if lang == "en" else 363.5, 3.5, "04_deck", "full", "deck"),
        (combo, 8.0, 4.0, "05_rabbits", "full", "summon"),
        (combo, 15.0, 4.5, "06_earth", "full", "earth"),
        (combo, 22.0, 4.5, "07_fire", "full", "fire"),
    ]
    if lang == "zh":
        shots.append(("seg_manual2.avi", 360.0, 2.5, "08_victory", "full", "victory"))
    shots.append(("seg_test.avi", 4.3, 4.5, "09_title", "full", "wishlist"))
    return shots


def run(args, tag):
    r = subprocess.run([str(FF)] + args, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print("[FAIL]", tag)
        print((r.stderr or "")[-3000:])
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
    font = font_for(lang, 36 if lang == "en" else 38)
    box = d.textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    x = (1280 - tw) // 2
    d.rounded_rectangle((x - 28, 20, x + tw + 28, 20 + th + 28),
                        radius=15, fill=(10, 17, 22, 202),
                        outline=(222, 190, 112, 220), width=2)
    d.text((x, 33 - box[1]), text, font=font, fill=(250, 245, 224, 255))
    im.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", choices=["en", "zh"], required=True)
    args = ap.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    shots = shots_for(args.lang)
    for src, _ss, _dur, name, _mode, _cap in shots:
        if not (RAW / src).exists():
            raise FileNotFoundError(RAW / src)

    clips = []
    for idx, (src, ss, dur, name, mode, caption_key) in enumerate(shots):
        dst = WORK / ("%s_%s.mp4" % (name, args.lang))
        vf = ("crop=iw*0.84:ih*0.84:iw*0.08:ih*0.08," if mode == "ai" else "")
        vf += "fps=30,scale=1280:720:flags=lanczos,setsar=1"
        if idx == 0:
            vf += ",fade=t=in:st=0:d=0.25"
        if idx == len(shots) - 1:
            vf += ",fade=t=out:st=%.2f:d=0.5" % (dur - 0.5)
        frame_exact = src == "seg_manual2.avi"
        if frame_exact:
            # 这份 MJPEG AVI 的索引与时间戳都不可靠：直接按帧号取画面，
            # 音轨仍按秒截取；两边重置 PTS 后重新对齐。
            vf = "select='gte(n,%d)',setpts=PTS-STARTPTS," % int(round(ss * 30)) + vf
            cmd = ["-y", "-i", str(RAW / src)]
            audio_fc = "[0:a]atrim=start=%.3f:end=%.3f,asetpts=PTS-STARTPTS[a]" % (ss, ss + dur)
        else:
            cmd = ["-y", "-ss", "%.3f" % ss, "-t", "%.3f" % dur, "-i", str(RAW / src)]
            audio_fc = ""
        if caption_key:
            cap = WORK / ("v6_caption_%s_%s.png" % (caption_key, args.lang))
            make_caption(CAPTIONS[args.lang][caption_key], args.lang, cap)
            cmd += ["-loop", "1", "-i", str(cap)]
            fc = "[0:v]%s[v0];[v0][1:v]overlay=0:0:shortest=1[v]" % vf
            cmd += ["-filter_complex", fc + (";" + audio_fc if audio_fc else ""),
                    "-map", "[v]", "-map", "[a]" if audio_fc else "0:a?"]
        elif frame_exact:
            cmd += ["-filter_complex", "[0:v]%s[v];%s" % (vf, audio_fc),
                    "-map", "[v]", "-map", "[a]"]
        else:
            cmd += ["-vf", vf]
        cmd += ["-t", "%.3f" % dur, "-c:v", "libx264", "-crf", "17",
                "-preset", "medium", "-pix_fmt", "yuv420p",
                "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", str(dst)]
        if not run(cmd, name):
            return 1
        clips.append(dst)
        print("clip ok:", name, flush=True)

    lst = WORK / ("v6_list_%s.txt" % args.lang)
    lst.write_text("".join("file '%s'\n" % str(c).replace("\\", "/") for c in clips),
                   encoding="utf-8")
    merged = WORK / ("v6_merged_%s.mp4" % args.lang)
    if not run(["-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                "-c", "copy", str(merged)], "concat"):
        return 1

    # 三句旁白分别对准：选牌 8 秒、土元素/布阵 14.8 秒、地图 4.5 秒。
    if args.lang == "en":
        voice = [(0.0, 1.35, 8000), (2.0, 3.65, 14800), (4.3, 7.45, 4500)]
    else:
        voice = [(0.15, 1.95, 8300), (3.05, 5.10, 14800), (6.0, 9.55, 4500)]
    fc = ["[0:a]volume=0.45[a0]", "[2:a]volume=0.12[bg]"]
    labels = ["a0", "bg"]
    for i, (start, end, delay) in enumerate(voice):
        fc.append("[1:a]atrim=start=%.2f:end=%.2f,asetpts=PTS-STARTPTS,volume=1.5,adelay=%d|%d[v%d]"
                  % (start, end, delay, delay, i))
        labels.append("v%d" % i)
    fc.append("[%s]amix=inputs=%d:duration=first:normalize=0[mix]" %
              ("][".join(labels), len(labels)))
    fc.append("[mix]anull[aout]")
    premaster = WORK / ("v6_premaster_%s.mp4" % args.lang)
    if not run(["-y", "-i", str(merged), "-i", str(RAW / NARR[args.lang]),
                "-i", str(ROOT / "assets" / "audio" / "bgm" / "title.ogg"),
                "-filter_complex", ";".join(fc), "-map", "0:v", "-map", "[aout]",
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
                "-shortest", str(premaster)], "mix"):
        return 1

    # 真正的两遍 loudnorm：先量混合音轨，再按实测值线性归一。
    # 最后用略低于 -2 dBFS 的限制器给 AAC 真峰值留余量。
    probe = subprocess.run([str(FF), "-hide_banner", "-i", str(premaster),
                            "-af", "loudnorm=I=-16:TP=-2:LRA=11:print_format=json",
                            "-f", "null", "-"], capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
    matches = re.findall(r'\{\s*"input_i".*?\}', probe.stderr or "", re.S)
    if probe.returncode != 0 or not matches:
        print("[FAIL] loudness probe")
        print((probe.stderr or "")[-2400:])
        return 1
    measured = json.loads(matches[-1])
    master = ("loudnorm=I=-16:TP=-2:LRA=11"
              ":measured_I=%s:measured_TP=%s:measured_LRA=%s"
              ":measured_thresh=%s:offset=%s:linear=true"
              ",alimiter=limit=0.79:level=false" %
              (measured["input_i"], measured["input_tp"], measured["input_lra"],
               measured["input_thresh"], measured["target_offset"]))
    final = OUT / ("quackill_trailer_v6_%s.mp4" % args.lang)
    if not run(["-y", "-i", str(premaster), "-af", master,
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
                "-movflags", "+faststart", str(final)], "master"):
        return 1
    print("FINAL:", final)
    print("size:", final.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
