# -*- coding: utf-8 -*-
"""9242 普罗诺亚之影：v2 头顶几乎贴上边缘，448x403 裁窗只用更紧一点就会削头。

店长 2026-11-11 提醒「感觉很容易被裁掉脑袋，要小心使用」。
按纪律 G 用确定性画布延展兜底：成图等比缩到 84% 居中贴回 1254 方图，
底图 = 同图高斯模糊 + 压暗，边缘羽化过渡。
裁切仍走标准 cardart_prep.py，448x403 裁窗一笔不动，画风不改。
"""
import os
from PIL import Image, ImageFilter, ImageDraw, ImageEnhance

D = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(D, "raw")
SCALE = 0.84
FEATHER = 24

cid, name = 9242, "普罗诺亚之影"
src = os.path.join(RAW, "%d_%s_v2.png" % (cid, name))
dst = os.path.join(RAW, "%d_%s_v3.png" % (cid, name))
im = Image.open(src).convert("RGB")
S = im.width
w = int(S * SCALE)
off = (S - w) // 2

small = im.resize((w, w), Image.LANCZOS)
bg = ImageEnhance.Brightness(im.filter(ImageFilter.GaussianBlur(30))).enhance(0.80)
mask = Image.new("L", (w, w), 0)
ImageDraw.Draw(mask).rectangle([FEATHER, FEATHER, w - FEATHER, w - FEATHER], fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(FEATHER // 2))
canvas = bg.copy()
canvas.paste(small, (off, off), mask)
canvas.save(dst)
print("%d %s -> %s  (%d -> %d, 每边留 %dpx)" % (
    cid, name, os.path.basename(dst), S, w, off))
