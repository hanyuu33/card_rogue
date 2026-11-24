# -*- coding: utf-8 -*-
"""第七版预告片：换掉旧伤害数字素材后的英文/中文实机镜头。

python tools/trailer_build_v7.py --lang en
python tools/trailer_build_v7.py --lang zh

与 v6 的区别：
  1. 实机段落全部改用新录的素材（伤害数字已换素材）；
  2. **不再收胜利界面** —— 那张结算页的按钮与实机不一致，店长点名不要；
  3. 英文本体用 `--trailer-clean` 录的干净素材（战斗层中文说明不显示），
     但伤害数字照常出现。
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
WORK = ROOT / "release" / "trailer" / "work_v7"
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
        "summon": "SUMMON · COPY · COMBO",
        "earth": "0-COST EARTH PRIMAL",
        "combat": "STRIKE · TRADE · SURVIVE",
        "wishlist": "QUACKILL  ·  WISHLIST ON STEAM",
    },
    "zh": {
        "run": "每一局，都是新的战局",
        "summon": "召唤 · 复制 · 连携铺场",
        "earth": "0 费土元素 · 连携入场",
        "combat": "交锋 · 换血 · 站住场",
        "wishlist": "嘎嘎乱杀  ·  加入 Steam 愿望单",
    },
}
# 实机素材：换成新录的、带新伤害数字的镜头。
PLAY = {
    "en": "seg_manual_loadout_20261117_en_clean_v5.avi",
    "zh": "seg_element_combo_zh_clean.avi",
}
MAP = {"en": "seg_en.avi", "zh": "seg_manual2.avi"}
TITLE = {"en": "seg_title_en_20261117.avi", "zh": "seg_title_zh_20261117.avi"}


def shots_for(lang):
    play = PLAY[lang]
    if lang == "en":
        deploy, earth, comb1, comb2 = 12.0, 18.0, 26.0, 38.5
    else:
        # 中文素材里连携铺场大约在 20~40 秒之间，逐段取。
        deploy, earth, comb1, comb2 = 9.0, 15.0, 19.0, 23.0
    # ⚠️ 不收地图镜头：老 `seg_en.avi` 的图层名 / 左侧工具栏仍是中文，
    #    新截的图又几乎全是迷雾云朵 —— 两个都不适合当宣传画面，干脆不剪进去。
    # ⚠️ 不收胜利界面：那张结算页的按钮与实机不一致（店长点名不要）。
    return [
        (FOREST, 0.0, 2.0, "01_forest", "ai", ""),
        (DUCKS, 0.0, 2.5, "02_ducks", "ai", ""),
        (play, deploy, 3.5, "03_summon", "full", "summon"),
        (play, earth, 4.0, "04_earth", "full", "earth"),
        (play, comb1, 4.0, "05_combat", "full", "combat"),
        (play, comb2, 4.0, "06_combat2", "full", ""),
        (TITLE[lang], 0.6, 4.5, "07_wishlist", "full", "wishlist"),
    ]


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
        # MJPEG AVI（Godot Movie Maker）的索引不可靠 → 一律按帧号定位画面，
        # 音轨按秒截取，两边重置 PTS 后对齐。
        frame_exact = src.endswith(".avi")
        if frame_exact:
            vf = "select='gte(n,%d)',setpts=PTS-STARTPTS," % int(round(ss * 30)) + vf
            cmd = ["-y", "-i", str(RAW / src)]
            audio_fc = "[0:a]atrim=start=%.3f:end=%.3f,asetpts=PTS-STARTPTS[a]" % (ss, ss + dur)
        else:
            cmd = ["-y", "-ss", "%.3f" % ss, "-t", "%.3f" % dur, "-i", str(RAW / src)]
            audio_fc = ""
        if caption_key:
            cap = WORK / ("v7_caption_%s_%s.png" % (caption_key, args.lang))
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

    lst = WORK / ("v7_list_%s.txt" % args.lang)
    lst.write_text("".join("file '%s'\n" % str(c).replace("\\", "/") for c in clips),
                   encoding="utf-8")
    merged = WORK / ("v7_merged_%s.mp4" % args.lang)
    if not run(["-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                "-c", "copy", str(merged)], "concat"):
        return 1

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
    premaster = WORK / ("v7_premaster_%s.mp4" % args.lang)
    if not run(["-y", "-i", str(merged), "-i", str(RAW / NARR[args.lang]),
                "-i", str(ROOT / "assets" / "audio" / "bgm" / "title.ogg"),
                "-filter_complex", ";".join(fc), "-map", "0:v", "-map", "[aout]",
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
                "-shortest", str(premaster)], "mix"):
        return 1

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
    final = OUT / ("quackill_trailer_v7_%s.mp4" % args.lang)
    if not run(["-y", "-i", str(premaster), "-af", master,
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
                "-movflags", "+faststart", str(final)], "master"):
        return 1
    print("FINAL:", final)
    print("size:", final.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
