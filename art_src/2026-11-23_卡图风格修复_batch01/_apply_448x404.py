# -*- coding: utf-8 -*-
"""batch01 修订图 -> assets/pics 落图（R874）。

口径（沿用 art_src 其它批次）：
  * 卡图窗槽位 448×404（现役 328 张里 324 张是这个尺寸）；
  * 按 448:404 比例裁切，**纵向 0.30 锚点**（宁可裁脚，不裁头 —— 与 card_face R843i-3 同一口径）；
  * LANCZOS 重采样，RGB，写 assets/pics/<id>.png；
  * 同时在源目录留一张 `定稿_448x404_<id>_<名>.png` 供回看。
四张原图底部 25% 已逐张目视核过：无水印，无需切底。
"""
import os
from PIL import Image

SRC_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(SRC_DIR))
OUT_DIR = os.path.join(ROOT, "assets", "pics")

W, H = 448, 404
ANCHOR_Y = 0.30          # 纵向裁切锚点：0=保头顶，1=保脚底

JOB = [
    ("8025_素体.png", "8025.png", "素体"),
    ("8026_构装体_v2.png", "8026.png", "构装体"),
    ("8027_升级.png", "8027.png", "升级"),
    ("8030_过载.png", "8030.png", "过载"),
]

target = W / H
for src, dst, tag in JOB:
    im = Image.open(os.path.join(SRC_DIR, src)).convert("RGB")
    w, h = im.size
    cur = w / h
    if abs(cur - target) > 1e-4:
        if cur > target:                  # 太宽 -> 左右裁
            nw = int(round(h * target))
            x0 = (w - nw) // 2
            im = im.crop((x0, 0, x0 + nw, h))
        else:                             # 太高 -> 上下裁（锚点偏上）
            nh = int(round(w / target))
            y0 = int(round((h - nh) * ANCHOR_Y))
            im = im.crop((0, y0, w, y0 + nh))
    im = im.resize((W, H), Image.LANCZOS)
    im.save(os.path.join(OUT_DIR, dst))
    im.save(os.path.join(SRC_DIR, "定稿_448x404_%s_%s" % (tag, dst)))
    print("OK %-22s %sx%s -> %s  448x404" % (src, w, h, dst), flush=True)

print("done")
