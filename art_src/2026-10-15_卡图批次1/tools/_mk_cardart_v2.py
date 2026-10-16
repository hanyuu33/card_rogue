# -*- coding: utf-8 -*-
"""卡图批次1 重制（8047 嵌合暴君 / 9047 机械巨鸭）：居中裁到 1.112，缩到 448x403，覆盖入库。"""
import os
from PIL import Image

RATIO = 1.112
OUT_W, OUT_H = 448, 403
ROOT = r"D:\work\card_rogue"
PICS = os.path.join(ROOT, "assets", "pics")

JOBS = [
    (r"D:\work\gen_raw\A_colossal_menacing_robot_tyra_2026-10-15T11-50-57.png", "8047"),
    (r"D:\work\gen_raw\A_chubby__plump__round_cute_wh_2026-10-15T11-50-56.png", "9047"),
]

for src, cid in JOBS:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    # 居中裁到目标比例（以高为基准裁宽）
    tw = int(round(h * RATIO))
    if tw > w:
        tw = w
    x0 = (w - tw) // 2
    im = im.crop((x0, 0, x0 + tw, h))
    im = im.resize((OUT_W, OUT_H), Image.LANCZOS)
    dst = os.path.join(PICS, cid + ".png")
    im.save(dst)
    print(cid, "->", dst, im.size)
print("done")
