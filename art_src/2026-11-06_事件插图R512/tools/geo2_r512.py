# -*- coding: utf-8 -*-
"""量 bg_core_contract.png（1280×720）中央凹槽的圆心与半径。"""
from PIL import Image

im = Image.open('D:/work/card_rogue/assets/ui/bg_core_contract.png').convert('L')
w, h = im.size
px = im.load()

# 在石台范围内找「暗坑」：亮度低于阈值且被亮刻痕包围
best = None
for thr in (70, 80, 90, 100, 110):
    xs, ys = [], []
    for y in range(280, 520):
        for x in range(380, 900):
            if px[x, y] < thr:
                xs.append(x)
                ys.append(y)
    if not xs:
        continue
    cx = sum(xs) / len(xs)
    cy = sum(ys) / len(ys)
    bw = max(xs) - min(xs)
    bh = max(ys) - min(ys)
    print('thr=%d  n=%5d  bbox x %d..%d (w %d)  y %d..%d (h %d)  centroid (%.0f, %.0f)'
          % (thr, len(xs), min(xs), max(xs), bw, min(ys), max(ys), bh, cx, cy))
