# -*- coding: utf-8 -*-
"""R807：诅咒娃娃 9276 卡图「画风回调」后处理 —— 448×404 + 三条垂直偏移候选 + 可见带对比页。

用法：python _prep_doll.py card_9276_style_v1 style_v1
可见带 = 448x404 的第 68..335 行（CARD_ART_RATIO=0.662）。
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = "E:/work/card_rogue/"
BASE = ROOT + "art_src/2026-11-18_诡异洋房与诅咒娃娃_R807/"
OUT = BASE + "processed/"
TARGET = (448, 404)
RATIO = TARGET[0] / float(TARGET[1])
BAND = (68, 335)

os.makedirs(OUT, exist_ok=True)

src_name = sys.argv[1] if len(sys.argv) > 1 else "card_9276_style_v1"
tag = sys.argv[2] if len(sys.argv) > 2 else "style_v1"
SRC = BASE + "raw/" + src_name + ".png"


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


def band_pv(im404, dim=0.8):
    pv = im404.copy().convert("RGB")
    ov = Image.new("RGB", pv.size, (0, 0, 0))
    pv.paste(Image.blend(pv.crop((0, 0, 448, BAND[0])), ov.crop((0, 0, 448, BAND[0])), dim),
             (0, 0))
    pv.paste(Image.blend(pv.crop((0, BAND[1], 448, 404)), ov.crop((0, BAND[1], 448, 404)), dim),
             (0, BAND[1]))
    d = ImageDraw.Draw(pv)
    d.line([(0, BAND[0]), (447, BAND[0])], fill=(255, 70, 70), width=1)
    d.line([(0, BAND[1]), (447, BAND[1])], fill=(255, 70, 70), width=1)
    return pv


src = Image.open(SRC).convert("RGB")
CAND = [("dy0", 0), ("dy25", 25), ("dy51", 51)]
made = []
for t, dy in CAND:
    im, box = prep(src, dy)
    im.save(OUT + "9276_%s_%s.png" % (tag, t))
    made.append((t, im, box))
    print("  %-6s top=%d" % (t, box[1]))

W, H = 448, 404
sheet = Image.new("RGB", (W * 3 + 20, H * 2 + 56), (22, 18, 28))
d = ImageDraw.Draw(sheet)
for i, (t, im, box) in enumerate(made):
    x = i * (W + 10)
    sheet.paste(im, (x, 0))
    sheet.paste(band_pv(im), (x, H + 24))
    d.text((x + 8, H + 6), "9276 %s %s top=%d" % (tag, t, box[1]), fill=(236, 222, 255))
sheet.save(OUT + "_compare3_%s.png" % tag)
print("done", sheet.size, "src", src.size)
