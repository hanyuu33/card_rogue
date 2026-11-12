# -*- coding: utf-8 -*-
"""R606 候选实机预览：把每张候选铺成 1920×1080 塞进 assets/ui/title_art.png，
跑一次标题页截图，再还原原图。

为什么必须看实机：标题页的按钮列压在画面中段（约 36%~70% 高），
而这两版候选的字都排在 14%~63%，字会不会被按钮盖住，只有跑起来才知道。
"""
import os
import shutil
import subprocess
import sys

from PIL import Image

ROOT = r"E:\work\card_rogue"
RAW = os.path.join(ROOT, "art_src", "2026-11-12_开场与标题_R604", "raw")
UI = os.path.join(ROOT, "assets", "ui", "title_art.png")
BAK = os.path.join(ROOT, "_review", "r605_title_art_backup.png")
GODOT = os.path.expanduser(
    r"~\.workbuddy\binaries\godot\Godot_v4.3-stable_win64_console.exe")
W, H = 1920, 1080

CANDS = [
    ("9011", "9011_标题字鸭嘴版_v1.png"),
    ("9012", "9012_标题字木牌版_v1.png"),
]


def fit_cover(src, w, h):
    im = Image.open(src).convert("RGB")
    s = max(w / im.width, h / im.height)
    im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    left = (im.width - w) // 2
    top = (im.height - h) // 2
    return im.crop((left, top, left + w, top + h))


def main():
    if not os.path.exists(BAK):
        shutil.copyfile(UI, BAK)
        print("backup ->", BAK)
    for cid, fname in CANDS:
        src = os.path.join(RAW, fname)
        if not os.path.exists(src):
            print("MISS", fname)
            continue
        fit_cover(src, W, H).save(UI, optimize=True)
        out = os.path.join(ROOT, "_review", "r606_title_%s.png" % cid)
        r = subprocess.run([GODOT, "--path", ROOT, "--script",
                            "res://tools/_shot_title_r603.gd"],
                           capture_output=True, text=True)
        shot = os.path.join(ROOT, "_review", "r603_title.png")
        if "TITLE OK" in r.stdout and os.path.exists(shot):
            shutil.copyfile(shot, out)
            print("SHOT", cid, "->", os.path.basename(out))
        else:
            print("FAIL", cid, r.stdout[-300:], r.stderr[-300:])
    shutil.copyfile(BAK, UI)
    print("restored assets/ui/title_art.png")


if __name__ == "__main__":
    main()
