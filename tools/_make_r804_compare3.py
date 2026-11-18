# -*- coding: utf-8 -*-
"""R804：b / c 两版连斩卡图 → 448×404，并出三联对比（含可见带蒙版 + 实际尺寸）。"""
import os

from PIL import Image, ImageDraw

ROOT = "E:/work/card_rogue/"
BASE = ROOT + "art_src/2026-11-18_连斩_重出_R804/"
RAW = BASE + "raw/"
OUT = BASE + "processed/"
TARGET = (448, 404)
RATIO = TARGET[0] / float(TARGET[1])
BAND = (68, 335)

os.makedirs(OUT, exist_ok=True)


def prep(im, dy=0):
    w, h = im.size
    tw = int(round(h * RATIO))
    if tw <= w:
        left = (w - tw) // 2
        box = (left, 0, left + tw, h)
    else:
        th = int(round(w / RATIO))
        top = max(0, min(h - th, (h - th) // 2 + dy))
        box = (0, top, w, top + th)
    return im.crop(box).resize(TARGET, Image.LANCZOS), box


def band(im404, dim=0.8):
    pv = im404.copy().convert("RGB")
    ov = Image.new("RGB", pv.size, (0, 0, 0))
    pv.paste(Image.blend(pv.crop((0, 0, 448, BAND[0])), ov.crop((0, 0, 448, BAND[0])), dim), (0, 0))
    pv.paste(Image.blend(pv.crop((0, BAND[1], 448, 404)), ov.crop((0, BAND[1], 448, 404)), dim),
             (0, BAND[1]))
    return pv


old = Image.open(ROOT + "assets/pics/9272.png").convert("RGB")
jobs = [("old", old, 0)]
for tag, src, dy in [("b", "card_9272_b.png", 40), ("c", "card_9272_c.png", 30)]:
    im, box = prep(Image.open(RAW + src).convert("RGB"), dy)
    im.save(OUT + "9272_%s.png" % tag)
    jobs.append((tag, im, box[1]))
    print("  %s crop_top=%d" % (tag, box[1]))

# 三联：完整图 3 张 + 可见带 3 张（上下两排）
W, H = 448, 404
sheet = Image.new("RGB", (W * 3 + 20, H * 2 + 56), (22, 18, 28))
d = ImageDraw.Draw(sheet)
for i, (tag, im, top) in enumerate(jobs):
    x = i * (W + 10)
    sheet.paste(im, (x, 0))
    sheet.paste(band(im), (x, H + 24))
    d.text((x + 8, H + 6), "9272_%s  top=%d" % (tag, top), fill=(236, 222, 255))
sheet.save(OUT + "_compare3_full.png")
print("_compare3_full.png", sheet.size)

# 实际尺寸对照（手牌 99×119）
sheet2 = Image.new("RGB", (99 * 3 + 200, 190), (22, 18, 28))
d2 = ImageDraw.Draw(sheet2)
x = 16
for tag, im, _ in jobs:
    artscale = 119 * 0.66
    aw = artscale * 448.0 / 404.0
    a = im.resize((int(aw), int(artscale)), Image.LANCZOS)
    card = Image.new("RGB", (99, 119), (40, 32, 52))
    card.paste(a, ((99 - a.width) // 2, 12))
    sheet2.paste(card.resize((99 * 2, 119 * 2), Image.NEAREST), (x, 20))
    d2.text((x, 4), tag, fill=(236, 222, 255))
    x += 99 * 2 + 30
sheet2.save(OUT + "_compare3_size.png")
print("_compare3_size.png", sheet2.size)
