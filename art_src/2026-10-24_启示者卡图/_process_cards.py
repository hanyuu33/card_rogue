#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""R357 / R368：启示者三阶段卡图处理 —— 切水印 → 居中裁 1.111 → LANCZOS 448×403。

口径与 art_src 里其它批次一致：
  * 原图 1024×1024（生成模型的最接近方形尺寸）；
  * 切掉底部 11%（右下角「AI生成 / WORKBUDDY」水印）；
  * 按卡图窗比例 448:403 居中裁（不多裁主体）；
  * LANCZOS → 448×403，写进 assets/pics/。

R368 重画后，三张分居 raw3 / raw6 / raw9 三个子目录（每轮探索各占一个），
所以 JOB 的路径带上子目录名；重跑这个脚本会原样还原当前定稿。
"""

import os

from PIL import Image

SRC_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(SRC_DIR))
OUT_DIR = os.path.join(ROOT, "assets", "pics")

W, H = 448, 403
JOB = [
    ("raw9/Japanese_anime_science_fiction_2026-10-24T12-49-39.png",
     "9200.png", "阶段1_舰炮齐射"),
    ("raw3/Japanese_anime_science_fiction_2026-10-24T12-41-53.png",
     "9200_p2.png", "阶段2_六边穹顶"),
    ("raw6/Japanese_anime_science_fiction_2026-10-24T12-43-33.png",
     "9200_p3.png", "阶段3_熔光下沉"),
]

for src, dst, tag in JOB:
    p = os.path.join(SRC_DIR, src)
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
    im.save(os.path.join(OUT_DIR, dst))
    im.save(os.path.join(SRC_DIR, "定稿_%s_%s" % (tag, dst)))
    print("OK %s -> %s (%s)" % (src, dst, tag))

print("done")
