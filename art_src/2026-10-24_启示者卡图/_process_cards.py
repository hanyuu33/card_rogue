#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""R357：启示者三阶段卡图处理 —— 切水印 → 居中裁 1.111 → LANCZOS 448×403。

口径与 art_src 里其它批次一致：
  * 原图 1024×1024（生成模型的最接近方形尺寸）；
  * 切掉底部 11%（右下角「AI生成 / WORKBUDDY」水印）；
  * 按卡图窗比例 448:403 居中裁（不多裁主体）；
  * LANCZOS → 448×403，写进 assets/pics/。
"""

import io
import os

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(ROOT, "art_src", "2026-10-24_启示者卡图", "raw")
OUT_DIR = os.path.join(ROOT, "assets", "pics")
SRC_DIR = os.path.join(ROOT, "art_src", "2026-10-24_启示者卡图")

W, H = 448, 403
JOB = [
    ("Japanese_anime_film_key_visual_2026-10-24T09-54-15.png", "9200.png", "阶段1_远景舰炮"),
    ("Same_futuristic_sky_battleship_2026-10-24T09-54-43.png", "9200_p2.png", "阶段2_近景电磁屏障"),
    ("Japanese_anime_movie_backgroun_2026-10-24T09-56-01.png", "9200_p3.png", "阶段3_室内起火"),
]

for src, dst, tag in JOB:
    p = os.path.join(RAW, src)
    im = Image.open(p).convert("RGB")
    w, h = im.size
    # ① 切掉底部 11%（水印）
    keep_h = int(round(h * 0.89))
    im = im.crop((0, 0, w, keep_h))
    # ② 居中裁成 448:403
    target = W / H
    cur = w / keep_h
    if cur > target:
        nw = int(round(keep_h * target))
        x0 = (w - nw) // 2
        im = im.crop((x0, 0, x0 + nw, keep_h))
    elif cur < target:
        nh = int(round(w / target))
        y0 = (keep_h - nh) // 2
        im = im.crop((0, y0, w, y0 + nh))
    # ③ 缩放
    im = im.resize((W, H), Image.LANCZOS)
    out = os.path.join(OUT_DIR, dst)
    im.save(out)
    im.save(os.path.join(SRC_DIR, "定稿_%s_%s" % (tag, dst)))
    print("OK %s -> %s (%s)" % (src, dst, tag))

print("done")
