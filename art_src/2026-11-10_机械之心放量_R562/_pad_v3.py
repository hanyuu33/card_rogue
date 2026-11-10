# -*- coding: utf-8 -*-
"""R562 v3 兜底：8032 / 9167 的 v2 内容合格，但四周贴边。

448x403 裁窗固定切掉上下各 63px（5%），v2 里右上肩甲、塔顶天线杆尖端被削。
纪律 E 说「返工只重出图、不动裁切」；但模型两次都没把留白守到位（占幅被参考图带走），
所以这里用确定性的画布延展：成图等比缩到 84% 居中贴回 1254 方图，
底图 = 同一张的高斯模糊版，边缘羽化过渡。裁切仍走标准 cardart_prep.py，不改裁窗。
"""
import os
from PIL import Image, ImageFilter, ImageDraw, ImageEnhance

D = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(D, "raw")
SCALE = 0.84
FEATHER = 24

for cid, name in [(8032, "侦察塔"), (9167, "合体")]:
    src = os.path.join(RAW, "%d_%s_v2.png" % (cid, name))
    dst = os.path.join(RAW, "%d_%s_v3.png" % (cid, name))
    im = Image.open(src).convert("RGB")
    S = im.width
    w = int(S * SCALE)
    off = (S - w) // 2

    small = im.resize((w, w), Image.LANCZOS)
    bg = ImageEnhance.Brightness(im.filter(ImageFilter.GaussianBlur(30))).enhance(0.80)

    mask = Image.new("L", (w, w), 0)
    ImageDraw.Draw(mask).rectangle(
        [FEATHER, FEATHER, w - FEATHER, w - FEATHER], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(FEATHER // 2))

    canvas = bg.copy()
    canvas.paste(small, (off, off), mask)
    canvas.save(dst)
    print("%d %s -> %s  (%d -> %d, 贴边 %dpx)" % (
        cid, name, os.path.basename(dst), S, w, off))
