# -*- coding: utf-8 -*-
"""第十版预告片：森林空镜开场 + 角色动作段 + 实机玩法 + 标题收尾，全片 25.4s。

相对 v9 的改动：
  1. **去掉机械之心、森林精魄两段角色动画**（店长判定「像在 CG 上硬做的动画」，
     不要了）；
  2. **开场换成森林空镜**（v8 用过的那条 `Cinematic_establishing_shot_of_*`），
     2.2s 缓慢淡入，给人声留出 1.2s 的空气；
  3. 角色段缩到 5 段：森林空镜 → 骑士快放 → 弓手放箭 → 刺客跑位 → 诗人 → 风元素；
  4. 旁白与字幕按新段落重排（句1 落森林尾/骑士头，句2 落弓手尾/刺客头，
     句3 横跨诗人与风元素）；旁白边界按 silencedetect 实测值收；
  5. 前置段静音轨、delogo/crop 去水印、BGM battle_elite 铺底、结尾 CTA 全部沿用 v9。

用法：
    python tools/trailer_build_v10.py --lang zh
    python tools/trailer_build_v10.py --lang en
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
CG = RAW / "cg"
WORK = ROOT / "release" / "trailer" / "work_v13"
OUT = ROOT / "release" / "trailer" / "out"
FF = Path(os.environ.get(
    "CARD_ROGUE_FFMPEG",
    r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages"
    r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe",
))
BGM = {
    "battle_elite": ROOT / "assets" / "audio" / "bgm" / "battle_elite.ogg",
    "title": ROOT / "assets" / "audio" / "bgm" / "title.ogg",
}
NARR = {
    "en": "Static_simple_dark_blue_studio_2026-11-14T17-48-18.mp4",
    "zh": "Static_simple_dark_blue_studio_2026-11-14T17-51-14.mp4",
}
PLAY = {
    "en": "seg_manual_loadout_20261117_en_clean_v5.avi",
    "zh": "seg_element_combo_zh_clean.avi",
}
TITLE = {"en": "seg_title_en_20261117.avi", "zh": "seg_title_zh_20261117.avi"}

# 水印精确包围盒（以 1344x768 为基准，按源分辨率等比缩放）
LOGO_TL_BASE = (5, 3, 94, 50)
LOGO_BR_BASE = (1248, 713, 94, 53)

# (子目录, 源文件, 源起点, 源时长, 速度, 成片时长, 名称, 去水印方式)
# 顺序即成片顺序；成片时长 = 源时长 / 速度，用于给字幕和混音排时间轴。
# sub 为空字符串表示素材在 raw 根目录。
CHAR_SHOTS = [
    ("", "Cinematic_establishing_shot_of_2026-11-14T16-06-36.mp4",
     0.30, 2.20, 1.0, 2.20, "00_forest", "crop"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-44-45.mp4",
     0.55, 3.00, 2.0, 1.50, "01_knight", "delogo"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-47-11.mp4",
     2.30, 1.50, 1.0, 1.50, "02_archer", "delogo"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T11-37-06.mp4",
     0.60, 2.40, 1.0, 2.40, "03_rogue", "delogo"),
    ("ref2", "2D_anime_cel_shaded_animation__2026-11-17T12-02-25.mp4",
     2.60, 1.40, 1.0, 1.40, "06_bard", "delogo"),
    ("ref", "2D_anime_cel_shaded_animation__2026-11-17T11-12-47.mp4",
     0.45, 1.60, 1.0, 1.60, "07_wind", "delogo"),
]

# 前置段落里的字幕窗口（成片秒）。段落边界：
#   0.00-2.20 森林空镜 / 2.20-3.70 骑士 / 3.70-5.20 弓手
#   5.20-7.60 刺客 / 7.60-9.00 诗人 / 9.00-10.60 风元素
SUBS = {
    "zh": [
        ("构筑你的牌组", 1.15, 2.12),
        ("掌控每一步走位", 3.95, 5.18),
        ("每一局 · 都是新的战局", 7.58, 10.16),
    ],
    "en": [
        ("BUILD YOUR DECK", 1.15, 2.22),
        ("COMMAND THE GRID", 3.95, 5.22),
        ("EVERY RUN · A NEW BATTLE", 7.54, 10.06),
    ],
}
CTA = {
    "en": "QUACKILL  ·  WISHLIST ON STEAM",
    "zh": "嘎嘎乱杀  ·  加入 Steam 愿望单",
}
# 旁白分句：(源起, 源止, 成片落点秒)。边界按 silencedetect 实测值各放宽 ~0.03s。
VOICE = {
    "zh": [(0.66, 1.85, 1.20), (3.52, 4.97, 3.90), (6.50, 9.50, 7.58)],
    "en": [(0.25, 1.17, 1.20), (2.25, 3.43, 3.90), (4.78, 7.39, 7.54)],
}


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


def probe(path):
    p = subprocess.run([str(FF).replace("ffmpeg.exe", "ffprobe.exe"),
                        "-v", "error", "-select_streams", "v:0",
                        "-show_entries", "stream=width,height", "-of", "csv=p=0",
                        str(path)], capture_output=True, text=True)
    w, h = p.stdout.strip().split(",")[:2]
    return int(w), int(h)


def build_char_vf(w, h, out_dur, speed, fi, fo, mode="delogo"):
    if mode == "crop":
        # 空镜类素材：直接裁掉四周 8%（水印在角上），等比放回 1280x720
        vf = "crop=iw*0.84:ih*0.84:iw*0.08:ih*0.08,scale=1280:720,setsar=1,"
    else:
        sx, sy = w / 1344.0, h / 768.0
        tl = "delogo=x=%d:y=%d:w=%d:h=%d" % tuple(
            int(round(v * s)) for v, s in zip(LOGO_TL_BASE, (sx, sy, sx, sy)))
        br = "delogo=x=%d:y=%d:w=%d:h=%d" % tuple(
            int(round(v * s)) for v, s in zip(LOGO_BR_BASE, (sx, sy, sx, sy)))
        if w / h > 16 / 9:
            cw = int(round(h * 16 / 9))
            ch, cx, cy = h, (w - cw) // 2, 0
        else:
            cw = w
            ch = int(round(w * 9 / 16 / 2)) * 2
            cx, cy = 0, (h - ch) // 2
        vf = ("%s,%s,crop=%d:%d:%d:%d,scale=1280:720,setsar=1,"
              % (tl, br, cw, ch, cx, cy))
    if speed != 1.0:
        vf += "setpts=%.6f*PTS," % (1.0 / speed)
    vf += "fps=30,"
    if fi > 0:
        vf += "fade=t=in:st=0:d=%.2f," % fi
    if fo > 0:
        vf += "fade=t=out:st=%.2f:d=%.2f," % (out_dur - fo, fo)
    vf += "format=yuv420p"
    return vf


def build_chars(lang):
    clips = []
    total = sum(s[5] for s in CHAR_SHOTS)
    for i, (sub, fname, ss, sdur, speed, odur, name, mode) in enumerate(CHAR_SHOTS):
        # sub 为空 = raw 根目录（森林空镜）；否则走 cg/<sub>/（角色素材）
        src = (RAW / fname) if not sub else (CG / sub / fname)
        if not src.exists():
            raise FileNotFoundError(src)
        w, h = probe(src)
        # 中间段硬切（0.1s 淡变叠在素材暗帧上会闪黑 3 帧）；只首尾做淡入淡出。
        if i == 0:
            fi = 0.50 if mode == "crop" else 0.30
        else:
            fi = 0.0
        fo = 0.30 if i == len(CHAR_SHOTS) - 1 else 0.0
        vf = build_char_vf(w, h, odur, speed, fi, fo, mode)
        dst = WORK / ("%s_%s.mp4" % (name, lang))
        # 前置段无声：垫一条静音轨，保证与实机段 concat 时音轨对齐
        ok = run(["-y", "-hide_banner", "-loglevel", "error",
                  "-ss", "%.3f" % ss, "-t", "%.3f" % sdur, "-i", str(src),
                  "-f", "lavfi", "-t", "%.3f" % odur,
                  "-i", "anullsrc=r=48000:cl=stereo",
                  "-filter_complex", "[0:v]%s[v]" % vf,
                  "-map", "[v]", "-map", "1:a",
                  "-t", "%.3f" % odur,
                  "-c:v", "libx264", "-crf", "17", "-preset", "medium",
                  "-pix_fmt", "yuv420p",
                  "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
                  str(dst)], "char:%s" % name)
        if not ok:
            raise RuntimeError(name)
        clips.append(dst)
        print("char ok:", name, flush=True)

    lst = WORK / ("chars_list_%s.txt" % lang)
    lst.write_text("".join("file '%s'\n" % str(c).replace("\\", "/") for c in clips),
                   encoding="utf-8")
    merged = WORK / ("chars_%s.mp4" % lang)
    if not run(["-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                "-c", "copy", str(merged)], "chars concat"):
        raise RuntimeError("concat")
    return merged, total


def burn_subs(src, lang, dur):
    """把三句字幕叠到前置段上，带 0.2s alpha 淡变。"""
    ins, fc, prev = [], [], "0:v"
    for i, (text, t0, t1) in enumerate(SUBS[lang]):
        png = WORK / ("sub_%s_%d.png" % (lang, i))
        make_caption(text, lang, png)
        ins += ["-loop", "1", "-t", "%.3f" % dur, "-i", str(png)]
        idx = i + 1
        fc.append("[%d:v]format=rgba,fade=t=in:st=%.2f:d=0.20:alpha=1,"
                  "fade=t=out:st=%.2f:d=0.20:alpha=1[s%d]"
                  % (idx, t0, t1 - 0.20, i))
        fc.append("[%s][s%d]overlay=0:0:enable='between(t,%.2f,%.2f)'[v%d]"
                  % (prev, i, t0, t1, i))
        prev = "v%d" % i
    dst = WORK / ("chars_sub_%s.mp4" % lang)
    ok = run(["-y", "-hide_banner", "-loglevel", "error", "-i", str(src)] + ins +
             ["-filter_complex", ";".join(fc),
              "-map", "[%s]" % prev, "-map", "0:a",
              "-c:v", "libx264", "-crf", "17", "-preset", "medium",
              "-pix_fmt", "yuv420p",
              "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
              "-t", "%.3f" % dur, str(dst)], "subs:%s" % lang)
    if not ok:
        raise RuntimeError("subs")
    return dst


def build_shot(src, ss, dur, name, lang, mode="", caption_key="", fade_in=False,
               fade_out=False):
    dst = WORK / ("%s_%s.mp4" % (name, lang))
    vf = ("crop=iw*0.84:ih*0.84:iw*0.08:ih*0.08," if mode == "ai" else "")
    vf += "fps=30,scale=1280:720:flags=lanczos,setsar=1"
    if fade_in:
        vf += ",fade=t=in:st=0:d=0.25"
    if fade_out:
        vf += ",fade=t=out:st=%.2f:d=0.5" % (dur - 0.5)

    src_path = Path(src) if os.path.isabs(str(src)) else (RAW / src)
    frame_exact = str(src).endswith(".avi")
    if frame_exact:
        vf = "select='gte(n,%d)',setpts=PTS-STARTPTS," % int(round(ss * 30)) + vf
        cmd = ["-y", "-i", str(src_path)]
        audio_fc = "[0:a]atrim=start=%.3f:end=%.3f,asetpts=PTS-STARTPTS[a]" % (
            ss, ss + dur)
    else:
        cmd = ["-y", "-ss", "%.3f" % ss, "-t", "%.3f" % dur, "-i", str(src_path)]
        audio_fc = ""

    if caption_key:
        cap = WORK / ("cta_%s_%s.png" % (caption_key, lang))
        make_caption(CTA[lang], lang, cap)
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
        raise RuntimeError(name)
    return dst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", choices=["en", "zh"], required=True)
    ap.add_argument("--bgm", default="battle_elite", choices=list(BGM))
    args = ap.parse_args()
    lang = args.lang
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    # ---- 1. 前置段：森林空镜 + 角色动作 ----
    chars, char_dur = build_chars(lang)
    chars = burn_subs(chars, lang, char_dur)
    print("chars done: %.2fs" % char_dur, flush=True)

    # ---- 2. 实机段 ----
    play = PLAY[lang]
    if lang == "en":
        deploy, earth, comb1, comb2 = 12.0, 18.0, 26.0, 38.5
    else:
        deploy, earth, comb1, comb2 = 9.0, 15.0, 19.0, 23.0
    clips = [chars]
    clips.append(build_shot(play, deploy, 3.0, "08_summon", lang))
    clips.append(build_shot(play, earth, 3.0, "09_earth", lang))
    clips.append(build_shot(play, comb1, 3.0, "10_combat", lang))
    clips.append(build_shot(play, comb2, 2.6, "11_combat2", lang))
    clips.append(build_shot(TITLE[lang], 0.05, 3.2, "12_wishlist", lang,
                            caption_key="wishlist", fade_out=True))
    for c in clips[1:]:
        print("shot ok:", c.name, flush=True)

    # ⚠️ 不能用 concat demuxer 的 -c copy：前置段的 start_time 带 0.067s 偏移，
    #    拼完时间戳不连续，播放器与 fps 滤镜都会错位（实机段被提前抽到）。
    #    这里改用 concat filter 重编码一次，时间轴绝对连续。
    ins = []
    for c in clips:
        ins += ["-i", str(c)]
    n = len(clips)
    cfc = "".join("[%d:v][%d:a]" % (i, i) for i in range(n))
    cfc += "concat=n=%d:v=1:a=1[v][a]" % n
    merged = WORK / ("v10_merged_%s.mp4" % lang)
    if not run(["-y"] + ins + [
            "-filter_complex", cfc, "-map", "[v]", "-map", "[a]",
            "-c:v", "libx264", "-crf", "17", "-preset", "medium",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
            str(merged)], "concat"):
        return 1

    total = char_dur + 3.0 + 3.0 + 3.0 + 2.6 + 3.2
    print("total: %.2fs" % total, flush=True)

    # ---- 3. 混音：实机原声 + 旁白分句 + BGM ----
    fc = ["[0:a]volume=0.55[a0]"]
    labels = ["a0"]
    for i, (s0, s1, at) in enumerate(VOICE[lang]):
        fc.append("[1:a]atrim=start=%.2f:end=%.2f,asetpts=PTS-STARTPTS,"
                  "volume=1.6,adelay=%d|%d[v%d]"
                  % (s0, s1, int(at * 1000), int(at * 1000), i))
        labels.append("v%d" % i)
    fc.append("[2:a]atrim=start=0:end=%.2f,volume=0.16,"
              "afade=t=in:st=0:d=1.0,afade=t=out:st=%.2f:d=1.4[bg]"
              % (total, total - 1.4))
    labels.append("bg")
    fc.append("[%s]amix=inputs=%d:duration=first:normalize=0[mix]"
              % ("][".join(labels), len(labels)))
    fc.append("[mix]alimiter=limit=0.95:level=false[aout]")
    premaster = WORK / ("v10_premaster_%s.mp4" % lang)
    if not run(["-y", "-i", str(merged), "-i", str(RAW / NARR[lang]),
                "-i", str(BGM[args.bgm]),
                "-filter_complex", ";".join(fc),
                "-map", "0:v", "-map", "[aout]",
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
                "-shortest", str(premaster)], "mix"):
        return 1

    # ---- 4. 响度归一 ----
    probe_out = subprocess.run([str(FF), "-hide_banner", "-i", str(premaster),
                                "-af", "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json",
                                "-f", "null", "-"], capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
    matches = re.findall(r'\{\s*"input_i".*?\}', probe_out.stderr or "", re.S)
    if probe_out.returncode != 0 or not matches:
        print("[FAIL] loudness probe")
        print((probe_out.stderr or "")[-2400:])
        return 1
    m = json.loads(matches[-1])
    master = ("loudnorm=I=-16:TP=-1.5:LRA=11"
              ":measured_I=%s:measured_TP=%s:measured_LRA=%s"
              ":measured_thresh=%s:offset=%s:linear=true"
              ",alimiter=limit=0.84:level=false" %
              (m["input_i"], m["input_tp"], m["input_lra"],
               m["input_thresh"], m["target_offset"]))
    final = OUT / ("quackill_trailer_v10_%s.mp4" % lang)
    if not run(["-y", "-i", str(premaster), "-af", master,
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
                "-movflags", "+faststart", str(final)], "master"):
        return 1
    print("FINAL:", final)
    print("size:", final.stat().st_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
