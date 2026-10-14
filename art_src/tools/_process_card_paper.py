# -*- coding: utf-8 -*-
"""卡片底图 v2 处理：裁剪 0.83 + 扫分区坐标（金线/窗/名称条）+ 输出工程规格 png。"""
from PIL import Image
import json

SRC = r'D:\work\gen_raw\Trading_card_game_card_frame_t_2026-10-12T11-25-47.png'
DST = r'D:\work\card_rogue\assets\ui\card_paper.png'
REPORT = r'D:\work\card_rogue\assets\ui\card_paper_layout.json'

img = Image.open(SRC).convert('RGB')
w, h = img.size
print('src:', w, h)

# 裁剪：去掉右下角水印 + 裁到 0.83（1024 x 1234）
crop = img.crop((0, 40, 1024, 1274))
cw, ch = crop.size
print('crop:', cw, ch, 'ratio=%.3f' % (cw / ch))

# 扫金线行：中部横条与名称条上下缘（金 = r>150 and g>110 and b<130 and r > b+35）
px = crop.load()
def is_gold(c):
    r, g, b = c
    return r > 150 and g > 110 and b < 135 and r > b + 35

row_gold = []
for y in range(ch):
    n = 0
    for x in range(cw):
        if is_gold(px[x, y]):
            n += 1
    row_gold.append(n)

# 峰值行（>60% 宽度的金行 = 横条中心）
peaks = [(y, n) for y, n in enumerate(row_gold) if n > cw * 0.55]
# 聚类
groups = []
for y, n in peaks:
    if groups and y - groups[-1][-1][0] <= 3:
        groups[-1].append((y, n))
    else:
        groups.append([(y, n)])
centers = [sum(y * n for y, n in g) / sum(n for y, n in g) for g in groups]
print('gold bar centers (y, frac):', [(round(c), round(c / ch, 4)) for c in centers])

# 窗：扫内框金线的左右边界（在窗区 y 中点横切找金线列）
mid_y = ch // 3
gold_cols = []
for x in range(cw):
    n = 0
    for y in range(int(ch * 0.06), int(ch * 0.52)):
        if is_gold(px[x, y]):
            n += 1
    if n > ch * 0.06:
        gold_cols.append(x)
print('art window x range:', (gold_cols[0], gold_cols[-1]) if gold_cols else None)

layout = {
    "note": "card_paper.png v2 分区坐标（归一化，R152 由 PIL 从底图实测）",
    "art_ratio": round(centers[0] / ch, 4) if centers else 0.50,
    "gold_centers": [round(c / ch, 4) for c in centers],
    "art_window": {
        "x0": round((gold_cols[0] + 6) / cw, 4) if gold_cols else 0.07,
        "x1": round((gold_cols[-1] - 6) / cw, 4) if gold_cols else 0.93,
        "y0": 0.055,
        "y1": round(centers[0] / ch - 0.015, 4) if centers else 0.48,
    },
}
print(json.dumps(layout, ensure_ascii=False, indent=1))

# 输出工程规格：640 x 772（0.829）
out = crop.resize((640, 772), Image.LANCZOS)
out.save(DST)
with open(REPORT, 'w', encoding='utf-8') as f:
    json.dump(layout, f, ensure_ascii=False, indent=1)
print('saved:', DST, out.size)
