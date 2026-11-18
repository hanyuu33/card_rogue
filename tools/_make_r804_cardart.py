# -*- coding: utf-8 -*-
"""R804：连斩 9272 卡图重出（构图修正：同一护手扇面，非双刀交叉）→ 448×404。

因为主体偏右下（刀柄在角落），先出几个垂直偏移的候选，再用「可见带」预览挑一个。
可见带口径：448×404 的第 68..335 行（CARD_ART_RATIO=0.662），只有这段真的会显示。
"""
import os

from PIL import Image, ImageDraw

ROOT = "E:/work/card_rogue/"
BASE = ROOT + "art_src/2026-11-18_连斩_重出_R804/"
SRC = BASE + "raw/card_9272_b.png"
OUTP = BASE + "processed/"
TARGET = (448, 404)
RATIO = TARGET[0] / float(TARGET[1])
BAND = (68, 335)  # 可见带行号

os.makedirs(OUTP, exist_ok=True)


def prep(im, dy=0):
    """dy：裁窗垂直偏移（原图尺度像素，正=裁窗下移、保住画面下方）。"""
    w, h = im.size
    tw = int(round(h * RATIO))
    if tw <= w:
        left = (w - tw) // 2
        box = (left, 0, left + tw, h)
    else:
        th = int(round(w / RATIO))
        top = (h - th) // 2 + dy
        top = max(0, min(h - th, top))
        box = (0, top, w, top + th)
    return im.crop(box).resize(TARGET, Image.LANCZOS), box


def band_preview(im404, path):
    """模拟卡面：可见带之外压暗，用来判断主体有没有掉出显示区。"""
    pv = im404.copy().convert("RGB")
    ov = Image.new("RGB", pv.size, (0, 0, 0))
    pv.paste(Image.blend(pv.crop((0, 0, 448, BAND[0])), ov.crop((0, 0, 448, BAND[0])), 0.78), (0, 0))
    pv.paste(Image.blend(pv.crop((0, BAND[1], 448, 404)), ov.crop((0, BAND[1], 448, 404)), 0.78),
             (0, BAND[1]))
    d = ImageDraw.Draw(pv)
    d.line([(0, BAND[0]), (447, BAND[0])], fill=(255, 60, 60), width=1)
    d.line([(0, BAND[1]), (447, BAND[1])], fill=(255, 60, 60), width=1)
    pv.save(path)


src = Image.open(SRC).convert("RGB")
CAND = [("dy-60", -60), ("dy0", 0), ("dy+40", 40), ("dy+80", 80)]
made = []
for tag, dy in CAND:
    im404, box = prep(src, dy)
    p = OUTP + "9272_b_%s.png" % tag
    im404.save(p)
    band_preview(im404, OUTP + "pv_%s.png" % tag)
    made.append((tag, box, p))
    print("  %-8s crop=%s" % (tag, box))

# 四联对比（含可见带蒙版）
cell = (448, 404)
sheet = Image.new("RGB", (cell[0] * 4, cell[1] + 24), (24, 20, 30))
for i, (tag, box, p) in enumerate(made):
    sheet.paste(Image.open(OUTP + "pv_%s.png" % tag), (i * cell[0], 0))
    d = ImageDraw.Draw(sheet)
    d.text((i * cell[0] + 8, cell[1] + 6), "9272 %s  crop_top=%d" % (tag, box[1]), fill=(235, 220, 255))
sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS).save(OUTP + "_compare.png")
print("done ->", OUTP + "_compare.png")
