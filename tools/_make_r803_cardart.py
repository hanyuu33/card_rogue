# -*- coding: utf-8 -*-
"""R803：codex 出的两张卡图 → 项目规格 448×404（居中等比裁切）。

规格来源：assets/pics 里 326 张定稿图全是 448×404（`tools/cardart_prep.py` 的 TARGET
写的是 403，是旧值；这里跟现网多数保持一致）。

裁法：按 448/404 的宽高比、以图片高度为准算裁窗宽度；若原图不够宽则改为按宽度算高度。
两边都居中，不做非等比拉伸。

用法：python tools/_make_r803_cardart.py
"""
import os

from PIL import Image

ROOT = "E:/work/card_rogue/"
RAW = ROOT + "art_src/2026-11-18_连斩炮火就位与蘑菇_R803/raw/"
TARGET = (448, 404)
RATIO = TARGET[0] / float(TARGET[1])

JOBS = [("card_9272.png", "9272"), ("card_9273.png", "9273")]


def prep(src, dst):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    tw = int(round(h * RATIO))
    if tw <= w:
        left = (w - tw) // 2
        box = (left, 0, left + tw, h)
    else:
        th = int(round(w / RATIO))
        top = (h - th) // 2
        box = (0, top, w, top + th)
    im.crop(box).resize(TARGET, Image.LANCZOS).save(dst)
    print("  %-16s %s  %s -> %s" % (os.path.basename(src), box, im.size, TARGET))


for src, cid in JOBS:
    p = RAW + src
    if not os.path.exists(p):
        print("跳过（raw 缺图）：", src)
        continue
    prep(p, ROOT + "assets/pics/%s.png" % cid)
    # 归档一份成品，和 raw 放一起便于复查
    out = ROOT + "art_src/2026-11-18_连斩炮火就位与蘑菇_R803/processed/%s.png" % cid
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.open(ROOT + "assets/pics/%s.png" % cid).save(out)
print("done")
