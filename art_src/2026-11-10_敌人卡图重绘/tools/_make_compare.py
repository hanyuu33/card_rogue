# -*- coding: utf-8 -*-
"""生成 7 张敌人卡重绘的新旧对比拼图（旧 | 新，逐行）."""
from PIL import Image, ImageDraw, ImageFont
import os

ROOT = 'E:/work/card_rogue'
ids = [
    ('1013', '灰烬龙'),
    ('1061', '爆裂机甲'),
    ('9014', '远古虚骨龙'),
    ('9132', '俄倪厄'),
    ('9135', '赫菲斯托斯'),
    ('9200', '启示者'),
    ('9237', '巴兰-α'),
]
OLD = os.path.join(ROOT, 'assets', 'pics')
NEW = os.path.join(ROOT, 'assets', 'pics', '_pending')
label_w = 150
cell_w = 448
cell_h = 403
pad = 16
row_h = cell_h + 30
W = label_w + cell_w * 2 + pad * 4
H = len(ids) * row_h + pad * 2
canvas = Image.new('RGB', (W, H), (26, 27, 31))
d = ImageDraw.Draw(canvas)
try:
    f = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22)
    fb = ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttc', 34)
except Exception:
    f = ImageFont.load_default()
    fb = f
bar_h = 44
for i, (cid, name) in enumerate(ids):
    y = pad + i * row_h
    d.text((pad + 6, y + 8), '%s\n%s' % (cid, name), fill=(240, 230, 200), font=f)
    old = Image.open(os.path.join(OLD, cid + '.png')).convert('RGB')
    ox = label_w + pad
    canvas.paste(old, (ox, y))
    d.rectangle([ox, y, ox + cell_w - 1, y + bar_h - 1], fill=(190, 80, 30))
    d.text((ox + 12, y + 3), '旧', fill=(255, 255, 255), font=fb)
    new = Image.open(os.path.join(NEW, cid + '.png')).convert('RGB')
    nx = ox + cell_w + pad
    canvas.paste(new, (nx, y))
    d.rectangle([nx, y, nx + cell_w - 1, y + bar_h - 1], fill=(30, 150, 70))
    d.text((nx + 12, y + 3), '新', fill=(255, 255, 255), font=fb)
out = os.path.join(ROOT, '_preview', 'enemy_rework_compare.png')
os.makedirs(os.path.dirname(out), exist_ok=True)
canvas.save(out)
print('saved', out, canvas.size)
