# -*- coding: utf-8 -*-
"""R801：爆炸蘑菇 7016 图标 —— 抠图 + 44px 验收图。"""
import hashlib
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
SRC = "E:/tmp/_art_wip_r801/"
RAW = SRC + "A_cute_hand_drawn_cartoon_game_2026-11-18T12-02-44.png"
OUT = "assets/ui/trap_icon_7016.png"
WATCH = ["assets/ui/trap_icon_7012.png", "assets/ui/ui_tool_swap.png"]


def md5(p):
    return hashlib.md5(open(ROOT + p, "rb").read()).hexdigest()


before = {p: md5(p) for p in WATCH}
sys.path.insert(0, ROOT + "tools")
import _make_r755_icons as R755   # noqa: E402  （import 时会重写两张旧图）
for p in WATCH:
    if md5(p) != before[p]:
        subprocess.run(["git", "checkout", "--", p], cwd=ROOT, check=True)
        print("restored", p)
R755.ROOT = ROOT

from PIL import Image, ImageDraw   # noqa: E402

im = Image.open(RAW).convert("RGB")
w, h = im.size
d = ImageDraw.Draw(im)
d.rectangle([int(w * 0.86), int(h * 0.93), w, h], fill=(255, 255, 255))
tmp = SRC + "_clean_7016.png"
im.save(tmp)
R755.cut(tmp, OUT, pad_pct=0.07)

# ---- 透明校验 ----
ic = Image.open(ROOT + OUT).convert("RGBA")
a = ic.split()[3]
print("size", ic.size, "alpha min/max", a.getextrema(), "corner", ic.getpixel((0, 0)),
      "center", ic.getpixel((64, 64)))

# ---- 44px 对照（垫游戏面板色）----
icons = ["assets/ui/trap_icon_7001.png", "assets/ui/trap_icon_7004.png",
         "assets/ui/trap_icon_7012.png", "assets/ui/trap_icon_7015.png",
         "assets/ui/trap_icon_7016.png"]
cell, gap = 44, 12
sheet = Image.new("RGBA", (len(icons) * (cell + gap) + gap, cell + 2 * gap), (44, 38, 32, 255))
for i, rel in enumerate(icons):
    s = Image.open(ROOT + rel).convert("RGBA").resize((cell, cell), Image.LANCZOS)
    sheet.alpha_composite(s, (gap + i * (cell + gap), gap))
# 2x 放大版（88px）单独一张，方便肉眼看
big = Image.new("RGBA", (len(icons) * (88 + 16) + 16, 88 + 32), (44, 38, 32, 255))
for i, rel in enumerate(icons):
    s = Image.open(ROOT + rel).convert("RGBA").resize((88, 88), Image.LANCZOS)
    big.alpha_composite(s, (16 + i * (88 + 16), 16))
stage = "art_src/2026-11-18_爆炸蘑菇_R801/"
os.makedirs(ROOT + stage + "raw", exist_ok=True)
os.makedirs(ROOT + stage + "processed", exist_ok=True)
sheet.save(ROOT + stage + "processed/_preview_44px.png")
big.save(ROOT + stage + "processed/_preview_88px.png")
print("preview ok")
