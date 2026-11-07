# -*- coding: utf-8 -*-
"""R516 出图核验：暗紫肤 + 左右布局。

arcane / delivery 验「整屏 CG 上压暗紫卡片」的观感；
gaze 验 R513 的暗页在统一配色后没有回头变糊；
lake_lady 验新的左右布局（左图右文、无框、右缘代码羽化）。
"""
import os
import shutil
import subprocess
import time

G = 'C:/Users/Administrator/.workbuddy/binaries/godot/Godot_v4.3-stable_win64_console.exe'
ROOT = 'E:/work/card_rogue'
OUT = os.path.join(ROOT, 'art_src', '2026-11-07_事件插图R515', '_review')
os.makedirs(OUT, exist_ok=True)

SHOTS = [('r516_arcane', '--arcane'), ('r516_lake_lady', '--lakelady'),
         ('r516_gaze', '--gaze'), ('r516_delivery', '--delivery')]

for name, arg in SHOTS:
    src = os.path.join(ROOT, 'screenshot_event.png')
    if os.path.exists(src):
        os.remove(src)
    t0 = time.time()
    r = subprocess.run([G, '--path', ROOT, 'res://scenes/event.tscn', '--', arg, '--screenshot'],
                       cwd=ROOT, capture_output=True, timeout=180)
    if os.path.exists(src):
        shutil.move(src, os.path.join(OUT, name + '.png'))
        print('%-16s ok   %.1fs  %d KB' % (name, time.time() - t0,
                                           os.path.getsize(os.path.join(OUT, name + '.png')) // 1024))
    else:
        print('%-16s MISSING rc=%d' % (name, r.returncode))
        print((r.stdout or b'').decode('utf-8', 'replace')[-1500:])
