# -*- coding: utf-8 -*-
"""R518 出图核验：宽度自适应（不写死接缝 / 卡片宽度）+ 湖中仙女文案。

lake_lady / lakeladylie  验左右布局按文案反推接缝（含结算态文字变短后是否跟着收）
arcane                   验「最长一行 25 字」的按钮组不再被迫缩字号
cardmerchant             验三行按钮 + 最长按钮文案（卡片该加宽）
furnace                  验最多按钮（3 选项 + 离开）的页在加宽后不越界
rest                     验最普通的居中页观感没变
"""
import os
import shutil
import subprocess
import time

G = 'C:/Users/Administrator/.workbuddy/binaries/godot/Godot_v4.3-stable_win64_console.exe'
ROOT = 'E:/work/card_rogue'
OUT = os.path.join(ROOT, 'art_src', '2026-11-07_事件插图R515', '_review')
os.makedirs(OUT, exist_ok=True)

SHOTS = [
    ('r518_lake_lady', ['--lakelady']),
    ('r518_lake_lady_done', ['--lakelady', '--lakeladylie']),
    ('r518_arcane', ['--arcane']),
    ('r518_cardmerchant', ['--cardmerchant']),
    ('r518_furnace', ['--furnace']),
    ('r518_rest', ['--bbq']),
]

for name, extra in SHOTS:
    src = os.path.join(ROOT, 'screenshot_event.png')
    if os.path.exists(src):
        os.remove(src)
    t0 = time.time()
    r = subprocess.run([G, '--path', ROOT, 'res://scenes/event.tscn', '--']
                       + extra + ['--screenshot'],
                       cwd=ROOT, capture_output=True, timeout=180)
    if os.path.exists(src):
        shutil.move(src, os.path.join(OUT, name + '.png'))
        print('%-22s ok   %.1fs  %d KB' % (name, time.time() - t0,
                                           os.path.getsize(os.path.join(OUT, name + '.png')) // 1024))
    else:
        print('%-22s MISSING rc=%d' % (name, r.returncode))
        print((r.stdout or b'').decode('utf-8', 'replace')[-2000:])
