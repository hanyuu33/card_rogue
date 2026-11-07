# -*- coding: utf-8 -*-
"""R518 回归扫图：居中布局在加宽后有没有越界 / 折行错乱。

覆盖：长文案（corecontract / hero / oblivion / divination）、
最多按钮（furnace 系列）、有整屏 CG 的页（delivery / treasure / chest）、
少量普通页（martial / smith / apple / snowleopard / pear）。
产物：_review/sweep_r518/<name>.png，外加一张 3×4 拼图 sweep_r518.png 便于一眼过。
"""
import os
import shutil
import subprocess
import time

from PIL import Image

G = 'C:/Users/Administrator/.workbuddy/binaries/godot/Godot_v4.3-stable_win64_console.exe'
ROOT = 'E:/work/card_rogue'
OUT = os.path.join(ROOT, 'art_src', '2026-11-07_事件插图R515', '_review', 'sweep_r518')
os.makedirs(OUT, exist_ok=True)

SHOTS = [
    ('corecontract', ['--corecontract']),
    ('hero', ['--hero']),
    ('oblivion', ['--oblivion']),
    ('divination', ['--div1']),
    ('treasure', ['--treasure']),
    ('chest', ['--chest']),
    ('moon', ['--moon']),
    ('martial', ['--martial']),
    ('smith', ['--smith']),
    ('apple', ['--apple']),
    ('snowleopard', ['--snowleopard']),
    ('pear', ['--pear']),
]

for name, extra in SHOTS:
    src = os.path.join(ROOT, 'screenshot_event.png')
    if os.path.exists(src):
        os.remove(src)
    t0 = time.time()
    r = subprocess.run([G, '--path', ROOT, 'res://scenes/event.tscn', '--']
                       + extra + ['--screenshot'],
                       cwd=ROOT, capture_output=True, timeout=180)
    dst = os.path.join(OUT, name + '.png')
    if os.path.exists(src):
        shutil.move(src, dst)
        print('%-14s ok   %.1fs' % (name, time.time() - t0))
    else:
        print('%-14s MISSING rc=%d' % (name, r.returncode))
        print((r.stdout or b'').decode('utf-8', 'replace')[-1200:])

# 拼图：3 列 × N 行，每格缩到 544 宽
cell_w = 544
names = [n for n, _ in SHOTS if os.path.exists(os.path.join(OUT, n + '.png'))]
imgs = [Image.open(os.path.join(OUT, n + '.png')) for n in names]
if imgs:
    cell_h = int(cell_w * imgs[0].height / imgs[0].width)
    cols = 3
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new('RGB', (cell_w * cols, cell_h * rows), (20, 16, 28))
    for i, im in enumerate(imgs):
        sheet.paste(im.resize((cell_w, cell_h), Image.LANCZOS),
                    ((i % cols) * cell_w, (i // cols) * cell_h))
    p = os.path.join(OUT, '..', 'sweep_r518.png')
    sheet.save(p)
    print('sheet ->', p, sheet.size)
