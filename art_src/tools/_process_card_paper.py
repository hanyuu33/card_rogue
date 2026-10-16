# -*- coding: utf-8 -*-
"""卡片底图 v4 处理（R193）：裁水印 + 缩放到 640 宽 + 取底部 772 + 输出分区坐标。"""
from PIL import Image
import json

SRC = r'D:\work\gen_raw\Blank_fantasy_trading_card_tem_2026-10-16T12-40-22.png'
DST = r'D:\work\card_rogue\assets\ui\card_paper.png'
REPORT = r'D:\work\card_rogue\assets\ui\card_paper_layout.json'

img = Image.open(SRC).convert('RGB')
w, h = img.size

# 裁掉右下角 AI 水印（底部约 55px）
crop = img.crop((0, 0, w, h - 55))
cw, ch = crop.size

# 等比缩放到宽 640，再取底部 772 px（保留完整底纹姓名牌）
scale = 640.0 / cw
scaled = crop.resize((640, int(round(ch * scale))), Image.LANCZOS)
sw, sh = scaled.size
final_h = 772
if sh < final_h:
    pad = Image.new('RGB', (sw, final_h), (245, 240, 228))
    pad.paste(scaled, (0, final_h - sh))
    out = pad
else:
    out = scaled.crop((0, sh - final_h, sw, sh))
fw, fh = out.size

px = out.load()

def is_gold(c):
    r, g, b = c
    return r > 150 and g > 110 and b < 135 and r > b + 35

row_gold = [sum(1 for x in range(fw) if is_gold(px[x, y])) for y in range(fh)]
peaks = [(y, n) for y, n in enumerate(row_gold) if n > fw * 0.25]
groups = []
for y, n in peaks:
    if groups and y - groups[-1][-1][0] <= 3:
        groups[-1].append((y, n))
    else:
        groups.append([(y, n)])
centers = [sum(y*n for y, n in g) / sum(n for y, n in g) for g in groups]

# art_ratio：取 0.45~0.85 之间的最高金条中心
sep_candidates = [c for c in centers if 0.45 < c/fh < 0.85]
art_ratio = round(min(sep_candidates) / fh, 4) if sep_candidates else 0.662

# 姓名牌内框：按 R193 人工目检定下的安全区（AI 实测因明暗渐变会偏小）
np_x0, np_y0, np_x1, np_y1 = 0.06, 0.745, 0.94, 0.94

# 卡图窗 x 边距：在 art 中部横切，找内框金线列
mid_y = int(fh * art_ratio * 0.5)
gold_cols = []
for x in range(fw):
    n = sum(1 for y in range(max(0, mid_y-20), min(fh, mid_y+20)) if is_gold(px[x, y]))
    if n > 6:
        gold_cols.append(x)
art_x0 = round((gold_cols[0] + 4) / fw, 4) if gold_cols else 0.06
art_x1 = round((gold_cols[-1] - 4) / fw, 4) if gold_cols else 0.94

layout = {
    "note": "card_paper.png v4 分区坐标（归一化，R193 PIL 从 AI 生成底图实测）",
    "art_ratio": art_ratio,
    "gold_centers": [round(c / fh, 4) for c in centers],
    "art_window": {
        "x0": art_x0,
        "x1": art_x1,
        "y0": 0.03,
        "y1": round(art_ratio - 0.015, 4),
    },
    "nameplate": {
        "x0": np_x0,
        "y0": np_y0,
        "x1": np_x1,
        "y1": np_y1,
    }
}
print(json.dumps(layout, ensure_ascii=False, indent=1))

out.save(DST)
with open(REPORT, 'w', encoding='utf-8') as f:
    json.dump(layout, f, ensure_ascii=False, indent=1)
print('saved:', DST, out.size)
