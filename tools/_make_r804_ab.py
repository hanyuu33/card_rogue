# -*- coding: utf-8 -*-
"""R804：连斩新旧版本 A/B 对比（完整图 + 可见带蒙版 + 实际卡面尺寸）。

旧版 = assets/pics/9272.png（R803 codex 出的双刀交叉版）
新版 = processed/9272_b_dy+40.png
"""
import os

from PIL import Image, ImageDraw

ROOT = "E:/work/card_rogue/"
BASE = ROOT + "art_src/2026-11-18_连斩_重出_R804/"
OUT = BASE + "processed/"
BAND = (68, 335)

OLD = ROOT + "assets/pics/9272.png"
NEW = OUT + "9272_b_dy+40.png"


def band(im404):
    pv = im404.copy().convert("RGB")
    ov = Image.new("RGB", pv.size, (0, 0, 0))
    pv.paste(Image.blend(pv.crop((0, 0, 448, BAND[0])), ov.crop((0, 0, 448, BAND[0])), 0.8), (0, 0))
    pv.paste(Image.blend(pv.crop((0, BAND[1], 448, 404)), ov.crop((0, BAND[1], 448, 404)), 0.8),
             (0, BAND[1]))
    return pv


old = Image.open(OLD).convert("RGB")
new = Image.open(NEW).convert("RGB")

# 1) 大图对比：旧 / 新 / 旧可见带 / 新可见带
cols = [old, new, band(old), band(new)]
sheet = Image.new("RGB", (448 * 4 + 30, 404 + 26), (22, 18, 28))
d = ImageDraw.Draw(sheet)
labels = ["old 9272", "new 9272", "old band", "new band"]
for i, c in enumerate(cols):
    x = i * (448 + 10)
    sheet.paste(c, (x, 0))
    d.text((x + 8, 408), labels[i], fill=(236, 222, 255))
sheet.save(OUT + "_ab_full.png")
print("_ab_full.png", sheet.size)

# 2) 实际尺寸对比：战场 77×92、手牌 99×119（卡图区按 448:404 等比内嵌）
rows = []
for name, (cw, ch) in [("battle 77x92", (77, 92)), ("hand 99x119", (99, 119))]:
    rows.append((name, cw, ch))
sheet2 = Image.new("RGB", (600, 300), (22, 18, 28))
d2 = ImageDraw.Draw(sheet2)
y = 16
for name, cw, ch in rows:
    d2.text((12, y), name, fill=(236, 222, 255))
    x = 130
    for tag, im in [("old", old), ("new", new)]:
        # 卡图区：卡面高度约 66%，宽度按 448:404 比例
        artscale = ch * 0.66
        aw = artscale * 448.0 / 404.0
        a = im.resize((max(1, int(aw)), max(1, int(artscale))), Image.LANCZOS)
        card = Image.new("RGB", (cw, ch), (40, 32, 52))
        card.paste(a, ((cw - a.width) // 2, int(ch * 0.10)))
        sheet2.paste(card, (x, y - 4))
        d2.text((x, y + ch), tag, fill=(200, 190, 220))
        x += cw + 60
    y += ch + 54
sheet2.save(OUT + "_ab_size.png")
print("_ab_size.png", sheet2.size)
