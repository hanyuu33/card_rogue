# -*- coding: utf-8 -*-
"""R797b：6077 钻头 / 6078 龟壳 / 7015 河豚 图标对照页。
原图 128 放在棋盘格上（验透明），实际尺寸 44 / 88 放在游戏面板色上（验观感）。
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = "E:/work/card_rogue"
OUT = ROOT + "/art_src/2026-11-18_钻头重做与河豚_R797/_preview_icons_r797.png"

ITEMS = [
    ("6077", "钻头", "道具 · 一般 · 已重做", "relic_icon_6077.png"),
    ("6078", "龟壳", "道具 · 一般 · 新增", "relic_icon_6078.png"),
    ("7015", "河豚", "工具 · 25 金 · 新增", "trap_icon_7015.png"),
]

BG = (26, 23, 20)
PANEL = (44, 38, 33)
CELL_BG = (28, 25, 22)      # 游戏内深色面板
CHECK_A = (58, 52, 46)
CHECK_B = (44, 39, 34)
LINE = (92, 78, 64)
TXT = (238, 228, 212)
DIM = (156, 138, 118)
ACCENT = (232, 186, 108)

COL_W = 250
PAD = 26
TOP_H = 96
TITLE_H = 104
BIG = 128
SY = 26          # 原图 → 小图 间距
SMALL = 88
LBL = 34
BOT = 30

W = PAD * 2 + COL_W * len(ITEMS)
H = TOP_H + TITLE_H + BIG + SY + SMALL + LBL + BOT


def font(sz, bold=False):
    for p in ("C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc",
              "C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/simhei.ttf"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, sz)
            except Exception:
                pass
    return ImageFont.load_default()


F_T = font(26, True)
F_S = font(19)
F_M = font(15)
F_XS = font(13)

img = Image.new("RGBA", (W, H), BG)
d = ImageDraw.Draw(img)


def checker(box, step=16):
    x0, y0, x1, y1 = box
    for yy in range(y0, y1, step):
        for xx in range(x0, x1, step):
            c = CHECK_A if ((xx - x0) // step + (yy - y0) // step) % 2 == 0 else CHECK_B
            d.rectangle([xx, yy, min(xx + step - 1, x1 - 1), min(yy + step - 1, y1 - 1)], fill=c)


d.text((PAD, 26), "R797 新道具图标对照", font=F_T, fill=TXT)
d.text((PAD, 58), "上排：原图 128×128（棋盘格＝透明区域）", font=F_M, fill=DIM)
d.text((PAD, 78), "下排：游戏内实际尺寸 44px / 88px（垫游戏面板色 #2c2620）", font=F_M, fill=DIM)
d.line([(PAD, TOP_H - 10), (W - PAD, TOP_H - 10)], fill=LINE, width=1)

for i, (rid, name, sub, fn) in enumerate(ITEMS):
    x0 = PAD + i * COL_W
    cx = x0 + COL_W // 2

    d.rounded_rectangle([x0 + 6, TOP_H + 2, x0 + COL_W - 6, H - BOT + 6],
                        radius=10, fill=PANEL, outline=LINE, width=1)

    d.text((cx, TOP_H + 26), name, font=F_T, fill=ACCENT, anchor="mm")
    d.text((cx, TOP_H + 56), "#" + rid, font=F_S, fill=TXT, anchor="mm")
    d.text((cx, TOP_H + 80), sub, font=F_XS, fill=DIM, anchor="mm")

    src = Image.open(ROOT + "/assets/ui/" + fn).convert("RGBA")

    by = TOP_H + TITLE_H
    checker((cx - BIG // 2, by, cx + BIG // 2, by + BIG))
    big = src.resize((BIG, BIG), Image.LANCZOS)
    img.paste(big, (cx - BIG // 2, by), big)

    sy = by + BIG + SY
    d.rounded_rectangle([cx - 100, sy - 8, cx + 100, sy + SMALL + 8],
                        radius=8, fill=CELL_BG, outline=(64, 56, 47), width=1)
    for j, (px, lbl) in enumerate([(44, "44px"), (88, "88px 2×")]):
        sm = src.resize((px, px), Image.LANCZOS)
        sx = cx - 60 + j * 66
        img.paste(sm, (sx, sy + (SMALL - px) // 2), sm)
        d.text((sx + px // 2, sy + SMALL + 26), lbl, font=F_XS, fill=DIM, anchor="ma")

img.convert("RGB").save(OUT, quality=95)
print("saved", OUT, img.size)
