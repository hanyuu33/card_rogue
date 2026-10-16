# -*- coding: utf-8 -*-
# 卡图处理：AI 原图 → 居中裁到卡图窗比例 1.112 → 缩到 448x403 → assets/pics/<id>.png
import os
from PIL import Image

GEN = r"D:\work\gen_raw"
PICS = r"D:\work\card_rogue\assets\pics"
TW, TH = 448, 403
RATIO = TW / TH  # 1.1117

jobs = [
    ("Keep_this_exact_anime_characte_2026-10-15T11-29-03.png", "8004.png"),        # 熊（森林精魄同框）
    ("A_chubby__plump__round_cute_wh_2026-10-15T11-29-48.png", "9047.png"),        # 机械巨鸭
    ("A_giant_hulking_robot_tyrant_a_2026-10-15T11-29-45.png", "8047.png"),        # 嵌合暴君
    ("A_chubby__plump__round_cute_du_2026-10-15T11-29-44.png", "9116.png"),        # 恶魔鸭
    ("Keep_this_exact_chubby_demon_d_2026-10-15T11-32-09.png", "9116_sleep.png"),  # 恶魔鸭·沉睡
]

os.makedirs(PICS, exist_ok=True)
for fn, name in jobs:
    src = os.path.join(GEN, fn)
    im = Image.open(src).convert("RGB")
    w, h = im.size
    r = w / h
    if r > RATIO:                      # 太宽 → 居中裁宽
        nw = int(round(h * RATIO))
        x0 = (w - nw) // 2
        im = im.crop((x0, 0, x0 + nw, h))
    else:                              # 太高 → 居中裁高
        nh = int(round(w / RATIO))
        y0 = (h - nh) // 2
        im = im.crop((0, y0, w, y0 + nh))
    im = im.resize((TW, TH), Image.LANCZOS)
    im.save(os.path.join(PICS, name))
    print("saved", name, im.size)
print("done")
